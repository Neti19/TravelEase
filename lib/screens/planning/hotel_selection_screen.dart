import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../models/hotel.dart';
import '../../models/place_map_reader.dart';
import '../../services/day_planner.dart';
import '../../services/hotel_service.dart';
import '../../services/trip_destination_service.dart';
import '../../services/trip_service.dart';
import '../../widgets/dashboard_navigation_button.dart';

class HotelSelectionScreen extends StatefulWidget {
  final String tripId;

  const HotelSelectionScreen({super.key, required this.tripId});

  @override
  State<HotelSelectionScreen> createState() => _HotelSelectionScreenState();
}

class _HotelSelectionScreenState extends State<HotelSelectionScreen> {
  final HotelService _hotelService = HotelService();

  final TripDestinationService _destinationService = TripDestinationService();

  final TripService _tripService = TripService();

  // Flattened list of every recommended hotel (used for the empty check).
  List<Map<String, dynamic>> _hotels = [];

  // One entry per stay area (consecutive days that share a hotel).
  List<_StayOption> _stays = [];

  // stay index -> selected hotel id
  final Map<int, String> _selectedByStay = {};

  // When true every day gets its own stay/hotel list.
  bool _separateHotels = false;
  int _numberOfDays = 1;
  int _selectedDay = 1;

  bool _loading = true;
  bool _saving = false;
  String? _hotelLoadError;
  String? _hotelLoadWarning;

  @override
  void initState() {
    super.initState();
    _loadHotels();
  }

  /// Hotel budget share used to rank hotels (35% of the trip budget,
  /// spread over the nights). Only a ranking hint, never a hard filter.
  static const double _hotelBudgetShare = 0.35;

  Map<int, Map<String, dynamic>> _dayChoicesFromState() {
    final choices = <int, Map<String, dynamic>>{};
    for (var i = 0; i < _stays.length; i++) {
      final id = _selectedByStay[i];
      if (id == null) continue;
      for (final hotel in _stays[i].hotels) {
        if (PlaceMap.id(hotel) == id) {
          for (final day in _stays[i].stay.dayNumbers) {
            choices[day] = hotel;
          }
          break;
        }
      }
    }
    return choices;
  }

