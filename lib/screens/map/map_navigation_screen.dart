
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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

class _MapNavigationScreenState extends State<MapNavigationScreen> {
  final RouteService _routeService = RouteService();

  final TripDestinationService _destinationService =
  TripDestinationService();

  GoogleMapController? _mapController;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  RouteResult? _routeResult;

  bool _loading = true;
  bool _saving = false;

  String? _error;

  LatLng? _initialLocation;

  String _transportType = 'Transportation';

  @override
  void initState() {
    super.initState();
    _calculateMainRoute();
  }

  // ============================================================
  // CALCULATE ROUTE
  // ============================================================

  Future<void> _calculateMainRoute() async {
    try {
      final tripId = widget.tripId.trim();

      if (tripId.isEmpty) {
        throw Exception(
          'Trip ID is missing. Please open the route from your trip.',
        );
      }

      if (!mounted) return;

      setState(() {
        _loading = true;
        _error = null;
      });

      // GET TRIP

      final tripSnapshot = await FirebaseFirestore.instance
          .collection('trips')
          .doc(tripId)
          .get();

      if (!tripSnapshot.exists) {
        throw Exception('Trip not found.');
      }

      final trip = tripSnapshot.data()!;

      // TRANSPORT

      final selectedTransport = trip['selectedTransport'];

      if (selectedTransport is Map) {
        final type = selectedTransport['type']?.toString();

        if (type != null && type.trim().isNotEmpty) {
          _transportType = type;
        }
      }

      // STARTING LOCATION

      final startLatitude =
      (trip['startLatitude'] as num?)?.toDouble();

      final startLongitude =
      (trip['startLongitude'] as num?)?.toDouble();

      final startLocation =
          trip['startLocation']?.toString() ??
              'Starting Location';

      if (startLatitude == null || startLongitude == null) {
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

      // GET DESTINATIONS AND TOURIST PLACES

      final destinations =
      await _destinationService.getDestinations(tripId);

      final selectedPlaces =
      await _destinationService.getSelectedPlaces(tripId);

      final routeStops = <RoutePoint>[];

      for (final place in destinations) {
        _addRouteStop(routeStops, place, 'destination');
      }

      for (final place in selectedPlaces) {
        _addRouteStop(routeStops, place, 'tourist_spot');
      }

      if (routeStops.isEmpty) {
        throw Exception(
          'Add at least one destination before creating a route.',
        );
      }

      // SELECTED HOTEL

      final selectedHotel = trip['selectedHotel'];

      if (selectedHotel is Map) {
        final location = selectedHotel['location'];

        if (location is Map) {
          final latitude =
          (location['latitude'] as num?)?.toDouble();

          final longitude =
          (location['longitude'] as num?)?.toDouble();

          if (latitude != null && longitude != null) {
            final displayName = selectedHotel['displayName'];

            routeStops.add(
              RoutePoint(
                id: selectedHotel['id']?.toString() ?? 'hotel',
                name: displayName is Map &&
                    displayName['text'] != null
                    ? displayName['text'].toString()
                    : 'Selected Hotel',
                latitude: latitude,
                longitude: longitude,
                type: 'hotel',
              ),
            );
          }
        }
      }

      // SELECTED RESTAURANT

      final selectedRestaurant = trip['selectedRestaurant'];

      if (selectedRestaurant is Map) {
        final location = selectedRestaurant['location'];

        if (location is Map) {
          final latitude =
          (location['latitude'] as num?)?.toDouble();

          final longitude =
          (location['longitude'] as num?)?.toDouble();

          if (latitude != null && longitude != null) {
            final displayName =
            selectedRestaurant['displayName'];

            routeStops.add(
              RoutePoint(
                id: selectedRestaurant['id']?.toString() ??
                    'restaurant',
                name: displayName is Map &&
                    displayName['text'] != null
                    ? displayName['text'].toString()
                    : 'Selected Restaurant',
                latitude: latitude,
                longitude: longitude,
                type: 'restaurant',
              ),
            );
          }
        }
      }

      // CALCULATE GOOGLE ROUTE

      final result = await _routeService.calculateRoute(
        origin: origin,
        stops: routeStops,
      );

      if (!mounted) return;

      setState(() {
        _routeResult = result;
        _loading = false;
      });

      _buildMap(result);

      // SAVE ROUTE TO FIRESTORE

      await FirebaseFirestore.instance
          .collection('trips')
          .doc(tripId)
          .set(
        {
          'route': {
            'distanceMeters': result.distanceMeters,
            'duration': result.duration,
            'distanceKm': result.distanceKm,
            'formattedDuration': result.formattedDuration,
            'orderedStops': result.orderedPoints
                .map((point) => point.toMap())
                .toList(),
            'createdAt': FieldValue.serverTimestamp(),
          },
          'routeGenerated': true,
          'updatedAt': FieldValue.serverTimestamp(),
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
  // NAVIGATE TO AN INDIVIDUAL STOP
  // ============================================================

  Future<void> _openGoogleMapsNavigation(RoutePoint point) async {
    final uri = Uri.https(
      'www.google.com',
      '/maps/dir/',
      {
        'api': '1',
        'destination': '${point.latitude},${point.longitude}',
        'travelmode': 'driving',
        'dir_action': 'navigate',
      },
    );

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        _showMessage('Could not open Google Maps.');
      }
    } catch (e) {
      _showMessage('Could not open Google Maps: $e');
    }
  }

  // ============================================================
  // NAVIGATE THROUGH THE FULL ROUTE
  // ============================================================

  Future<void> _openFullRouteNavigation() async {
    final result = _routeResult;

    if (result == null || result.orderedPoints.length < 2) {
      _showMessage('No route is available for navigation.');
      return;
    }

    final points = result.orderedPoints;
    final origin = points.first;
    final destination = points.last;

    final waypoints = points
        .skip(1)
        .take(points.length - 2)
        .map((point) => '${point.latitude},${point.longitude}')
        .join('|');

    final uri = Uri.https(
      'www.google.com',
      '/maps/dir/',
      {
        'api': '1',
        'origin': '${origin.latitude},${origin.longitude}',
        'destination':
        '${destination.latitude},${destination.longitude}',
        if (waypoints.isNotEmpty) 'waypoints': waypoints,
        'travelmode': 'driving',
        'dir_action': 'navigate',
      },
    );

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        _showMessage('Could not open Google Maps.');
      }
    } catch (e) {
      _showMessage('Could not open Google Maps: $e');
    }
  }

  // ============================================================
  // ADD ROUTE STOP
  // ============================================================

  void _addRouteStop(
      List<RoutePoint> routeStops,
      Map<String, dynamic> place,
      String type,
      ) {
    final latitude =
    (place['latitude'] as num?)?.toDouble();

    final longitude =
    (place['longitude'] as num?)?.toDouble();

    if (latitude == null || longitude == null) {
      return;
    }

    final duplicate = routeStops.any(
          (stop) =>
      stop.type != 'hotel' &&
          stop.type != 'restaurant' &&
          Geolocator.distanceBetween(
            stop.latitude,
            stop.longitude,
            latitude,
            longitude,
          ) <
              30,
    );

    if (duplicate) return;

    final rawName = place['name']?.toString().trim() ?? '';

    final address = place['address']?.toString().trim() ?? '';

    final name = rawName.isNotEmpty
        ? rawName
        : address.isNotEmpty
        ? address.split(',').first
        : 'Stop ${routeStops.length + 1}';

    routeStops.add(
      RoutePoint(
        id: place['id']?.toString() ??
            'stop_${routeStops.length}',
        name: name,
        latitude: latitude,
        longitude: longitude,
        type: type,
      ),
    );
  }

  // ============================================================
  // BUILD MAP
  // ============================================================

  void _buildMap(RouteResult result) {
    if (!mounted) return;

    final markers = <Marker>{};

    for (int i = 0; i < result.orderedPoints.length; i++) {
      final point = result.orderedPoints[i];

      final position = LatLng(
        point.latitude,
        point.longitude,
      );

      BitmapDescriptor icon = BitmapDescriptor.defaultMarker;

      if (point.type == 'start') {
        icon = BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueGreen,
        );
      } else if (point.type == 'hotel') {
        icon = BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueRed,
        );
      } else if (point.type == 'restaurant') {
        icon = BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueOrange,
        );
      } else {
        icon = BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueAzure,
        );
      }

      markers.add(
        Marker(
          markerId: MarkerId('${point.id}_$i'),
          position: position,
          icon: icon,
          infoWindow: InfoWindow(
            title: '${i + 1}. ${point.name}',
            snippet: _getTypeText(point.type),
          ),
        ),
      );
    }

    final polylinePoints = result.polylinePoints
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

    final polylines = <Polyline>{
      Polyline(
        polylineId: const PolylineId('main_route'),
        points: polylinePoints,
        width: 6,
        color: const Color(0xFF1677FF),
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

    _fitRouteOnMap(polylinePoints);
  }

  // ============================================================
  // TYPE TEXT
  // ============================================================

  String _getTypeText(String type) {
    switch (type) {
      case 'start':
        return 'Starting Location';
      case 'destination':
        return 'Trip Destination';
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

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'start':
        return Icons.trip_origin_rounded;
      case 'destination':
        return Icons.location_on_rounded;
      case 'tourist_spot':
        return Icons.photo_camera_rounded;
      case 'hotel':
        return Icons.hotel_rounded;
      case 'restaurant':
        return Icons.restaurant_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'start':
        return const Color(0xFF2EAD67);
      case 'destination':
        return const Color(0xFF1677FF);
      case 'tourist_spot':
        return const Color(0xFFFF8A65);
      case 'hotel':
        return const Color(0xFFE53935);
      case 'restaurant':
        return const Color(0xFFFF8A65);
      default:
        return const Color(0xFF607D8B);
    }
  }

  // ============================================================
  // FIT ROUTE ON MAP
  // ============================================================

  Future<void> _fitRouteOnMap(List<LatLng> points) async {
    final controller = _mapController;

    if (controller == null || points.isEmpty || !mounted) {
      return;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    if ((maxLat - minLat).abs() < 0.00001) {
      minLat -= 0.001;
      maxLat += 0.001;
    }

    if ((maxLng - minLng).abs() < 0.00001) {
      minLng -= 0.001;
      maxLng += 0.001;
    }

    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          90,
        ),
      );
    } catch (e) {
      debugPrint('Could not move map camera: $e');
    }
  }

  // ============================================================
  // GENERATE ITINERARY
  // ============================================================

  Future<void> _generateItinerary() async {
    if (_routeResult == null || _saving) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.tripId)
          .set(
        {
          'routeConfirmed': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      Navigator.pushNamed(
        context,
        AppRoutes.generateItinerary,
        arguments: {
          'tripId': widget.tripId,
        },
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage('Could not continue: $e');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ============================================================
  // HOME
  // ============================================================

  void _goHome() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.home,
          (_) => false,
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_error != null) {
      return _buildError();
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _initialLocation ??
                const LatLng(22.6916, 72.8634),
            zoom: 10,
          ),
          onMapCreated: (controller) async {
            _mapController = controller;

            if (_routeResult != null) {
              final points = _routeResult!.polylinePoints
                  .map(
                    (point) => LatLng(
                  point.latitude,
                  point.longitude,
                ),
              )
                  .toList();

              await _fitRouteOnMap(points);
            }
          },
          markers: _markers,
          polylines: _polylines,
          zoomControlsEnabled: false,
          myLocationButtonEnabled: true,
          mapToolbarEnabled: false,
          compassEnabled: true,
        ),

        // TOP BAR

        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                _mapButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 17,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.10),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Your Route',
                      style: TextStyle(
                        color: Color(0xFF102A43),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _mapButton(
                  icon: Icons.refresh_rounded,
                  onTap: _loading ? null : _calculateMainRoute,
                ),
              ],
            ),
          ),
        ),

        // ROUTE SUMMARY

        if (!_loading && _routeResult != null)
          Positioned(
            top: 92,
            left: 16,
            right: 16,
            child: _buildRouteSummary(),
          ),

        // LOADING

        if (_loading)
          Container(
            color: Colors.white.withOpacity(0.78),
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(30),
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 62,
                      width: 62,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1677FF).withOpacity(0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Color(0xFF1677FF),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Creating your route',
                      style: TextStyle(
                        color: Color(0xFF102A43),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Finding the best order for your stops...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // MAP BUTTON
  // ============================================================

  Widget _mapButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.15),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          height: 48,
          width: 48,
          child: Icon(
            icon,
            color: onTap == null
                ? Colors.grey
                : const Color(0xFF102A43),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ROUTE SUMMARY
  // ============================================================

  Widget _buildRouteSummary() {
    final result = _routeResult!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF1677FF).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.route_rounded,
                  color: Color(0xFF1677FF),
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Optimized Route',
                      style: TextStyle(
                        color: Color(0xFF102A43),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Your stops are arranged efficiently',
                      style: TextStyle(
                        color: Color(0xFF78909C),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _summaryItem(
                  Icons.route_rounded,
                  '${result.distanceKm.toStringAsFixed(1)} km',
                  'Total distance',
                ),
              ),
              Container(
                height: 35,
                width: 1,
                color: const Color(0xFFE5EBF0),
              ),
              Expanded(
                child: _summaryItem(
                  Icons.access_time_rounded,
                  result.formattedDuration,
                  'Travel time',
                ),
              ),
              Container(
                height: 35,
                width: 1,
                color: const Color(0xFFE5EBF0),
              ),
              Expanded(
                child: _summaryItem(
                  Icons.directions_car_rounded,
                  _transportType,
                  'Transport',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(
      IconData icon,
      String value,
      String label,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Column(
        children: [
          Icon(
            icon,
            color: const Color(0xFF1677FF),
            size: 19,
          ),
          const SizedBox(height: 5),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF102A43),
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF90A4AE),
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError() {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8A65).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.route_outlined,
                  color: Color(0xFFFF7043),
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'We couldn’t create your route',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF102A43),
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _error ??
                    'Something went wrong while creating the route.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  height: 1.4,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _calculateMainRoute,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1677FF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM BAR
  // ============================================================

  Widget _buildBottomBar() {
    if (_loading || _routeResult == null) {
      return const SizedBox.shrink();
    }

    final points = _routeResult!.orderedPoints;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 15),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(26),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // HANDLE

            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD5DEE5),
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            const SizedBox(height: 13),

            // TITLE

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Your stops',
                    style: TextStyle(
                      color: Color(0xFF102A43),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1677FF).withOpacity(0.09),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${points.length} stops',
                    style: const TextStyle(
                      color: Color(0xFF1677FF),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // STOP CARDS

            SizedBox(
              height: 112,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: points.length,
                itemBuilder: (context, index) {
                  final point = points[index];
                  final isLast = index == points.length - 1;

                  return Row(
                    children: [
                      _buildStopCard(point, index),
                      if (!isLast)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 5),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: Color(0xFFB0BEC5),
                            size: 18,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // START GOOGLE MAPS NAVIGATION

            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _openFullRouteNavigation,
                icon: const Icon(Icons.navigation_rounded),
                label: const Text('Start Navigation'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1677FF),
                  side: const BorderSide(
                    color: Color(0xFF1677FF),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // GENERATE ITINERARY

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _generateItinerary,
                icon: _saving
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  _saving ? 'Preparing...' : 'Generate My Itinerary',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1677FF),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFB8D6F7),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // STOP CARD
  // ============================================================

  Widget _buildStopCard(RoutePoint point, int index) {
    final typeColor = _getTypeColor(point.type);

    return GestureDetector(
      onTap: () => _openGoogleMapsNavigation(point),
      child: Container(
        width: 190,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE4EBF0),
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 39,
              width: 39,
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getTypeIcon(point.type),
                color: typeColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'STOP ${index + 1}',
                    style: TextStyle(
                      color: typeColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    point.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF102A43),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getTypeText(point.type),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF90A4AE),
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
