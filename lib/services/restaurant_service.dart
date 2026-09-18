import 'places_service.dart';

class RestaurantService {
  final PlacesService _placesService =
      PlacesService();

  Future<List<Map<String, dynamic>>>
      getRestaurantsNearPlaces({
    required List<Map<String, dynamic>>
        selectedPlaces,
    double radius = 5000,
  }) async {
    final results =
        <Map<String, dynamic>>[];

    final seenIds = <String>{};

    for (final place in selectedPlaces) {
      final latitude =
          (place['latitude'] as num?)?.toDouble();

      final longitude =
          (place['longitude'] as num?)?.toDouble();

      if (latitude == null ||
          longitude == null) {
        continue;
      }

      final restaurants =
          await _placesService
              .searchNearbyRestaurants(
        latitude: latitude,
        longitude: longitude,
        radius: radius,
      );

      for (final restaurant in restaurants) {
        final id =
            restaurant['id']?.toString();

        if (id == null ||
            seenIds.contains(id)) {
          continue;
        }

        final location =
            restaurant['location']
                as Map<String, dynamic>?;

        final restaurantLat =
            (location?['latitude'] as num?)
                ?.toDouble();

        final restaurantLng =
            (location?['longitude'] as num?)
                ?.toDouble();

        if (restaurantLat == null ||
            restaurantLng == null) {
          continue;
        }

        seenIds.add(id);

        results.add({
          ...restaurant,
          'nearPlace':
              place['name']?.toString() ?? '',
          'nearPlaceLatitude': latitude,
          'nearPlaceLongitude': longitude,
          'restaurantLatitude': restaurantLat,
          'restaurantLongitude': restaurantLng,
        });
      }
    }

    return results;
  }
}