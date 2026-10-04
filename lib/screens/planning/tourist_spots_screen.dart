import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../services/places_service.dart';
import '../../services/trip_destination_service.dart';
import '../../widgets/dashboard_navigation_button.dart';

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
  String? _recommendationError;

  List<Map<String, dynamic>> _destinations = [];

  List<Map<String, dynamic>> _recommendations = [];

  List<String> _preferences = [];

  String? _selectedPreference;

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
    _recommendationError = null;
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
      final destinations = await _tripDestinationService.getDestinations(
        tripId,
      );

      final selected = await _tripDestinationService.getSelectedPlaces(tripId);

      final savedPreferences = await _loadPreferences(tripId);
      final preferences = savedPreferences.isEmpty
          ? const ['Culture', 'Nature', 'Adventure']
          : savedPreferences;

      final selectedIds = selected
          .map((item) => item['placeId']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      final results = <Map<String, dynamic>>[];
      final queryErrors = <String>[];

      final seen = <String>{};

      for (final destination in destinations) {
        final latitude = (destination['latitude'] as num?)?.toDouble();

        final longitude = (destination['longitude'] as num?)?.toDouble();

        final destinationName = destination['name']?.toString() ?? '';

        if (latitude == null || longitude == null || destinationName.isEmpty) {
          continue;
        }

        for (final preference in preferences) {
          final query = _preferenceQuery(preference, destinationName);

          List<Map<String, dynamic>> places;
          try {
            places = await _placesService.searchPlaces(
              query: query,
              latitude: latitude,
              longitude: longitude,
              pageSize: 5,
            );
          } catch (e) {
            queryErrors.add('$preference: $e');
            continue;
          }

          for (final place in places) {
            final id = place['id']?.toString();

            final location = place['location'] as Map<String, dynamic>?;

            final lat = (location?['latitude'] as num?)?.toDouble();

            final lng = (location?['longitude'] as num?)?.toDouble();

            if (id == null || id.isEmpty || lat == null || lng == null) {
              continue;
            }

            if (seen.contains(id)) {
              continue;
            }

            seen.add(id);

            results.add({
              ...place,
              'matchedPreference': preference,
              'nearDestination': destinationName,
              'alreadySelected': selectedIds.contains(id),
            });
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _destinations = destinations;
        _preferences = preferences;
        if (!preferences.contains(_selectedPreference)) {
          _selectedPreference = preferences.first;
        }

        _selectedPlaceIds
          ..clear()
          ..addAll(selectedIds);

        _recommendations = results;

        _recommendationError = queryErrors.isEmpty
            ? null
            : queryErrors.join('\n');
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _recommendationError = e.toString();
      });

      _showMessage('Could not load places: $e');
    }
  }

  Future<List<String>> _loadPreferences(String tripId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('trips')
        .doc(tripId)
        .get();

    final value = snapshot.data()?['preferences'];

    if (value is List) {
      return value.whereType<String>().toList();
    }

    return [];
  }

  String _preferenceQuery(String preference, String destination) {
    switch (preference) {
      case 'Beach':
      case 'Beaches':
        return 'best beaches and waterfront places near $destination';

      case 'Nature':
        return 'best nature parks scenic places near $destination';

      case 'Culture':
      case 'History':
        return 'historical places museums cultural attractions near $destination';

      case 'Adventure':
        return 'adventure activities hiking attractions near $destination';

      case 'Shopping':
        return 'shopping markets malls local shopping near $destination';

      case 'Food':
      case 'Food & Drinks':
        return 'famous food places and local attractions near $destination';

      case 'Nightlife':
      case 'Entertainment':
        return 'popular nightlife entertainment places near $destination';

      case 'Relaxation':
        return 'wellness relaxing scenic places near $destination';

      default:
        return 'top tourist attractions near $destination';
    }
  }

  Future<void> _searchPlaces(String value) async {
    _searchDebounce?.cancel();

    final query = value.trim();

    if (query.length < 2) {
      if (!mounted) return;

      setState(() {
        _searchSuggestions = [];
        _searching = false;
      });

      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        if (!mounted) return;

        setState(() {
          _searching = true;
        });

        final results = await _placesService.autocomplete(query);

        if (!mounted) return;

        setState(() {
          _searchSuggestions = results;
          _searching = false;
        });
      } catch (e) {
        if (!mounted) return;

        setState(() {
          _searching = false;
        });

        _showMessage('Search failed: $e');
      }
    });
  }

  Future<void> _addSearchedPlace(Map<String, dynamic> suggestion) async {
    final tripId = _tripId;

    final placeId = suggestion['placeId']?.toString() ?? '';

    if (tripId == null || tripId.isEmpty || placeId.isEmpty) {
      return;
    }

    if (_selectedPlaceIds.contains(placeId)) {
      _closeSearch();
      return;
    }

    try {
      final place = await _placesService.getPlaceDetails(placeId);

      final location = place['location'] as Map<String, dynamic>?;

      final displayName = place['displayName'] as Map<String, dynamic>?;

      final latitude = (location?['latitude'] as num?)?.toDouble();

      final longitude = (location?['longitude'] as num?)?.toDouble();

      if (latitude == null || longitude == null) {
        _showMessage('This place has no location data.');
        return;
      }

      final name =
          displayName?['text']?.toString() ??
          suggestion['mainText']?.toString() ??
          'Place';

      final address =
          place['formattedAddress']?.toString() ??
          suggestion['secondaryText']?.toString() ??
          '';

      await _tripDestinationService.saveSelectedPlace(
        tripId: tripId,
        placeId: placeId,
        name: name,
        address: address,
        latitude: latitude,
        longitude: longitude,
        category: 'Added manually',
      );

      if (!mounted) return;

      setState(() {
        _selectedPlaceIds.add(placeId);

        _searchController.clear();

        _searchSuggestions = [];
      });

      _showMessage('$name added to your trip.');
    } catch (e) {
      _showMessage('Could not add place: $e');
    }
  }

  Future<void> _toggleRecommendation(Map<String, dynamic> place) async {
    final tripId = _tripId;

    final placeId = place['id']?.toString() ?? '';

    final displayName = place['displayName'] as Map<String, dynamic>?;

    final location = place['location'] as Map<String, dynamic>?;

    final latitude = (location?['latitude'] as num?)?.toDouble();

    final longitude = (location?['longitude'] as num?)?.toDouble();

    if (tripId == null ||
        tripId.isEmpty ||
        placeId.isEmpty ||
        latitude == null ||
        longitude == null) {
      return;
    }

    try {
      if (_selectedPlaceIds.contains(placeId)) {
        await _tripDestinationService.removeSelectedPlace(tripId, placeId);

        if (!mounted) return;

        setState(() {
          _selectedPlaceIds.remove(placeId);
        });
      } else {
        await _tripDestinationService.saveSelectedPlace(
          tripId: tripId,
          placeId: placeId,
          name: displayName?['text']?.toString() ?? 'Place',
          address: place['formattedAddress']?.toString() ?? '',
          latitude: latitude,
          longitude: longitude,
          category: place['matchedPreference']?.toString(),
        );

        if (!mounted) return;

        setState(() {
          _selectedPlaceIds.add(placeId);
        });
      }
    } catch (e) {
      _showMessage('Could not update selection: $e');
    }
  }

  Future<void> _removeSelectedPlace(String placeId) async {
    final tripId = _tripId;

    if (tripId == null || tripId.isEmpty) {
      return;
    }

    try {
      await _tripDestinationService.removeSelectedPlace(tripId, placeId);

      if (!mounted) return;

      setState(() {
        _selectedPlaceIds.remove(placeId);
      });
    } catch (e) {
      _showMessage('Could not remove place: $e');
    }
  }

  Future<void> _continue() async {
    final tripId = _tripId;

    if (tripId == null || tripId.isEmpty) {
      return;
    }

    if (_selectedPlaceIds.isEmpty) {
      _showMessage('Select at least one place to visit.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await FirebaseFirestore.instance.collection('trips').doc(tripId).set({
        'placesSelected': true,
        'placesSelectedCount': _selectedPlaceIds.length,
        'updatedAt': FieldValue.serverTimestamp(),
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
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _closeSearch() {
    _searchController.clear();

    if (!mounted) return;

    setState(() {
      _searchSuggestions = [];
    });
  }

  String _placeName(Map<String, dynamic> place) {
    final displayName = place['displayName'] as Map<String, dynamic>?;

    return displayName?['text']?.toString() ??
        place['name']?.toString() ??
        'Place';
  }

  String _placeAddress(Map<String, dynamic> place) {
    return place['formattedAddress']?.toString() ??
        place['address']?.toString() ??
        '';
  }

  String _rating(Map<String, dynamic> place) {
    final value = (place['rating'] as num?)?.toDouble();

    if (value == null || value <= 0) {
      return 'New';
    }

    return value.toStringAsFixed(1);
  }

  Map<String, List<Map<String, dynamic>>> _recommendationsByPreference() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final preference in _preferences) {
      grouped.putIfAbsent(preference, () => []);
    }
    for (final place in _recommendations) {
      final preference =
          place['matchedPreference']?.toString() ?? 'Recommended';
      grouped.putIfAbsent(preference, () => []).add(place);
    }
    return {
      for (final entry in grouped.entries)
        if (entry.value.isNotEmpty) entry.key: entry.value,
    };
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.fixed),
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
        backgroundColor: Color(0xFFF7FAFC),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1677FF)),
        ),
      );
    }

    final recommendationsByPreference = _recommendationsByPreference();
    final selectedRecommendations =
        recommendationsByPreference[_selectedPreference] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7FAFC),
        title: const Text(
          'Places to visit',
          style: TextStyle(
            color: Color(0xFF102A43),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: const [DashboardNavigationButton()],
      ),
      body: Column(
        children: [
          _buildHeader(),

          _buildSearch(),

          _buildSelectedSummary(),

          if (_preferences.isNotEmpty) _buildPreferenceTabs(),

          if (_recommendationError != null && _recommendations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Some recommendation searches failed: '
                '$_recommendationError',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF9A5B13), fontSize: 12),
              ),
            ),

          Expanded(
            child: _recommendations.isEmpty || selectedRecommendations.isEmpty
                ? _recommendations.isEmpty
                      ? _buildEmptyState()
                      : _buildNoPlacesForPreference()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    children: [
                      for (final place in selectedRecommendations)
                        _buildPlaceCard(place),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildNoPlacesForPreference() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Text(
          'No places found for $_selectedPreference. '
          'Try another preference or search for a place above.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF627D98), fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildPreferenceTabs() {
    final recommendationsByPreference = _recommendationsByPreference();

    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _preferences.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final preference = _preferences[index];
          final selected = preference == _selectedPreference;
          final count = recommendationsByPreference[preference]?.length ?? 0;

          return ChoiceChip(
            label: Text('$preference ($count)'),
            selected: selected,
            onSelected: (value) {
              if (!value) return;
              setState(() {
                _selectedPreference = preference;
              });
            },
            selectedColor: const Color(0xFFDFF4FF),
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected
                  ? const Color(0xFF1677FF)
                  : const Color(0xFFE1EAF2),
            ),
            showCheckmark: false,
            labelStyle: TextStyle(
              color: selected
                  ? const Color(0xFF1677FF)
                  : const Color(0xFF536B7A),
              fontWeight: FontWeight.w700,
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    final destinationName = _destinations.isNotEmpty
        ? _destinations.first['name']?.toString()
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1677FF), Color(0xFF45A7FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.explore_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Make your trip yours',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    destinationName == null
                        ? 'Choose places you would love to explore.'
                        : 'Discover great places in $destinationName.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 12.5,
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

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(17),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              onChanged: _searchPlaces,
              decoration: InputDecoration(
                hintText: 'Search for any place',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF1677FF),
                ),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: _closeSearch,
                        icon: const Icon(Icons.close_rounded),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(17),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          if (_searchSuggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              constraints: const BoxConstraints(maxHeight: 230),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(17),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 12),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _searchSuggestions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _searchSuggestions[index];

                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFDFF4FF),
                      child: Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFF1677FF),
                      ),
                    ),
                    title: Text(
                      item['mainText']?.toString() ?? 'Place',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      item['secondaryText']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(
                      Icons.add_circle_outline_rounded,
                      color: Color(0xFF1677FF),
                    ),
                    onTap: () => _addSearchedPlace(item),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedSummary() {
    final count = _selectedPlaceIds.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF1677FF),
            size: 20,
          ),
          const SizedBox(width: 7),
          Text(
            count == 0
                ? 'No places selected yet'
                : '$count ${count == 1 ? 'place' : 'places'} selected',
            style: const TextStyle(
              color: Color(0xFF102A43),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          const Text(
            'Tap a card to add',
            style: TextStyle(color: Color(0xFF829AB1), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceCard(Map<String, dynamic> place) {
    final id = place['id']?.toString() ?? '';

    final selected = _selectedPlaceIds.contains(id);

    final name = _placeName(place);

    final address = _placeAddress(place);

    final preference = place['matchedPreference']?.toString() ?? 'Recommended';

    final nearDestination = place['nearDestination']?.toString() ?? '';

    final rating = _rating(place);

    final ratingCount = (place['userRatingCount'] as num?)?.toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _toggleRecommendation(place),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? const Color(0xFF1677FF)
                    : const Color(0xFFE1EAF2),
                width: selected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: selected ? 0.07 : 0.025,
                  ),
                  blurRadius: selected ? 14 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFDFF4FF)
                        : const Color(0xFFFFF1EC),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _iconForPreference(preference),
                    color: selected
                        ? const Color(0xFF1677FF)
                        : const Color(0xFFFF8A65),
                    size: 27,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF102A43),
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFF1677FF)
                                  : const Color(0xFFF1F5F8),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              selected
                                  ? Icons.check_rounded
                                  : Icons.add_rounded,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF627D98),
                              size: 20,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 7),

                      Wrap(
                        spacing: 6,
                        runSpacing: 5,
                        children: [
                          _infoChip(Icons.auto_awesome_rounded, preference),
                          if (rating != 'New')
                            _infoChip(Icons.star_rounded, rating),
                        ],
                      ),

                      const SizedBox(height: 7),

                      if (address.isNotEmpty)
                        Text(
                          address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF627D98),
                            fontSize: 12,
                          ),
                        ),

                      if (nearDestination.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: Color(0xFF829AB1),
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  'Near $nearDestination',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF829AB1),
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (ratingCount != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            '$ratingCount reviews',
                            style: const TextStyle(
                              color: Color(0xFF9FB3C8),
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F7FC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF1677FF)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF486581),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForPreference(String preference) {
    final value = preference.toLowerCase();

    if (value.contains('beach')) {
      return Icons.beach_access_rounded;
    }

    if (value.contains('nature')) {
      return Icons.park_rounded;
    }

    if (value.contains('adventure')) {
      return Icons.landscape_rounded;
    }

    if (value.contains('culture') || value.contains('history')) {
      return Icons.museum_rounded;
    }

    if (value.contains('shopping')) {
      return Icons.shopping_bag_rounded;
    }

    if (value.contains('food')) {
      return Icons.restaurant_rounded;
    }

    if (value.contains('nightlife') || value.contains('entertainment')) {
      return Icons.nightlife_rounded;
    }

    if (value.contains('relax')) {
      return Icons.spa_rounded;
    }

    return Icons.place_rounded;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFDFF4FF),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.explore_rounded,
                size: 36,
                color: Color(0xFF1677FF),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _recommendationError == null
                  ? 'No recommendations found'
                  : 'Could not load recommendations',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF102A43),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _recommendationError ??
                  'Use the search above to find places you want to visit.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF627D98), fontSize: 13),
            ),
            if (_recommendationError != null) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _loading ? null : _loadRecommendations,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 15,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: _saving ? null : _continue,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1677FF),
            disabledBackgroundColor: const Color(0xFFB7C9DB),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _selectedPlaceIds.isEmpty
                          ? 'Select places to continue'
                          : 'Continue with ${_selectedPlaceIds.length} ${_selectedPlaceIds.length == 1 ? 'place' : 'places'}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_selectedPlaceIds.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
