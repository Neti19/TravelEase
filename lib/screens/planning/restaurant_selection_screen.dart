import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../models/hotel.dart';
import '../../models/place_map_reader.dart';
import '../../models/restaurant.dart';
import '../../services/day_planner.dart';
import '../../services/restaurant_service.dart';
import '../../services/trip_destination_service.dart';
import '../../services/trip_service.dart';
import '../../widgets/dashboard_navigation_button.dart';

class RestaurantSelectionScreen extends StatefulWidget {
  final String tripId;

  const RestaurantSelectionScreen({super.key, required this.tripId});

  @override
  State<RestaurantSelectionScreen> createState() =>
      _RestaurantSelectionScreenState();
}

class _RestaurantSelectionScreenState extends State<RestaurantSelectionScreen> {
  final RestaurantService _restaurantService = RestaurantService();

  final TripDestinationService _destinationService = TripDestinationService();

  final TripService _tripService = TripService();

  // Flattened list of every recommendation (used for the empty check).
  List<Map<String, dynamic>> _restaurants = [];

  // One slot per day + meal, each with its own nearby options.
  List<_MealSlot> _slots = [];

  // slot key ("1_lunch") -> selected restaurant id
  final Map<String, String> _selectedBySlot = {};

  bool _includeBreakfast = false;
  int _numberOfDays = 1;
  int _selectedDay = 1;

  bool _loading = true;
  bool _saving = false;
  String? _restaurantLoadError;
  String? _restaurantLoadWarning;

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  static const double _foodBudgetShare = 0.25;

  Map<String, Map<String, dynamic>> _choicesFromState() {
    final out = <String, Map<String, dynamic>>{};
    for (final slot in _slots) {
      final id = _selectedBySlot[slot.key];
      if (id == null) continue;
      for (final r in slot.options) {
        if (PlaceMap.id(r) == id) {
          out[slot.key] = r;
          break;
        }
      }
    }
    return out;
  }

  DateTime _mealTime(DateTime tripStart, int day, MealType meal) {
    final base = DateTime(
      tripStart.year,
      tripStart.month,
      tripStart.day,
    ).add(Duration(days: day - 1));
    switch (meal) {
      case MealType.breakfast:
        return DateTime(base.year, base.month, base.day, 8, 30);
      case MealType.lunch:
        return DateTime(base.year, base.month, base.day, 13, 0);
      case MealType.dinner:
        return DateTime(base.year, base.month, base.day, 19, 30);
    }
  }

