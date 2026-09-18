import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../app_routes.dart';
import '../../services/places_service.dart';
import '../../services/trip_destination_service.dart';
import '../../services/trip_service.dart';

class SelectDestinationScreen extends StatefulWidget {
  final String? tripId;

  const SelectDestinationScreen({super.key, this.tripId});

  @override
  State<SelectDestinationScreen> createState() =>
      _SelectDestinationScreenState();
}

class _SelectDestinationScreenState extends State<SelectDestinationScreen> {
  final TextEditingController _searchController = TextEditingController();
  final PlacesService _placesService = PlacesService();
  final TripDestinationService _destinationService =
      TripDestinationService();
  final Map<String, Map<String, dynamic>> _selectedDestinations = {};

  GoogleMapController? _mapController;
  Timer? _searchDebounce;
  String? _tripId;
  bool _loading = true;
  bool _searching = false;
  bool _saving = false;

  List<Map<String, dynamic>> _suggestions = [];
  LatLng _mapCenter = const LatLng(22.6916, 72.8634);

  @override
  void initState() {
    super.initState();
    _tripId = widget.tripId;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_tripId == null || _tripId!.isEmpty) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        _tripId = args['tripId']?.toString();
      } else if (args is String) {
        _tripId = args;
      }
    }

    if (_loading) {
      _loadTripData();
    }
  }

  Future<void> _loadTripData() async {
    final tripId = _tripId;
    if (tripId == null || tripId.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    try {
      final trip = await TripService().getTrip(tripId);
      final saved = await _destinationService.getDestinations(tripId);

      if (!mounted) return;

      if (trip != null) {
        _mapCenter = LatLng(trip.startLatitude, trip.startLongitude);
      }

      for (final item in saved) {
        _selectedDestinations[item['id'].toString()] = item;
      }

      setState(() => _loading = false);

      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_mapCenter, 11),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Could not load destinations: $e');
    }
  }

  Future<void> _searchPlaces(String value) async {
    _searchDebounce?.cancel();

    if (value.trim().length < 2) {
      setState(() {
        _suggestions = [];
        _searching = false;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        setState(() => _searching = true);
        final results = await _placesService.autocomplete(value.trim());
        if (!mounted) return;
        setState(() {
          _suggestions = results;
          _searching = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() => _searching = false);
        _showMessage('Place search failed: $e');
      }
    });
  }

  Future<void> _selectSearchResult(Map<String, dynamic> suggestion) async {
    final placeId = suggestion['placeId']?.toString() ?? '';
    if (placeId.isEmpty) return;

    try {
      final details = await _placesService.getPlaceDetails(placeId);
      final location = details['location'] as Map<String, dynamic>?;
      final displayName = details['displayName'] as Map<String, dynamic>?;

      final lat = (location?['latitude'] as num?)?.toDouble();
      final lng = (location?['longitude'] as num?)?.toDouble();

      if (lat == null || lng == null) {
        _showMessage('This place does not have a map location.');
        return;
      }

      final name = displayName?['text']?.toString() ??
          suggestion['mainText']?.toString() ??
          suggestion['description']?.toString() ??
          'Selected place';
      final address = details['formattedAddress']?.toString() ??
          suggestion['secondaryText']?.toString() ??
          '';

      await _addDestination(
        name: name,
        address: address,
        latitude: lat,
        longitude: lng,
        placeId: placeId,
        source: 'places_api',
      );

      _searchController.clear();
      setState(() => _suggestions = []);
    } catch (e) {
      _showMessage('Could not add this place: $e');
    }
  }

  Future<void> _selectMapPoint(LatLng position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      String address = 'Selected map location';
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        address = [
          p.name,
          p.street,
          p.locality,
          p.administrativeArea,
        ].where((value) => value != null && value!.trim().isNotEmpty).join(', ');
      }

      await _addDestination(
        name: address,
        address: address,
        latitude: position.latitude,
        longitude: position.longitude,
        source: 'map_tap',
      );
    } catch (e) {
      _showMessage('Could not read this map location: $e');
    }
  }

  Future<void> _useCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showMessage('Please turn on location services.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('Location permission is required.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final point = LatLng(position.latitude, position.longitude);
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(point, 14),
      );
      await _selectMapPoint(point);
    } catch (e) {
      _showMessage('Could not get current location: $e');
    }
  }

  Future<void> _addDestination({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    String? placeId,
    required String source,
  }) async {
    final tripId = _tripId;
    if (tripId == null || tripId.isEmpty) {
      _showMessage('Trip ID is missing.');
      return;
    }

    final documentId = await _destinationService.addDestination(
      tripId: tripId,
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
      placeId: placeId,
      source: source,
    );

    if (documentId == null) {
      _showMessage('This destination is already selected.');
      return;
    }

    final data = {
      'id': documentId,
      'placeId': placeId,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'source': source,
    };

    setState(() {
      _selectedDestinations[documentId] = data;
      _mapCenter = LatLng(latitude, longitude);
    });

    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(latitude, longitude), 12),
    );
  }

  Future<void> _removeDestination(String id) async {
    final tripId = _tripId;
    if (tripId == null) return;

    await _destinationService.removeDestination(tripId, id);
    setState(() => _selectedDestinations.remove(id));
  }

  Future<void> _continue() async {
    if (_selectedDestinations.isEmpty) {
      _showMessage('Select at least one destination.');
      return;
    }

    final tripId = _tripId;
    if (tripId == null || tripId.isEmpty) {
      _showMessage('Trip ID is missing.');
      return;
    }

    setState(() => _saving = true);

    try {
      await TripService().updateTrip(tripId, {
        'destinationCount': _selectedDestinations.length,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pushNamed(
        context,
        AppRoutes.selectPreferences,
        arguments: {'tripId': tripId},
      );
    } catch (e) {
      _showMessage('Could not save trip destinations: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Set<Marker> _markers() {
    return _selectedDestinations.entries.map((entry) {
      final data = entry.value;
      return Marker(
        markerId: MarkerId(entry.key),
        position: LatLng(
          (data['latitude'] as num).toDouble(),
          (data['longitude'] as num).toDouble(),
        ),
        infoWindow: InfoWindow(
          title: data['name']?.toString() ?? 'Destination',
          snippet: data['address']?.toString() ?? '',
        ),
      );
    }).toSet();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('2. Select Destinations'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _mapCenter,
              zoom: 10,
            ),
            markers: _markers(),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
            },
            onTap: _selectMapPoint,
          ),

          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              children: [
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _searchPlaces,
                    decoration: InputDecoration(
                      hintText: 'Search destination or place',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _suggestions = []);
                              },
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                if (_suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 260),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(blurRadius: 8, color: Colors.black26),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final item = _suggestions[index];
                        return ListTile(
                          leading: const Icon(Icons.location_on),
                          title: Text(
                            item['mainText']?.toString().isNotEmpty == true
                                ? item['mainText'].toString()
                                : item['description'].toString(),
                          ),
                          subtitle: Text(
                            item['secondaryText']?.toString() ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _selectSearchResult(item),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          Positioned(
            right: 12,
            bottom: 165,
            child: FloatingActionButton(
              heroTag: 'current_location_destination',
              mini: true,
              onPressed: _useCurrentLocation,
              child: const Icon(Icons.my_location),
            ),
          ),

          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Material(
              elevation: 5,
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.place),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_selectedDestinations.length} destination(s) selected',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Text('Tap map to add'),
                      ],
                    ),
                    if (_selectedDestinations.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 58,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: _selectedDestinations.entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InputChip(
                                label: SizedBox(
                                  width: 130,
                                  child: Text(
                                    entry.value['name'].toString(),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                onDeleted: () =>
                                    _removeDestination(entry.key),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _continue,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: _saving
                            ? const CircularProgressIndicator()
                            : const Text('Next: Select Preferences'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
