import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../app_routes.dart';
import '../../services/route_service.dart';
import '../../services/trip_destination_service.dart';

class MapNavigationScreen extends StatefulWidget {
  final String tripId;

  const MapNavigationScreen({
    super.key,
    required this.tripId,
  });

  @override
  State<MapNavigationScreen> createState() =>
      _MapNavigationScreenState();
}

class _MapNavigationScreenState
    extends State<MapNavigationScreen> {
  final RouteService _routeService = RouteService();

  final TripDestinationService _destinationService =
      TripDestinationService();

  GoogleMapController? _mapController;

  final Set<Marker> _markers = {};

  final Set<Polyline> _polylines = {};

  RouteResult? _routeResult;

  bool _loading = true;

  String? _error;

  LatLng? _initialLocation;

  @override
  void initState() {
    super.initState();
    _calculateMainRoute();
  }

  // ============================================================
  // CALCULATE MAIN ROUTE
  // ============================================================

  Future<void> _calculateMainRoute() async {
    try {
      final tripId = widget.tripId.trim();

      if (tripId.isEmpty) {
        throw Exception(
          'Trip ID is missing. Please open Main Route from the trip.',
        );
      }

      if (!mounted) return;

      // Do NOT set _mapController = null here.
      // The GoogleMap remains alive while recalculating.
      setState(() {
        _loading = true;
        _error = null;
      });

      // --------------------------------------------------------
      // GET TRIP
      // --------------------------------------------------------

      final tripSnapshot =
          await FirebaseFirestore.instance
              .collection('trips')
              .doc(tripId)
              .get();

      if (!tripSnapshot.exists) {
        throw Exception(
          'Trip not found for ID: $tripId',
        );
      }

      final trip = tripSnapshot.data()!;

      // --------------------------------------------------------
      // GET STARTING LOCATION
      // --------------------------------------------------------

      final startLatitude =
          (trip['startLatitude'] as num?)?.toDouble();

      final startLongitude =
          (trip['startLongitude'] as num?)?.toDouble();

      final startLocation =
          trip['startLocation']?.toString() ??
              'Starting Location';

      if (startLatitude == null ||
          startLongitude == null) {
        throw Exception(
          'Starting location coordinates are missing.',
        );
      }

      _initialLocation = LatLng(
        startLatitude,
        startLongitude,
      );

      final origin = RoutePoint(
        id: 'start',
        name: startLocation,
        latitude: startLatitude,
        longitude: startLongitude,
        type: 'start',
      );

      // --------------------------------------------------------
      // GET SELECTED TOURIST PLACES
      // --------------------------------------------------------

      final selectedPlaces =
          await _destinationService.getSelectedPlaces(
        tripId,
      );

      if (selectedPlaces.isEmpty) {
        throw Exception(
          'No tourist places selected.',
        );
      }

      final routeStops = <RoutePoint>[];

      for (final place in selectedPlaces) {
        final latitude =
            (place['latitude'] as num?)?.toDouble();

        final longitude =
            (place['longitude'] as num?)?.toDouble();

        if (latitude == null ||
            longitude == null) {
          continue;
        }

        routeStops.add(
          RoutePoint(
            id: place['id']?.toString() ??
                'place_${routeStops.length}',
            name: place['name']?.toString() ??
                'Tourist Place',
            latitude: latitude,
            longitude: longitude,
            type: 'tourist_spot',
          ),
        );
      }

      // --------------------------------------------------------
      // GET SELECTED HOTEL
      // --------------------------------------------------------

      final selectedHotel =
          trip['selectedHotel'];

      if (selectedHotel is Map) {
        final location =
            selectedHotel['location'];

        if (location is Map) {
          final latitude =
              (location['latitude'] as num?)?.toDouble();

          final longitude =
              (location['longitude'] as num?)?.toDouble();

          if (latitude != null &&
              longitude != null) {
            final displayName =
                selectedHotel['displayName'];

            String hotelName =
                'Selected Hotel';

            if (displayName is Map &&
                displayName['text'] != null) {
              hotelName =
                  displayName['text'].toString();
            }

            routeStops.add(
              RoutePoint(
                id:
                    selectedHotel['id']?.toString() ??
                        'hotel',
                name: hotelName,
                latitude: latitude,
                longitude: longitude,
                type: 'hotel',
              ),
            );
          }
        }
      }

      // --------------------------------------------------------
      // GET SELECTED RESTAURANT
      // --------------------------------------------------------

      final selectedRestaurant =
          trip['selectedRestaurant'];

      if (selectedRestaurant is Map) {
        final location =
            selectedRestaurant['location'];

        if (location is Map) {
          final latitude =
              (location['latitude'] as num?)?.toDouble();

          final longitude =
              (location['longitude'] as num?)?.toDouble();

          if (latitude != null &&
              longitude != null) {
            final displayName =
                selectedRestaurant['displayName'];

            String restaurantName =
                'Selected Restaurant';

            if (displayName is Map &&
                displayName['text'] != null) {
              restaurantName =
                  displayName['text'].toString();
            }

            routeStops.add(
              RoutePoint(
                id:
                    selectedRestaurant['id']
                            ?.toString() ??
                        'restaurant',
                name: restaurantName,
                latitude: latitude,
                longitude: longitude,
                type: 'restaurant',
              ),
            );
          }
        }
      }

      // --------------------------------------------------------
      // CHECK ROUTE STOPS
      // --------------------------------------------------------

      if (routeStops.isEmpty) {
        throw Exception(
          'No valid locations available for routing.',
        );
      }

      // --------------------------------------------------------
      // CALCULATE GOOGLE ROUTES API ROUTE
      // --------------------------------------------------------

      final result =
          await _routeService.calculateRoute(
        origin: origin,
        stops: routeStops,
      );

      if (!mounted) return;

      setState(() {
        _routeResult = result;
        _loading = false;
      });

      // --------------------------------------------------------
      // BUILD MAP
      // --------------------------------------------------------

      _buildMap(result);

      // --------------------------------------------------------
      // SAVE ROUTE TO FIRESTORE
      // --------------------------------------------------------

      await FirebaseFirestore.instance
          .collection('trips')
          .doc(tripId)
          .set(
        {
          'route': {
            'distanceMeters':
                result.distanceMeters,
            'duration':
                result.duration,
            'distanceKm':
                result.distanceKm,
            'formattedDuration':
                result.formattedDuration,
            'orderedStops':
                result.orderedPoints
                    .map(
                      (point) => point.toMap(),
                    )
                    .toList(),
            'createdAt':
                FieldValue.serverTimestamp(),
          },
          'routeGenerated': true,
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  // ============================================================
  // BUILD MAP
  // ============================================================

  void _buildMap(
    RouteResult result,
  ) {
    if (!mounted) return;

    final markers = <Marker>{};

    // ----------------------------------------------------------
    // ADD MARKERS
    // ----------------------------------------------------------

    for (int i = 0;
        i < result.orderedPoints.length;
        i++) {
      final point =
          result.orderedPoints[i];

      final position = LatLng(
        point.latitude,
        point.longitude,
      );

      BitmapDescriptor icon =
          BitmapDescriptor.defaultMarker;

      if (point.type == 'start') {
        icon =
            BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueGreen,
        );
      } else if (point.type == 'hotel') {
        icon =
            BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueRed,
        );
      } else if (point.type == 'restaurant') {
        icon =
            BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueOrange,
        );
      } else {
        icon =
            BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueAzure,
        );
      }

      markers.add(
        Marker(
          markerId: MarkerId(
            point.id,
          ),
          position: position,
          icon: icon,
          infoWindow: InfoWindow(
            title:
                '${i + 1}. ${point.name}',
            snippet:
                _getTypeText(
              point.type,
            ),
          ),
        ),
      );
    }

    // ----------------------------------------------------------
    // CREATE ROAD POLYLINE
    // ----------------------------------------------------------

    final polylinePoints =
        result.polylinePoints
            .map(
              (point) => LatLng(
                point.latitude,
                point.longitude,
              ),
            )
            .toList();

    if (polylinePoints.length < 2) {
      throw Exception(
        'Route does not contain enough points to draw the road.',
      );
    }

    final polylines =
        <Polyline>{
      Polyline(
        polylineId:
            const PolylineId(
          'main_route',
        ),
        points: polylinePoints,
        width: 6,
        color: Colors.blue,
        geodesic: false,
      ),
    };

    setState(() {
      _markers
        ..clear()
        ..addAll(markers);

      _polylines
        ..clear()
        ..addAll(polylines);
    });

    // ----------------------------------------------------------
    // FIT MAP TO ROUTE
    // ----------------------------------------------------------

    _fitRouteOnMap(
      polylinePoints,
    );
  }

  // ============================================================
  // GET TYPE TEXT
  // ============================================================

  String _getTypeText(
    String type,
  ) {
    switch (type) {
      case 'start':
        return 'Starting Location';

      case 'tourist_spot':
        return 'Tourist Place';

      case 'hotel':
        return 'Hotel';

      case 'restaurant':
        return 'Restaurant';

      default:
        return 'Location';
    }
  }

  // ============================================================
  // FIT ROUTE ON MAP
  // ============================================================

  Future<void> _fitRouteOnMap(
    List<LatLng> points,
  ) async {
    final controller =
        _mapController;

    if (controller == null ||
        points.isEmpty ||
        !mounted) {
      return;
    }

    double minLat =
        points.first.latitude;

    double maxLat =
        points.first.latitude;

    double minLng =
        points.first.longitude;

    double maxLng =
        points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) {
        minLat =
            point.latitude;
      }

      if (point.latitude > maxLat) {
        maxLat =
            point.latitude;
      }

      if (point.longitude < minLng) {
        minLng =
            point.longitude;
      }

      if (point.longitude > maxLng) {
        maxLng =
            point.longitude;
      }
    }

    // Prevent invalid bounds
    // when points are extremely close.
    if ((maxLat - minLat).abs() <
        0.00001) {
      minLat -= 0.001;
      maxLat += 0.001;
    }

    if ((maxLng - minLng).abs() <
        0.00001) {
      minLng -= 0.001;
      maxLng += 0.001;
    }

    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              minLat,
              minLng,
            ),
            northeast: LatLng(
              maxLat,
              maxLng,
            ),
          ),
          70,
        ),
      );
    } catch (e) {
      debugPrint(
        'Could not move map camera: $e',
      );
    }
  }

  // ============================================================
  // START NAVIGATION
  // ============================================================

  Future<void> _startNavigation() async {
    if (_routeResult == null) {
      _showMessage(
        'Route is not ready yet.',
      );
      return;
    }

    _showMessage(
      'Route is ready. Turn-by-turn navigation can be started from the route.',
    );
  }

  // ============================================================
  // SHOW MESSAGE
  // ============================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          message,
        ),
      ),
    );
  }

  // ============================================================
  // GO HOME
  // ============================================================

  void _goHome() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.home,
      (route) => false,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '7. Main Route',
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh,
            ),
            tooltip:
                'Recalculate Route',
            onPressed:
                _loading
                    ? null
                    : _calculateMainRoute,
          ),
          IconButton(
            icon: const Icon(
              Icons.home,
            ),
            onPressed: _goHome,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar:
          _buildBottomBar(),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    // ----------------------------------------------------------
    // ERROR
    // ----------------------------------------------------------

    if (_error != null) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.route_outlined,
                size: 70,
              ),
              const SizedBox(
                height: 16,
              ),
              const Text(
                'Could not calculate route',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              const SizedBox(
                height: 12,
              ),
              Text(
                _error!,
                textAlign:
                    TextAlign.center,
              ),
              const SizedBox(
                height: 20,
              ),
              ElevatedButton(
                onPressed:
                    _calculateMainRoute,
                child: const Text(
                  'Try Again',
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ----------------------------------------------------------
    // MAP
    // ----------------------------------------------------------

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition:
              CameraPosition(
            target:
                _initialLocation ??
                    const LatLng(
                      22.6916,
                      72.8634,
                    ),
            zoom: 10,
          ),

          onMapCreated:
              (controller) async {
            _mapController =
                controller;

            if (_routeResult != null) {
              final points =
                  _routeResult!
                      .polylinePoints
                      .map(
                        (point) =>
                            LatLng(
                          point.latitude,
                          point.longitude,
                        ),
                      )
                      .toList();

              await _fitRouteOnMap(
                points,
              );
            }
          },

          markers: _markers,

          polylines: _polylines,

          zoomControlsEnabled:
              true,

          myLocationButtonEnabled:
              true,
        ),

        // ------------------------------------------------------
        // LOADING OVERLAY
        // ------------------------------------------------------

        if (_loading)
          Container(
            color: Colors.white
                .withOpacity(0.75),
            child: const Center(
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(
                    height: 20,
                  ),
                  Text(
                    'Finding the best route...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w500,
                    ),
                  ),
                  SizedBox(
                    height: 8,
                  ),
                  Text(
                    'Calculating distance and travel time',
                  ),
                ],
              ),
            ),
          ),

        // ------------------------------------------------------
        // ROUTE SUMMARY
        // ------------------------------------------------------

        if (!_loading &&
            _routeResult != null)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child:
                _buildRouteSummary(),
          ),
      ],
    );
  }

  // ============================================================
  // ROUTE SUMMARY
  // ============================================================

  Widget _buildRouteSummary() {
    final result =
        _routeResult!;

    return Card(
      elevation: 5,
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Optimized Route',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Row(
              children: [
                const Icon(
                  Icons.route,
                  size: 20,
                ),
                const SizedBox(
                  width: 8,
                ),
                Text(
                  '${result.distanceKm.toStringAsFixed(1)} km',
                ),
                const SizedBox(
                  width: 20,
                ),
                const Icon(
                  Icons.access_time,
                  size: 20,
                ),
                const SizedBox(
                  width: 8,
                ),
                Text(
                  result.formattedDuration,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM BAR
  // ============================================================

  Widget _buildBottomBar() {
    if (_loading ||
        _routeResult == null) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            // --------------------------------------------------
            // ROUTE STOPS
            // --------------------------------------------------

            SizedBox(
              height: 100,
              child:
                  ListView.builder(
                itemCount:
                    _routeResult!
                        .orderedPoints
                        .length,
                itemBuilder:
                    (context, index) {
                  final point =
                      _routeResult!
                          .orderedPoints[
                              index];

                  return ListTile(
                    dense: true,
                    leading:
                        CircleAvatar(
                      radius: 14,
                      child: Text(
                        '$index',
                        style:
                            const TextStyle(
                          fontSize: 12,
                        ),
                      ),
                    ),
                    title: Text(
                      point.name,
                    ),
                    subtitle: Text(
                      _getTypeText(
                        point.type,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            // --------------------------------------------------
            // START NAVIGATION
            // --------------------------------------------------

            SizedBox(
              width:
                  double.infinity,
              child:
                 ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.generateItinerary,
                    arguments: {
                      'tripId': widget.tripId,
                    },
                  );
                },
                icon: const Icon(
                  Icons.auto_awesome,
                ),
                label: const Text(
                  'Generate Itinerary',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}