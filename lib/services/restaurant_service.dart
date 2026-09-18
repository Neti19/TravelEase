import 'dart:math' as math;

import 'places_service.dart';

class RestaurantService {
  final PlacesService _placesService = PlacesService();

  Future<List<Map<String, dynamic>>> getRestaurantsNearPlaces({
    required List<Map<String, dynamic>> selectedPlaces,
    required int maxPriceLevel,
  }) async {
    final results = <Map<String, dynamic>>[];
    final seenIds = <String>{};

    for (final place in selectedPlaces) {
      final latitude =
          (place['latitude'] as num?)?.toDouble();
      final longitude =
          (place['longitude'] as num?)?.toDouble();

      if (latitude == null || longitude == null) {
        continue;
      }

      final restaurants =
          await _placesService.searchNearbyRestaurants(
        latitude: latitude,
        longitude: longitude,
      );

      for (final restaurant in restaurants) {
        final id = restaurant['id']?.toString();

        if (id == null || seenIds.contains(id)) {
          continue;
        }

        final location =
            restaurant['location'] as Map<String, dynamic>?;

        final restaurantLat =
            (location?['latitude'] as num?)?.toDouble();
        final restaurantLng =
            (location?['longitude'] as num?)?.toDouble();

        if (restaurantLat == null ||
            restaurantLng == null) {
          continue;
        }

        final priceLevel =
            _priceLevel(restaurant['priceLevel']);

        if (priceLevel > maxPriceLevel) {
          continue;
        }

        final distance = _distanceKm(
          latitude,
          longitude,
          restaurantLat,
          restaurantLng,
        );

        seenIds.add(id);

        results.add({
          ...restaurant,
          'distanceFromPlaceKm': distance,
          'priceLevelNumber': priceLevel,
          'nearPlace': place['name'],
        });
      }
    }

    results.sort(
      (a, b) =>
          (a['distanceFromPlaceKm'] as double)
              .compareTo(
                b['distanceFromPlaceKm'] as double,
              ),
    );

    return results;
  }

  int _priceLevel(dynamic value) {
    switch (value?.toString()) {
      case 'PRICE_LEVEL_FREE':
        return 0;
      case 'PRICE_LEVEL_INEXPENSIVE':
        return 1;
      case 'PRICE_LEVEL_MODERATE':
        return 2;
      case 'PRICE_LEVEL_EXPENSIVE':
        return 3;
      case 'PRICE_LEVEL_VERY_EXPENSIVE':
        return 4;
      default:
        return 2;
    }
  }

  double _distanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371.0;

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(
      math.sqrt(a),
      math.sqrt(1 - a),
    );

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }
}