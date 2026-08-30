class Trip {
  final String id;
  final String startLocation;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final int numberOfDays;
  final int travelersCount;
  final double budget;
  final List<String> selectedPreferenceIds;

  Trip({
    required this.id,
    required this.startLocation,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.numberOfDays,
    required this.travelersCount,
    required this.budget,
    this.selectedPreferenceIds = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'startLocation': startLocation,
    'destination': destination,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'numberOfDays': numberOfDays,
    'travelersCount': travelersCount,
    'budget': budget,
    'selectedPreferenceIds': selectedPreferenceIds,
  };

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
    id: json['id'],
    startLocation: json['startLocation'],
    destination: json['destination'],
    startDate: DateTime.parse(json['startDate']),
    endDate: DateTime.parse(json['endDate']),
    numberOfDays: json['numberOfDays'],
    travelersCount: json['travelersCount'],
    budget: (json['budget'] as num).toDouble(),
    selectedPreferenceIds: List<String>.from(json['selectedPreferenceIds'] ?? []),
  );
}