import '../models/place_map_reader.dart';
import 'day_planner.dart';
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

  // ------------------------------------------------------------
  // PER-STAY RECOMMENDATIONS (multi-hotel)
  // ------------------------------------------------------------

  /// Recommends several hotels for ONE stay group (consecutive days that
  /// share an area). Reuses PlacesService.searchNearbyHotels.
  ///
  /// Each returned map is the raw Places map plus:
  ///  avgDistanceKm / maxDistanceKm  distance to the stay's places
  ///  estimatedPricePerNight         per room (estimate, INR)
  ///  recommendationScore            higher is better
  ///  stayDays                       day numbers this stay covers
  ///  nearPlace                      closest planned place (legacy key)
  Future<List<Map<String, dynamic>>> recommendHotelsForStay({
    required StayGroup stay,
    double maxBudgetPerNight = 0,
    int travelers = 1,
    double radius = 8000,
    int limit = 6,
  }) async {
    var hotels = await _placesService.searchNearbyHotels(
      latitude: stay.centerLatitude,
      longitude: stay.centerLongitude,
      radius: radius,
    );
    if (hotels.length < 3) {
      hotels = await _placesService.searchNearbyHotels(
        latitude: stay.centerLatitude,
        longitude: stay.centerLongitude,
        radius: radius * 2.5,
      );
    }

    final rooms = (travelers / 2).ceil().clamp(1, 20);
    final seen = <String>{};
    final scored = <Map<String, dynamic>>[];

    for (final hotel in hotels) {
      final id = PlaceMap.id(hotel);
      final lat = PlaceMap.latitude(hotel);
      final lng = PlaceMap.longitude(hotel);
      if (id.isEmpty || lat == null || lng == null || !seen.add(id)) {
        continue;
      }

      double sum = 0;
      double maxD = 0;
      String nearest = '';
      double nearestD = double.infinity;
      for (final p in stay.places) {
        final d = PlaceMap.distanceKm(lat, lng, p.latitude, p.longitude);
        sum += d;
        if (d > maxD) maxD = d;
        if (d < nearestD) {
          nearestD = d;
          nearest = p.name;
        }
      }
      final avg = stay.places.isEmpty
          ? PlaceMap.distanceKm(
              lat, lng, stay.centerLatitude, stay.centerLongitude)
          : sum / stay.places.length;

      final perRoom = PlaceMap.estimatedHotelPerNight(hotel);
      final perNight = perRoom * rooms;

      var score = PlaceMap.rating(hotel) * 2.0 - avg * 0.5;
      if (maxBudgetPerNight > 0 && perNight > maxBudgetPerNight) {
        final over = (perNight - maxBudgetPerNight) / maxBudgetPerNight;
        score -= (over * 3).clamp(0.0, 4.0);
      }

      scored.add({
        ...hotel,
        'avgDistanceKm': double.parse(avg.toStringAsFixed(1)),
        'maxDistanceKm': double.parse(maxD.toStringAsFixed(1)),
        'estimatedPricePerNight': perNight,
        'recommendationScore': score,
        'stayDays': stay.dayNumbers,
        'nearPlace': nearest,
        'hotelLatitude': lat,
        'hotelLongitude': lng,
      });
    }

    scored.sort((a, b) => (b['recommendationScore'] as double)
        .compareTo(a['recommendationScore'] as double));
    return scored.take(limit).toList();
  }
}