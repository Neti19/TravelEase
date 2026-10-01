import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../services/places_service.dart';

class StartingLocationPickerScreen extends StatefulWidget {
  final String? tripId;

  const StartingLocationPickerScreen({
    super.key,
    this.tripId,
  });

  @override
  State<StartingLocationPickerScreen> createState() =>
      _StartingLocationPickerScreenState();
}

class _StartingLocationPickerScreenState
    extends State<StartingLocationPickerScreen> {
  GoogleMapController? _mapController;
  final PlacesService _placesService = PlacesService();
  LatLng _selectedLocation =
  const LatLng(22.6916, 72.8634);

  String _address = 'Getting location...';

  bool _loadingCurrentLocation = false;

  Set<Marker> _markers = {};
  String? _tripId;

  @override
  void initState() {
    super.initState();

    _tripId = widget.tripId;

    _updateMarker(_selectedLocation);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_tripId == null || _tripId!.isEmpty) {
      final args = ModalRoute.of(context)?.settings.arguments;

      if (args is Map && args['tripId'] != null) {
        _tripId = args['tripId'].toString();
      } else if (args is String && args.isNotEmpty) {
        _tripId = args;
      }
    }
  }

  void _updateMarker(LatLng position) {
    setState(() {
      _selectedLocation = position;

      _markers = {
        Marker(
          markerId: const MarkerId('starting_location'),
          position: position,
          draggable: true,
          onDragEnd: (newPosition) {
            _selectLocation(newPosition);
          },
        ),
      };

      _address = 'Getting location...';
    });

    _getAddress(position);
  }

  Future<void> _selectLocation(LatLng position) async {
    _updateMarker(position);
  }

  Future<void> _getAddress(LatLng position) async {
    String? locationName;
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final place = placemarks.isEmpty ? null : placemarks.first;
      final placemarkName = [
        place?.name,
        place?.subLocality,
        place?.locality,
        place?.administrativeArea,
        place?.country,
      ].whereType<String>().where((part) => part.trim().isNotEmpty).join(', ');
      if (placemarkName.isNotEmpty) locationName = placemarkName;
    } catch (_) {
      // Use the Places reverse-geocoding fallback on web and plugin failures.
    }

    if (locationName == null || kIsWeb) {
      try {
        final apiName = await _placesService.getLocationName(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        if (apiName.trim().isNotEmpty &&
            !apiName.toLowerCase().startsWith('location near ')) {
          locationName = apiName;
        }
      } catch (_) {
        // Coordinate fallback below always keeps selection usable.
      }
    }

    if (mounted &&
        _selectedLocation.latitude == position.latitude &&
        _selectedLocation.longitude == position.longitude) {
      setState(() {
        _address = locationName ?? 'Selected location';
      });
    }
  }
  Future<void> _useCurrentLocation() async {
    setState(() {
      _loadingCurrentLocation = true;
    });

    try {
      bool serviceEnabled =
      await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (mounted) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Location is disabled'),
              content: const Text(
                'Please enable location services on your device.',
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }

        return;
      }

      LocationPermission permission =
      await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission =
        await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception(
          'Location permission denied.',
        );
      }

      if (permission ==
          LocationPermission.deniedForever) {
        throw Exception(
          'Location permission permanently denied. '
              'Please enable it from device settings.',
        );
      }

      final position =
      await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final currentLocation = LatLng(
        position.latitude,
        position.longitude,
      );

      _updateMarker(currentLocation);

      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: currentLocation,
            zoom: 16,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst(
                'Exception: ',
                '',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingCurrentLocation = false;
        });
      }
    }
  }

  Future<void> _confirmLocation() async {
    if (mounted) {
      final address = _address == 'Getting location...'
          ? 'Selected location'
          : _address;
      Navigator.pop(
        context,
        {
          'tripId': _tripId,
          'address': address,
          'latitude':
          _selectedLocation.latitude,
          'longitude':
          _selectedLocation.longitude,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Select Starting Location',
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedLocation,
              zoom: 12,
            ),
            markers: _markers,
            // The map can be used without granting location permission;
            // the explicit current-location action requests it when needed.
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            onMapCreated: (controller) {
              _mapController = controller;
            },
            onTap: _selectLocation,
          ),

          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _address,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            right: 16,
            bottom: 100,
            child: FloatingActionButton(
              onPressed: _loadingCurrentLocation
                  ? null
                  : _useCurrentLocation,
              child: _loadingCurrentLocation
                  ? const SizedBox(
                width: 24,
                height: 24,
                child:
                CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
                  : const Icon(
                Icons.my_location,
              ),
            ),
          ),

          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              onPressed: _confirmLocation,
              icon: const Icon(Icons.check),
              label: const Text('Confirm Starting Location'),
              style:
              ElevatedButton.styleFrom(
                minimumSize:
                const Size(
                  double.infinity,
                  52,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
