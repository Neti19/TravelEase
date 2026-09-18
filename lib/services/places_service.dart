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
    String input,
  ) async {
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