import 'dart:convert';

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

  LatLngPoint({
    required this.latitude,
    required this.longitude,
  });
}

class RouteResult {
  final int distanceMeters;
  final String duration;
  final List<RoutePoint> orderedPoints;
  final List<LatLngPoint> polylinePoints;

  RouteResult({
    required this.distanceMeters,
    required this.duration,
    required this.orderedPoints,
    required this.polylinePoints,
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
      throw Exception(
        'At least one destination is required.',
      );
    }

    final apiKey = ApiKeys.routesApiKey.trim();

    if (apiKey.isEmpty) {
      throw Exception(
        'Routes API key is missing.',
      );
    }

    /*
     * Google Routes API requires a destination.
     *
     * The last stop is the destination.
     * All previous stops are intermediate waypoints.
     */
    final destination = stops.last;

    final intermediateStops =
        stops.length > 1
            ? stops.sublist(0, stops.length - 1)
            : <RoutePoint>[];

    final body = <String, dynamic>{
      'origin': _waypoint(origin),
      'destination': _waypoint(destination),

      'travelMode': 'DRIVE',

      'routingPreference':
          'TRAFFIC_AWARE',

      'computeAlternativeRoutes': false,

      /*
       * IMPORTANT:
       *
       * Use GeoJSON instead of encoded polyline.
       * This removes the decoding problem.
       */
      'polylineQuality': 'HIGH_QUALITY',
      'polylineEncoding':
          'GEO_JSON_LINESTRING',

      'languageCode': 'en-US',
      'units': 'METRIC',

      'intermediates':
          intermediateStops
              .map(_waypoint)
              .toList(),

      /*
       * Google can optimize the order
       * of intermediate tourist places.
       */
      if (intermediateStops.isNotEmpty)
        'optimizeWaypointOrder': true,
    };

    final response = await http.post(
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
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Routes API failed '
        '(${response.statusCode}): '
        '${response.body}',
      );
    }

    final data =
        jsonDecode(response.body)
            as Map<String, dynamic>;

    final routes =
        data['routes'] as List<dynamic>?;

    if (routes == null ||
        routes.isEmpty) {
      throw Exception(
        'Routes API returned no route.',
      );
    }

    final route =
        routes.first as Map<String, dynamic>;

    final distanceMeters =
        (route['distanceMeters'] as num?)
                ?.toInt() ??
            0;

    final duration =
        route['duration']
                ?.toString() ??
            '0s';

    /*
     * --------------------------------------------------
     * Read optimized waypoint order
     * --------------------------------------------------
     */
    final orderedPoints =
        _getOrderedPoints(
      origin: origin,
      stops: stops,
      route: route,
    );

    /*
     * --------------------------------------------------
     * Read GeoJSON road polyline
     * --------------------------------------------------
     */
    final polylinePoints =
        _readGeoJsonPolyline(route);

    if (polylinePoints.length < 2) {
      throw Exception(
        'Routes API returned an invalid road polyline.',
      );
    }

    return RouteResult(
      distanceMeters: distanceMeters,
      duration: duration,
      orderedPoints: orderedPoints,
      polylinePoints: polylinePoints,
    );
  }

  Map<String, dynamic> _waypoint(
    RoutePoint point,
  ) {
    return {
      'location': {
        'latLng': {
          'latitude': point.latitude,
          'longitude': point.longitude,
        },
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
        route[
                'optimizedIntermediateWaypointIndex']
            as List<dynamic>?;

    if (indexes != null &&
        indexes.isNotEmpty) {
      for (final value in indexes) {
        final index =
            (value as num).toInt();

        if (index >= 0 &&
            index <
                stops.length - 1) {
          result.add(
            stops[index],
          );
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

  List<LatLngPoint> _readGeoJsonPolyline(
    Map<String, dynamic> route,
  ) {
    final polyline =
        route['polyline']
            as Map<String, dynamic>?;

    if (polyline == null) {
      return [];
    }

    final geoJson =
        polyline['geoJsonLinestring']
            as Map<String, dynamic>?;

    if (geoJson == null) {
      return [];
    }

    final coordinates =
        geoJson['coordinates']
            as List<dynamic>?;

    if (coordinates == null) {
      return [];
    }

    final points = <LatLngPoint>[];

    for (final coordinate
        in coordinates) {
      if (coordinate is! List ||
          coordinate.length < 2) {
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
      final longitude =
          (coordinate[0] as num)
              .toDouble();

      final latitude =
          (coordinate[1] as num)
              .toDouble();

      points.add(
        LatLngPoint(
          latitude: latitude,
          longitude: longitude,
        ),
      );
    }

    return points;
  }
}