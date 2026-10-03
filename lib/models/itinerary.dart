enum ActivityType { spot, transport, hotel, restaurant }

class ItineraryActivity {
  final String id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final double cost;
  final ActivityType type;

  // ---- Optional, backward-compatible fields (absent in old trips) ----
  final double? latitude;
  final double? longitude;
  final int? dayNumber;
  final int? sequence;
  final String? placeId;
  final int? travelMinutesFromPrevious;
  final String? mealType; // breakfast | lunch | dinner (restaurant only)

  ItineraryActivity({
    required this.id,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.cost,
    required this.type,
    this.latitude,
    this.longitude,
    this.dayNumber,
    this.sequence,
    this.placeId,
    this.travelMinutesFromPrevious,
    this.mealType,
  });

  bool get hasLocation => latitude != null && longitude != null;

  Duration get duration => endTime.difference(startTime);

  ItineraryActivity copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    double? cost,
    ActivityType? type,
    double? latitude,
    double? longitude,
    int? dayNumber,
    int? sequence,
    String? placeId,
    int? travelMinutesFromPrevious,
    String? mealType,
  }) {
    return ItineraryActivity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      cost: cost ?? this.cost,
      type: type ?? this.type,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      dayNumber: dayNumber ?? this.dayNumber,
      sequence: sequence ?? this.sequence,
      placeId: placeId ?? this.placeId,
      travelMinutesFromPrevious:
          travelMinutesFromPrevious ?? this.travelMinutesFromPrevious,
      mealType: mealType ?? this.mealType,
    );
  }

  bool overlapsWith(ItineraryActivity other) {
    return startTime.isBefore(other.endTime) && endTime.isAfter(other.startTime);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'cost': cost,
    'type': type.name,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    if (dayNumber != null) 'dayNumber': dayNumber,
    if (sequence != null) 'sequence': sequence,
    if (placeId != null) 'placeId': placeId,
    if (travelMinutesFromPrevious != null)
      'travelMinutesFromPrevious': travelMinutesFromPrevious,
    if (mealType != null) 'mealType': mealType,
  };

  factory ItineraryActivity.fromJson(Map<String, dynamic> json) {
    ActivityType readType(dynamic v) {
      for (final t in ActivityType.values) {
        if (t.name == v?.toString()) return t;
      }
      return ActivityType.spot;
    }

    return ItineraryActivity(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      startTime: DateTime.parse(json['startTime'].toString()),
      endTime: DateTime.parse(json['endTime'].toString()),
      cost: (json['cost'] as num?)?.toDouble() ?? 0.0,
      type: readType(json['type']),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      dayNumber: (json['dayNumber'] as num?)?.toInt(),
      sequence: (json['sequence'] as num?)?.toInt(),
      placeId: json['placeId']?.toString(),
      travelMinutesFromPrevious:
          (json['travelMinutesFromPrevious'] as num?)?.toInt(),
      mealType: json['mealType']?.toString(),
    );
  }
}

class DayItinerary {
  final int dayNumber;
  final DateTime date;
  List<ItineraryActivity> activities;

  DayItinerary({
    required this.dayNumber,
    required this.date,
    required this.activities,
  });

  double get totalDayCost => activities.fold(0.0, (sum, item) => sum + item.cost);

  Map<String, dynamic> toJson() => {
    'dayNumber': dayNumber,
    'date': date.toIso8601String(),
    'activities': activities.map((a) => a.toJson()).toList(),
  };

  factory DayItinerary.fromJson(Map<String, dynamic> json) => DayItinerary(
    dayNumber: json['dayNumber'],
    date: DateTime.parse(json['date']),
    activities: (json['activities'] as List)
        .map((a) => ItineraryActivity.fromJson(a))
        .toList(),
  );
}

class FullItinerary {
  final String id;
  final String tripId;
  List<DayItinerary> days;

  FullItinerary({
    required this.id,
    required this.tripId,
    required this.days,
  });

  double get totalTripCost => days.fold(0.0, (sum, day) => sum + day.totalDayCost);

  bool isOverBudget(double maxBudget) => totalTripCost > maxBudget;

  Map<String, dynamic> toJson() => {
    'id': id,
    'tripId': tripId,
    'days': days.map((d) => d.toJson()).toList(),
  };

  factory FullItinerary.fromJson(Map<String, dynamic> json) => FullItinerary(
    id: json['id'],
    tripId: json['tripId'],
    days: (json['days'] as List).map((d) => DayItinerary.fromJson(d)).toList(),
  );
}