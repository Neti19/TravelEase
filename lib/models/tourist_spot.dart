class TouristSpot {
  final String id;
  final String name;
  final String category;
  final double distanceKm;
  final double rating;
  final String openingTime; // e.g., "09:00 AM"
  final String closingTime; // e.g., "06:00 PM"
  final Duration estimatedVisitDuration;
  final double entryFee;
  final double latitude;
  final double longitude;

  TouristSpot({
    required this.id,
    required this.name,
    required this.category,
    required this.distanceKm,
    required this.rating,
    required this.openingTime,
    required this.closingTime,
    required this.estimatedVisitDuration,
    required this.entryFee,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'distanceKm': distanceKm,
    'rating': rating,
    'openingTime': openingTime,
    'closingTime': closingTime,
    'estimatedVisitDurationMinutes': estimatedVisitDuration.inMinutes,
    'entryFee': entryFee,
    'latitude': latitude,
    'longitude': longitude,
  };

  factory TouristSpot.fromJson(Map<String, dynamic> json) => TouristSpot(
    id: json['id'],
    name: json['name'],
    category: json['category'],
    distanceKm: (json['distanceKm'] as num).toDouble(),
    rating: (json['rating'] as num).toDouble(),
    openingTime: json['openingTime'],
    closingTime: json['closingTime'],
    estimatedVisitDuration: Duration(minutes: json['estimatedVisitDurationMinutes']),
    entryFee: (json['entryFee'] as num).toDouble(),
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
  );
}