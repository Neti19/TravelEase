import 'package:flutter_test/flutter_test.dart';
import 'package:travel_plan/services/route_service.dart';

void main() {
  group('RouteService.estimateRoute', () {
    final origin = RoutePoint(
      id: 'start',
      name: 'Start',
      latitude: 0,
      longitude: 0,
      type: 'start',
    );

    test('builds a marked estimate and keeps every stop', () {
      final far = RoutePoint(
        id: 'far',
        name: 'Far stop',
        latitude: 0,
        longitude: 1,
        type: 'tourist_spot',
      );
      final near = RoutePoint(
        id: 'near',
        name: 'Near stop',
        latitude: 0,
        longitude: 0.1,
        type: 'tourist_spot',
      );
      final destination = RoutePoint(
        id: 'destination',
        name: 'Destination',
        latitude: 0,
        longitude: 2,
        type: 'destination',
      );

      final route = RouteService.estimateRoute(
        origin: origin,
        stops: [far, near, destination],
        reason: 'test quota limit',
      );

      expect(route.isEstimated, isTrue);
      expect(route.estimateReason, 'test quota limit');
      expect(route.orderedPoints, [origin, near, far, destination]);
      expect(route.polylinePoints, hasLength(4));
      expect(route.distanceMeters, greaterThan(0));
      expect(route.duration, endsWith('s'));
      expect(route.formattedDuration, isNotEmpty);
    });

    test('builds a line for a route with one stop', () {
      final destination = RoutePoint(
        id: 'destination',
        name: 'Destination',
        latitude: 0,
        longitude: 0.25,
        type: 'destination',
      );

      final route = RouteService.estimateRoute(
        origin: origin,
        stops: [destination],
      );

      expect(route.isEstimated, isTrue);
      expect(route.orderedPoints, [origin, destination]);
      expect(route.polylinePoints, hasLength(2));
    });
  });
}