  Future<void> _loadHotels() async {
    _hotelLoadError = null;
    _hotelLoadWarning = null;

    try {
      final trip = await _tripService.getTrip(widget.tripId);

      if (trip == null) {
        throw Exception('Trip not found.');
      }

      final rawSnapshot = await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.tripId)
          .get();

      final tripData = rawSnapshot.data() ?? <String, dynamic>{};

      final selectedPlaces = await _destinationService.getSelectedPlaces(
        widget.tripId,
      );

      final places = <PlannerPlace>[];

      for (final map in selectedPlaces) {
        final place = PlannerPlace.fromMap(map);
        if (place != null) places.add(place);
      }

      if (places.isEmpty) {
        throw Exception('No tourist places selected.');
      }

      final days = trip.numberOfDays < 1 ? 1 : trip.numberOfDays;
      final destinationLatitude =
          (tripData['destinationLatitude'] as num?)?.toDouble();
      final destinationLongitude =
          (tripData['destinationLongitude'] as num?)?.toDouble();
      final hasDestinationCoordinates =
          destinationLatitude != null && destinationLongitude != null;

      final clusters = DayPlanner.clusterIntoDays(
        places: places,
        numberOfDays: days,
        startLatitude: hasDestinationCoordinates
            ? destinationLatitude
            : trip.startLatitude,
        startLongitude: hasDestinationCoordinates
            ? destinationLongitude
            : trip.startLongitude,
      );

      final groups = DayPlanner.buildStayGroups(
        clusters,
        // A negative threshold never merges: one stay per day.
        mergeThresholdKm: _separateHotels ? -1 : 25,
      );

      final nights = days > 1 ? days - 1 : 1;
      final budgetPerNight = trip.budget > 0
          ? trip.budget * _hotelBudgetShare / nights
          : 0.0;

      // Choices the user already made (this session) or saved earlier.
      final carry = _stays.isEmpty ? null : _dayChoicesFromState();
      final saved = HotelPlan.fromTrip(tripData, numberOfDays: days);
      final firstVisit = tripData['hotelSelected'] == null;

      final stays = <_StayOption>[];
      var failedStays = 0;
      Object? firstSearchError;

      for (final group in groups) {
        var hotels = <Map<String, dynamic>>[];

        try {
          hotels = await _hotelService.recommendHotelsForStay(
            stay: group,
            maxBudgetPerNight: budgetPerNight,
            travelers: trip.travelersCount < 1 ? 1 : trip.travelersCount,
          );
        } catch (e) {
          failedStays++;
          firstSearchError ??= e;
        }

        stays.add(_StayOption(stay: group, hotels: hotels));
      }

      if (failedStays == stays.length) {
        throw Exception('Hotel search failed: $firstSearchError');
      }

      final selection = <int, String>{};

      for (var i = 0; i < stays.length; i++) {
        final firstDay = stays[i].stay.firstDay;

        Map<String, dynamic>? preferred = carry?[firstDay];

        if (preferred == null && saved.isNotEmpty) {
          preferred = HotelPlan.forDay(saved, firstDay)?.hotel;
        }

        if (preferred != null && PlaceMap.id(preferred).isNotEmpty) {
          final id = PlaceMap.id(preferred);
          final exists = stays[i].hotels.any((h) => PlaceMap.id(h) == id);
          if (!exists) {
            // Keep an earlier choice visible even if it is no longer
            // among the fresh recommendations.
            stays[i].hotels.insert(0, preferred);
          }
          selection[i] = id;
        } else if (firstVisit && carry == null && stays[i].hotels.isNotEmpty) {
          // First visit: pre-select the best match. The user can
          // change or deselect it.
          selection[i] = PlaceMap.id(stays[i].hotels.first);
        }
      }

      if (!mounted) return;

      setState(() {
        _numberOfDays = days;
        _selectedDay = _selectedDay.clamp(1, days);
        _stays = stays;
        _hotels = [for (final option in stays) ...option.hotels];
        _selectedByStay
          ..clear()
          ..addAll(selection);
        _hotelLoadWarning = failedStays > 0
            ? 'Some stay areas could not load hotel results: '
                  '$firstSearchError'
            : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _hotelLoadError = e.toString();
      });

      _showMessage('Could not load hotels: $e');
    }
  }

  Future<void> _continue() async {
    if (_saving) return;

    setState(() {
      _saving = true;
    });

    try {
      // One HotelPlan per day. A hotel chosen for a multi-day stay is
      // written for every day of that stay.
      final plans = <HotelPlan>[];
      Map<String, dynamic>? firstHotel;

      for (var i = 0; i < _stays.length; i++) {
        final id = _selectedByStay[i];
        if (id == null) continue;

        Map<String, dynamic>? hotel;
        for (final candidate in _stays[i].hotels) {
          if (PlaceMap.id(candidate) == id) {
            hotel = candidate;
            break;
          }
        }
        if (hotel == null) continue;

        firstHotel ??= hotel;

        for (final day in _stays[i].stay.dayNumbers) {
          plans.add(HotelPlan(dayNumber: day, hotel: hotel));
        }
      }

      plans.sort((a, b) => a.dayNumber.compareTo(b.dayNumber));

      final data = <String, dynamic>{
        'hotelSelected': plans.isNotEmpty,
        'hotelPlans': plans.map((p) => p.toJson()).toList(),
        // Legacy field kept in sync so older screens keep working.
        'selectedHotel': firstHotel ?? FieldValue.delete(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await _tripService.updateTrip(widget.tripId, data);

      if (!mounted) return;

      Navigator.pushNamed(
        context,
        AppRoutes.restaurantSelection,
        arguments: {'tripId': widget.tripId},
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage('Could not save hotel selection: $e');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String _getName(Map<String, dynamic> hotel) {
    final displayName = hotel['displayName'] as Map<String, dynamic>?;

    return displayName?['text']?.toString() ??
        hotel['name']?.toString() ??
        'Hotel';
  }

  String _getPrice(Map<String, dynamic> hotel) {
    final price = hotel['priceLevel']?.toString();

    switch (price) {
      case 'PRICE_LEVEL_INEXPENSIVE':
        return '₹ Budget';

      case 'PRICE_LEVEL_MODERATE':
        return '₹₹ Moderate';

      case 'PRICE_LEVEL_EXPENSIVE':
        return '₹₹₹ Premium';

      case 'PRICE_LEVEL_VERY_EXPENSIVE':
        return '₹₹₹₹ Luxury';

      default:
        return 'Price unavailable';
    }
  }

  String _getAddress(Map<String, dynamic> hotel) {
    return hotel['formattedAddress']?.toString() ??
        hotel['address']?.toString() ??
        'Address unavailable';
  }

  double _getRating(Map<String, dynamic> hotel) {
    return (hotel['rating'] as num?)?.toDouble() ?? 0;
  }

  int _getReviewCount(Map<String, dynamic> hotel) {
    return (hotel['userRatingCount'] as num?)?.toInt() ?? 0;
  }

  String _getNearPlace(Map<String, dynamic> hotel) {
    return hotel['nearPlace']?.toString() ?? '';
  }

  IconData _getHotelIcon(Map<String, dynamic> hotel) {
    final price = hotel['priceLevel']?.toString();

    switch (price) {
      case 'PRICE_LEVEL_VERY_EXPENSIVE':
        return Icons.workspace_premium_rounded;

      case 'PRICE_LEVEL_EXPENSIVE':
        return Icons.hotel_rounded;

      default:
        return Icons.bed_rounded;
    }
  }

  void _selectHotel(int stayIndex, String hotelId) {
    setState(() {
      if (_selectedByStay[stayIndex] == hotelId) {
        _selectedByStay.remove(stayIndex);
      } else {
        _selectedByStay[stayIndex] = hotelId;
      }
    });
  }

  String _dayLabel(StayGroup stay) {
    if (stay.dayNumbers.length == 1) {
      return 'Day ${stay.firstDay}';
    }
    return 'Days ${stay.firstDay}\u2013${stay.lastDay}';
  }

  String _nightsLabel(StayGroup stay) {
    final n = stay.dayNumbers.length;
    return n == 1 ? '1 day' : '$n days';
  }

  String _placesLabel(StayGroup stay) {
    final names = stay.places.map((p) => p.name).toList();
    if (names.isEmpty) return 'Around your trip area';
    final shown = names.take(3).join(', ');
    final extra = names.length - 3;
    return extra > 0 ? '$shown +$extra more' : shown;
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.fixed,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? selectedHotel;
    for (var i = 0; i < _stays.length && selectedHotel == null; i++) {
      final id = _selectedByStay[i];
      if (id == null) continue;
      for (final hotel in _stays[i].hotels) {
        if (PlaceMap.id(hotel) == id) {
          selectedHotel = hotel;
          break;
        }
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        titleSpacing: 20,
        title: const Text(
          'Hotels',
          style: TextStyle(
            color: Color(0xFF102A43),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: const [DashboardNavigationButton()],
      ),
      body: _loading
          ? _buildLoading()
          : _hotels.isEmpty
          ? _buildEmptyState()
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 140),
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 14),
                      if (_hotelLoadWarning != null) ...[
                        _buildHotelSearchWarning(_hotelLoadWarning!),
                        const SizedBox(height: 14),
                      ],
                      _buildDaySelector(),
                      const SizedBox(height: 14),
                      _buildSplitToggle(),
                      const SizedBox(height: 18),
                      for (var i = 0; i < _stays.length; i++) ...[
                        if (_stays[i].stay.dayNumbers.contains(_selectedDay)) ...[
                        _buildStayHeader(_stays[i]),
                        if (_stays[i].hotels.isEmpty)
                          _buildNoHotelsForStay()
                        else
                          ..._stays[i].hotels.map(
                            (hotel) => _buildHotelCard(hotel, i),
                          ),
                        const SizedBox(height: 6),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _loading || _hotels.isEmpty
          ? null
          : _buildBottomBar(selectedHotel),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 70,
            width: 70,
            decoration: BoxDecoration(
              color: const Color(0xFFDFF4FF),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.hotel_rounded,
              size: 34,
              color: Color(0xFF1677FF),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Finding nearby stays...',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF102A43),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Looking around your selected places',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Color(0xFF1677FF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHotelSearchWarning(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF4C78A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFE07817)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF7A4B11), height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1677FF), Color(0xFF45A9FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1677FF).withOpacity(0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.hotel_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Where will you stay?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'We grouped your days by area and found stays close to each day\'s places.',
                  style: TextStyle(
                    color: Colors.white,
                    height: 1.4,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHotelCard(Map<String, dynamic> hotel, int stayIndex) {
    final id = hotel['id']?.toString() ?? '';

    final selected = _selectedByStay[stayIndex] == id;

    final avgKm = (hotel['avgDistanceKm'] as num?)?.toDouble();
    final maxKm = (hotel['maxDistanceKm'] as num?)?.toDouble();
    final perNight = PlaceMap.estimatedHotelPerNight(hotel);
    final recommended =
        _stays[stayIndex].hotels.isNotEmpty &&
        PlaceMap.id(_stays[stayIndex].hotels.first) == id &&
        hotel['recommendationScore'] != null;

    final name = _getName(hotel);
    final address = _getAddress(hotel);
    final rating = _getRating(hotel);
    final reviewCount = _getReviewCount(hotel);
    final nearPlace = _getNearPlace(hotel);
    final price = _getPrice(hotel);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected ? const Color(0xFF1677FF) : const Color(0xFFE6EDF3),
          width: selected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(selected ? 0.08 : 0.035),
            blurRadius: selected ? 18 : 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _selectHotel(stayIndex, id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 62,
                    width: 62,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFDFF4FF)
                          : const Color(0xFFF2F7FB),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      _getHotelIcon(hotel),
                      color: selected
                          ? const Color(0xFF1677FF)
                          : const Color(0xFF55758F),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF102A43),
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFFFB703),
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating > 0 ? rating.toStringAsFixed(1) : 'N/A',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF102A43),
                              ),
                            ),
                            if (reviewCount > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '($reviewCount)',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 34,
                    width: 34,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF1677FF)
                          : const Color(0xFFF1F5F8),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      selected
                          ? Icons.check_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: selected ? Colors.white : const Color(0xFF78909C),
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: Color(0xFF1677FF),
                    size: 19,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
              if (nearPlace.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.near_me_rounded,
                      color: Color(0xFFFF8A65),
                      size: 18,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Near $nearPlace',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF536B7A),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (avgKm != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.route_rounded,
                      color: Color(0xFF1677FF),
                      size: 18,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        maxKm == null
                            ? '${avgKm.toStringAsFixed(1)} km from your places'
                            : '${avgKm.toStringAsFixed(1)} km avg \u00B7 ${maxKm.toStringAsFixed(1)} km max from this stay\'s places',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF536B7A),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$price \u00B7 \u2248 \u20B9${perNight.round()}/night',
                      style: const TextStyle(
                        color: Color(0xFFE76F00),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (recommended && !selected) ...[
                    const Text(
                      'Best match',
                      style: TextStyle(
                        color: Color(0xFF2E9E6B),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    selected ? 'Selected' : 'Tap to select',
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFF1677FF)
                          : Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSplitToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EDF3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.swap_horiz_rounded,
            color: Color(0xFF1677FF),
            size: 22,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Different hotel each day',
                  style: TextStyle(
                    color: Color(0xFF102A43),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Off: nearby days share one hotel',
                  style: TextStyle(color: Color(0xFF78909C), fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: _separateHotels,
            activeColor: const Color(0xFF1677FF),
            onChanged: _loading
                ? null
                : (value) {
                    setState(() {
                      _separateHotels = value;
                      _loading = true;
                    });
                    _loadHotels();
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hotel options for',
          style: TextStyle(
            color: Color(0xFF102A43),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var day = 1; day <= _numberOfDays; day++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('Day $day'),
                    selected: _selectedDay == day,
                    onSelected: (selected) {
                      if (!selected) return;
                      setState(() {
                        _selectedDay = day;
                      });
                    },
                    selectedColor: const Color(0xFFDFF4FF),
                    labelStyle: TextStyle(
                      color: _selectedDay == day
                          ? const Color(0xFF1677FF)
                          : const Color(0xFF536B7A),
                      fontWeight: FontWeight.w700,
                    ),
                    side: BorderSide(
                      color: _selectedDay == day
                          ? const Color(0xFF1677FF)
                          : const Color(0xFFE1EAF2),
                    ),
                    showCheckmark: false,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStayHeader(_StayOption option) {
    final stay = option.stay;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFDFF4FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _dayLabel(stay),
              style: const TextStyle(
                color: Color(0xFF1677FF),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stay near ${_placesLabel(stay)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF102A43),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_nightsLabel(stay)} \u00B7 same hotel for these days',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoHotelsForStay() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EDF3)),
      ),
      child: Text(
        'No hotels found near this area. You can continue without one.',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      ),
    );
  }

  Widget _buildBottomBar(Map<String, dynamic>? selectedHotel) {
    final hasSelection = _selectedByStay.isNotEmpty;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  hasSelection
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded,
                  color: hasSelection
                      ? const Color(0xFF1677FF)
                      : const Color(0xFF78909C),
                  size: 19,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasSelection
                        ? '${_selectedByStay.length} of ${_stays.length} stay area(s) have a hotel'
                        : 'Hotel selection is optional',
                    style: TextStyle(
                      color: hasSelection
                          ? const Color(0xFF102A43)
                          : Colors.grey.shade700,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (selectedHotel != null) ...[
              const SizedBox(height: 5),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _getName(selectedHotel),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1677FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _saving ? null : _continue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1677FF),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFB8D6F7),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Next: Restaurants',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
            Container(
              height: 86,
              width: 86,
              decoration: BoxDecoration(
                color: const Color(0xFFDFF4FF),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.hotel_outlined,
                size: 42,
                color: Color(0xFF1677FF),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _hotelLoadError == null
                  ? 'No hotels found'
                  : 'Hotel search failed',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF102A43),
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _hotelLoadError ??
                  'We could not find nearby stays for your selected places.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.4),
            ),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _loading = true;
                });
                _loadHotels();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1677FF),
                side: const BorderSide(color: Color(0xFF1677FF)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _saving ? null : _continue,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Continue without hotels'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1677FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StayOption {
  final StayGroup stay;
  final List<Map<String, dynamic>> hotels;

  _StayOption({required this.stay, required this.hotels});
}
