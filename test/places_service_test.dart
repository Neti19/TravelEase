import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:travel_plan/services/places_service.dart';
import 'package:travel_plan/services/route_service.dart';

void main() {
  setUpAll(() {
    dotenv.testLoad(
      fileInput: 'PLACES_API_KEY=test-key\nROUTES_API_KEY=test-key',
    );
  });

  group('PlacesService.searchNearbyHotels', () {
    test('uses lodging type and parses Nearby Search results', () async {
      final requests = <http.Request>[];
      final hotels = await http.runWithClient(
        () => PlacesService().searchNearbyHotels(latitude: 19, longitude: 72),
        () => MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'places': [
                {
                  'id': 'hotel-1',
                  'displayName': {'text': 'Test Hotel'},
                  'location': {'latitude': 19.01, 'longitude': 72.01},
                },
              ],
            }),
            200,
          );
        }),
      );

      expect(hotels, hasLength(1));
      expect(hotels.single['id'], 'hotel-1');
      expect(requests, hasLength(1));
      expect(requests.single.url.path, endsWith('places:searchNearby'));
      expect(jsonDecode(requests.single.body)['includedTypes'], ['lodging']);
    });

    test('falls back to nearby text results and enforces the radius', () async {
      final requests = <http.Request>[];
      final hotels = await http.runWithClient(
        () => PlacesService().searchNearbyHotels(
          latitude: 19,
          longitude: 72,
          radius: 3000,
        ),
        () => MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('places:searchNearby')) {
            return http.Response('{"places":[]}', 200);
          }

          return http.Response(
            jsonEncode({
              'places': [
                {
                  'id': 'nearby-hotel',
                  'location': {'latitude': 19.01, 'longitude': 72},
                },
                {
                  'id': 'distant-hotel',
                  'location': {'latitude': 19.04, 'longitude': 72},
                },
              ],
            }),
            200,
          );
        }),
      );

      expect(requests, hasLength(2));
      expect(requests.last.url.path, endsWith('places:searchText'));
      expect(jsonDecode(requests.last.body)['pageSize'], 20);
      expect(
        jsonDecode(requests.last.body).containsKey('maxResultCount'),
        isFalse,
      );
      expect(hotels.map((hotel) => hotel['id']), ['nearby-hotel']);
    });
  });

  group('PlacesService.autocomplete', () {
    test('falls back to Text Search when autocomplete has no predictions',
        () async {
      final requests = <http.Request>[];
      final suggestions = await http.runWithClient(
        () => PlacesService().autocomplete(
          'Kyoto',
          latitude: 19,
          longitude: 72,
        ),
        () => MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('places:autocomplete')) {
            return http.Response('{"suggestions":[]}', 200);
          }

          return http.Response(
            jsonEncode({
              'places': [
                {
                  'id': 'destination-1',
                  'displayName': {'text': 'Kyoto'},
                  'formattedAddress': 'Kyoto, Japan',
                },
              ],
            }),
            200,
          );
        }),
      );

      expect(requests, hasLength(2));
      expect(requests.last.url.path, endsWith('places:searchText'));
      expect(suggestions, hasLength(1));
      expect(suggestions.single['placeId'], 'destination-1');
      expect(suggestions.single['mainText'], 'Kyoto');
      expect(suggestions.single['secondaryText'], 'Kyoto, Japan');
    });
  });

  group('PlacesService.searchNearbyDestinations', () {
    test('falls back to text search when Nearby Search fails', () async {
      final requests = <http.Request>[];
      final destinations = await http.runWithClient(
        () => PlacesService().searchNearbyDestinations(
          latitude: 19,
          longitude: 72,
          radius: 3000,
        ),
        () => MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('places:searchNearby')) {
            return http.Response(
              '{"error":{"message":"Invalid included type"}}',
              400,
            );
          }
          return http.Response(
            jsonEncode({
              'places': [
                {
                  'id': 'nearby-destination',
                  'location': {'latitude': 19.01, 'longitude': 72},
                },
                {
                  'id': 'distant-destination',
                  'location': {'latitude': 19.04, 'longitude': 72},
                },
              ],
            }),
            200,
          );
        }),
      );

      expect(requests, hasLength(2));
      expect(requests.last.url.path, endsWith('places:searchText'));
      expect(destinations.map((place) => place['id']), [
        'nearby-destination',
      ]);
    });
  });

  group('PlacesService.searchNearbyRestaurants', () {
    test('uses Nearby Search results for restaurant types', () async {
      final requests = <http.Request>[];
      final restaurants = await http.runWithClient(
        () => PlacesService().searchNearbyRestaurants(
          latitude: 19,
          longitude: 72,
        ),
        () => MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'places': [
                {
                  'id': 'restaurant-1',
                  'displayName': {'text': 'Test Restaurant'},
                  'location': {'latitude': 19.01, 'longitude': 72.01},
                },
              ],
            }),
            200,
          );
        }),
      );

      expect(restaurants, hasLength(1));
      expect(restaurants.single['id'], 'restaurant-1');
      expect(requests, hasLength(1));
      expect(requests.single.url.path, endsWith('places:searchNearby'));
      expect(jsonDecode(requests.single.body)['includedTypes'], ['restaurant']);
    });

    test('falls back to text search and enforces the radius', () async {
      final requests = <http.Request>[];
      final restaurants = await http.runWithClient(
        () => PlacesService().searchNearbyRestaurants(
          latitude: 19,
          longitude: 72,
          radius: 3000,
          includedTypes: const [
            'breakfast_restaurant',
            'cafe',
            'bakery',
            'restaurant',
          ],
          includeOpeningHours: true,
        ),
        () => MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('places:searchNearby')) {
            return http.Response(
              '{"error":{"message":"Invalid included type"}}',
              400,
            );
          }

          return http.Response(
            jsonEncode({
              'places': [
                {
                  'id': 'nearby-restaurant',
                  'location': {'latitude': 19.01, 'longitude': 72},
                },
                {
                  'id': 'distant-restaurant',
                  'location': {'latitude': 19.04, 'longitude': 72},
                },
              ],
            }),
            200,
          );
        }),
      );

      expect(requests, hasLength(2));
      expect(requests.last.url.path, endsWith('places:searchText'));
      expect(
        jsonDecode(requests.last.body)['textQuery'],
        'breakfast restaurants cafes bakeries',
      );
      expect(jsonDecode(requests.last.body)['pageSize'], 20);
      expect(
        jsonDecode(requests.last.body).containsKey('maxResultCount'),
        isFalse,
      );
      expect(restaurants.map((restaurant) => restaurant['id']), [
        'nearby-restaurant',
      ]);
    });
  });

  test('RouteService estimates the route when the API fails', () async {
    final origin = RoutePoint(
      id: 'start',
      name: 'Start',
      latitude: 19,
      longitude: 72,
      type: 'start',
    );
    final destination = RoutePoint(
      id: 'destination',
      name: 'Destination',
      latitude: 19.1,
      longitude: 72.1,
      type: 'destination',
    );

    final route = await http.runWithClient(
      () => RouteService().calculateRoute(origin: origin, stops: [destination]),
      () => MockClient(
        (_) async =>
            http.Response('{"error":{"message":"API not enabled"}}', 403),
      ),
    );

    expect(route.isEstimated, isTrue);
    expect(route.orderedPoints, [origin, destination]);
    expect(route.polylinePoints, hasLength(2));
  });
}
