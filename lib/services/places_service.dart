import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_keys.dart';

class PlacesService {
  static String get _apiKey => ApiKeys.placesApiKey;

  static const String _baseUrl =
      'https://places.googleapis.com/v1';

  void _checkKey() {
    if (_apiKey.isEmpty) {
      throw Exception(
        'Places API key is missing.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> autocomplete(
    String input, {
    double? latitude,
    double? longitude,
  }) async {
    _checkKey();

    final response = await http.post(
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
        'includedRegionCodes': ['in'],
        if (latitude != null && longitude != null)
          'locationBias': {
            'circle': {
              'center': {
                'latitude': latitude,
                'longitude': longitude,
              },
              'radius': 50000.0,
            },
          },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Places autocomplete failed '
            '(${response.statusCode}): ${response.body}',
      );
    }

    final data =
    jsonDecode(response.body) as Map<String, dynamic>;

    final suggestions =
        data['suggestions'] as List<dynamic>? ?? [];

    return suggestions
        .where(
          (item) => item['placePrediction'] != null,
    )
        .map((item) {
      final prediction =
      item['placePrediction']
      as Map<String, dynamic>;

      final text =
      prediction['text']
      as Map<String, dynamic>?;

      final structured =
      prediction['structuredFormat']
      as Map<String, dynamic>?;

      final mainText =
      structured?['mainText']
      as Map<String, dynamic>?;

      final secondaryText =
      structured?['secondaryText']
      as Map<String, dynamic>?;

      return {
        'placeId':
        prediction['placeId']?.toString() ?? '',
        'description':
        text?['text']?.toString() ?? '',
        'mainText':
        mainText?['text']?.toString() ?? '',
        'secondaryText':
        secondaryText?['text']?.toString() ?? '',
      };
    })
        .where(
          (item) =>
      (item['placeId'] as String).isNotEmpty,
    )
        .toList();
  }

  Future<Map<String, dynamic>> getPlaceDetails(
      String placeId,
      ) async {
    _checkKey();

    final response = await http.get(
      Uri.parse('$_baseUrl/places/$placeId'),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _apiKey,
        'X-Goog-FieldMask':
        'id,displayName,formattedAddress,location,types',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Place details failed '
            '(${response.statusCode}): ${response.body}',
      );
    }

    return jsonDecode(response.body)
    as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> searchPlaces({
    required String query,
    required double latitude,
    required double longitude,
    int pageSize = 8,
  }) async {
    _checkKey();

    final response = await http.post(
      Uri.parse('$_baseUrl/places:searchText'),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _apiKey,
        'X-Goog-FieldMask':
        'places.id,'
            'places.displayName,'
            'places.formattedAddress,'
            'places.location,'
            'places.types',
      },
      body: jsonEncode({
        'textQuery': query,
        'pageSize': pageSize,
        'locationBias': {
          'circle': {
            'center': {
              'latitude': latitude,
              'longitude': longitude,
            },
            'radius': 50000.0,
          },
        },
        'regionCode': 'IN',
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Places search failed '
            '(${response.statusCode}): ${response.body}',
      );
    }

    final data =
    jsonDecode(response.body)
    as Map<String, dynamic>;

    final places =
        data['places'] as List<dynamic>? ?? [];

    return places
        .map(
          (place) =>
      place as Map<String, dynamic>,
    )
        .toList();
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

    final response = await http.post(
      Uri.parse('$_baseUrl/places:searchNearby'),
      headers: {
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
      },
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
          'circle': {
            'center': {
              'latitude': latitude,
              'longitude': longitude,
            },
            'radius': radius,
          },
        },
        'regionCode': 'IN',
        'languageCode': 'en',
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Nearby destination search failed '
            '(${response.statusCode}): ${response.body}',
      );
    }

    final data =
    jsonDecode(response.body)
    as Map<String, dynamic>;

    final places =
        data['places'] as List<dynamic>? ?? [];

    return places
        .map(
          (place) =>
      place as Map<String, dynamic>,
    )
        .toList();
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

    final response = await http.post(
      Uri.parse('$_baseUrl/places:searchNearby'),
      headers: {
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
      },
      body: jsonEncode({
        'includedTypes': ['hotel'],
        'maxResultCount': maxResultCount,
        'rankPreference': 'DISTANCE',
        'locationRestriction': {
          'circle': {
            'center': {
              'latitude': latitude,
              'longitude': longitude,
            },
            'radius': radius,
          },
        },
        'regionCode': 'IN',
        'languageCode': 'en',
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Nearby hotel search failed '
            '(${response.statusCode}): ${response.body}',
      );
    }

    final data =
    jsonDecode(response.body)
    as Map<String, dynamic>;

    return List<Map<String, dynamic>>.from(
      data['places'] ?? [],
    );
  }

  Future<String> getLocationName({
    required double latitude,
    required double longitude,
  }) async {
    _checkKey();

    // Reverse geocoding gives the user a readable locality on Flutter Web,
    // where the native geocoding plugin is not available.
    try {
      final reverseResponse = await http.get(
        Uri.https(
          'maps.googleapis.com',
          '/maps/api/geocode/json',
          {
            'latlng': '$latitude,$longitude',
            'key': _apiKey,
            'language': 'en',
          },
        ),
      ).timeout(const Duration(seconds: 8));

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
        'X-Goog-FieldMask':
        'places.displayName,places.formattedAddress',
      },
      body: jsonEncode({
        'textQuery':
        'location near $latitude, $longitude',
        'pageSize': 1,
        'locationBias': {
          'circle': {
            'center': {
              'latitude': latitude,
              'longitude': longitude,
            },
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

    final data =
    jsonDecode(response.body) as Map<String, dynamic>;

    final places =
        data['places'] as List<dynamic>? ?? [];

    if (places.isEmpty) {
      return 'Location near ${latitude.toStringAsFixed(5)}, '
          '${longitude.toStringAsFixed(5)}';
    }

    final place =
    places.first as Map<String, dynamic>;

    final formattedAddress =
    place['formattedAddress']?.toString();

    if (formattedAddress != null &&
        formattedAddress.isNotEmpty) {
      return formattedAddress;
    }

    final displayName =
    place['displayName'] as Map<String, dynamic>?;

    final name = displayName?['text']?.toString();
    if (name != null && name.trim().isNotEmpty) return name;
    return 'Location near ${latitude.toStringAsFixed(5)}, '
        '${longitude.toStringAsFixed(5)}';
  }
  // ------------------------------------------------------------
  // NEARBY RESTAURANTS
  // ------------------------------------------------------------

  Future<List<Map<String, dynamic>>>
  searchNearbyRestaurants({
    required double latitude,
    required double longitude,
    double radius = 5000,
    int maxResultCount = 20,
  }) async {
    _checkKey();

    final response = await http.post(
      Uri.parse('$_baseUrl/places:searchNearby'),
      headers: {
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
      },
      body: jsonEncode({
        'includedTypes': ['restaurant'],
        'maxResultCount': maxResultCount,
        'rankPreference': 'DISTANCE',
        'locationRestriction': {
          'circle': {
            'center': {
              'latitude': latitude,
              'longitude': longitude,
            },
            'radius': radius,
          },
        },
        'regionCode': 'IN',
        'languageCode': 'en',
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Nearby restaurant search failed '
            '(${response.statusCode}): ${response.body}',
      );
    }

    final data =
    jsonDecode(response.body)
    as Map<String, dynamic>;

    return List<Map<String, dynamic>>.from(
      data['places'] ?? [],
    );
  }
}
