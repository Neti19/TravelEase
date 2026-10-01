
class Trip {
  final String id;
  final String name;
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
    this.name = '',
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
      'name': name,
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
    DateTime readDate(dynamic value) {
      if (value is DateTime) return value;
      // Firestore Timestamp is intentionally handled without importing
      // cloud_firestore into this plain data model.
      if (value != null && value is! String && value is! num) {
        try {
          final dynamic date = (value as dynamic).toDate();
          if (date is DateTime) return date;
        } catch (_) {
          // Fall through to ISO string parsing for older/local data.
        }
      }
      return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
    }

    return Trip(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      startLocation: json['startLocation']?.toString() ?? '',
      startLatitude:
          (json['startLatitude'] as num?)?.toDouble() ?? 0.0,
      startLongitude:
          (json['startLongitude'] as num?)?.toDouble() ?? 0.0,
      destination: json['destination']?.toString() ?? '',
      startDate: readDate(json['startDate']),
      endDate: readDate(json['endDate']),
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
