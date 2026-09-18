import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

class HotelService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> getHotelsNearPlaces({
    required List<Map<String, dynamic>> selectedPlaces,
    required double maxPricePerNight,
  }) async {
    final snapshot =
        await _firestore.collection('hotels').get();

    final hotels = <Map<String, dynamic>>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final hotelLat =
          (data['latitude'] as num?)?.toDouble();
      final hotelLng =
          (data['longitude'] as num?)?.toDouble();
      final price =
          (data['pricePerNight'] as num?)?.toDouble();

      if (hotelLat == null ||
          hotelLng == null ||
          price == null) {
        continue;
      }

      // Price filter
      if (price > maxPricePerNight) {
        continue;
      }

      double nearestDistance = double.infinity;

      for (final place in selectedPlaces) {
        final placeLat =
            (place['latitude'] as num?)?.toDouble();
        final placeLng =
            (place['longitude'] as num?)?.toDouble();

        if (placeLat == null || placeLng == null) {
          continue;
        }

        final distance = _distanceKm(
          hotelLat,
          hotelLng,
          placeLat,
          placeLng,
        );

        if (distance < nearestDistance) {
          nearestDistance = distance;
        }
      }

      // Hotel must be within 15 km of a selected place.
      if (nearestDistance <= 15) {
        hotels.add({
          'id': doc.id,
          ...data,
          'distanceFromAttractionsKm': nearestDistance,
        });
      }
    }

    hotels.sort(
      (a, b) =>
          (a['distanceFromAttractionsKm'] as double)
              .compareTo(
                b['distanceFromAttractionsKm'] as double,
              ),
    );

    return hotels;
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