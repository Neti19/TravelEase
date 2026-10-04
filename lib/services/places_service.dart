import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../config/api_keys.dart';

class PlacesService {
  static String get _apiKey => ApiKeys.placesApiKey.trim();

  static const String _baseUrl = 'https://places.googleapis.com/v1';

  void _checkKey() {
    if (_apiKey.isEmpty) {
      throw Exception('Places API key is missing.');
    }
  }

  Future<List<Map<String, dynamic>>> autocomplete(
    String input, {
    double? latitude,
    double? longitude,
  }) async {
    _checkKey();

    Object? autocompleteError;
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/places:autocomplete'),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': _apiKey,
              'X-Goog-FieldMask':
                  'suggestions.placePrediction.placeId,'
                  'suggestions.placePrediction.text.text,'
                  'suggestions.placePrediction.structuredFormat',
            },
            body: jsonEncode({
              'input': input,
              'languageCode': 'en',
              if (latitude != null && longitude != null)
                'locationBias': {
                  'circle': {
                    'center': {'latitude': latitude, 'longitude': longitude},
                    'radius': 50000.0,
                  },
                },
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        throw Exception(
          'Places autocomplete failed '
          '(${response.statusCode}): ${response.body}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final suggestions = _readAutocompleteSuggestions(data);
      if (suggestions.isNotEmpty) return suggestions;
    } catch (e) {
      autocompleteError = e;
    }

    try {
      final places = await searchPlaces(
        query: input,
        latitude: latitude,
        longitude: longitude,
        pageSize: 8,
      );

      return places
          .map((place) {
            final displayName = place['displayName'] as Map<String, dynamic>?;
            final name = displayName?['text']?.toString().trim() ?? '';
            final address = place['formattedAddress']?.toString().trim() ?? '';
            return {
              'placeId': place['id']?.toString() ?? '',
              'description': [
                name,
                address,
              ].where((value) => value.isNotEmpty).join(', '),
              'mainText': name,
              'secondaryText': address,
            };
          })
          .where((suggestion) => (suggestion['placeId'] as String).isNotEmpty)
          .toList();
    } catch (textSearchError) {
      if (autocompleteError != null) {
        throw Exception(
          'Destination autocomplete and text search failed. '
          'Autocomplete: $autocompleteError Text search: $textSearchError',
        );
      }
      rethrow;
    }
  }

  List<Map<String, dynamic>> _readAutocompleteSuggestions(
    Map<String, dynamic> data,
  ) {
    final suggestions = data['suggestions'] as List<dynamic>? ?? [];

    return suggestions
        .where((item) => item is Map && item['placePrediction'] is Map)
        .map((item) {
          final prediction = item['placePrediction'] as Map<String, dynamic>;
          final text = prediction['text'] as Map<String, dynamic>?;
          final structured =
              prediction['structuredFormat'] as Map<String, dynamic>?;
          final mainText = structured?['mainText'] as Map<String, dynamic>?;
          final secondaryText =
              structured?['secondaryText'] as Map<String, dynamic>?;

          return <String, dynamic>{
            'placeId': prediction['placeId']?.toString() ?? '',
            'description': text?['text']?.toString() ?? '',
            'mainText': mainText?['text']?.toString() ?? '',
            'secondaryText': secondaryText?['text']?.toString() ?? '',
          };
        })
        .where((item) => (item['placeId'] as String).isNotEmpty)
        .toList();
  }

  Future<Map<String, dynamic>> getPlaceDetails(String placeId) async {
    _checkKey();

    final response = await http
        .get(
          Uri.parse('$_baseUrl/places/$placeId'),
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': _apiKey,
            'X-Goog-FieldMask':
                'id,displayName,formattedAddress,location,types',
          },
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
        'Place details failed '
        '(${response.statusCode}): ${response.body}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> searchPlaces({
    required String query,
    double? latitude,
    double? longitude,
    int pageSize = 8,
    bool detailed = false,
  }) async {
    _checkKey();

    final response = await http
        .post(
          Uri.parse('$_baseUrl/places:searchText'),
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': _apiKey,
            'X-Goog-FieldMask':
                'places.id,'
                'places.displayName,'
                'places.formattedAddress,'
                'places.location,'
                'places.types'
                '${detailed ? ',places.rating,places.userRatingCount,places.priceLevel,places.priceRange,places.regularOpeningHours' : ''}',
          },
          body: jsonEncode({
            'textQuery': query,
            'pageSize': pageSize,
            if (latitude != null && longitude != null)
              'locationBias': {
                'circle': {
                  'center': {'latitude': latitude, 'longitude': longitude},
                  'radius': 50000.0,
                },
              },
            'regionCode': 'IN',
            'languageCode': 'en',
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
        'Places search failed '
        '(${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    final places = data['places'] as List<dynamic>? ?? [];

    return places.map((place) => place as Map<String, dynamic>).toList();
  }

  // ------------------------------------------------------------
  // NEARBY DESTINATIONS
  // ------------------------------------------------------------

  Future<List<Map<String, dynamic>>> searchNearbyDestinations({
    required double latitude,
    required double longitude,
    double radius = 10000,
    int maxResultCount = 10,
  }) async {
    _checkKey();

    final headers = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': _apiKey,
      'X-Goog-FieldMask':
          'places.id,'
          'places.displayName,'
          'places.formattedAddress,'
          'places.location,'
          'places.types,'
          'places.rating,'
          'places.userRatingCount',
    };
    final center = {'latitude': latitude, 'longitude': longitude};
    Object? nearbySearchError;

    try {
      final response = await http
          .post(
        Uri.parse('$_baseUrl/places:searchNearby'),
        headers: headers,
        body: jsonEncode({
          'includedTypes': [
            'tourist_attraction',
            'museum',
            'park',
            'amusement_park',
            'historical_landmark',
            'art_gallery',
            'zoo',
            'aquarium',
            'shopping_mall',
          ],
          'maxResultCount': maxResultCount,
          'rankPreference': 'DISTANCE',
          'locationRestriction': {
            'circle': {'center': center, 'radius': radius},
          },
          'regionCode': 'IN',
          'languageCode': 'en',
        }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception(
          'Nearby destination search failed '
          '(${response.statusCode}): ${response.body}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final places = List<Map<String, dynamic>>.from(data['places'] ?? []);
      if (places.isNotEmpty) return places;
    } catch (e) {
      nearbySearchError = e;
    }

    try {
      final response = await http
          .post(
        Uri.parse('$_baseUrl/places:searchText'),
        headers: headers,
        body: jsonEncode({
          'textQuery': 'tourist attractions and points of interest',
          'pageSize': maxResultCount.clamp(1, 20),
          'locationBias': {
            'circle': {'center': center, 'radius': radius},
          },
          'regionCode': 'IN',
          'languageCode': 'en',
        }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception(
          'Destination text search failed '
          '(${response.statusCode}): ${response.body}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final places = List<Map<String, dynamic>>.from(data['places'] ?? []);
      return places.where((place) {
        final location = place['location'] as Map<String, dynamic>?;
        final lat = (location?['latitude'] as num?)?.toDouble();
        final lng = (location?['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) return false;
        return _distanceInMeters(latitude, longitude, lat, lng) <= radius;
      }).toList();
    } catch (textSearchError) {
      if (nearbySearchError != null) {
        throw Exception(
          'Nearby and text destination searches failed. '
          'Nearby: $nearbySearchError Text search: $textSearchError',
        );
      }
      rethrow;
    }
  }

  // ------------------------------------------------------------
  // NEARBY HOTELS
  // ------------------------------------------------------------

  Future<List<Map<String, dynamic>>> searchNearbyHotels({
    required double latitude,
    required double longitude,
    double radius = 10000,
    int maxResultCount = 20,
  }) async {
    _checkKey();

    final headers = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': _apiKey,
      'X-Goog-FieldMask':
          'places.id,'
          'places.displayName,'
          'places.formattedAddress,'
          'places.location,'
          'places.rating,'
          'places.userRatingCount,'
          'places.priceLevel,'
          'places.priceRange,'
          'places.types,'
          'places.googleMapsUri',
    };
    final center = {'latitude': latitude, 'longitude': longitude};

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/places:searchNearby'),
            headers: headers,
            body: jsonEncode({
              'includedTypes': ['lodging'],
              'maxResultCount': maxResultCount,
              'rankPreference': 'DISTANCE',
              'locationRestriction': {
                'circle': {'center': center, 'radius': radius},
              },
              'regionCode': 'IN',
              'languageCode': 'en',
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception(
          'Nearby hotel search failed '
          '(${response.statusCode}): ${response.body}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final places = List<Map<String, dynamic>>.from(data['places'] ?? []);
      if (places.isNotEmpty) return places;
    } catch (e) {
      // Text Search below can still return hotels if Nearby Search has
      // no matches in the requested radius or its endpoint rejects a filter.
      try {
        return await _searchHotelsByText(
          latitude: latitude,
          longitude: longitude,
          radius: radius,
          maxResultCount: maxResultCount,
          headers: headers,
          center: center,
        );
      } catch (fallbackError) {
        throw Exception(
          'Nearby and text hotel searches failed. '
          'Nearby: $e Text search: $fallbackError',
        );
      }
    }

    return _searchHotelsByText(
      latitude: latitude,
      longitude: longitude,
      radius: radius,
      maxResultCount: maxResultCount,
      headers: headers,
      center: center,
    );
  }

  Future<List<Map<String, dynamic>>> _searchHotelsByText({
    required double latitude,
    required double longitude,
    required double radius,
    required int maxResultCount,
    required Map<String, String> headers,
    required Map<String, double> center,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/places:searchText'),
          headers: headers,
          body: jsonEncode({
            'textQuery': 'hotels',
            'pageSize': maxResultCount,
            'locationBias': {
              'circle': {'center': center, 'radius': radius},
            },
            'regionCode': 'IN',
            'languageCode': 'en',
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
        'Hotel text search failed '
        '(${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final places = List<Map<String, dynamic>>.from(data['places'] ?? []);
    return places.where((place) {
      final location = place['location'] as Map<String, dynamic>?;
      final lat = (location?['latitude'] as num?)?.toDouble();
      final lng = (location?['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return false;
      return _distanceInMeters(latitude, longitude, lat, lng) <= radius;
    }).toList();
  }

  Future<String> getLocationName({
    required double latitude,
    required double longitude,
  }) async {
    _checkKey();

    // Reverse geocoding gives the user a readable locality on Flutter Web,
    // where the native geocoding plugin is not available.
    try {
      final reverseResponse = await http
          .get(
            Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
              'latlng': '$latitude,$longitude',
              'key': _apiKey,
              'language': 'en',
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (reverseResponse.statusCode == 200) {
        final reverseData =
            jsonDecode(reverseResponse.body) as Map<String, dynamic>;
        final results = reverseData['results'] as List<dynamic>? ?? [];
        if (results.isNotEmpty) {
          final result = results.first as Map<String, dynamic>;
          final address = result['formatted_address']?.toString();
          if (address != null && address.trim().isNotEmpty) {
            return address;
          }
        }
      }
    } catch (_) {
      // Continue with Places search below; callers can still show coordinates.
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/places:searchText'),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _apiKey,
        'X-Goog-FieldMask': 'places.displayName,places.formattedAddress',
      },
      body: jsonEncode({
        'textQuery': 'location near $latitude, $longitude',
        'pageSize': 1,
        'locationBias': {
          'circle': {
            'center': {'latitude': latitude, 'longitude': longitude},
            'radius': 1000.0,
          },
        },
        'regionCode': 'IN',
        'languageCode': 'en',
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Location lookup failed '
        '(${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    final places = data['places'] as List<dynamic>? ?? [];

    if (places.isEmpty) {
      return 'Location near ${latitude.toStringAsFixed(5)}, '
          '${longitude.toStringAsFixed(5)}';
    }

    final place = places.first as Map<String, dynamic>;

    final formattedAddress = place['formattedAddress']?.toString();

    if (formattedAddress != null && formattedAddress.isNotEmpty) {
      return formattedAddress;
    }

    final displayName = place['displayName'] as Map<String, dynamic>?;

    final name = displayName?['text']?.toString();
    if (name != null && name.trim().isNotEmpty) return name;
    return 'Location near ${latitude.toStringAsFixed(5)}, '
        '${longitude.toStringAsFixed(5)}';
  }
  // ------------------------------------------------------------
  // NEARBY RESTAURANTS
  // ------------------------------------------------------------

  Future<List<Map<String, dynamic>>> searchNearbyRestaurants({
    required double latitude,
    required double longitude,
    double radius = 5000,
    int maxResultCount = 20,
    List<String> includedTypes = const ['restaurant'],
    bool includeOpeningHours = false,
  }) async {
    _checkKey();

    final headers = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': _apiKey,
      'X-Goog-FieldMask':
          'places.id,'
          'places.displayName,'
          'places.formattedAddress,'
          'places.location,'
          'places.rating,'
          'places.userRatingCount,'
          'places.priceLevel,'
          'places.priceRange,'
          'places.types,'
          'places.googleMapsUri'
          '${includeOpeningHours ? ',places.regularOpeningHours' : ''}',
    };
    final center = {'latitude': latitude, 'longitude': longitude};
    Object? nearbySearchError;

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/places:searchNearby'),
            headers: headers,
            body: jsonEncode({
              'includedTypes': includedTypes,
              'maxResultCount': maxResultCount,
              'rankPreference': 'DISTANCE',
              'locationRestriction': {
                'circle': {'center': center, 'radius': radius},
              },
              'regionCode': 'IN',
              'languageCode': 'en',
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception(
          'Nearby restaurant search failed '
          '(${response.statusCode}): ${response.body}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final places = List<Map<String, dynamic>>.from(data['places'] ?? []);
      if (places.isNotEmpty) return places;
    } catch (e) {
      nearbySearchError = e;
    }

    try {
      return await _searchRestaurantsByText(
        latitude: latitude,
        longitude: longitude,
        radius: radius,
        maxResultCount: maxResultCount,
        includeBreakfast: includedTypes.contains('breakfast_restaurant'),
        headers: headers,
        center: center,
      );
    } catch (textSearchError) {
      if (nearbySearchError != null) {
        throw Exception(
          'Nearby and text restaurant searches failed. '
          'Nearby: $nearbySearchError Text search: $textSearchError',
        );
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _searchRestaurantsByText({
    required double latitude,
    required double longitude,
    required double radius,
    required int maxResultCount,
    required bool includeBreakfast,
    required Map<String, String> headers,
    required Map<String, double> center,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/places:searchText'),
          headers: headers,
          body: jsonEncode({
            'textQuery': includeBreakfast
                ? 'breakfast restaurants cafes bakeries'
                : 'restaurants',
            'pageSize': maxResultCount,
            'locationBias': {
              'circle': {'center': center, 'radius': radius},
            },
            'regionCode': 'IN',
            'languageCode': 'en',
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
        'Restaurant text search failed '
        '(${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final places = List<Map<String, dynamic>>.from(data['places'] ?? []);
    return places.where((place) {
      final location = place['location'] as Map<String, dynamic>?;
      final lat = (location?['latitude'] as num?)?.toDouble();
      final lng = (location?['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return false;
      return _distanceInMeters(latitude, longitude, lat, lng) <= radius;
    }).toList();
  }

  double _distanceInMeters(
    double latitude1,
    double longitude1,
    double latitude2,
    double longitude2,
  ) {
    const earthRadiusMeters = 6371000.0;
    final lat1 = _toRadians(latitude1);
    final lat2 = _toRadians(latitude2);
    final deltaLat = _toRadians(latitude2 - latitude1);
    final deltaLng = _toRadians(longitude2 - longitude1);
    final a =
        math.pow(math.sin(deltaLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(deltaLng / 2), 2);
    final boundedA = a.clamp(0.0, 1.0);
    return earthRadiusMeters *
        2 *
        math.atan2(math.sqrt(boundedA), math.sqrt(1 - boundedA));
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;
}
