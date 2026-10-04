import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class DestinationRecommendationService {
  static const String _endpoint =
      'https://places.googleapis.com/v1/places:searchText';

  Future<List<RecommendedDestination>> getRecommendations({
    required String experience,
    required String travelerType,
    required String duration,
    required double budget,
  }) async {
    final apiKey = dotenv.env['PLACES_API_KEY'];

    if (apiKey == null || apiKey.trim().isEmpty) {
      throw Exception('PLACES_API_KEY is missing from the .env file.');
    }

    final queries = _buildQueries(
      experience: experience,
      travelerType: travelerType,
      duration: duration,
      budget: budget,
    );

    final Map<String, Map<String, dynamic>> uniquePlaces = {};

    for (final query in queries) {
      final results = await _searchPlaces(query: query, apiKey: apiKey);

      for (final place in results) {
        final placeId = place['id']?.toString();

        if (placeId == null || placeId.isEmpty) {
          continue;
        }

        uniquePlaces[placeId] = place;
      }
    }

    final destinations = uniquePlaces.values
        .map(
          (place) => _convertToDestination(
            place,
            experience: experience,
            travelerType: travelerType,
            duration: duration,
            budget: budget,
          ),
        )
        .whereType<RecommendedDestination>()
        .toList();

    destinations.sort((a, b) => b.score.compareTo(a.score));

    return destinations.take(8).toList();
  }

  Future<List<Map<String, dynamic>>> _searchPlaces({
    required String query,
    required String apiKey,
  }) async {
    final response = await http.post(
      Uri.parse(_endpoint),
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
        'pageSize': 20,
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
        .map((place) => Map<String, dynamic>.from(place))
        .toList();
  }

  List<String> _buildQueries({
    required String experience,
    required String travelerType,
    required String duration,
    required double budget,
  }) {
    final experienceQuery = _experienceQuery(experience);
    final travelerQuery = _travelerQuery(travelerType);
    final durationQuery = _durationQuery(duration);
    final budgetQuery = _budgetQuery(budget);

    return [
      '$experienceQuery destinations',
      '$experienceQuery $travelerQuery destinations',
      '$experienceQuery $budgetQuery destinations',
      '$experienceQuery $travelerQuery $durationQuery destinations',
    ];
  }

  String _experienceQuery(String experience) {
    return experience
        .split(',')
        .map((item) => _singleExperienceQuery(item.trim()))
        .where((item) => item.isNotEmpty)
        .toSet()
        .join(' ');
  }

  String _singleExperienceQuery(String experience) {
    switch (experience.toLowerCase()) {
      case 'beach':
        return 'beach coastal tropical';
      case 'adventure':
        return 'adventure outdoor trekking rafting';
      case 'nature':
        return 'nature mountains forests wildlife';
      case 'food':
        return 'food culinary street food';
      case 'culture':
        return 'culture historical heritage';
      case 'nightlife':
        return 'nightlife entertainment';
      case 'shopping':
        return 'shopping markets malls';
      case 'relaxation':
        return 'relaxation wellness resort';
      default:
        return experience;
    }
  }

  String _travelerQuery(String travelerType) {
    switch (travelerType.toLowerCase()) {
      case 'solo':
        return 'solo travel';
      case 'couple':
        return 'romantic couple';
      case 'friends':
        return 'friends group';
      case 'family':
        return 'family friendly';
      default:
        return travelerType;
    }
  }

  String _durationQuery(String duration) {
    switch (duration.toLowerCase()) {
      case 'weekend':
        return 'weekend getaway';
      case 'short trip':
        return 'short trip';
      case 'one week':
        return 'one week vacation';
      case 'long escape':
        return 'long vacation';
      default:
        return duration;
    }
  }

  String _budgetQuery(double budget) {
    if (budget < 15000) {
      return 'budget affordable';
    }

    if (budget < 30000) {
      return 'affordable moderate';
    }

    if (budget < 60000) {
      return 'mid range';
    }

    if (budget < 100000) {
      return 'premium';
    }

    return 'luxury';
  }

  RecommendedDestination? _convertToDestination(
    Map<String, dynamic> place, {
    required String experience,
    required String travelerType,
    required String duration,
    required double budget,
  }) {
    final id = place['id']?.toString();

    final displayName = place['displayName'];

    String? name;

    if (displayName is Map<String, dynamic>) {
      name = displayName['text']?.toString();
    }

    name ??= displayName?.toString();

    if (id == null || name == null || name.trim().isEmpty) {
      return null;
    }

    final rating = _toDouble(place['rating']);
    final reviewCount = _toInt(place['userRatingCount']);

    final address = place['formattedAddress']?.toString() ?? '';

    final primaryType = place['primaryType']?.toString() ?? '';

    final types = place['types'] is List
        ? List<String>.from((place['types'] as List).whereType<String>())
        : <String>[];

    final location = place['location'];

    if (location is! Map) {
      return null;
    }

    final latitude = _toDouble(location['latitude']);
    final longitude = _toDouble(location['longitude']);

    if (latitude == 0 && longitude == 0) {
      return null;
    }

    final score = _calculateScore(
      rating: rating,
      reviewCount: reviewCount,
      experience: experience,
      primaryType: primaryType,
      types: types,
    );

    return RecommendedDestination(
      id: id,
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
      rating: rating,
      reviewCount: reviewCount,
      primaryType: primaryType,
      types: types,
      score: score,
    );
  }

  double _calculateScore({
    required double rating,
    required int reviewCount,
    required String experience,
    required String primaryType,
    required List<String> types,
  }) {
    double score = 0;

    // Rating contributes up to 40 points.
    score += (rating / 5.0) * 40;

    // Popularity contributes up to 20 points.
    if (reviewCount > 0) {
      final popularity = (reviewCount.clamp(0, 5000) / 5000) * 20;

      score += popularity;
    }

    final keywords = _experienceKeywords(experience);

    final searchableText = [primaryType, ...types].join(' ').toLowerCase();

    // Experience relevance contributes up to 30 points.
    final matchingKeywords = keywords
        .where((keyword) => searchableText.contains(keyword.toLowerCase()))
        .length;

    if (keywords.isNotEmpty) {
      score += (matchingKeywords / keywords.length) * 30;
    }

    // Small quality bonus for highly rated places.
    if (rating >= 4.5) {
      score += 5;
    }

    // Keep score within 100.
    return score.clamp(0, 100);
  }

  List<String> _experienceKeywords(String experience) {
    return experience
        .split(',')
        .expand((item) => _singleExperienceKeywords(item.trim()))
        .toSet()
        .toList();
  }

  List<String> _singleExperienceKeywords(String experience) {
    switch (experience.toLowerCase()) {
      case 'beach':
        return ['beach', 'coast', 'island', 'resort'];

      case 'adventure':
        return ['adventure', 'park', 'camp', 'hiking', 'sport'];

      case 'nature':
        return ['park', 'nature', 'mountain', 'forest', 'wildlife'];

      case 'food':
        return ['restaurant', 'food', 'cafe', 'bakery'];

      case 'culture':
        return ['museum', 'historical', 'heritage', 'temple', 'church'];

      case 'nightlife':
        return ['bar', 'nightclub', 'entertainment', 'casino'];

      case 'shopping':
        return ['shopping', 'mall', 'market', 'store'];

      case 'relaxation':
        return ['spa', 'resort', 'wellness', 'hotel'];

      default:
        return [];
    }
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

class RecommendedDestination {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double rating;
  final int reviewCount;
  final String primaryType;
  final List<String> types;
  final double score;

  const RecommendedDestination({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.reviewCount,
    required this.primaryType,
    required this.types,
    required this.score,
  });
}
