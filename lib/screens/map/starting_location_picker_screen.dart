import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../services/places_service.dart';
import '../../widgets/dashboard_navigation_button.dart';

class StartingLocationPickerScreen extends StatefulWidget {
  final String? tripId;

  const StartingLocationPickerScreen({super.key, this.tripId});

  @override
  State<StartingLocationPickerScreen> createState() =>
      _StartingLocationPickerScreenState();
}

class _StartingLocationPickerScreenState
    extends State<StartingLocationPickerScreen> {
  GoogleMapController? _mapController;
  final PlacesService _placesService = PlacesService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  int _searchRequestId = 0;
  LatLng _selectedLocation = const LatLng(22.6916, 72.8634);

  String _address = 'Getting location...';

  bool _loadingCurrentLocation = false;
  bool _searching = false;
  bool _selectingSearchResult = false;

  Set<Marker> _markers = {};
  List<Map<String, dynamic>> _suggestions = [];
  String? _tripId;

  @override
  void initState() {
    super.initState();

    _tripId = widget.tripId;

    _updateMarker(_selectedLocation);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
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

  void _updateMarker(LatLng position, {String? address}) {
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

      _address = address ?? 'Getting location...';
    });

    if (address == null) {
      _getAddress(position);
    }
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

  Future<void> _searchPlaces(String value) async {
    _searchDebounce?.cancel();
    final requestId = ++_searchRequestId;
    final query = value.trim();

    if (query.length < 2) {
      if (mounted) {
        setState(() {
          _suggestions = [];
          _searching = false;
        });
      }
      return;
    }

    setState(() {
      _suggestions = [];
      _searching = true;
    });

    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final results = await _placesService.autocomplete(query);
        if (!mounted ||
            requestId != _searchRequestId ||
            _searchController.text.trim() != query) {
          return;
        }
        setState(() {
          _suggestions = results;
          _searching = false;
        });
      } catch (e) {
        if (!mounted || requestId != _searchRequestId) return;
        setState(() {
          _searching = false;
        });
        _showMessage('Place search failed: $e');
      }
    });
  }

  Future<void> _selectSearchResult(Map<String, dynamic> suggestion) async {
    if (_selectingSearchResult) return;

    final placeId = suggestion['placeId']?.toString() ?? '';
    if (placeId.isEmpty) {
      _showMessage('This place cannot be selected.');
      return;
    }

    setState(() {
      _selectingSearchResult = true;
      _suggestions = [];
      _searching = false;
    });

    try {
      final details = await _placesService.getPlaceDetails(placeId);
      final location = details['location'] as Map<String, dynamic>?;
      final latitude = (location?['latitude'] as num?)?.toDouble();
      final longitude = (location?['longitude'] as num?)?.toDouble();

      if (latitude == null || longitude == null) {
        _showMessage('This place does not have a valid map location.');
        return;
      }

      final formattedAddress = details['formattedAddress']?.toString().trim();
      final address = formattedAddress != null && formattedAddress.isNotEmpty
          ? formattedAddress
          : suggestion['description']?.toString().trim();

      _updateMarker(
        LatLng(latitude, longitude),
        address: address == null || address.isEmpty
            ? suggestion['mainText']?.toString() ?? 'Selected location'
            : address,
      );
      _searchController.clear();
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(latitude, longitude), 15),
      );
    } catch (e) {
      if (mounted) {
        _showMessage('Could not select this place: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _selectingSearchResult = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message.replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.fixed,
        ),
      );
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _loadingCurrentLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

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
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }

        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission permanently denied. '
          'Please enable it from device settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final currentLocation = LatLng(position.latitude, position.longitude);

      _updateMarker(currentLocation);

      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: currentLocation, zoom: 16),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
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
      Navigator.pop(context, {
        'tripId': _tripId,
        'address': address,
        'latitude': _selectedLocation.latitude,
        'longitude': _selectedLocation.longitude,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Starting Location'),
        actions: const [DashboardNavigationButton()],
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  child: TextField(
                    controller: _searchController,
                    onChanged: _searchPlaces,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search city, place or address',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searching || _selectingSearchResult
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : _searchController.text.isNotEmpty
                          ? IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _searchController.clear();
                                _searchDebounce?.cancel();
                                _searchRequestId++;
                                setState(() {
                                  _suggestions = [];
                                  _searching = false;
                                });
                              },
                              icon: const Icon(Icons.close_rounded),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 15,
                      ),
                    ),
                  ),
                ),
                if (_suggestions.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, indent: 56),
                        itemBuilder: (context, index) {
                          final suggestion = _suggestions[index];
                          final mainText =
                              suggestion['mainText']?.toString().trim() ?? '';
                          final secondaryText =
                              suggestion['secondaryText']?.toString().trim() ??
                              '';
                          return ListTile(
                            leading: const Icon(
                              Icons.location_on_rounded,
                              color: Color(0xFF1677FF),
                            ),
                            title: Text(
                              mainText.isEmpty ? 'Location' : mainText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: secondaryText.isEmpty
                                ? null
                                : Text(
                                    secondaryText,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            onTap: _selectingSearchResult
                                ? null
                                : () => _selectSearchResult(suggestion),
                          );
                        },
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.trip_origin_rounded,
                          color: Color(0xFF1677FF),
                          size: 18,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            _address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            right: 16,
            bottom: 100,
            child: FloatingActionButton(
              onPressed: _loadingCurrentLocation ? null : _useCurrentLocation,
              child: _loadingCurrentLocation
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
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
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
