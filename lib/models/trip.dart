
class Trip {
  final String id;
  final String startLocation;
  final double startLatitude;
  final double startLongitude;
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
    required this.startLatitude,
    required this.startLongitude,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.numberOfDays,
    required this.travelersCount,
    required this.budget,
    this.selectedPreferenceIds = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'startLocation': startLocation,
      'startLatitude': startLatitude,
      'startLongitude': startLongitude,
      'destination': destination,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'numberOfDays': numberOfDays,
      'travelersCount': travelersCount,
      'budget': budget,
      'selectedPreferenceIds': selectedPreferenceIds,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      ...toMap(),
    };
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id']?.toString() ?? '',
      startLocation: json['startLocation']?.toString() ?? '',
      startLatitude:
          (json['startLatitude'] as num?)?.toDouble() ?? 0.0,
      startLongitude:
          (json['startLongitude'] as num?)?.toDouble() ?? 0.0,
      destination: json['destination']?.toString() ?? '',
      startDate: DateTime.parse(
        json['startDate'].toString(),
      ),
      endDate: DateTime.parse(
        json['endDate'].toString(),
      ),
      numberOfDays:
          (json['numberOfDays'] as num?)?.toInt() ?? 0,
      travelersCount:
          (json['travelersCount'] as num?)?.toInt() ?? 0,
      budget:
          (json['budget'] as num?)?.toDouble() ?? 0.0,
      selectedPreferenceIds:
          List<String>.from(
        json['selectedPreferenceIds'] ?? [],
      ),
    );
  }
}
