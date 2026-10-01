import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../app_routes.dart';
import '../../services/places_service.dart';
import '../../services/trip_destination_service.dart';
import '../../services/trip_service.dart';

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
  final TextEditingController _searchController =
  TextEditingController();

  final PlacesService _placesService = PlacesService();

  final TripDestinationService _destinationService =
  TripDestinationService();

  final Map<String, Map<String, dynamic>>
  _selectedDestinations = {};

  GoogleMapController? _mapController;

  Timer? _searchDebounce;

  String? _tripId;

  bool _loading = true;
  bool _searching = false;
  bool _saving = false;
  bool _loadingNearby = false;

  List<Map<String, dynamic>> _suggestions = [];

  List<Map<String, dynamic>> _nearbyDestinations = [];

  LatLng _mapCenter =
  const LatLng(22.6916, 72.8634);

  @override
  void initState() {
    super.initState();
    _tripId = widget.tripId;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_tripId == null || _tripId!.isEmpty) {
      final args =
          ModalRoute.of(context)?.settings.arguments;

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
      final trip =
      await TripService().getTrip(tripId);

      final saved =
      await _destinationService
          .getDestinations(tripId);

      if (!mounted) return;

      if (trip != null) {
        _mapCenter = LatLng(
          trip.startLatitude,
          trip.startLongitude,
        );
      }

      for (final item in saved) {
        _selectedDestinations[
        item['id'].toString()] = item;
      }

      setState(() => _loading = false);

      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            _mapCenter,
            11,
          ),
        );
      }

      if (_selectedDestinations.isNotEmpty) {
        await _loadNearbyDestinations(
          LatLng(
            (_selectedDestinations.values.first['latitude']
            as num)
                .toDouble(),
            (_selectedDestinations.values.first['longitude']
            as num)
                .toDouble(),
          ),
        );
      } else {
        await _loadNearbyDestinations(_mapCenter);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);

      _showMessage(
        'Could not load destinations: $e',
      );
    }
  }

  // ------------------------------------------------------------
  // SEARCH
  // ------------------------------------------------------------

  Future<void> _searchPlaces(String value) async {
    _searchDebounce?.cancel();

    if (value.trim().length < 2) {
      setState(() {
        _suggestions = [];
        _searching = false;
      });

      return;
    }

    _searchDebounce = Timer(
      const Duration(milliseconds: 450),
          () async {
        try {
          setState(() => _searching = true);

          final results =
          await _placesService.autocomplete(
            value.trim(),
            latitude: _mapCenter.latitude,
            longitude: _mapCenter.longitude,
          );

          if (!mounted) return;

          setState(() {
            _suggestions = results;
            _searching = false;
          });
        } catch (e) {
          if (!mounted) return;

          setState(() => _searching = false);

          _showMessage(
            'Place search failed: $e',
          );
        }
      },
    );
  }

  Future<void> _selectSearchResult(
      Map<String, dynamic> suggestion,
      ) async {
    final placeId =
        suggestion['placeId']?.toString() ?? '';

    if (placeId.isEmpty) return;

    try {
      final details =
      await _placesService.getPlaceDetails(
        placeId,
      );

      final location =
      details['location']
      as Map<String, dynamic>?;

      final displayName =
      details['displayName']
      as Map<String, dynamic>?;

      final lat =
      (location?['latitude'] as num?)
          ?.toDouble();

      final lng =
      (location?['longitude'] as num?)
          ?.toDouble();

      if (lat == null || lng == null) {
        _showMessage(
          'This place does not have a map location.',
        );

        return;
      }

      final name = <dynamic>[
        displayName?['text'],
        suggestion['mainText'],
        suggestion['description'],
      ]
          .whereType<String>()
          .map((value) => value.trim())
          .firstWhere((value) => value.isNotEmpty, orElse: () => 'Selected place');

      final suggestedAddress =
          details['formattedAddress']
              ?.toString() ??
              suggestion['secondaryText']
                  ?.toString() ??
              '';
      final address = suggestedAddress.trim().isEmpty
          ? name
          : suggestedAddress;

      await _addDestination(
        name: name,
        address: address,
        latitude: lat,
        longitude: lng,
        placeId: placeId,
        source: 'places_api',
      );

      _searchController.clear();

      setState(() {
        _suggestions = [];
      });
    } catch (e) {
      _showMessage(
        'Could not add this place: $e',
      );
    }
  }

  // ------------------------------------------------------------
  // MAP SELECTION
  // ------------------------------------------------------------

  Future<void> _selectMapPoint(
      LatLng position,
      ) async {
    try {
      /*
       * Do not use placemarkFromCoordinates here.
       *
       * That was causing the map-tap flow to fail,
       * especially on Flutter Web.
       *
       * A map tap can now directly become a destination.
       */

      var address = '';
      try {
        address = await _placesService.getLocationName(
          latitude: position.latitude,
          longitude: position.longitude,
        );
      } catch (_) {
        // Keep map selection available when reverse geocoding is unavailable.
      }
      if (address.trim().isEmpty ||
          address.toLowerCase().startsWith('location near ')) {
        address = 'Selected map point';
      }
      final name = address.split(',').first.trim();

      await _addDestination(
        name: name,
        address: address,
        latitude: position.latitude,
        longitude: position.longitude,
        source: 'map_tap',
      );
    } catch (e) {
      _showMessage(
        'Could not add map location: $e',
      );
    }
  }

  // ------------------------------------------------------------
  // CURRENT LOCATION
  // ------------------------------------------------------------

  Future<void> _useCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showMessage(
          'Please turn on location services.',
        );

        return;
      }

      var permission =
      await Geolocator.checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
        await Geolocator.requestPermission();
      }

      if (permission ==
          LocationPermission.denied ||
          permission ==
              LocationPermission.deniedForever) {
        _showMessage(
          'Location permission is required.',
        );

        return;
      }

      final position =
      await Geolocator.getCurrentPosition(
        locationSettings:
        const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final point = LatLng(
        position.latitude,
        position.longitude,
      );

      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          point,
          14,
        ),
      );

      await _selectMapPoint(point);
    } catch (e) {
      _showMessage(
        'Could not get current location: $e',
      );
    }
  }

  // ------------------------------------------------------------
  // ADD DESTINATION
  // ------------------------------------------------------------

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
      _showMessage(
        'This destination is already selected.',
      );

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
      _selectedDestinations[
      documentId] = data;

      _mapCenter =
          LatLng(latitude, longitude);
    });

    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(latitude, longitude),
        12,
      ),
    );

    /*
     * Once a destination is selected,
     * find nearby destinations around it.
     */
    await _loadNearbyDestinations(
      LatLng(latitude, longitude),
    );
  }

  // ------------------------------------------------------------
  // NEARBY DESTINATIONS
  // ------------------------------------------------------------

  Future<void> _loadNearbyDestinations(
      LatLng center,
      ) async {
    if (!mounted) return;

    setState(() {
      _loadingNearby = true;
    });

    try {
      final results =
      await _placesService
          .searchNearbyDestinations(
        latitude: center.latitude,
        longitude: center.longitude,
        radius: 10000,
        maxResultCount: 10,
      );

      final selectedPlaceIds =
      _selectedDestinations.values
          .map(
            (item) =>
            item['placeId']?.toString(),
      )
          .where(
            (id) =>
        id != null &&
            id.isNotEmpty,
      )
          .toSet();

      final selectedCoordinates =
      _selectedDestinations.values
          .map(
            (item) => LatLng(
          (item['latitude'] as num)
              .toDouble(),
          (item['longitude'] as num)
              .toDouble(),
        ),
      )
          .toList();

      final filtered = <Map<String, dynamic>>[];

      final seenIds = <String>{};

      for (final place in results) {
        final placeId =
            place['id']?.toString() ?? '';

        final location =
        place['location']
        as Map<String, dynamic>?;

        final lat =
        (location?['latitude'] as num?)
            ?.toDouble();

        final lng =
        (location?['longitude'] as num?)
            ?.toDouble();

        if (placeId.isEmpty ||
            lat == null ||
            lng == null) {
          continue;
        }

        if (selectedPlaceIds.contains(placeId)) {
          continue;
        }

        if (seenIds.contains(placeId)) {
          continue;
        }

        bool alreadySelectedByLocation = false;

        for (final selected
        in selectedCoordinates) {
          final distance =
          Geolocator.distanceBetween(
            selected.latitude,
            selected.longitude,
            lat,
            lng,
          );

          if (distance < 50) {
            alreadySelectedByLocation =
            true;

            break;
          }
        }

        if (alreadySelectedByLocation) {
          continue;
        }

        seenIds.add(placeId);

        filtered.add(place);
      }

      if (!mounted) return;

      setState(() {
        _nearbyDestinations = filtered;
        _loadingNearby = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingNearby = false;
      });

      _showMessage(
        'Could not load nearby destinations: $e',
      );
    }
  }

  Future<void> _addNearbyDestination(
      Map<String, dynamic> place,
      ) async {
    final location =
    place['location']
    as Map<String, dynamic>?;

    final displayName =
    place['displayName']
    as Map<String, dynamic>?;

    final latitude =
    (location?['latitude'] as num?)
        ?.toDouble();

    final longitude =
    (location?['longitude'] as num?)
        ?.toDouble();

    final placeId =
        place['id']?.toString() ?? '';

    if (latitude == null ||
        longitude == null ||
        placeId.isEmpty) {
      _showMessage(
        'This destination has incomplete location data.',
      );

      return;
    }

    final name =
        displayName?['text']?.toString() ??
            'Nearby destination';

    final formattedAddress =
        place['formattedAddress']
            ?.toString() ??
            '';
    final address = formattedAddress.trim().isEmpty ? name : formattedAddress;

    await _addDestination(
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
      placeId: placeId,
      source: 'nearby_places_api',
    );

    if (!mounted) return;

    setState(() {
      _nearbyDestinations.removeWhere(
            (item) =>
        item['id']?.toString() ==
            placeId,
      );
    });
  }

  // ------------------------------------------------------------
  // REMOVE
  // ------------------------------------------------------------

  Future<void> _removeDestination(
      String id,
      ) async {
    final tripId = _tripId;

    if (tripId == null) return;

    await _destinationService
        .removeDestination(
      tripId,
      id,
    );

    setState(() {
      _selectedDestinations.remove(id);
    });

    if (_selectedDestinations.isEmpty) {
      setState(() {
        _nearbyDestinations = [];
      });
      await _loadNearbyDestinations(_mapCenter);
    }
  }

  // ------------------------------------------------------------
  // CONTINUE
  // ------------------------------------------------------------

  Future<void> _continue() async {
    if (_selectedDestinations.isEmpty) {
      _showMessage(
        'Select at least one destination.',
      );

      return;
    }

    final tripId = _tripId;

    if (tripId == null || tripId.isEmpty) {
      _showMessage('Trip ID is missing.');
      return;
    }

    setState(() => _saving = true);

    try {
      await TripService().updateTrip(
        tripId,
        {
          'destination': _selectedDestinations.values
              .map((item) => item['name']?.toString().trim() ?? '')
              .where((name) => name.isNotEmpty)
              .join(', '),
          'destinationCount':
          _selectedDestinations.length,
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
        'Could not save trip destinations: $e',
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  // ------------------------------------------------------------
  // MARKERS
  // ------------------------------------------------------------

  Set<Marker> _markers() {
    return _selectedDestinations.entries
        .map(
          (entry) {
        final data = entry.value;

        return Marker(
          markerId:
          MarkerId(entry.key),
          position: LatLng(
            (data['latitude'] as num)
                .toDouble(),
            (data['longitude'] as num)
                .toDouble(),
          ),
          infoWindow: InfoWindow(
            title:
            data['name']?.toString() ??
                'Destination',
            snippet:
            data['address']?.toString() ??
                '',
          ),
        );
      },
    )
        .toSet();
  }

  void _showMessage(
      String message,
      ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child:
          CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '2. Select Destinations',
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition:
            CameraPosition(
              target: _mapCenter,
              zoom: 10,
            ),
            markers: _markers(),
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated:
                (controller) {
              _mapController =
                  controller;
            },
            onTap: _selectMapPoint,
          ),

          // --------------------------------------------------
          // SEARCH BAR
          // --------------------------------------------------

          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              children: [
                Material(
                  elevation: 4,
                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                  child: TextField(
                    controller:
                    _searchController,
                    onChanged:
                    _searchPlaces,
                    decoration:
                    InputDecoration(
                      hintText:
                      'Search destination or place',
                      prefixIcon:
                      const Icon(
                        Icons.search,
                      ),
                      suffixIcon:
                      _searching
                          ? const Padding(
                        padding:
                        EdgeInsets.all(
                          12,
                        ),
                        child:
                        SizedBox(
                          width: 20,
                          height: 20,
                          child:
                          CircularProgressIndicator(
                            strokeWidth:
                            2,
                          ),
                        ),
                      )
                          : IconButton(
                        icon:
                        const Icon(
                          Icons.close,
                        ),
                        onPressed:
                            () {
                          _searchController
                              .clear();

                          setState(
                                () =>
                            _suggestions =
                            [],
                          );
                        },
                      ),
                      filled: true,
                      fillColor:
                      Colors.white,
                      border:
                      OutlineInputBorder(
                        borderRadius:
                        BorderRadius
                            .circular(
                          12,
                        ),
                        borderSide:
                        BorderSide.none,
                      ),
                    ),
                  ),
                ),

                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: _suggestions.isNotEmpty
                      ? Container(
                    margin:
                    const EdgeInsets.only(
                      top: 4,
                    ),
                    constraints:
                    const BoxConstraints(
                      maxHeight: 260,
                    ),
                    decoration:
                    BoxDecoration(
                      color:
                      Colors.white,
                      borderRadius:
                      BorderRadius
                          .circular(
                        12,
                      ),
                      boxShadow:
                      const [
                        BoxShadow(
                          blurRadius: 8,
                          color:
                          Colors.black26,
                        ),
                      ],
                    ),
                    child:
                    ListView.builder(
                      shrinkWrap: true,
                      itemCount:
                      _suggestions.length,
                      itemBuilder:
                          (
                          context,
                          index,
                          ) {
                        final item =
                        _suggestions[
                        index];

                        return ListTile(
                          leading:
                          const Icon(
                            Icons
                                .location_on,
                          ),
                          title:
                          Text(
                            item['mainText']
                                ?.toString()
                                .isNotEmpty ==
                                true
                                ? item[
                            'mainText']
                                .toString()
                                : item[
                            'description']
                                .toString(),
                          ),
                          subtitle:
                          Text(
                            item[
                            'secondaryText']
                                ?.toString() ??
                                '',
                            maxLines: 2,
                            overflow:
                            TextOverflow
                                .ellipsis,
                          ),
                          onTap: () =>
                              _selectSearchResult(
                                item,
                              ),
                        );
                      },
                    ),
                        )
                      : const SizedBox.shrink(),
                ),

                if (_suggestions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 9, left: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Step 2 - Add stops near your starting point',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // --------------------------------------------------
          // CURRENT LOCATION
          // --------------------------------------------------

          Positioned(
            right: 12,
            bottom: 250,
            child:
            FloatingActionButton(
              heroTag:
              'current_location_destination',
              mini: true,
              onPressed:
              _useCurrentLocation,
              child: const Icon(
                Icons.my_location,
              ),
            ),
          ),

          // --------------------------------------------------
          // NEARBY DESTINATIONS
          // --------------------------------------------------

          if (_loadingNearby ||
              _nearbyDestinations.isNotEmpty ||
              _selectedDestinations.isNotEmpty)
            Positioned(
              left: 12,
              right: 12,
              bottom: 175,
              child: _buildNearbyDestinations(),
            ),

          // --------------------------------------------------
          // BOTTOM SELECTED DESTINATIONS
          // --------------------------------------------------

          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Material(
              elevation: 5,
              borderRadius:
              BorderRadius.circular(
                16,
              ),
              color: Colors.white,
              child: Padding(
                padding:
                const EdgeInsets.all(
                  12,
                ),
                child: Column(
                  mainAxisSize:
                  MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.place,
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: Text(
                              '${_selectedDestinations.length} '
                              '${_selectedDestinations.length == 1 ? 'stop' : 'stops'} selected',
                              key: ValueKey(_selectedDestinations.length),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const Text(
                          'Tap map to add',
                        ),
                      ],
                    ),

                    if (_selectedDestinations
                        .isNotEmpty) ...[
                      const SizedBox(
                        height: 8,
                      ),
                      SizedBox(
                        height: 58,
                        child:
                        ListView(
                          scrollDirection:
                          Axis.horizontal,
                          children:
                          _selectedDestinations
                              .entries
                              .map(
                                (entry) {
                              return Padding(
                                padding:
                                const EdgeInsets
                                    .only(
                                  right: 8,
                                ),
                                child:
                                InputChip(
                                  label:
                                  SizedBox(
                                    width:
                                    130,
                                    child:
                                    Text(
                                      entry.value[
                                      'name']
                                          .toString(),
                                      overflow:
                                      TextOverflow
                                          .ellipsis,
                                    ),
                                  ),
                                  onDeleted:
                                      () =>
                                      _removeDestination(
                                        entry.key,
                                      ),
                                ),
                              );
                            },
                          ).toList(),
                        ),
                      ),
                    ],

                    const SizedBox(
                      height: 8,
                    ),

                    SizedBox(
                      width:
                      double.infinity,
                      child:
                      ElevatedButton(
                        onPressed:
                        _saving
                            ? null
                            : _continue,
                        style:
                        ElevatedButton
                            .styleFrom(
                          minimumSize:
                          const Size(
                            double.infinity,
                            48,
                          ),
                        ),
                        child:
                        _saving
                            ? const CircularProgressIndicator()
                            : const Text(
                          'Next: Select Preferences',
                        ),
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

  // ------------------------------------------------------------
  // NEARBY UI
  // ------------------------------------------------------------

  Widget _buildNearbyDestinations() {
    return Material(
      elevation: 5,
      borderRadius:
      BorderRadius.circular(16),
      color: Colors.white,
      child: Padding(
        padding:
        const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.explore,
                  size: 20,
                ),
                const SizedBox(
                  width: 8,
                ),
                const Expanded(
                  child: Text(
                    'Nearby destinations',
                    style: TextStyle(
                      fontWeight:
                      FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (_loadingNearby)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
              ],
            ),

            const SizedBox(
              height: 8,
            ),

            if (_loadingNearby &&
                _nearbyDestinations
                    .isEmpty)
              const Padding(
                padding:
                EdgeInsets.symmetric(
                  vertical: 8,
                ),
                child: Text(
                  'Finding places near your destination...',
                ),
              )
            else if (_nearbyDestinations
                .isEmpty)
              const Padding(
                padding:
                EdgeInsets.symmetric(
                  vertical: 8,
                ),
                child: Text(
                  'No nearby destinations found.',
                ),
              )
            else
              SizedBox(
                height: 105,
                child: ListView.builder(
                  scrollDirection:
                  Axis.horizontal,
                  itemCount:
                  _nearbyDestinations
                      .length,
                  itemBuilder:
                      (context, index) {
                    final place =
                    _nearbyDestinations[
                    index];

                    final displayName =
                    place[
                    'displayName']
                    as Map<String,
                        dynamic>?;

                    final name =
                        displayName?[
                        'text']
                            ?.toString() ??
                            'Destination';

                    final address =
                        place[
                        'formattedAddress']
                            ?.toString() ??
                            '';

                    return Container(
                      width: 220,
                      margin:
                      const EdgeInsets
                          .only(
                        right: 8,
                      ),
                      padding:
                      const EdgeInsets
                          .all(10),
                      decoration:
                      BoxDecoration(
                        border: Border.all(
                          color: Colors
                              .grey
                              .shade300,
                        ),
                        borderRadius:
                        BorderRadius
                            .circular(
                          12,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons
                                    .location_on,
                                size: 18,
                              ),
                              const SizedBox(
                                width: 4,
                              ),
                              Expanded(
                                child:
                                Text(
                                  name,
                                  maxLines:
                                  1,
                                  overflow:
                                  TextOverflow
                                      .ellipsis,
                                  style:
                                  const TextStyle(
                                    fontWeight:
                                    FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 4,
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
                              TextStyle(
                                fontSize:
                                11,
                                color: Colors
                                    .grey
                                    .shade700,
                              ),
                            ),
                          ),

                          SizedBox(
                            height: 30,
                            child:
                            OutlinedButton(
                              onPressed:
                                  () =>
                                  _addNearbyDestination(
                                    place,
                                  ),
                              child:
                              const Text(
                                'Add',
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
