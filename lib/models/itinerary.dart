enum ActivityType { spot, transport, hotel, restaurant }

class ItineraryActivity {
  final String id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final double cost;
  final ActivityType type;

  ItineraryActivity({
    required this.id,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.cost,
    required this.type,
  });

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
  };

  factory ItineraryActivity.fromJson(Map<String, dynamic> json) => ItineraryActivity(
    id: json['id'],
    title: json['title'],
    description: json['description'],
    startTime: DateTime.parse(json['startTime']),
    endTime: DateTime.parse(json['endTime']),
    cost: (json['cost'] as num).toDouble(),
    type: ActivityType.values.byName(json['type']),
  );
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