enum TransportType { train, bus, flight, car }

class Transport {
  final String id;
  final TransportType type;
  final String providerName; // e.g., Express Airlines, Local Bus
  final String departureLocation;
  final String arrivalLocation;
  final DateTime departureTime;
  final DateTime arrivalTime;
  final double cost;

  Transport({
    required this.id,
    required this.type,
    required this.providerName,
    required this.departureLocation,
    required this.arrivalLocation,
    required this.departureTime,
    required this.arrivalTime,
    required this.cost,
  });

  Duration get travelDuration => arrivalTime.difference(departureTime);

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'providerName': providerName,
    'departureLocation': departureLocation,
    'arrivalLocation': arrivalLocation,
    'departureTime': departureTime.toIso8601String(),
    'arrivalTime': arrivalTime.toIso8601String(),
    'cost': cost,
  };

  factory Transport.fromJson(Map<String, dynamic> json) => Transport(
    id: json['id'],
    type: TransportType.values.byName(json['type']),
    providerName: json['providerName'],
    departureLocation: json['departureLocation'],
    arrivalLocation: json['arrivalLocation'],
    departureTime: DateTime.parse(json['departureTime']),
    arrivalTime: DateTime.parse(json['arrivalTime']),
    cost: (json['cost'] as num).toDouble(),
  );
}