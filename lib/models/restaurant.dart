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