class Restaurant {
  final String id;
  final String name;
  final String cuisineType;
  final double rating;
  final double averageMealCost;
  final String address;
  final double latitude;
  final double longitude;

  Restaurant({
    required this.id,
    required this.name,
    required this.cuisineType,
    required this.rating,
    required this.averageMealCost,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'cuisineType': cuisineType,
    'rating': rating,
    'averageMealCost': averageMealCost,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
  };

  factory Restaurant.fromJson(Map<String, dynamic> json) => Restaurant(
    id: json['id'],
    name: json['name'],
    cuisineType: json['cuisineType'],
    rating: (json['rating'] as num).toDouble(),
    averageMealCost: (json['averageMealCost'] as num).toDouble(),
    address: json['address'],
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
  );
}

enum MealType { breakfast, lunch, dinner }

extension MealTypeX on MealType {
  String get label {
    switch (this) {
      case MealType.breakfast:
        return 'Breakfast';
      case MealType.lunch:
        return 'Lunch';
      case MealType.dinner:
        return 'Dinner';
    }
  }

  static MealType parse(String? value) {
    return MealType.values.firstWhere(
      (m) => m.name == value,
      orElse: () => MealType.lunch,
    );
  }
}

/// A restaurant chosen for a specific meal on a specific day.
///
/// `restaurant` is the raw Google Places map (same shape as the legacy
/// `selectedRestaurant`).
///
/// Firestore field:
/// trips/{id}.restaurantPlans =
///   [{dayNumber, mealType: 'lunch', restaurant: {...}}]
class RestaurantPlan {
  final int dayNumber;
  final MealType mealType;
  final Map<String, dynamic> restaurant;

  const RestaurantPlan({
    required this.dayNumber,
    required this.mealType,
    required this.restaurant,
  });

  Map<String, dynamic> toJson() => {
        'dayNumber': dayNumber,
        'mealType': mealType.name,
        'restaurant': restaurant,
      };

  factory RestaurantPlan.fromJson(Map<String, dynamic> json) =>
      RestaurantPlan(
        dayNumber: (json['dayNumber'] as num?)?.toInt() ?? 1,
        mealType: MealTypeX.parse(json['mealType']?.toString()),
        restaurant:
            Map<String, dynamic>.from(json['restaurant'] as Map? ?? {}),
      );

  /// New `restaurantPlans` when present, otherwise the legacy single
  /// `selectedRestaurant` becomes Day 1 lunch (what the old generator did).
  static List<RestaurantPlan> fromTrip(Map<String, dynamic> trip) {
    final raw = trip['restaurantPlans'];
    if (raw is List && raw.isNotEmpty) {
      final plans = <RestaurantPlan>[];
      for (final item in raw) {
        if (item is Map && item['restaurant'] is Map) {
          plans.add(
            RestaurantPlan.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
      if (plans.isNotEmpty) return plans;
    }

    final legacy = trip['selectedRestaurant'];
    if (legacy is Map) {
      return [
        RestaurantPlan(
          dayNumber: 1,
          mealType: MealType.lunch,
          restaurant: Map<String, dynamic>.from(legacy),
        ),
      ];
    }
    return const [];
  }

  static RestaurantPlan? find(
    List<RestaurantPlan> plans,
    int dayNumber,
    MealType meal,
  ) {
    for (final plan in plans) {
      if (plan.dayNumber == dayNumber && plan.mealType == meal) return plan;
    }
    return null;
  }
}
