import '../models/place_map_reader.dart';
import '../models/restaurant.dart';
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

  // ------------------------------------------------------------
  // PER-MEAL RECOMMENDATIONS (multi-restaurant)
  // ------------------------------------------------------------

  /// Restaurants near where the traveller will actually be at [mealTime].
  /// Reuses PlacesService.searchNearbyRestaurants.
  ///
  /// Adds: distanceKm, estimatedMealPerPerson, openAtMealTime (true/false/
  /// null when unknown), recommendationScore, mealType, nearPlace.
  /// Closed-at-meal-time restaurants are dropped when hours are known.
  Future<List<Map<String, dynamic>>> recommendRestaurantsForMeal({
    required double latitude,
    required double longitude,
    required MealType meal,
    required DateTime mealTime,
    String nearPlaceName = '',
    double maxBudgetPerMealPerPerson = 0,
    List<String> foodKeywords = const [],
    double radius = 1500,
    int limit = 6,
  }) async {
    final types = meal == MealType.breakfast
        ? const ['breakfast_restaurant', 'cafe', 'bakery', 'restaurant']
        : const ['restaurant'];

    var results = await _placesService.searchNearbyRestaurants(
      latitude: latitude,
      longitude: longitude,
      radius: radius,
      includedTypes: types,
      includeOpeningHours: true,
    );
    if (results.length < 3) {
      results = await _placesService.searchNearbyRestaurants(
        latitude: latitude,
        longitude: longitude,
        radius: radius * 3,
        includedTypes: types,
        includeOpeningHours: true,
      );
    }

    final seen = <String>{};
    final scored = <Map<String, dynamic>>[];

    for (final r in results) {
      final id = PlaceMap.id(r);
      final lat = PlaceMap.latitude(r);
      final lng = PlaceMap.longitude(r);
      if (id.isEmpty || lat == null || lng == null || !seen.add(id)) {
        continue;
      }

      final open = PlaceMap.isOpenAt(r, mealTime);
      if (open == false) continue;

      final dist = PlaceMap.distanceKm(latitude, longitude, lat, lng);
      final cost = PlaceMap.estimatedMealPerPerson(r);

      var score = PlaceMap.rating(r) * 2.0 - dist * 1.5;
      if (open == true) score += 0.5;
      if (maxBudgetPerMealPerPerson > 0 && cost > maxBudgetPerMealPerPerson) {
        score -= ((cost - maxBudgetPerMealPerPerson) /
                maxBudgetPerMealPerPerson *
                2)
            .clamp(0.0, 3.0);
      }
      if (foodKeywords.isNotEmpty) {
        final haystack =
            '${PlaceMap.name(r)} ${(r['types'] as List?)?.join(' ') ?? ''}'
                .toLowerCase();
        if (foodKeywords.any((k) => haystack.contains(k.toLowerCase()))) {
          score += 1.0;
        }
      }

      scored.add({
        ...r,
        'distanceKm': double.parse(dist.toStringAsFixed(2)),
        'estimatedMealPerPerson': cost,
        'openAtMealTime': open,
        'recommendationScore': score,
        'mealType': meal.name,
        'nearPlace': nearPlaceName,
        'restaurantLatitude': lat,
        'restaurantLongitude': lng,
      });
    }

    scored.sort((a, b) => (b['recommendationScore'] as double)
        .compareTo(a['recommendationScore'] as double));
    return scored.take(limit).toList();
  }

  /// Manual restaurant search (user typed a name). Reuses
  /// PlacesService.searchPlaces; results are raw Places maps.
  Future<List<Map<String, dynamic>>> searchRestaurantsByText({
    required String query,
    required double latitude,
    required double longitude,
    String nearPlaceName = '',
  }) async {
    final places = await _placesService.searchPlaces(
      query: '$query restaurant',
      latitude: latitude,
      longitude: longitude,
      pageSize: 10,
      detailed: true,
    );

    final out = <Map<String, dynamic>>[];
    for (final r in places) {
      final lat = PlaceMap.latitude(r);
      final lng = PlaceMap.longitude(r);
      if (lat == null || lng == null) continue;
      out.add({
        ...r,
        'distanceKm': double.parse(
          PlaceMap.distanceKm(latitude, longitude, lat, lng)
              .toStringAsFixed(2),
        ),
        'nearPlace': nearPlaceName,
        'restaurantLatitude': lat,
        'restaurantLongitude': lng,
      });
    }
    return out;
  }
}