  Future<void> _loadRestaurants() async {
    _restaurantLoadError = null;
    _restaurantLoadWarning = null;

    try {
      final trip = await _tripService.getTrip(widget.tripId);
      if (trip == null) throw Exception('Trip not found.');

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
      final travelers = trip.travelersCount < 1 ? 1 : trip.travelersCount;
      final destinationLatitude = (tripData['destinationLatitude'] as num?)
          ?.toDouble();
      final destinationLongitude = (tripData['destinationLongitude'] as num?)
          ?.toDouble();
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

      final hotelPlans = HotelPlan.fromTrip(tripData, numberOfDays: days);

      // "Food" in the saved preferences => show a few more options.
      final prefs = tripData['preferences'];
      final foodLover =
          prefs is List &&
          prefs.any((p) => p.toString().toLowerCase().contains('food'));
      final limit = foodLover ? 8 : 5;

      final budgetPerMeal = trip.budget > 0
          ? trip.budget * _foodBudgetShare / (days * 2.5 * travelers)
          : 0.0;

      // ---- decide WHERE the traveller is at each meal ----
      final planned = <_MealSlot>[];

      for (final cluster in clusters) {
        if (cluster.places.isEmpty) continue;
        final dayPlaces = cluster.places;
        final hotel = HotelPlan.forDay(hotelPlans, cluster.dayNumber)?.hotel;
        final hotelLat = hotel == null ? null : PlaceMap.latitude(hotel);
        final hotelLng = hotel == null ? null : PlaceMap.longitude(hotel);

        if (_includeBreakfast) {
          // Breakfast: near the hotel, else near the first stop.
          final fallback = dayPlaces.first;
          planned.add(
            _MealSlot(
              day: cluster.dayNumber,
              meal: MealType.breakfast,
              nearName: hotel != null ? PlaceMap.name(hotel) : fallback.name,
              latitude: hotelLat ?? fallback.latitude,
              longitude: hotelLng ?? fallback.longitude,
              time: _mealTime(
                trip.startDate,
                cluster.dayNumber,
                MealType.breakfast,
              ),
            ),
          );
        }

        // Lunch: near the stop reached around the middle of the day.
        final lunchIndex = (((dayPlaces.length + 1) ~/ 2) - 1).clamp(
          0,
          dayPlaces.length - 1,
        );
        final lunchPlace = dayPlaces[lunchIndex];
        planned.add(
          _MealSlot(
            day: cluster.dayNumber,
            meal: MealType.lunch,
            nearName: lunchPlace.name,
            latitude: lunchPlace.latitude,
            longitude: lunchPlace.longitude,
            time: _mealTime(trip.startDate, cluster.dayNumber, MealType.lunch),
          ),
        );

        // Dinner: near the last stop of the day.
        final dinnerPlace = dayPlaces.last;
        planned.add(
          _MealSlot(
            day: cluster.dayNumber,
            meal: MealType.dinner,
            nearName: dinnerPlace.name,
            latitude: dinnerPlace.latitude,
            longitude: dinnerPlace.longitude,
            time: _mealTime(trip.startDate, cluster.dayNumber, MealType.dinner),
          ),
        );
      }

      // ---- fetch options for all slots (in parallel) ----
      var failed = 0;
      Object? firstSearchError;

      await Future.wait(
        planned.map((slot) async {
          try {
            slot.options = await _restaurantService.recommendRestaurantsForMeal(
              latitude: slot.latitude,
              longitude: slot.longitude,
              meal: slot.meal,
              mealTime: slot.time,
              nearPlaceName: slot.nearName,
              maxBudgetPerMealPerPerson: budgetPerMeal,
              limit: limit,
            );
          } catch (e) {
            failed++;
            firstSearchError ??= e;
          }
        }),
      );

      if (planned.isNotEmpty && failed == planned.length) {
        throw Exception('Restaurant search failed: $firstSearchError');
      }

      // ---- restore / pre-select ----
      final carry = _slots.isEmpty ? null : _choicesFromState();
      final saved = RestaurantPlan.fromTrip(tripData);
      final firstVisit = tripData['restaurantSelected'] == null;
      final selection = <String, String>{};
      final used = <String>{};

      for (final slot in planned) {
        Map<String, dynamic>? preferred = carry?[slot.key];

        if (preferred == null && carry == null) {
          final plan = RestaurantPlan.find(saved, slot.day, slot.meal);
          preferred = plan?.restaurant;
        }

        if (preferred != null && PlaceMap.id(preferred).isNotEmpty) {
          final id = PlaceMap.id(preferred);
          if (!slot.options.any((r) => PlaceMap.id(r) == id)) {
            slot.options.insert(0, preferred);
          }
          selection[slot.key] = id;
          used.add(id);
        } else if (firstVisit && carry == null) {
          for (final r in slot.options) {
            final id = PlaceMap.id(r);
            if (!used.contains(id)) {
              selection[slot.key] = id;
              used.add(id);
              break;
            }
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _numberOfDays = days;
        _selectedDay = _selectedDay.clamp(1, days);
        _slots = planned;
        _restaurants = [for (final slot in planned) ...slot.options];
        _selectedBySlot
          ..clear()
          ..addAll(selection);
        _restaurantLoadWarning = failed > 0
            ? 'Some meals could not load restaurant options: '
                  '$firstSearchError'
            : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _restaurantLoadError = e.toString();
      });

      _showMessage('Could not load restaurants: $e');
    }
  }

  Future<void> _continue() async {
    if (_saving) return;

    setState(() {
      _saving = true;
    });

    try {
      final plans = <RestaurantPlan>[];
      Map<String, dynamic>? legacy;

      for (final slot in _slots) {
        final id = _selectedBySlot[slot.key];
        if (id == null) continue;

        Map<String, dynamic>? restaurant;
        for (final candidate in slot.options) {
          if (PlaceMap.id(candidate) == id) {
            restaurant = candidate;
            break;
          }
        }
        if (restaurant == null) continue;

        plans.add(
          RestaurantPlan(
            dayNumber: slot.day,
            mealType: slot.meal,
            restaurant: restaurant,
          ),
        );

        if (legacy == null || slot.meal == MealType.lunch) {
          legacy ??= restaurant;
        }
      }

      final data = <String, dynamic>{
        'restaurantSelected': plans.isNotEmpty,
        'restaurantPlans': plans.map((p) => p.toJson()).toList(),
        // Legacy field kept in sync so older screens keep working.
        'selectedRestaurant': legacy ?? FieldValue.delete(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await _tripService.updateTrip(widget.tripId, data);

      if (!mounted) return;

      Navigator.pushNamed(
        context,
        AppRoutes.transportSelection,
        arguments: {'tripId': widget.tripId},
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage('Could not save restaurant selection: $e');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String _getName(Map<String, dynamic> restaurant) {
    final displayName = restaurant['displayName'] as Map<String, dynamic>?;

    return displayName?['text']?.toString() ??
        restaurant['name']?.toString() ??
        'Restaurant';
  }

  String _getPrice(Map<String, dynamic> restaurant) {
    switch (restaurant['priceLevel']?.toString()) {
      case 'PRICE_LEVEL_FREE':
        return 'Free';

      case 'PRICE_LEVEL_INEXPENSIVE':
        return '₹ Budget';

      case 'PRICE_LEVEL_MODERATE':
        return '₹₹ Moderate';

      case 'PRICE_LEVEL_EXPENSIVE':
        return '₹₹₹ Premium';

      case 'PRICE_LEVEL_VERY_EXPENSIVE':
        return '₹₹₹₹ Fine Dining';

      default:
        return 'Price unavailable';
    }
  }

  String _getAddress(Map<String, dynamic> restaurant) {
    return restaurant['formattedAddress']?.toString() ??
        restaurant['address']?.toString() ??
        'Address unavailable';
  }

  double _getRating(Map<String, dynamic> restaurant) {
    return (restaurant['rating'] as num?)?.toDouble() ?? 0;
  }

  int _getReviewCount(Map<String, dynamic> restaurant) {
    return (restaurant['userRatingCount'] as num?)?.toInt() ?? 0;
  }

  String _getNearPlace(Map<String, dynamic> restaurant) {
    return restaurant['nearPlace']?.toString() ?? '';
  }

  IconData _getRestaurantIcon(Map<String, dynamic> restaurant) {
    final price = restaurant['priceLevel']?.toString();

    switch (price) {
      case 'PRICE_LEVEL_VERY_EXPENSIVE':
        return Icons.auto_awesome_rounded;

      case 'PRICE_LEVEL_EXPENSIVE':
        return Icons.restaurant_rounded;

      default:
        return Icons.restaurant_menu_rounded;
    }
  }

  void _selectRestaurant(String slotKey, String restaurantId) {
    setState(() {
      if (_selectedBySlot[slotKey] == restaurantId) {
        _selectedBySlot.remove(slotKey);
      } else {
        _selectedBySlot[slotKey] = restaurantId;
      }
    });
  }

  Future<void> _searchManually(_MealSlot slot) async {
    final controller = TextEditingController();
    var results = <Map<String, dynamic>>[];
    var searching = false;
    String? error;

    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            Future<void> run() async {
              final query = controller.text.trim();
              if (query.isEmpty) return;
              setSheet(() {
                searching = true;
                error = null;
              });
              try {
                final found = await _restaurantService.searchRestaurantsByText(
                  query: query,
                  latitude: slot.latitude,
                  longitude: slot.longitude,
                  nearPlaceName: slot.nearName,
                );
                setSheet(() {
                  results = found;
                  searching = false;
                });
              } catch (e) {
                setSheet(() {
                  error = 'Search failed: $e';
                  searching = false;
                });
              }
            }

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Find a ${slot.meal.label.toLowerCase()} spot near ${slot.nearName}',
                    style: const TextStyle(
                      color: Color(0xFF102A43),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => run(),
                    decoration: InputDecoration(
                      hintText: 'Restaurant or cuisine name',
                      filled: true,
                      fillColor: const Color(0xFFF2F7FB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search_rounded),
                        onPressed: run,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (searching)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF8A65),
                        ),
                      ),
                    ),
                  if (error != null)
                    Text(
                      error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  for (final r in results)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.restaurant_menu_rounded,
                        color: Color(0xFFFF8A65),
                      ),
                      title: Text(
                        _getName(r),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        _getAddress(r),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.pop(sheetContext, r),
                    ),
                ],
              ),
            );
          },
        );
      },
    );

    controller.dispose();

    if (picked == null || !mounted) return;

    final id = PlaceMap.id(picked);
    if (id.isEmpty) return;

    setState(() {
      slot.options.removeWhere((r) => PlaceMap.id(r) == id);
      slot.options.insert(0, picked);
      _restaurants = [for (final s in _slots) ...s.options];
      _selectedBySlot[slot.key] = id;
    });
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
  Widget build(BuildContext context) {
    final selectedDaySlots = _slots
        .where((slot) => slot.day == _selectedDay)
        .toList();

    Map<String, dynamic>? selectedRestaurant;
    for (final slot in _slots) {
      final id = _selectedBySlot[slot.key];
      if (id == null) continue;
      for (final r in slot.options) {
        if (PlaceMap.id(r) == id) {
          selectedRestaurant = r;
          break;
        }
      }
      if (selectedRestaurant != null) break;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        titleSpacing: 20,
        title: const Text(
          'Restaurants',
          style: TextStyle(
            color: Color(0xFF102A43),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: const [DashboardNavigationButton()],
      ),
      body: _loading
          ? _buildLoading()
          : _restaurants.isEmpty
          ? _buildEmptyState()
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 140),
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 14),
                      if (_restaurantLoadWarning != null) ...[
                        _buildRestaurantSearchWarning(_restaurantLoadWarning!),
                        const SizedBox(height: 14),
                      ],
                      _buildDaySelector(),
                      const SizedBox(height: 14),
                      _buildBreakfastToggle(),
                      const SizedBox(height: 18),
                      if (selectedDaySlots.isEmpty)
                        _buildNoMealsForDay()
                      else
                        for (final slot in selectedDaySlots) ...[
                          _buildSlotHeader(slot),
                          if (slot.options.isEmpty)
                            _buildNoOptions()
                          else
                            ...slot.options.map(
                              (r) => _buildRestaurantCard(r, slot),
                            ),
                          const SizedBox(height: 6),
                        ],
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _loading || _restaurants.isEmpty
          ? null
          : _buildBottomBar(selectedRestaurant),
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
              color: const Color(0xFFFFEDE6),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.restaurant_rounded,
              size: 34,
              color: Color(0xFFFF8A65),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Finding places to eat...',
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
              color: Color(0xFFFF8A65),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantSearchWarning(String message) {
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
          colors: [Color(0xFFFF8A65), Color(0xFFFFB085)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8A65).withOpacity(0.18),
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
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.restaurant_rounded,
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
                  'Where will you eat?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Discover restaurants close to the places you want to visit.',
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

  Widget _buildRestaurantCard(Map<String, dynamic> restaurant, _MealSlot slot) {
    final id = restaurant['id']?.toString() ?? '';

    final selected = _selectedBySlot[slot.key] == id;

    final distanceKm = (restaurant['distanceKm'] as num?)?.toDouble();
    final perPerson = PlaceMap.estimatedMealPerPerson(restaurant);
    final openState = restaurant['openAtMealTime'];

    final name = _getName(restaurant);
    final address = _getAddress(restaurant);
    final rating = _getRating(restaurant);
    final reviewCount = _getReviewCount(restaurant);
    final nearPlace = _getNearPlace(restaurant);
    final price = _getPrice(restaurant);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected ? const Color(0xFFFF8A65) : const Color(0xFFE6EDF3),
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
        onTap: () => _selectRestaurant(slot.key, id),
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
                          ? const Color(0xFFFFEDE6)
                          : const Color(0xFFFFF6F1),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      _getRestaurantIcon(restaurant),
                      color: selected
                          ? const Color(0xFFFF8A65)
                          : const Color(0xFFE97855),
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
                          ? const Color(0xFFFF8A65)
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
                    color: Color(0xFFFF8A65),
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
                      color: Color(0xFF1677FF),
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
              if (distanceKm != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.directions_walk_rounded,
                      color: Color(0xFFFF8A65),
                      size: 18,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        '${distanceKm.toStringAsFixed(1)} km from ${slot.nearName}'
                        '${openState == true ? ' \u00B7 Open at ${slot.meal.label.toLowerCase()} time' : ''}',
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
                      '$price \u00B7 \u2248 \u20B9${perPerson.round()}/person',
                      style: const TextStyle(
                        color: Color(0xFFE76F00),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    selected ? 'Selected' : 'Tap to select',
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFFFF8A65)
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

  Widget _buildBreakfastToggle() {
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
            Icons.free_breakfast_rounded,
            color: Color(0xFFFF8A65),
            size: 22,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plan breakfast too',
                  style: TextStyle(
                    color: Color(0xFF102A43),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Lunch and dinner are suggested by default',
                  style: TextStyle(color: Color(0xFF78909C), fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: _includeBreakfast,
            activeColor: const Color(0xFFFF8A65),
            onChanged: _loading
                ? null
                : (value) {
                    setState(() {
                      _includeBreakfast = value;
                      _loading = true;
                    });
                    _loadRestaurants();
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
          'Restaurant options for',
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
                    selectedColor: const Color(0xFFFFEDE6),
                    labelStyle: TextStyle(
                      color: _selectedDay == day
                          ? const Color(0xFFE76F00)
                          : const Color(0xFF536B7A),
                      fontWeight: FontWeight.w700,
                    ),
                    side: BorderSide(
                      color: _selectedDay == day
                          ? const Color(0xFFFF8A65)
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

  Widget _buildNoMealsForDay() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EDF3)),
      ),
      child: Text(
        'No meal stops were planned for Day $_selectedDay.',
        style: const TextStyle(color: Color(0xFF536B7A)),
      ),
    );
  }

  Widget _buildSlotHeader(_MealSlot slot) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEDE6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              slot.meal.label,
              style: const TextStyle(
                color: Color(0xFFE76F00),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Near ${slot.nearName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF536B7A),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => _searchManually(slot),
            icon: const Icon(Icons.search_rounded, size: 18),
            label: const Text('Search'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF8A65),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoOptions() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EDF3)),
      ),
      child: Text(
        'No open restaurants found nearby. Use Search or skip this meal.',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      ),
    );
  }

  Widget _buildBottomBar(Map<String, dynamic>? selectedRestaurant) {
    final hasSelection = _selectedBySlot.isNotEmpty;

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
                      ? const Color(0xFFFF8A65)
                      : const Color(0xFF78909C),
                  size: 19,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasSelection
                        ? '${_selectedBySlot.length} meal(s) planned across ${_slots.map((s) => s.day).toSet().length} day(s)'
                        : 'Restaurant selection is optional',
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
            if (selectedRestaurant != null) ...[
              const SizedBox(height: 5),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _getName(selectedRestaurant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFF8A65),
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
                  backgroundColor: const Color(0xFFFF8A65),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFFFC5B2),
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
                            'Continue to Transport',
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
                      color: const Color(0xFFFFEDE6),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(
                      Icons.restaurant_outlined,
                      size: 42,
                      color: Color(0xFFFF8A65),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _restaurantLoadError == null
                        ? 'No restaurants found'
                        : 'Restaurant search failed',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF102A43),
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _restaurantLoadError ??
                        'We could not find nearby restaurants for your selected places.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, height: 1.4),
                  ),
                  const SizedBox(height: 22),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _loading = true;
                      });
                      _loadRestaurants();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try Again'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF8A65),
                      side: const BorderSide(color: Color(0xFFFF8A65)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _continue,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Continue without restaurants'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8A65),
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

class _MealSlot {
  final int day;
  final MealType meal;
  final String nearName;
  final double latitude;
  final double longitude;
  final DateTime time;
  List<Map<String, dynamic>> options;

  _MealSlot({
    required this.day,
    required this.meal,
    required this.nearName,
    required this.latitude,
    required this.longitude,
    required this.time,
    List<Map<String, dynamic>>? options,
  }) : options = options ?? <Map<String, dynamic>>[];

  String get key => '${day}_${meal.name}';
}
