import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class PlaceDetailsService {
  static const String _detailsBaseUrl =
      'https://places.googleapis.com/v1/places';

  final String? _apiKey = dotenv.env['PLACES_API_KEY'];

  Future<Map<String, dynamic>?> getPlaceDetails(
      String placeId,
      ) async {
    final apiKey = _apiKey?.trim();

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(
        'PLACES_API_KEY is missing from .env',
      );
    }

    if (placeId.trim().isEmpty) {
      return null;
    }

    final response = await http.get(
      Uri.parse(
        '$_detailsBaseUrl/$placeId',
      ),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': [
          'id',
          'displayName',
          'formattedAddress',
          'location',
          'rating',
          'userRatingCount',
          'primaryType',
          'types',
          'photos',
        ].join(','),
      },
    );

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        'Place details failed '
            '(${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final data = decoded;

    // -----------------------------------------------------------------------
    // PHOTO DETAILS
    // -----------------------------------------------------------------------

    final photos = data['photos'];

    if (photos is List && photos.isNotEmpty) {
      final firstPhoto = photos.first;

      if (firstPhoto is Map) {
        final photoName =
        firstPhoto['name']?.toString();

        // Preserve Google's required photo attribution information.
        final authorAttributions =
        firstPhoto['authorAttributions'];

        if (authorAttributions is List) {
          data['photoAuthorAttributions'] =
              authorAttributions;
        }

        if (photoName != null &&
            photoName.isNotEmpty) {
          final photoUrl =
          await _getPhotoUrl(
            photoName,
            apiKey,
          );

          if (photoUrl != null &&
              photoUrl.isNotEmpty) {
            data['photoUrl'] = photoUrl;
          }
        }
      }
    }

    return data;
  }

  // -------------------------------------------------------------------------
  // GOOGLE PLACE PHOTO
  // -------------------------------------------------------------------------

  Future<String?> _getPhotoUrl(
      String photoName,
      String apiKey,
      ) async {
    final uri = Uri.parse(
      'https://places.googleapis.com/v1/'
          '$photoName/media',
    ).replace(
      queryParameters: {
        'maxWidthPx': '900',
        'maxHeightPx': '600',
        'skipHttpRedirect': 'true',
        'key': apiKey,
      },
    );

    final response = await http.get(uri);

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      return null;
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    return decoded['photoUri']?.toString();
  }
}