import 'places_service.dart';

class HotelService {
  final PlacesService _placesService =
      PlacesService();

  Future<List<Map<String, dynamic>>> getHotelsNearPlaces({
    required List<Map<String, dynamic>> selectedPlaces,
    double radius = 10000,
  }) async {
    final results = <Map<String, dynamic>>[];

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

      final hotels =
          await _placesService.searchNearbyHotels(
        latitude: latitude,
        longitude: longitude,
        radius: radius,
      );

      for (final hotel in hotels) {
        final id =
            hotel['id']?.toString();

        if (id == null ||
            seenIds.contains(id)) {
          continue;
        }

        final location =
            hotel['location']
                as Map<String, dynamic>?;

        final hotelLat =
            (location?['latitude'] as num?)
                ?.toDouble();

        final hotelLng =
            (location?['longitude'] as num?)
                ?.toDouble();

        if (hotelLat == null ||
            hotelLng == null) {
          continue;
        }

        seenIds.add(id);

        results.add({
          ...hotel,
          'nearPlace':
              place['name']?.toString() ?? '',
          'nearPlaceLatitude': latitude,
          'nearPlaceLongitude': longitude,
          'hotelLatitude': hotelLat,
          'hotelLongitude': hotelLng,
        });
      }
    }

    return results;
  }
}