 import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../config/api_keys.dart';

class RoutePoint {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String type;

  RoutePoint({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'type': type,
    };
  }
}

class LatLngPoint {
  final double latitude;
  final double longitude;

  LatLngPoint({required this.latitude, required this.longitude});
}

class RouteResult {
  final int distanceMeters;
  final String duration;
  final List<RoutePoint> orderedPoints;
  final List<LatLngPoint> polylinePoints;
  final bool isEstimated;
  final String? estimateReason;

  RouteResult({
    required this.distanceMeters,
    required this.duration,
    required this.orderedPoints,
    required this.polylinePoints,
    this.isEstimated = false,
    this.estimateReason,
  });

  double get distanceKm => distanceMeters / 1000;

  String get formattedDuration {
    final seconds = _durationToSeconds(duration);

    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }

    return '${minutes}m';
  }

  int _durationToSeconds(String value) {
    final cleaned = value.replaceAll('s', '');

    final seconds = double.tryParse(cleaned);

    return seconds?.round() ?? 0;
  }
}

class RouteService {
  static const String _baseUrl =
      'https://routes.googleapis.com/directions/v2:computeRoutes';

  Future<RouteResult> calculateRoute({
    required RoutePoint origin,
    required List<RoutePoint> stops,
  }) async {
    if (stops.isEmpty) {
      throw Exception('At least one destination is required.');
    }

    final apiKey = ApiKeys.routesApiKey.trim();

    if (apiKey.isEmpty) {
      return estimateRoute(
        origin: origin,
        stops: stops,
        reason: 'the Routes API key is not configured',
      );
    }

    try {
      /*
     * Google Routes API requires a destination.
     *
     * The last stop is the destination.
     * All previous stops are intermediate waypoints.
     */
      final destination = stops.last;

      final intermediateStops = stops.length > 1
          ? stops.sublist(0, stops.length - 1)
          : <RoutePoint>[];

      final body = <String, dynamic>{
        'origin': _waypoint(origin),
        'destination': _waypoint(destination),

        'travelMode': 'DRIVE',

        'routingPreference': 'TRAFFIC_AWARE',

        'computeAlternativeRoutes': false,

        /*
       * IMPORTANT:
       *
       * Use GeoJSON instead of encoded polyline.
       * This removes the decoding problem.
       */
        'polylineQuality': 'HIGH_QUALITY',
        'polylineEncoding': 'GEO_JSON_LINESTRING',

        'languageCode': 'en-US',
        'units': 'METRIC',

        'intermediates': intermediateStops.map(_waypoint).toList(),

        /*
       * Google can optimize the order
       * of intermediate tourist places.
       */
        if (intermediateStops.isNotEmpty) 'optimizeWaypointOrder': true,
      };

      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': apiKey,

              /*
         * Request:
         * distance
         * duration
         * route GeoJSON polyline
         * optimized waypoint order
         */
              'X-Goog-FieldMask':
                  'routes.distanceMeters,'
                  'routes.duration,'
                  'routes.polyline.geoJsonLinestring,'
                  'routes.optimizedIntermediateWaypointIndex',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 429) {
        return estimateRoute(
          origin: origin,
          stops: stops,
          reason: 'Google Routes is rate-limited',
        );
      }

      if (response.statusCode != 200) {
        throw Exception(
          'Routes API failed '
          '(${response.statusCode}). Please try again later.',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      final routes = data['routes'] as List<dynamic>?;

      if (routes == null || routes.isEmpty) {
        throw Exception('Routes API returned no route.');
      }

      final route = routes.first as Map<String, dynamic>;

      final distanceMeters = (route['distanceMeters'] as num?)?.toInt() ?? 0;

      final duration = route['duration']?.toString() ?? '0s';

      /*
     * --------------------------------------------------
     * Read optimized waypoint order
     * --------------------------------------------------
     */
      final orderedPoints = _getOrderedPoints(
        origin: origin,
        stops: stops,
        route: route,
      );

      /*
     * --------------------------------------------------
     * Read GeoJSON road polyline
     * --------------------------------------------------
     */
      final polylinePoints = _readGeoJsonPolyline(route);

      if (polylinePoints.length < 2) {
        throw Exception('Routes API returned an invalid road polyline.');
      }

      return RouteResult(
        distanceMeters: distanceMeters,
        duration: duration,
        orderedPoints: orderedPoints,
        polylinePoints: polylinePoints,
      );
    } catch (e) {
      return estimateRoute(
        origin: origin,
        stops: stops,
        reason: 'Google Routes is unavailable: $e',
      );
    }
  }

  static RouteResult estimateRoute({
    required RoutePoint origin,
    required List<RoutePoint> stops,
    String reason = 'Google Routes is unavailable',
  }) {
    if (stops.isEmpty) {
      throw ArgumentError.value(stops, 'stops', 'Must not be empty.');
    }

    final finalStop = stops.last;
    final remaining = List<RoutePoint>.from(stops.take(stops.length - 1));
    final orderedPoints = <RoutePoint>[origin];
    var current = origin;

    while (remaining.isNotEmpty) {
      var nearestIndex = 0;
      var nearestDistance = double.infinity;

      for (var index = 0; index < remaining.length; index++) {
        final distance = _distanceKm(current, remaining[index]);
        if (distance < nearestDistance) {
          nearestDistance = distance;
          nearestIndex = index;
        }
      }

      current = remaining.removeAt(nearestIndex);
      orderedPoints.add(current);
    }

    orderedPoints.add(finalStop);

    final polylinePoints = orderedPoints
        .map(
          (point) =>
              LatLngPoint(latitude: point.latitude, longitude: point.longitude),
        )
        .toList();

    final straightLineDistanceKm = _routeDistanceKm(orderedPoints);
    final estimatedRoadDistanceKm = straightLineDistanceKm * 1.25;
    final distanceMeters = (estimatedRoadDistanceKm * 1000).round();
    final estimatedSeconds = (estimatedRoadDistanceKm / 30 * 3600).round();

    return RouteResult(
      distanceMeters: distanceMeters,
      duration: '${estimatedSeconds}s',
      orderedPoints: orderedPoints,
      polylinePoints: polylinePoints,
      isEstimated: true,
      estimateReason: reason,
    );
  }

  static double _routeDistanceKm(List<RoutePoint> points) {
    var distance = 0.0;
    for (var index = 1; index < points.length; index++) {
      distance += _distanceKm(points[index - 1], points[index]);
    }
    return distance;
  }

  static double _distanceKm(RoutePoint from, RoutePoint to) {
    const earthRadiusKm = 6371.0;
    final lat1 = _degreesToRadians(from.latitude);
    final lat2 = _degreesToRadians(to.latitude);
    final latitudeDelta = _degreesToRadians(to.latitude - from.latitude);
    final longitudeDelta = _degreesToRadians(to.longitude - from.longitude);
    final a =
        math.pow(math.sin(latitudeDelta / 2), 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.pow(math.sin(longitudeDelta / 2), 2);
    return 2 *
        earthRadiusKm *
        math.asin(math.min(1.0, math.sqrt(a.toDouble())));
  }

  static double _degreesToRadians(double degrees) => degrees * math.pi / 180;

  Map<String, dynamic> _waypoint(RoutePoint point) {
    return {
      'location': {
        'latLng': {'latitude': point.latitude, 'longitude': point.longitude},
      },
    };
  }

  List<RoutePoint> _getOrderedPoints({
    required RoutePoint origin,
    required List<RoutePoint> stops,
    required Map<String, dynamic> route,
  }) {
    final result = <RoutePoint>[origin];

    final indexes =
        route['optimizedIntermediateWaypointIndex'] as List<dynamic>?;

    if (indexes != null && indexes.isNotEmpty) {
      for (final value in indexes) {
        final index = (value as num).toInt();

        if (index >= 0 && index < stops.length - 1) {
          result.add(stops[index]);
        }
      }

      /*
       * Last stop remains the final destination.
       */
      result.add(stops.last);

      return result;
    }

    /*
     * If Google does not return
     * optimization information,
     * use the original order.
     */
    result.addAll(stops);

    return result;
  }

  List<LatLngPoint> _readGeoJsonPolyline(Map<String, dynamic> route) {
    final polyline = route['polyline'] as Map<String, dynamic>?;

    if (polyline == null) {
      return [];
    }

    final geoJson = polyline['geoJsonLinestring'] as Map<String, dynamic>?;

    if (geoJson == null) {
      return [];
    }

    final coordinates = geoJson['coordinates'] as List<dynamic>?;

    if (coordinates == null) {
      return [];
    }

    final points = <LatLngPoint>[];

    for (final coordinate in coordinates) {
      if (coordinate is! List || coordinate.length < 2) {
        continue;
      }

      /*
       * GeoJSON order is:
       *
       * [longitude, latitude]
       *
       * Flutter GoogleMap requires:
       *
       * LatLng(latitude, longitude)
       */
      final longitude = (coordinate[0] as num).toDouble();

      final latitude = (coordinate[1] as num).toDouble();

      points.add(LatLngPoint(latitude: latitude, longitude: longitude));
    }

    return points;
  }
}
