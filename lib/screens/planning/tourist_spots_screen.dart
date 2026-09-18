import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../app_routes.dart';
import '../../services/places_service.dart';
import '../../services/trip_destination_service.dart';

class TouristSpotsScreen extends StatefulWidget {
  final String? tripId;

  const TouristSpotsScreen({super.key, this.tripId});

  @override
  State<TouristSpotsScreen> createState() => _TouristSpotsScreenState();
}

class _TouristSpotsScreenState extends State<TouristSpotsScreen> {
  final PlacesService _placesService = PlacesService();
  final TripDestinationService _tripDestinationService =
      TripDestinationService();
  final TextEditingController _searchController = TextEditingController();

  String? _tripId;
  bool _loading = true;
  bool _saving = false;
  bool _searching = false;

  List<Map<String, dynamic>> _destinations = [];
  List<Map<String, dynamic>> _recommendations = [];
  List<Map<String, dynamic>> _searchSuggestions = [];
  final Set<String> _selectedPlaceIds = {};
  Timer? _searchDebounce;

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
      _loadRecommendations();
    }
  }

  Future<void> _loadRecommendations() async {
    final tripId = _tripId;
    if (tripId == null || tripId.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    try {
      final destinations =
          await _tripDestinationService.getDestinations(tripId);
      final selected =
          await _tripDestinationService.getSelectedPlaces(tripId);

      _destinations = destinations;
      _selectedPlaceIds.addAll(
        selected.map((item) => item['placeId'].toString()),
      );

      final preferences = await _loadPreferences(tripId);
      final results = <Map<String, dynamic>>[];
      final seen = <String>{};

      for (final destination in destinations) {
        final latitude = (destination['latitude'] as num).toDouble();
        final longitude = (destination['longitude'] as num).toDouble();
        final destinationName = destination['name'].toString();

        for (final preference in preferences) {
          final query = _preferenceQuery(preference, destinationName);
          final places = await _placesService.searchPlaces(
            query: query,
            latitude: latitude,
            longitude: longitude,
            pageSize: 5,
          );

          for (final place in places) {
            final id = place['id']?.toString();
            final location = place['location'] as Map<String, dynamic>?;
            final lat = (location?['latitude'] as num?)?.toDouble();
            final lng = (location?['longitude'] as num?)?.toDouble();

            if (id == null || lat == null || lng == null || seen.contains(id)) {
              continue;
            }

            seen.add(id);
            results.add({
              ...place,
              'matchedPreference': preference,
              'nearDestination': destinationName,
            });
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _recommendations = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Could not load recommendations: $e');
    }
  }

  Future<List<String>> _loadPreferences(String tripId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('trips')
        .doc(tripId)
        .get();

    return List<String>.from(snapshot.data()?['preferences'] ?? []);
  }

  String _preferenceQuery(String preference, String destination) {
    switch (preference) {
      case 'Beaches':
        return 'beaches and waterfront places near $destination';
      case 'Nature':
        return 'nature parks and scenic places near $destination';
      case 'History':
        return 'historical places and museums near $destination';
      case 'Adventure':
        return 'adventure activities and places near $destination';
      case 'Shopping':
        return 'shopping places and markets near $destination';
      case 'Food & Drinks':
        return 'popular food and restaurants near $destination';
      case 'Entertainment':
        return 'entertainment places near $destination';
      default:
        return 'tourist attractions near $destination';
    }
  }

  Future<void> _searchPlaces(String value) async {
    _searchDebounce?.cancel();

    if (value.trim().length < 2) {
      setState(() {
        _searchSuggestions = [];
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
          _searchSuggestions = results;
          _searching = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() => _searching = false);
        _showMessage('Search failed: $e');
      }
    });
  }

  Future<void> _addSearchedPlace(Map<String, dynamic> suggestion) async {
    final tripId = _tripId;
    final placeId = suggestion['placeId']?.toString() ?? '';
    if (tripId == null || tripId.isEmpty || placeId.isEmpty) return;

    try {
      final place = await _placesService.getPlaceDetails(placeId);
      final location = place['location'] as Map<String, dynamic>?;
      final displayName = place['displayName'] as Map<String, dynamic>?;
      final lat = (location?['latitude'] as num?)?.toDouble();
      final lng = (location?['longitude'] as num?)?.toDouble();

      if (lat == null || lng == null) {
        _showMessage('This place has no location data.');
        return;
      }

      await _tripDestinationService.saveSelectedPlace(
        tripId: tripId,
        placeId: placeId,
        name: displayName?['text']?.toString() ?? suggestion['description'].toString(),
        address: place['formattedAddress']?.toString() ?? '',
        latitude: lat,
        longitude: lng,
      );

      if (!mounted) return;
      setState(() {
        _selectedPlaceIds.add(placeId);
        _searchController.clear();
        _searchSuggestions = [];
      });
    } catch (e) {
      _showMessage('Could not add place: $e');
    }
  }

  Future<void> _toggleRecommendation(Map<String, dynamic> place) async {
    final tripId = _tripId;
    final placeId = place['id']?.toString() ?? '';
    final displayName = place['displayName'] as Map<String, dynamic>?;
    final location = place['location'] as Map<String, dynamic>?;
    final lat = (location?['latitude'] as num?)?.toDouble();
    final lng = (location?['longitude'] as num?)?.toDouble();

    if (tripId == null || placeId.isEmpty || lat == null || lng == null) return;

    if (_selectedPlaceIds.contains(placeId)) {
      await _tripDestinationService.removeSelectedPlace(tripId, placeId);
      setState(() => _selectedPlaceIds.remove(placeId));
    } else {
      await _tripDestinationService.saveSelectedPlace(
        tripId: tripId,
        placeId: placeId,
        name: displayName?['text']?.toString() ?? 'Place',
        address: place['formattedAddress']?.toString() ?? '',
        latitude: lat,
        longitude: lng,
        category: place['matchedPreference']?.toString(),
      );
      setState(() => _selectedPlaceIds.add(placeId));
    }
  }

  Future<void> _continue() async {
    final tripId = _tripId;
    if (tripId == null || tripId.isEmpty) return;

    if (_selectedPlaceIds.isEmpty) {
      _showMessage('Select at least one place to visit.');
      return;
    }

    setState(() => _saving = true);

    try {
      await FirebaseFirestore.instance.collection('trips').doc(tripId).set({
        'updatedAt': FieldValue.serverTimestamp(),
        'placesSelected': true,
      }, SetOptions(merge: true));
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        AppRoutes.hotelSelection,
        arguments: {'tripId': tripId},
      );
    } catch (e) {
      _showMessage('Could not save selected places: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
      appBar: AppBar(title: const Text('4. Recommended Places')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _searchPlaces,
                  decoration: InputDecoration(
                    hintText: 'Search and add another place',
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
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (_searchSuggestions.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchSuggestions.length,
                      itemBuilder: (context, index) {
                        final item = _searchSuggestions[index];
                        return ListTile(
                          leading: const Icon(Icons.add_location_alt),
                          title: Text(item['mainText'].toString()),
                          subtitle: Text(item['secondaryText'].toString()),
                          onTap: () => _addSearchedPlace(item),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Recommended for your preferences',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),
          Expanded(
            child: _recommendations.isEmpty
                ? const Center(
                    child: Text('No recommendations found. Search and add places manually.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: _recommendations.length,
                    itemBuilder: (context, index) {
                      final place = _recommendations[index];
                      final id = place['id'].toString();
                      final displayName =
                          place['displayName'] as Map<String, dynamic>?;
                      final selected = _selectedPlaceIds.contains(id);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: CheckboxListTile(
                          value: selected,
                          onChanged: (_) => _toggleRecommendation(place),
                          title: Text(
                            displayName?['text']?.toString() ?? 'Place',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${place['matchedPreference']} • ${place['nearDestination']}\n${place['formattedAddress'] ?? ''}',
                          ),
                          isThreeLine: true,
                          secondary: const Icon(Icons.place),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _saving ? null : _continue,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
          child: _saving
              ? const CircularProgressIndicator()
              : Text('Next: Select Hotel (${_selectedPlaceIds.length} selected)'),
        ),
      ),
    );
  }
}

