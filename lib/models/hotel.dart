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