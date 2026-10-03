class Hotel {
  final String id;
  final String name;
  final double pricePerNight;
  final double rating;
  final String address;
  final double distanceFromAttractionsKm;
  final double latitude;
  final double longitude;

  Hotel({
    required this.id,
    required this.name,
    required this.pricePerNight,
    required this.rating,
    required this.address,
    required this.distanceFromAttractionsKm,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'pricePerNight': pricePerNight,
    'rating': rating,
    'address': address,
    'distanceFromAttractionsKm': distanceFromAttractionsKm,
    'latitude': latitude,
    'longitude': longitude,
  };

  factory Hotel.fromJson(Map<String, dynamic> json) => Hotel(
    id: json['id'],
    name: json['name'],
    pricePerNight: (json['pricePerNight'] as num).toDouble(),
    rating: (json['rating'] as num).toDouble(),
    address: json['address'],
    distanceFromAttractionsKm: (json['distanceFromAttractionsKm'] as num).toDouble(),
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
  );
}

/// One night/day of the trip and the hotel the traveller sleeps in.
///
/// `hotel` is the raw Google Places map (same shape the app already saved in
/// `selectedHotel`), so old and new data are interchangeable.
///
/// Firestore field: trips/{id}.hotelPlans = [{dayNumber, hotel: {...}}]
class HotelPlan {
  final int dayNumber;
  final Map<String, dynamic> hotel;

  const HotelPlan({
    required this.dayNumber,
    required this.hotel,
  });
  Map<String, dynamic> toJson() => {
        'dayNumber': dayNumber,
        'hotel': hotel,
      };

  factory HotelPlan.fromJson(Map<String, dynamic> json) => HotelPlan(
        dayNumber: (json['dayNumber'] as num?)?.toInt() ?? 1,
        hotel: Map<String, dynamic>.from(json['hotel'] as Map? ?? {}),
      );

  /// Reads hotel plans from a trip document.
  ///
  /// 1. `hotelPlans` (new format) when present.
  /// 2. Otherwise the legacy single `selectedHotel` is used for every day,
  ///    so trips saved before this change keep working.
  static List<HotelPlan> fromTrip(
    Map<String, dynamic> trip, {
    required int numberOfDays,
  }) {
    final raw = trip['hotelPlans'];
    if (raw is List && raw.isNotEmpty) {
      final plans = <HotelPlan>[];
      for (final item in raw) {
        if (item is Map && item['hotel'] is Map) {
          plans.add(HotelPlan.fromJson(Map<String, dynamic>.from(item)));
        }
      }
      if (plans.isNotEmpty) {
        plans.sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
        return plans;
      }
    }

    final legacy = trip['selectedHotel'];
    if (legacy is Map) {
      final days = numberOfDays < 1 ? 1 : numberOfDays;
      return [
        for (var d = 1; d <= days; d++)
          HotelPlan(
            dayNumber: d,
            hotel: Map<String, dynamic>.from(legacy),
          ),
      ];
    }
    return const [];
  }

  /// Hotel for [dayNumber]. Falls back to the closest earlier day, so a
  /// hotel "carries over" until the user/planner changes it.
  static HotelPlan? forDay(List<HotelPlan> plans, int dayNumber) {
    HotelPlan? best;
    for (final plan in plans) {
      if (plan.dayNumber == dayNumber) return plan;
      if (plan.dayNumber < dayNumber &&
          (best == null || plan.dayNumber > best.dayNumber)) {
        best = plan;
      }
    }
    return best ?? (plans.isEmpty ? null : plans.first);
  }
}
