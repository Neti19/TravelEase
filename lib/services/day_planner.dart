import '../models/place_map_reader.dart';

/// A visitable place used by the planner (tourist spot / destination).
class PlannerPlace {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String category;
  final Map<String, dynamic> raw;

  const PlannerPlace({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.category = '',
    this.raw = const {},
  });

  /// Builds a PlannerPlace from a Firestore `selectedPlaces` /
  /// `destinations` document map. Returns null without coordinates.
  static PlannerPlace? fromMap(Map<String, dynamic> map) {
    final lat = (map['latitude'] as num?)?.toDouble();
    final lng = (map['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return PlannerPlace(
      id: map['placeId']?.toString() ?? map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Place',
      latitude: lat,
      longitude: lng,
      category: map['category']?.toString() ?? '',
      raw: map,
    );
  }
}

/// Places grouped for one calendar day, already in visiting order.
class DayCluster {
  final int dayNumber;
  final List<PlannerPlace> places;
  final double centerLatitude;
  final double centerLongitude;

  const DayCluster({
    required this.dayNumber,
    required this.places,
    required this.centerLatitude,
    required this.centerLongitude,
  });
}

/// Consecutive days that can share one hotel (they are close together).
class StayGroup {
  final List<int> dayNumbers;
  final List<PlannerPlace> places;
  final double centerLatitude;
  final double centerLongitude;

  const StayGroup({
    required this.dayNumbers,
    required this.places,
    required this.centerLatitude,
    required this.centerLongitude,
  });

  int get firstDay => dayNumbers.first;
  int get lastDay => dayNumbers.last;
}

/// Pure-Dart planning heuristics (no Firebase, no network).
///
/// 1. Nearest-neighbour tour over every place, starting near the trip start.
/// 2. The tour is cut into balanced, contiguous day chunks (compact areas).
/// 3. Each day is re-ordered with 2-opt to remove backtracking.
/// 4. Neighbouring days whose centres are close share a hotel.
class DayPlanner {
  DayPlanner._();

  static double distanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) =>
      PlaceMap.distanceKm(lat1, lon1, lat2, lon2);

  static List<PlannerPlace> nearestNeighborOrder(
    List<PlannerPlace> places, {
    required double fromLatitude,
    required double fromLongitude,
  }) {
    final remaining = List<PlannerPlace>.from(places);
    final ordered = <PlannerPlace>[];
    var curLat = fromLatitude;
    var curLng = fromLongitude;

    while (remaining.isNotEmpty) {
      var bestIndex = 0;
      var best = double.infinity;
      for (var i = 0; i < remaining.length; i++) {
        final d = distanceKm(
          curLat,
          curLng,
          remaining[i].latitude,
          remaining[i].longitude,
        );
        if (d < best) {
          best = d;
          bestIndex = i;
        }
      }
      final next = remaining.removeAt(bestIndex);
      ordered.add(next);
      curLat = next.latitude;
      curLng = next.longitude;
    }
    return ordered;
  }

  /// Open-path 2-opt (start point fixed, end free).
  static List<PlannerPlace> twoOpt(
    List<PlannerPlace> path, {
    required double fromLatitude,
    required double fromLongitude,
    int maxPasses = 6,
  }) {
    final p = List<PlannerPlace>.from(path);
    final n = p.length;
    if (n < 3) return p;

    double d(double aLat, double aLng, PlannerPlace b) =>
        distanceKm(aLat, aLng, b.latitude, b.longitude);

    for (var pass = 0; pass < maxPasses; pass++) {
      var improved = false;
      for (var i = 0; i < n - 1; i++) {
        final prevLat = i == 0 ? fromLatitude : p[i - 1].latitude;
        final prevLng = i == 0 ? fromLongitude : p[i - 1].longitude;
        for (var j = i + 1; j < n; j++) {
          final before = d(prevLat, prevLng, p[i]) +
              (j < n - 1
                  ? distanceKm(
                      p[j].latitude,
                      p[j].longitude,
                      p[j + 1].latitude,
                      p[j + 1].longitude,
                    )
                  : 0.0);
          final after = d(prevLat, prevLng, p[j]) +
              (j < n - 1
                  ? distanceKm(
                      p[i].latitude,
                      p[i].longitude,
                      p[j + 1].latitude,
                      p[j + 1].longitude,
                    )
                  : 0.0);
          if (after < before - 1e-9) {
            final reversed = p.sublist(i, j + 1).reversed.toList();
            p.replaceRange(i, j + 1, reversed);
            improved = true;
          }
        }
      }
      if (!improved) break;
    }
    return p;
  }

