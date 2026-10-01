import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../app_routes.dart';
import '../../services/places_service.dart';
import '../../services/trip_destination_service.dart';
import '../../services/trip_service.dart';
import '../../services/place_details_service.dart';

class SelectDestinationScreen extends StatefulWidget {
  final String? tripId;

  const SelectDestinationScreen({
    super.key,
    this.tripId,
  });

  @override
  State<SelectDestinationScreen> createState() =>
      _SelectDestinationScreenState();
}

class _SelectDestinationScreenState
    extends State<SelectDestinationScreen> {
  final PlacesService _placesService = PlacesService();

  final TripDestinationService _destinationService =
  TripDestinationService();

  final TripService _tripService = TripService();

  final PlaceDetailsService _placeDetailsService =
  PlaceDetailsService();

  final TextEditingController _searchController =
  TextEditingController();

  GoogleMapController? _mapController;

  Timer? _searchDebounce;

  String? _tripId;

  bool _loading = true;
  bool _searching = false;
  bool _saving = false;
  bool _selectingDestination = false;
  bool _loadingNearby = false;

  String _startingLocation = 'Starting location';

  double _startingLatitude = 22.6916;
  double _startingLongitude = 72.8634;

  Map<String, dynamic>? _selectedDestination;

  Map<String, dynamic>? _destinationDetails;

  List<Map<String, dynamic>> _nearbyPlaces = [];

  final Set<String> _addingNearbyPlaces = {};

  List<Map<String, dynamic>> _suggestions = [];

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

  // ===========================================================================
  // LOAD TRIP
  // ===========================================================================

  Future<void> _loadTripData() async {
    final tripId = _tripId;

    if (tripId == null || tripId.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    try {
      final trip = await _tripService.getTrip(tripId);

      final savedDestinations =
      await _destinationService.getDestinations(tripId);

      if (!mounted) return;

      if (trip != null) {
        _startingLocation =
        trip.startLocation.trim().isNotEmpty
            ? trip.startLocation.trim()
            : 'Starting location';

        _startingLatitude = trip.startLatitude;
        _startingLongitude = trip.startLongitude;
      }

      // TravelEase allows exactly ONE destination.
      if (savedDestinations.isNotEmpty) {
        final destination = savedDestinations.first;

        final latitude =
        (destination['latitude'] as num?)?.toDouble();

        final longitude =
        (destination['longitude'] as num?)?.toDouble();

        if (latitude != null && longitude != null) {
          _selectedDestination = {
            ...destination,
            'latitude': latitude,
            'longitude': longitude,
          };
        }
      }

      setState(() {
        _loading = false;
      });

      await Future.delayed(
        const Duration(milliseconds: 150),
      );

      if (!mounted) return;

      if (_selectedDestination != null) {
        final latitude =
        (_selectedDestination!['latitude'] as num).toDouble();

        final longitude =
        (_selectedDestination!['longitude'] as num).toDouble();

        await _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(latitude, longitude),
            14,
          ),
        );

        await _loadDestinationDetails();

        await _loadNearbyPlaces(
          latitude,
          longitude,
        );
      } else {
        await _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(
              _startingLatitude,
              _startingLongitude,
            ),
            10,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage(
        'Could not load trip details: $e',
      );
    }
  }

  // ===========================================================================
  // SEARCH
  // ===========================================================================

  Future<void> _searchPlaces(String value) async {
    _searchDebounce?.cancel();

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

    _searchDebounce = Timer(
      const Duration(milliseconds: 400),
          () async {
        try {
          if (!mounted) return;

          setState(() {
            _searching = true;
          });

          final results = await _placesService.autocomplete(
            query,
            latitude: _startingLatitude,
            longitude: _startingLongitude,
          );

          if (!mounted) return;

          setState(() {
            _suggestions = results;
            _searching = false;
          });
        } catch (e) {
          if (!mounted) return;

          setState(() {
            _searching = false;
          });

          _showMessage(
            'Place search failed: $e',
          );
        }
      },
    );
  }

  // ===========================================================================
  // SEARCH RESULT
  // ===========================================================================

  Future<void> _selectSearchResult(
      Map<String, dynamic> suggestion,
      ) async {
    if (_selectingDestination) return;

    final placeId =
        suggestion['placeId']?.toString() ?? '';

    if (placeId.isEmpty) {
      _showMessage(
        'This place cannot be selected.',
      );
      return;
    }

    setState(() {
      _selectingDestination = true;
      _suggestions = [];
    });

    try {
      // Get exact coordinates of the clicked suggestion.
      final details =
      await _placesService.getPlaceDetails(placeId);

      final location =
      details['location'] as Map<String, dynamic>?;

      final displayName =
      details['displayName'] as Map<String, dynamic>?;

      final latitude =
      (location?['latitude'] as num?)?.toDouble();

      final longitude =
      (location?['longitude'] as num?)?.toDouble();

      if (latitude == null || longitude == null) {
        _showMessage(
          'This place does not have a valid map location.',
        );
        return;
      }

      final name = <String>[
        displayName?['text']?.toString() ?? '',
        suggestion['mainText']?.toString() ?? '',
        suggestion['description']?.toString() ?? '',
      ]
          .map((value) => value.trim())
          .firstWhere(
            (value) => value.isNotEmpty,
        orElse: () => 'Selected destination',
      );

      final formattedAddress =
          details['formattedAddress']
              ?.toString()
              .trim() ??
              '';

      final address = formattedAddress.isNotEmpty
          ? formattedAddress
          : suggestion['secondaryText']
          ?.toString() ??
          name;

      await _setDestination(
        name: name,
        address: address,
        latitude: latitude,
        longitude: longitude,
        placeId: placeId,
        source: 'places_api',
      );

      if (!mounted) return;

      _searchController.clear();

      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(latitude, longitude),
          14,
        ),
      );
    } catch (e) {
      if (mounted) {
        _showMessage(
          'Could not select this destination: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _selectingDestination = false;
        });
      }
    }
  }

  // ===========================================================================
  // MAP TAP
  // ===========================================================================

  Future<void> _selectMapPoint(
      LatLng position,
      ) async {
    if (_selectingDestination) return;

    setState(() {
      _selectingDestination = true;
      _suggestions = [];
    });

    FocusScope.of(context).unfocus();

    try {
      String address = '';

      try {
        address = await _placesService.getLocationName(
          latitude: position.latitude,
          longitude: position.longitude,
        );
      } catch (_) {}

      if (address.trim().isEmpty) {
        address = 'Selected location';
      }

      final parts = address
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();

      final name = parts.isNotEmpty
          ? parts.first
          : 'Selected destination';

      await _setDestination(
        name: name,
        address: address,
        latitude: position.latitude,
        longitude: position.longitude,
        source: 'map_tap',
      );
    } catch (e) {
      if (mounted) {
        _showMessage(
          'Could not select this map location: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _selectingDestination = false;
        });
      }
    }
  }

  // ===========================================================================
  // SAVE ONE DESTINATION
  // ===========================================================================

  Future<void> _setDestination({
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

    /*
     * IMPORTANT:
     *
     * TravelEase has ONE destination.
     *
     * Remove any old destination before saving
     * the new one.
     */

    final existing =
    await _destinationService.getDestinations(tripId);

    for (final destination in existing) {
      final id =
      destination['id']?.toString();

      if (id != null && id.isNotEmpty) {
        await _destinationService.removeDestination(
          tripId,
          id,
        );
      }
    }

    final documentId =
    await _destinationService.addDestination(
      tripId: tripId,
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
      placeId: placeId,
      source: source,
    );

    if (documentId == null) {
      throw Exception(
        'Could not save the selected destination.',
      );
    }

    await _tripService.updateTrip(
      tripId,
      {
        'destination': name,
        'destinationAddress': address,
        'destinationLatitude': latitude,
        'destinationLongitude': longitude,
        'destinationPlaceId': placeId,
        'destinationCount': 1,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    if (!mounted) return;

    setState(() {
      _selectedDestination = {
        'id': documentId,
        'placeId': placeId,
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'source': source,
      };

      _destinationDetails = null;
      _nearbyPlaces = [];
    });

    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(latitude, longitude),
        14,
      ),
    );

    // Load the selected destination's rich details.
    await _loadDestinationDetails();

    // Then suggest nearby tourist places.
    await _loadNearbyPlaces(
      latitude,
      longitude,
    );
  }

  // ===========================================================================
  // DESTINATION DETAILS
  // ===========================================================================

  Future<void> _loadDestinationDetails() async {
    final destination = _selectedDestination;

    if (destination == null) return;

    final placeId =
        destination['placeId']?.toString() ?? '';

    if (placeId.isEmpty) return;

    try {
      final details =
      await _placeDetailsService.getPlaceDetails(
        placeId,
      );

      if (!mounted || details == null) return;

      setState(() {
        _destinationDetails = details;
      });
    } catch (_) {
      // Destination itself is already saved.
      // Photo/details are optional enhancements.
    }
  }

  // ===========================================================================
  // NEARBY PLACES
  // ===========================================================================

  Future<void> _loadNearbyPlaces(
      double latitude,
      double longitude,
      ) async {
    if (!mounted) return;

    setState(() {
      _loadingNearby = true;
      _nearbyPlaces = [];
    });

    try {
      final results =
      await _placesService.searchNearbyDestinations(
        latitude: latitude,
        longitude: longitude,
        radius: 10000,
        maxResultCount: 10,
      );

      if (!mounted) return;

      final selectedPlaceId =
      _selectedDestination?['placeId']?.toString();

      final filtered = results.where((place) {
        final placeId =
            place['placeId']?.toString() ??
                place['id']?.toString();

        if (selectedPlaceId != null &&
            selectedPlaceId.isNotEmpty &&
            placeId == selectedPlaceId) {
          return false;
        }

        return true;
      }).take(6).toList();

      setState(() {
        _nearbyPlaces = filtered;
        _loadingNearby = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingNearby = false;
        _nearbyPlaces = [];
      });
    }
  }

  // ===========================================================================
  // ADD NEARBY TOURIST PLACE
  // ===========================================================================

  Future<void> _addNearbyPlace(
      Map<String, dynamic> place,
      ) async {
    final tripId = _tripId;

    if (tripId == null || tripId.isEmpty) {
      _showMessage('Trip ID is missing.');
      return;
    }

    final placeId =
        place['placeId']?.toString() ??
            place['id']?.toString() ??
            '';

    if (placeId.isEmpty) {
      _showMessage(
        'This place cannot be added.',
      );
      return;
    }

    if (_addingNearbyPlaces.contains(placeId)) {
      return;
    }

    setState(() {
      _addingNearbyPlaces.add(placeId);
    });

    try {
      final details =
      await _placesService.getPlaceDetails(
        placeId,
      );

      final location =
      details['location'] as Map<String, dynamic>?;

      final displayName =
      details['displayName'] as Map<String, dynamic>?;

      final latitude =
          (location?['latitude'] as num?)?.toDouble() ??
              (place['latitude'] as num?)?.toDouble();

      final longitude =
          (location?['longitude'] as num?)?.toDouble() ??
              (place['longitude'] as num?)?.toDouble();

      if (latitude == null || longitude == null) {
        throw Exception(
          'Place location is unavailable.',
        );
      }

      final name =
          displayName?['text']?.toString() ??
              place['name']?.toString() ??
              'Tourist place';

      final address =
          details['formattedAddress']?.toString() ??
              place['address']?.toString() ??
              '';

      final category =
          details['primaryType']?.toString() ??
              place['category']?.toString() ??
              'tourist_attraction';

      await _destinationService.saveSelectedPlace(
        tripId: tripId,
        placeId: placeId,
        name: name,
        address: address,
        latitude: latitude,
        longitude: longitude,
        category: category,
      );

      if (!mounted) return;

      _showMessage(
        '$name added to your places.',
      );
    } catch (e) {
      if (mounted) {
        _showMessage(
          'Could not add this place: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _addingNearbyPlaces.remove(placeId);
        });
      }
    }
  }

  // ===========================================================================
  // CHANGE DESTINATION
  // ===========================================================================

  Future<void> _clearDestination() async {
    final tripId = _tripId;

    if (tripId == null || tripId.isEmpty) {
      return;
    }

    final destination = _selectedDestination;

    if (destination != null) {
      final id =
      destination['id']?.toString();

      if (id != null && id.isNotEmpty) {
        await _destinationService.removeDestination(
          tripId,
          id,
        );
      }
    }

    await _tripService.updateTrip(
      tripId,
      {
        'destination': '',
        'destinationAddress': '',
        'destinationLatitude': null,
        'destinationLongitude': null,
        'destinationPlaceId': null,
        'destinationCount': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    if (!mounted) return;

    setState(() {
      _selectedDestination = null;
      _destinationDetails = null;
      _nearbyPlaces = [];
    });

    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(
          _startingLatitude,
          _startingLongitude,
        ),
        10,
      ),
    );
  }

  // ===========================================================================
  // CONTINUE
  // ===========================================================================

  Future<void> _continue() async {
    final tripId = _tripId;

    if (tripId == null || tripId.isEmpty) {
      _showMessage('Trip ID is missing.');
      return;
    }

    if (_selectedDestination == null) {
      _showMessage(
        'Choose one destination before continuing.',
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await _tripService.updateTrip(
        tripId,
        {
          'destination':
          _selectedDestination!['name']
              ?.toString() ??
              '',
          'destinationAddress':
          _selectedDestination!['address']
              ?.toString() ??
              '',
          'destinationLatitude':
          _selectedDestination!['latitude'],
          'destinationLongitude':
          _selectedDestination!['longitude'],
          'destinationPlaceId':
          _selectedDestination!['placeId'],
          'destinationCount': 1,
          'updatedAt':
          FieldValue.serverTimestamp(),
        },
      );

      if (!mounted) return;

      Navigator.pushNamed(
        context,
        AppRoutes.selectPreferences,
        arguments: {
          'tripId': tripId,
        },
      );
    } catch (e) {
      _showMessage(
        'Could not save destination: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ===========================================================================
  // MARKER
  // ===========================================================================

  Set<Marker> _markers() {
    final destination = _selectedDestination;

    if (destination == null) {
      return {};
    }

    final latitude =
    (destination['latitude'] as num?)?.toDouble();

    final longitude =
    (destination['longitude'] as num?)?.toDouble();

    if (latitude == null || longitude == null) {
      return {};
    }

    return {
      Marker(
        markerId:
        const MarkerId('selected_destination'),
        position: LatLng(
          latitude,
          longitude,
        ),
        icon:
        BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueAzure,
        ),
        infoWindow: InfoWindow(
          title:
          destination['name']
              ?.toString() ??
              'Destination',
          snippet:
          destination['address']
              ?.toString() ??
              '',
        ),
      ),
    };
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  String _readPhotoUrl(
      Map<String, dynamic>? data,
      ) {
    if (data == null) return '';

    return data['photoUrl']?.toString() ??
        data['photoUri']?.toString() ??
        '';
  }

  String _readPlaceName(
      Map<String, dynamic> place,
      ) {
    final displayName =
    place['displayName'];

    if (displayName is Map &&
        displayName['text'] != null) {
      return displayName['text']
          .toString()
          .trim();
    }

    return place['name']?.toString() ??
        'Tourist place';
  }

  String _readAddress(
      Map<String, dynamic> place,
      ) {
    return place['formattedAddress']
        ?.toString()
        .trim()
        .isNotEmpty ==
        true
        ? place['formattedAddress']
        .toString()
        .trim()
        : place['address']?.toString() ??
        '';
  }

  double? _readRating(
      Map<String, dynamic> place,
      ) {
    final value =
    place['rating'];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ?? '',
    );
  }

  int? _readReviewCount(
      Map<String, dynamic> place,
      ) {
    final value =
    place['userRatingCount'];

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value?.toString() ?? '',
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ===========================================================================
  // DISPOSE
  // ===========================================================================

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7FAFC),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF1677FF),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
      const Color(0xFFF7FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopHeader(),

            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GoogleMap(
                      initialCameraPosition:
                      CameraPosition(
                        target:
                        _selectedDestination !=
                            null
                            ? LatLng(
                          (_selectedDestination![
                          'latitude']
                          as num)
                              .toDouble(),
                          (_selectedDestination![
                          'longitude']
                          as num)
                              .toDouble(),
                        )
                            : LatLng(
                          _startingLatitude,
                          _startingLongitude,
                        ),
                        zoom:
                        _selectedDestination !=
                            null
                            ? 14
                            : 10,
                      ),

                      markers: _markers(),

                      myLocationEnabled: false,
                      myLocationButtonEnabled:
                      false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      compassEnabled: true,

                      onTap: _selectMapPoint,

                      onMapCreated:
                          (controller) {
                        _mapController =
                            controller;

                        Future.delayed(
                          const Duration(
                            milliseconds: 250,
                          ),
                              () {
                            if (!mounted ||
                                _mapController ==
                                    null) {
                              return;
                            }

                            final destination =
                                _selectedDestination;

                            final target =
                            destination !=
                                null
                                ? LatLng(
                              (destination[
                              'latitude']
                              as num)
                                  .toDouble(),
                              (destination[
                              'longitude']
                              as num)
                                  .toDouble(),
                            )
                                : LatLng(
                              _startingLatitude,
                              _startingLongitude,
                            );

                            _mapController!
                                .animateCamera(
                              CameraUpdate
                                  .newLatLngZoom(
                                target,
                                destination !=
                                    null
                                    ? 14
                                    : 10,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  Positioned(
                    top: 14,
                    left: 14,
                    right: 14,
                    child: _buildSearchBox(),
                  ),

                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 18,
                    child:
                    _buildMapInstruction(),
                  ),

                  Positioned(
                    right: 14,
                    bottom: 88,
                    child:
                    FloatingActionButton.small(
                      heroTag:
                      'destination_recenter_button',
                      backgroundColor:
                      Colors.white,
                      foregroundColor:
                      const Color(0xFF1677FF),
                      elevation: 5,
                      onPressed: () {
                        _mapController
                            ?.animateCamera(
                          CameraUpdate
                              .newLatLngZoom(
                            LatLng(
                              _startingLatitude,
                              _startingLongitude,
                            ),
                            10,
                          ),
                        );
                      },
                      child: const Icon(
                        Icons
                            .my_location_rounded,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            _buildBottomPanel(),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _buildTopHeader() {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.fromLTRB(
        18,
        12,
        18,
        14,
      ),
      color:
      const Color(0xFFF7FAFC),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration:
            BoxDecoration(
              color:
              const Color(0xFFDFF4FF),
              borderRadius:
              BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.explore_rounded,
              color:
              Color(0xFF1677FF),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  '2. Choose your destination',
                  style: TextStyle(
                    color:
                    Color(0xFF102A43),
                    fontSize: 18,
                    fontWeight:
                    FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Search or explore the map',
                  style: TextStyle(
                    color:
                    Color(0xFF627D98),
                    fontSize: 12,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SEARCH BOX
  // ===========================================================================

  Widget _buildSearchBox() {
    return Column(
      children: [
        Material(
          elevation: 8,
          shadowColor: Colors.black26,
          borderRadius:
          BorderRadius.circular(18),
          color: Colors.white,
          child: TextField(
            controller:
            _searchController,
            onChanged:
            _searchPlaces,
            textInputAction:
            TextInputAction.search,
            decoration:
            InputDecoration(
              hintText:
              'Search city, place or destination',
              hintStyle:
              const TextStyle(
                color:
                Color(0xFF829AB1),
                fontSize: 14,
              ),
              prefixIcon:
              const Icon(
                Icons.search_rounded,
                color:
                Color(0xFF1677FF),
              ),
              suffixIcon:
              _searching ||
                  _selectingDestination
                  ? const Padding(
                padding:
                EdgeInsets.all(
                  12,
                ),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                    color:
                    Color(
                      0xFF1677FF,
                    ),
                  ),
                ),
              )
                  : _searchController
                  .text
                  .isNotEmpty
                  ? IconButton(
                icon:
                const Icon(
                  Icons
                      .close_rounded,
                ),
                color:
                const Color(
                  0xFF627D98,
                ),
                onPressed: () {
                  _searchController
                      .clear();

                  setState(() {
                    _suggestions =
                    [];
                  });
                },
              )
                  : null,
              filled: true,
              fillColor:
              Colors.white,
              border:
              OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(
                  18,
                ),
                borderSide:
                BorderSide.none,
              ),
              contentPadding:
              const EdgeInsets
                  .symmetric(
                vertical: 16,
              ),
            ),
          ),
        ),

        if (_suggestions.isNotEmpty)
          Container(
            margin:
            const EdgeInsets.only(
              top: 7,
            ),
            constraints:
            const BoxConstraints(
              maxHeight: 285,
            ),
            decoration:
            BoxDecoration(
              color: Colors.white,
              borderRadius:
              BorderRadius.circular(
                18,
              ),
              boxShadow: const [
                BoxShadow(
                  color:
                  Colors.black26,
                  blurRadius: 16,
                  offset:
                  Offset(0, 7),
                ),
              ],
            ),
            child:
            ListView.separated(
              shrinkWrap: true,
              padding:
              const EdgeInsets
                  .symmetric(
                vertical: 5,
              ),
              itemCount:
              _suggestions.length,
              separatorBuilder:
                  (_, __) =>
              const Divider(
                height: 1,
                indent: 64,
                endIndent: 12,
              ),
              itemBuilder:
                  (context, index) {
                final item =
                _suggestions[
                index];

                final mainText =
                    item['mainText']
                        ?.toString()
                        .trim() ??
                        '';

                final secondaryText =
                    item['secondaryText']
                        ?.toString()
                        .trim() ??
                        '';

                return InkWell(
                  borderRadius:
                  BorderRadius
                      .circular(
                    14,
                  ),
                  onTap:
                  _selectingDestination
                      ? null
                      : () =>
                      _selectSearchResult(
                        item,
                      ),
                  child:
                  Padding(
                    padding:
                    const EdgeInsets
                        .symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration:
                          BoxDecoration(
                            color:
                            const Color(
                              0xFFE8F3FF,
                            ),
                            borderRadius:
                            BorderRadius
                                .circular(
                              12,
                            ),
                          ),
                          child:
                          const Icon(
                            Icons
                                .location_on_rounded,
                            color:
                            Color(
                              0xFF1677FF,
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 11,
                        ),
                        Expanded(
                          child:
                          Column(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                            children: [
                              Text(
                                mainText
                                    .isNotEmpty
                                    ? mainText
                                    : 'Destination',
                                maxLines:
                                1,
                                overflow:
                                TextOverflow
                                    .ellipsis,
                                style:
                                const TextStyle(
                                  color:
                                  Color(
                                    0xFF102A43,
                                  ),
                                  fontWeight:
                                  FontWeight
                                      .w800,
                                  fontSize:
                                  14,
                                ),
                              ),
                              if (secondaryText
                                  .isNotEmpty) ...[
                                const SizedBox(
                                  height: 3,
                                ),
                                Text(
                                  secondaryText,
                                  maxLines:
                                  2,
                                  overflow:
                                  TextOverflow
                                      .ellipsis,
                                  style:
                                  const TextStyle(
                                    color:
                                    Color(
                                      0xFF627D98,
                                    ),
                                    fontSize:
                                    12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(
                          width: 6,
                        ),
                        const Icon(
                          Icons
                              .arrow_forward_ios_rounded,
                          size: 14,
                          color:
                          Color(
                            0xFF9FB3C8,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ===========================================================================
  // MAP INSTRUCTION
  // ===========================================================================

  Widget _buildMapInstruction() {
    return Material(
      elevation: 4,
      borderRadius:
      BorderRadius.circular(16),
      color:
      Colors.white.withOpacity(0.95),
      child: Padding(
        padding:
        const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 10,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration:
              BoxDecoration(
                color:
                const Color(0xFFFFF1EC),
                borderRadius:
                BorderRadius.circular(
                  10,
                ),
              ),
              child: const Icon(
                Icons.touch_app_rounded,
                color:
                Color(0xFFFF8A65),
                size: 20,
              ),
            ),
            const SizedBox(
              width: 10,
            ),
            const Expanded(
              child: Text(
                'Tap anywhere on the map to choose a destination',
                style: TextStyle(
                  color:
                  Color(0xFF486581),
                  fontSize: 12,
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // BOTTOM PANEL
  // ===========================================================================

  Widget _buildBottomPanel() {
    final destination =
        _selectedDestination;

    return Container(
      width: double.infinity,
      constraints:
      const BoxConstraints(
        maxHeight: 440,
      ),
      padding:
      const EdgeInsets.fromLTRB(
        16,
        14,
        16,
        16,
      ),
      decoration:
      const BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.vertical(
          top: Radius.circular(26),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 18,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SingleChildScrollView(
        physics:
        const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            _buildStartingLocation(),

            const SizedBox(
              height: 11,
            ),

            if (destination == null)
              _buildNoDestination()
            else ...[
              _buildDestinationCard(),

              const SizedBox(
                height: 16,
              ),

              _buildNearbyPlaces(),

              const SizedBox(
                height: 14,
              ),

              _buildContinueButton(),
            ],
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // STARTING LOCATION
  // ===========================================================================

  Widget _buildStartingLocation() {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration:
          BoxDecoration(
            color:
            const Color(0xFFE8F3FF),
            borderRadius:
            BorderRadius.circular(
              11,
            ),
          ),
          child: const Icon(
            Icons.trip_origin_rounded,
            color:
            Color(0xFF1677FF),
            size: 20,
          ),
        ),
        const SizedBox(
          width: 10,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              const Text(
                'Starting from',
                style: TextStyle(
                  color:
                  Color(0xFF829AB1),
                  fontSize: 10,
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
              const SizedBox(
                height: 2,
              ),
              Text(
                _startingLocation,
                maxLines: 2,
                overflow:
                TextOverflow.ellipsis,
                style:
                const TextStyle(
                  color:
                  Color(0xFF102A43),
                  fontSize: 13,
                  fontWeight:
                  FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // NO DESTINATION
  // ===========================================================================

  Widget _buildNoDestination() {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(14),
      decoration:
      BoxDecoration(
        color:
        const Color(0xFFF7FAFC),
        borderRadius:
        BorderRadius.circular(16),
        border: Border.all(
          color:
          const Color(0xFFE1EAF2),
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons
                .location_searching_rounded,
            color:
            Color(0xFF829AB1),
          ),
          SizedBox(
            width: 10,
          ),
          Expanded(
            child: Text(
              'Search for a destination or tap a place on the map.',
              style:
              TextStyle(
                color:
                Color(0xFF627D98),
                fontWeight:
                FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // DESTINATION CARD
  // ===========================================================================

  Widget _buildDestinationCard() {
    final destination =
    _selectedDestination!;

    final photoUrl =
    _readPhotoUrl(
      _destinationDetails,
    );

    final rating =
    _readRating(
      _destinationDetails ??
          destination,
    );

    final reviewCount =
    _readReviewCount(
      _destinationDetails ??
          destination,
    );

    final name =
        destination['name']
            ?.toString() ??
            'Destination';

    final address =
        destination['address']
            ?.toString() ??
            '';

    return Container(
      width: double.infinity,
      decoration:
      BoxDecoration(
        color:
        const Color(0xFFE8F3FF),
        borderRadius:
        BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color:
          const Color(0xFFB9D8FF),
        ),
      ),
      clipBehavior:
      Clip.antiAlias,
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          if (photoUrl.isNotEmpty)
            SizedBox(
              height: 150,
              width: double.infinity,
              child: Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) =>
                    _buildPhotoPlaceholder(),
                loadingBuilder:
                    (
                    context,
                    child,
                    progress,
                    ) {
                  if (progress ==
                      null) {
                    return child;
                  }

                  return
                    _buildPhotoLoading();
                },
              ),
            )
          else
            _buildPhotoPlaceholder(),

          Padding(
            padding:
            const EdgeInsets.all(
              13,
            ),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          const Text(
                            'YOUR DESTINATION',
                            style:
                            TextStyle(
                              color:
                              Color(
                                0xFF1677FF,
                              ),
                              fontSize:
                              9,
                              fontWeight:
                              FontWeight
                                  .w900,
                              letterSpacing:
                              0.7,
                            ),
                          ),
                          const SizedBox(
                            height: 3,
                          ),
                          Text(
                            name,
                            maxLines:
                            2,
                            overflow:
                            TextOverflow
                                .ellipsis,
                            style:
                            const TextStyle(
                              color:
                              Color(
                                0xFF102A43,
                              ),
                              fontSize:
                              18,
                              fontWeight:
                              FontWeight
                                  .w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip:
                      'Change destination',
                      onPressed:
                      _selectingDestination
                          ? null
                          : _clearDestination,
                      icon:
                      const Icon(
                        Icons
                            .edit_location_alt_rounded,
                        color:
                        Color(
                          0xFF1677FF,
                        ),
                      ),
                    ),
                  ],
                ),

                if (rating != null) ...[
                  const SizedBox(
                    height: 6,
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color:
                        Color(
                          0xFFFFB400,
                        ),
                        size: 18,
                      ),
                      const SizedBox(
                        width: 4,
                      ),
                      Text(
                        rating
                            .toStringAsFixed(
                          1,
                        ),
                        style:
                        const TextStyle(
                          color:
                          Color(
                            0xFF102A43,
                          ),
                          fontSize:
                          12,
                          fontWeight:
                          FontWeight
                              .w800,
                        ),
                      ),
                      if (reviewCount !=
                          null) ...[
                        const SizedBox(
                          width: 5,
                        ),
                        Text(
                          '($reviewCount reviews)',
                          style:
                          const TextStyle(
                            color:
                            Color(
                              0xFF627D98,
                            ),
                            fontSize:
                            11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],

                if (address.isNotEmpty) ...[
                  const SizedBox(
                    height: 7,
                  ),
                  Row(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      const Icon(
                        Icons
                            .location_on_outlined,
                        color:
                        Color(
                          0xFF627D98,
                        ),
                        size: 17,
                      ),
                      const SizedBox(
                        width: 5,
                      ),
                      Expanded(
                        child: Text(
                          address,
                          maxLines:
                          2,
                          overflow:
                          TextOverflow
                              .ellipsis,
                          style:
                          const TextStyle(
                            color:
                            Color(
                              0xFF627D98,
                            ),
                            fontSize:
                            11,
                            height:
                            1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPlaceholder() {
    return Container(
      height: 130,
      width: double.infinity,
      color:
      const Color(0xFFDFF4FF),
      child: const Center(
        child: Icon(
          Icons.landscape_rounded,
          color:
          Color(0xFF1677FF),
          size: 52,
        ),
      ),
    );
  }

  Widget _buildPhotoLoading() {
    return Container(
      height: 150,
      width: double.infinity,
      color:
      const Color(0xFFDFF4FF),
      child: const Center(
        child:
        CircularProgressIndicator(
          color:
          Color(0xFF1677FF),
        ),
      ),
    );
  }

  // ===========================================================================
  // NEARBY PLACES
  // ===========================================================================

  Widget _buildNearbyPlaces() {
    if (_loadingNearby) {
      return Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            'Nearby places you may like',
            style:
            TextStyle(
              color:
              Color(0xFF102A43),
              fontSize: 16,
              fontWeight:
              FontWeight.w900,
            ),
          ),
          const SizedBox(
            height: 4,
          ),
          const Text(
            'Finding interesting places around your destination...',
            style:
            TextStyle(
              color:
              Color(0xFF627D98),
              fontSize: 12,
            ),
          ),
          const SizedBox(
            height: 14,
          ),
          const Center(
            child:
            CircularProgressIndicator(
              strokeWidth: 2.5,
              color:
              Color(0xFF1677FF),
            ),
          ),
        ],
      );
    }

    if (_nearbyPlaces.isEmpty) {
      return Container(
        width: double.infinity,
        padding:
        const EdgeInsets.all(14),
        decoration:
        BoxDecoration(
          color:
          const Color(0xFFF7FAFC),
          borderRadius:
          BorderRadius.circular(
            15,
          ),
        ),
        child: const Row(
          children: [
            Icon(
              Icons
                  .travel_explore_rounded,
              color:
              Color(0xFF1677FF),
            ),
            SizedBox(
              width: 10,
            ),
            Expanded(
              child: Text(
                'No nearby suggestions found. You can continue and choose places later.',
                style:
                TextStyle(
                  color:
                  Color(0xFF627D98),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        const Text(
          'Nearby places you may like',
          style:
          TextStyle(
            color:
            Color(0xFF102A43),
            fontSize: 16,
            fontWeight:
            FontWeight.w900,
          ),
        ),
        const SizedBox(
          height: 4,
        ),
        const Text(
          'Add places you want to visit. They will be used later for your route and itinerary.',
          style:
          TextStyle(
            color:
            Color(0xFF627D98),
            fontSize: 11,
            height: 1.35,
          ),
        ),
        const SizedBox(
          height: 12,
        ),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection:
            Axis.horizontal,
            physics:
            const BouncingScrollPhysics(),
            itemCount:
            _nearbyPlaces.length,
            separatorBuilder:
                (_, __) =>
            const SizedBox(
              width: 11,
            ),
            itemBuilder:
                (context, index) {
              return _buildNearbyPlaceCard(
                _nearbyPlaces[index],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNearbyPlaceCard(
      Map<String, dynamic> place,
      ) {
    final placeId =
        place['placeId']?.toString() ??
            place['id']?.toString() ??
            '';

    final name =
    _readPlaceName(place);

    final address =
    _readAddress(place);

    final rating =
    _readRating(place);

    final reviewCount =
    _readReviewCount(place);

    final isAdding =
    _addingNearbyPlaces.contains(
      placeId,
    );

    return Container(
      width: 220,
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(
          17,
        ),
        border: Border.all(
          color:
          const Color(0xFFE1EAF2),
        ),
        boxShadow: const [
          BoxShadow(
            color:
            Colors.black12,
            blurRadius: 8,
            offset:
            Offset(0, 3),
          ),
        ],
      ),
      clipBehavior:
      Clip.antiAlias,
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Container(
            height: 78,
            width: double.infinity,
            decoration:
            const BoxDecoration(
              color:
              Color(0xFFDFF4FF),
            ),
            child: const Center(
              child: Icon(
                Icons
                    .photo_camera_back_rounded,
                color:
                Color(0xFF1677FF),
                size: 30,
              ),
            ),
          ),

          Expanded(
            child: Padding(
              padding:
              const EdgeInsets.all(
                10,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow:
                    TextOverflow
                        .ellipsis,
                    style:
                    const TextStyle(
                      color:
                      Color(
                        0xFF102A43,
                      ),
                      fontSize: 13,
                      fontWeight:
                      FontWeight.w900,
                    ),
                  ),

                  const SizedBox(
                    height: 3,
                  ),

                  if (rating != null)
                    Row(
                      children: [
                        const Icon(
                          Icons
                              .star_rounded,
                          color:
                          Color(
                            0xFFFFB400,
                          ),
                          size: 14,
                        ),
                        const SizedBox(
                          width: 3,
                        ),
                        Text(
                          rating
                              .toStringAsFixed(
                            1,
                          ),
                          style:
                          const TextStyle(
                            color:
                            Color(
                              0xFF486581,
                            ),
                            fontSize:
                            10,
                            fontWeight:
                            FontWeight
                                .w700,
                          ),
                        ),
                        if (reviewCount !=
                            null)
                          Text(
                            ' • $reviewCount',
                            style:
                            const TextStyle(
                              color:
                              Color(
                                0xFF829AB1,
                              ),
                              fontSize:
                              9,
                            ),
                          ),
                      ],
                    ),

                  if (address.isNotEmpty)
                    Padding(
                      padding:
                      const EdgeInsets
                          .only(
                        top: 3,
                      ),
                      child: Text(
                        address,
                        maxLines: 1,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style:
                        const TextStyle(
                          color:
                          Color(
                            0xFF829AB1,
                          ),
                          fontSize:
                          9,
                        ),
                      ),
                    ),

                  const Spacer(),

                  SizedBox(
                    width:
                    double.infinity,
                    height: 32,
                    child:
                    FilledButton(
                      onPressed:
                      placeId.isEmpty ||
                          isAdding
                          ? null
                          : () =>
                          _addNearbyPlace(
                            place,
                          ),
                      style:
                      FilledButton
                          .styleFrom(
                        backgroundColor:
                        const Color(
                          0xFF1677FF,
                        ),
                        disabledBackgroundColor:
                        const Color(
                          0xFFB7C9DB,
                        ),
                        padding:
                        EdgeInsets
                            .zero,
                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            9,
                          ),
                        ),
                      ),
                      child: isAdding
                          ? const SizedBox(
                        width: 15,
                        height: 15,
                        child:
                        CircularProgressIndicator(
                          strokeWidth:
                          2,
                          color:
                          Colors.white,
                        ),
                      )
                          : const Text(
                        'Add to my places',
                        style:
                        TextStyle(
                          fontSize:
                          10,
                          fontWeight:
                          FontWeight
                              .w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // CONTINUE BUTTON
  // ===========================================================================

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed:
        _saving ||
            _selectingDestination ||
            _selectedDestination ==
                null
            ? null
            : _continue,
        style:
        FilledButton.styleFrom(
          backgroundColor:
          const Color(
            0xFF1677FF,
          ),
          disabledBackgroundColor:
          const Color(
            0xFFB7C9DB,
          ),
          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(
              15,
            ),
          ),
        ),
        child: _saving
            ? const SizedBox(
          width: 22,
          height: 22,
          child:
          CircularProgressIndicator(
            strokeWidth: 2.5,
            color:
            Colors.white,
          ),
        )
            : const Row(
          mainAxisAlignment:
          MainAxisAlignment
              .center,
          children: [
            Text(
              'Continue to Preferences',
              style:
              TextStyle(
                fontSize: 15,
                fontWeight:
                FontWeight.w800,
              ),
            ),
            SizedBox(
              width: 8,
            ),
            Icon(
              Icons
                  .arrow_forward_rounded,
            ),
          ],
        ),
      ),
    );
  }
}