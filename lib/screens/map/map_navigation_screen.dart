import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/tourist_spot.dart';
import '../../models/hotel.dart';
import '../../models/restaurant.dart';

class MapNavigationScreen extends StatefulWidget {
  final List<TouristSpot> spots;
  final Hotel? hotel;
  final List<Restaurant> restaurants;

  const MapNavigationScreen({
    super.key,
    this.spots = const [],
    this.hotel,
    this.restaurants = const [],
  });

  @override
  State<MapNavigationScreen> createState() => _MapNavigationScreenState();
}

class _MapNavigationScreenState extends State<MapNavigationScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  bool _hasError = false;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(35.6762, 139.6503), // Tokyo Center default
    zoom: 12.0,
  );

  @override
  void initState() {
    super.initState();
    _loadMapItems();
  }

  void _loadMapItems() {
    try {
      List<LatLng> routePoints = [];

      // 1. Hotel Marker
      if (widget.hotel != null) {
        final hotelLatLng = LatLng(widget.hotel!.latitude, widget.hotel!.longitude);
        routePoints.add(hotelLatLng);

        _markers.add(
          Marker(
            markerId: MarkerId('hotel_${widget.hotel!.id}'),
            position: hotelLatLng,
            infoWindow: InfoWindow(
              title: widget.hotel!.name,
              snippet: 'Hotel Stay',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
        );
      }

      // 2. Tourist Spot Markers
      for (var spot in widget.spots) {
        final spotLatLng = LatLng(spot.latitude, spot.longitude);
        routePoints.add(spotLatLng);

        _markers.add(
          Marker(
            markerId: MarkerId('spot_${spot.id}'),
            position: spotLatLng,
            infoWindow: InfoWindow(
              title: spot.name,
              snippet: 'Tourist Attraction',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          ),
        );
      }

      // 3. Restaurant Markers
      for (var rest in widget.restaurants) {
        final restLatLng = LatLng(rest.latitude, rest.longitude);

        _markers.add(
          Marker(
            markerId: MarkerId('rest_${rest.id}'),
            position: restLatLng,
            infoWindow: InfoWindow(
              title: rest.name,
              snippet: rest.cuisineType,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          ),
        );
      }

      // 4. Connect points with polyline
      if (routePoints.length > 1) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route_path'),
            points: routePoints,
            color: Colors.blue,
            width: 5,
          ),
        );
      }
    } catch (e) {
      setState(() => _hasError = true);
    }
  }

  void _goHome() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map & Navigation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Center Location',
            onPressed: () {
              if (_markers.isNotEmpty && _mapController != null) {
                _mapController!.animateCamera(
                  CameraUpdate.newLatLngZoom(_markers.first.position, 13),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Go to Home',
            onPressed: _goHome,
          ),
        ],
      ),
      body: _hasError
          ? _buildErrorFallback()
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: _initialPosition,
                  markers: _markers,
                  polylines: _polylines,
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                  },
                ),
                
                // Map Legend Overlay
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        _LegendItem(color: Colors.red, label: 'Hotel'),
                        _LegendItem(color: Colors.blue, label: 'Tourist Spot'),
                        _LegendItem(color: Colors.orange, label: 'Restaurant'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: Row(
          children: [
            OutlinedButton.icon(
              onPressed: _goHome,
              icon: const Icon(Icons.home),
              label: const Text('Home'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(100, 48),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Starting Turn-by-Turn Navigation...')),
                  );
                },
                icon: const Icon(Icons.navigation),
                label: const Text('Start Navigation'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorFallback() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Unable to Load Google Maps JS SDK',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please check web/index.html and ensure the Google Maps script tag is added.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _goHome,
              icon: const Icon(Icons.home),
              label: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on, color: color, size: 16),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}