  static List<DayCluster> clusterIntoDays({
    required List<PlannerPlace> places,
    required int numberOfDays,
    required double startLatitude,
    required double startLongitude,
  }) {
    final days = numberOfDays < 1 ? 1 : numberOfDays;

    if (places.isEmpty) {
      return [
        for (var d = 1; d <= days; d++)
          DayCluster(
            dayNumber: d,
            places: const [],
            centerLatitude: startLatitude,
            centerLongitude: startLongitude,
          ),
      ];
    }

    final tour = nearestNeighborOrder(
      places,
      fromLatitude: startLatitude,
      fromLongitude: startLongitude,
    );

    final groups = days < tour.length ? days : tour.length;
    final base = tour.length ~/ groups;
    final extra = tour.length % groups;

    final clusters = <DayCluster>[];
    var cursor = 0;
    var prevLat = startLatitude;
    var prevLng = startLongitude;

    for (var g = 0; g < groups; g++) {
      final size = base + (g < extra ? 1 : 0);
      final chunk = tour.sublist(cursor, cursor + size);
      cursor += size;

      final ordered = twoOpt(
        chunk,
        fromLatitude: prevLat,
        fromLongitude: prevLng,
      );

      var latSum = 0.0;
      var lngSum = 0.0;
      for (final place in ordered) {
        latSum += place.latitude;
        lngSum += place.longitude;
      }

      clusters.add(
        DayCluster(
          dayNumber: g + 1,
          places: ordered,
          centerLatitude: latSum / ordered.length,
          centerLongitude: lngSum / ordered.length,
        ),
      );

      prevLat = ordered.last.latitude;
      prevLng = ordered.last.longitude;
    }

    // Extra days (more days than places) stay near the last area.
    for (var d = groups + 1; d <= days; d++) {
      clusters.add(
        DayCluster(
          dayNumber: d,
          places: const [],
          centerLatitude: clusters.last.centerLatitude,
          centerLongitude: clusters.last.centerLongitude,
        ),
      );
    }
    return clusters;
  }

  /// Merges neighbouring days into one hotel stay when their centres are
  /// within [mergeThresholdKm]. Avoids a hotel change every day.
  static List<StayGroup> buildStayGroups(
    List<DayCluster> clusters, {
    double mergeThresholdKm = 25,
  }) {
    final groups = <StayGroup>[];
    if (clusters.isEmpty) return groups;

    var days = <int>[clusters.first.dayNumber];
    var places = List<PlannerPlace>.from(clusters.first.places);
    var anchorLat = clusters.first.centerLatitude;
    var anchorLng = clusters.first.centerLongitude;

    StayGroup close() {
      var latSum = 0.0;
      var lngSum = 0.0;
      for (final p in places) {
        latSum += p.latitude;
        lngSum += p.longitude;
      }
      final lat = places.isEmpty ? anchorLat : latSum / places.length;
      final lng = places.isEmpty ? anchorLng : lngSum / places.length;
      return StayGroup(
        dayNumbers: List<int>.from(days),
        places: List<PlannerPlace>.from(places),
        centerLatitude: lat,
        centerLongitude: lng,
      );
    }

    for (var i = 1; i < clusters.length; i++) {
      final c = clusters[i];
      final gap = distanceKm(
        anchorLat,
        anchorLng,
        c.centerLatitude,
        c.centerLongitude,
      );
      if (gap <= mergeThresholdKm) {
        days.add(c.dayNumber);
        places.addAll(c.places);
      } else {
        groups.add(close());
        days = <int>[c.dayNumber];
        places = List<PlannerPlace>.from(c.places);
        anchorLat = c.centerLatitude;
        anchorLng = c.centerLongitude;
      }
    }
    groups.add(close());
    return groups;
  }
}
