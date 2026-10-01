import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/trip.dart';
import 'itinerary_generator_service.dart';
import 'route_service.dart';
import 'trip_service.dart';
import 'destination_recommendation_service.dart';

/// Creates the complete trip data needed by the Help Me Choose shortcut.
///
/// The user does not need to fill the normal trip setup screens. The selected
/// recommendation becomes the trip's starting point, nearby attractions are
/// discovered from Google Places, Google Routes orders them, and the existing
/// itinerary generator creates the day-wise plan.
class HelpMeChooseTripService {
  static const String _placesEndpoint =
      'https://places.googleapis.com/v1/places:searchText';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TripService _tripService = TripService();
  final RouteService _routeService = RouteService();
  final ItineraryGeneratorService _itineraryGenerator =
  ItineraryGeneratorService();

  Future<String> createTripAndGenerateItinerary({
    required RecommendedDestination destination,
    required String experience,
    required String travelerType,
    required String duration,
    required double budget,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Please log in before planning a trip.');
    }

    final numberOfDays = _numberOfDays(duration);
    final travelers = _travelerCount(travelerType);
    final startDate = _nextStartDate();
    final endDate = startDate.add(
      Duration(days: numberOfDays - 1),
    );

    final trip = Trip(
      id: '',
      name: destination.name,
      startLocation: destination.name,
      startLatitude: destination.latitude,
      startLongitude: destination.longitude,
      destination: destination.name,
      startDate: startDate,
      endDate: endDate,
      numberOfDays: numberOfDays,
      travelersCount: travelers,
      budget: budget,
      selectedPreferenceIds: [
        experience,
        travelerType,
        duration,
      ],
    );

    final tripId = await _tripService.saveTrip(trip);

    try {
      final attractions = await _findNearbyAttractions(
        destination: destination,
        experience: experience,
      );

      if (attractions.isEmpty) {
        throw Exception(
          'No suitable nearby attractions were found for this destination. '
              'Please choose another recommendation.',
        );
      }

      final stops = attractions
          .map(_toRoutePoint)
          .toList();

      final origin = RoutePoint(
        id: destination.id,
        name: destination.name,
        latitude: destination.latitude,
        longitude: destination.longitude,
        type: 'destination',
      );

      final route = await _routeService.calculateRoute(
        origin: origin,
        stops: stops,
      );

      if (route.orderedPoints.length < 2) {
        throw Exception(
          'Could not create a usable route for this destination.',
        );
      }

      await _firestore
          .collection('trips')
          .doc(tripId)
          .set(
        {
          'route': {
            'distanceMeters': route.distanceMeters,
            'duration': route.duration,
            'optimized': true,
            'orderedStops': route.orderedPoints
                .map((point) => point.toMap())
                .toList(),
            'polylinePoints': route.polylinePoints
                .map(
                  (point) => {
                'latitude': point.latitude,
                'longitude': point.longitude,
              },
            )
                .toList(),
            'generatedAt': FieldValue.serverTimestamp(),
          },
          'planningMode': 'help_me_choose',
          'experience': experience,
          'travelerType': travelerType,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await _itineraryGenerator.generateForTrip(tripId);

      return tripId;
    } catch (e) {
      // Keep the created trip because it is useful for debugging/recovery,
      // but mark the automatic planning attempt as failed.
      await _firestore
          .collection('trips')
          .doc(tripId)
          .set(
        {
          'planningMode': 'help_me_choose',
          'planningError': e.toString(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      rethrow;
    }
  }

  Future<List<_NearbyPlace>> _findNearbyAttractions({
    required RecommendedDestination destination,
    required String experience,
  }) async {
    final apiKey = dotenv.env['PLACES_API_KEY'];

    if (apiKey == null || apiKey.trim().isEmpty) {
      throw Exception(
        'PLACES_API_KEY is missing from the .env file.',
      );
    }

    final queries = _attractionQueries(experience);
    final unique = <String, _NearbyPlace>{};

    for (final query in queries) {
      final places = await _searchNearby(
        query: query,
        destination: destination,
        apiKey: apiKey,
      );

      for (final place in places) {
        if (place.id == destination.id) {
          continue;
        }

        unique[place.id] = place;
      }

      if (unique.length >= 5) {
        break;
      }
    }

    final places = unique.values.toList();

    places.sort((a, b) {
      final ratingCompare = b.rating.compareTo(a.rating);
      if (ratingCompare != 0) {
        return ratingCompare;
      }
      return b.reviewCount.compareTo(a.reviewCount);
    });

    // Four attractions gives the existing itinerary generator enough places
    // to spread across short and longer trips without overloading a day.
    return places.take(4).toList();
  }

  Future<List<_NearbyPlace>> _searchNearby({
    required String query,
    required RecommendedDestination destination,
    required String apiKey,
  }) async {
    final response = await http.post(
      Uri.parse(_placesEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': [
          'places.id',
          'places.displayName',
          'places.formattedAddress',
          'places.location',
          'places.rating',
          'places.userRatingCount',
          'places.primaryType',
          'places.types',
        ].join(','),
      },
      body: jsonEncode({
        'textQuery': query,
        'languageCode': 'en',
        'pageSize': 10,
        'locationBias': {
          'circle': {
            'center': {
              'latitude': destination.latitude,
              'longitude': destination.longitude,
            },
            'radius': 15000.0,
          },
        },
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Google Places API error '
            '(${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      return [];
    }

    final places = decoded['places'];

    if (places is! List) {
      return [];
    }

    return places
        .whereType<Map>()
        .map((place) => _readNearbyPlace(
      Map<String, dynamic>.from(place),
    ))
        .whereType<_NearbyPlace>()
        .toList();
  }

  _NearbyPlace? _readNearbyPlace(
      Map<String, dynamic> place,
      ) {
    final id = place['id']?.toString();
    final displayName = place['displayName'];
    final location = place['location'];

    if (id == null || id.isEmpty || location is! Map) {
      return null;
    }

    String? name;

    if (displayName is Map) {
      name = displayName['text']?.toString();
    }

    name ??= displayName?.toString();

    if (name == null || name.trim().isEmpty) {
      return null;
    }

    final latitude = _toDouble(location['latitude']);
    final longitude = _toDouble(location['longitude']);

    if (latitude == 0 && longitude == 0) {
      return null;
    }

    final types = place['types'] is List
        ? List<String>.from(
      (place['types'] as List).whereType<String>(),
    )
        : <String>[];

    return _NearbyPlace(
      id: id,
      name: name,
      address: place['formattedAddress']?.toString() ?? '',
      latitude: latitude,
      longitude: longitude,
      rating: _toDouble(place['rating']),
      reviewCount: _toInt(place['userRatingCount']),
      primaryType: place['primaryType']?.toString() ?? '',
      types: types,
    );
  }

  RoutePoint _toRoutePoint(_NearbyPlace place) {
    return RoutePoint(
      id: place.id,
      name: place.name,
      latitude: place.latitude,
      longitude: place.longitude,
      type: 'tourist_spot',
    );
  }

  List<String> _attractionQueries(String experience) {
    switch (experience.toLowerCase()) {
      case 'beach':
        return [
          'best beaches and scenic places',
          'beach attractions',
          'coastal tourist attractions',
        ];
      case 'adventure':
        return [
          'adventure attractions',
          'outdoor activities and attractions',
          'hiking parks and adventure places',
        ];
      case 'nature':
        return [
          'nature attractions',
          'parks gardens and scenic places',
          'wildlife and nature places',
        ];
      case 'food':
        return [
          'food attractions and famous food places',
          'local food markets',
          'culinary attractions',
        ];
      case 'culture':
        return [
          'cultural attractions',
          'museums historical places and heritage',
          'temples monuments and heritage places',
        ];
      case 'nightlife':
        return [
          'nightlife attractions',
          'entertainment attractions',
          'popular evening places',
        ];
      case 'shopping':
        return [
          'shopping attractions',
          'popular markets and shopping places',
          'shopping malls and markets',
        ];
      case 'relaxation':
        return [
          'relaxation attractions',
          'spas resorts and wellness places',
          'scenic relaxing places',
        ];
      default:
        return [
          'tourist attractions',
          'popular places to visit',
          'top attractions',
        ];
    }
  }

  int _numberOfDays(String duration) {
    switch (duration.toLowerCase()) {
      case 'weekend':
        return 2;
      case 'short trip':
        return 4;
      case 'one week':
        return 7;
      case 'long escape':
        return 10;
      default:
        return 4;
    }
  }

  int _travelerCount(String travelerType) {
    switch (travelerType.toLowerCase()) {
      case 'solo':
        return 1;
      case 'couple':
        return 2;
      case 'friends':
        return 3;
      case 'family':
        return 4;
      default:
        return 1;
    }
  }

  DateTime _nextStartDate() {
    final now = DateTime.now();
    final candidate = now.add(const Duration(days: 7));

    return DateTime(
      candidate.year,
      candidate.month,
      candidate.day,
    );
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _NearbyPlace {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double rating;
  final int reviewCount;
  final String primaryType;
  final List<String> types;

  const _NearbyPlace({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.reviewCount,
    required this.primaryType,
    required this.types,
  });
}
