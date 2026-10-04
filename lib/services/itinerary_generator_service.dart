import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/hotel.dart';
import '../models/itinerary.dart';
import '../models/place_map_reader.dart';
import '../models/restaurant.dart';
import '../services/day_planner.dart';
import '../services/route_service.dart';

class ItineraryGeneratorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final RouteService _routeService = RouteService();

  final Map<String, int> _travelMinutesCache = {};

  Future<FullItinerary> generateForTrip(String tripId) async {
    final tripRef = _firestore.collection('trips').doc(tripId);

    final tripSnapshot = await tripRef.get();

    if (!tripSnapshot.exists) {
      throw Exception('Trip not found.');
    }

    final tripData = tripSnapshot.data()!;

    final startDate = _readDate(tripData['startDate']);

    final numberOfDays = (tripData['numberOfDays'] as num?)?.toInt() ?? 1;

    final travelers = (tripData['travelersCount'] as num?)?.toInt() ?? 1;

    if (numberOfDays <= 0) {
      throw Exception('Invalid number of trip days.');
    }

    final tripStartLatitude = (tripData['startLatitude'] as num?)?.toDouble();

    final tripStartLongitude = (tripData['startLongitude'] as num?)?.toDouble();

    if (tripStartLatitude == null || tripStartLongitude == null) {
      throw Exception('Starting location coordinates are missing.');
    }

    final destinationLatitude = (tripData['destinationLatitude'] as num?)
        ?.toDouble();
    final destinationLongitude = (tripData['destinationLongitude'] as num?)
        ?.toDouble();
    final itineraryStartLatitude = destinationLatitude ?? tripStartLatitude;
    final itineraryStartLongitude = destinationLongitude ?? tripStartLongitude;
    final itineraryStartName =
        destinationLatitude != null && destinationLongitude != null
        ? tripData['destination']?.toString() ?? 'Trip destination'
        : tripData['startLocation']?.toString() ?? 'Starting Location';

    /*
     * ----------------------------------------------------------
     * SELECTED TOURIST PLACES
     * ----------------------------------------------------------
     */

    final selectedPlacesRaw = await _readSelectedPlaces(tripId);

    final places = <PlannerPlace>[];

    for (final map in selectedPlacesRaw) {
      final place = PlannerPlace.fromMap(map);
      if (place != null) {
        places.add(place);
      }
    }

    if (places.isEmpty) {
      throw Exception('No tourist places selected.');
    }

    /*
     * ----------------------------------------------------------
     * CREATE THE SAME DAY CLUSTERS USED BY THE
     * HOTEL AND RESTAURANT SELECTION SCREENS.
     * ----------------------------------------------------------
     */

    final clusters = DayPlanner.clusterIntoDays(
      places: places,
      numberOfDays: numberOfDays,
      startLatitude: itineraryStartLatitude,
      startLongitude: itineraryStartLongitude,
    );

    /*
     * ----------------------------------------------------------
     * SELECTED HOTEL PLANS
     *
     * hotelPlans:
     * [{dayNumber, hotel: {...}}]
     *
     * Older trips using selectedHotel are also supported by
     * HotelPlan.fromTrip().
     * ----------------------------------------------------------
     */

    final hotelPlans = HotelPlan.fromTrip(tripData, numberOfDays: numberOfDays);

    /*
     * ----------------------------------------------------------
     * SELECTED RESTAURANT PLANS
     *
     * restaurantPlans:
     * [{dayNumber, mealType, restaurant: {...}}]
     *
     * Older trips using selectedRestaurant become Day 1 lunch.
     * ----------------------------------------------------------
     */

    final restaurantPlans = RestaurantPlan.fromTrip(tripData);

    final days = <DayItinerary>[];

    RoutePoint previousDayEnd = RoutePoint(
      id: destinationLatitude != null && destinationLongitude != null
          ? 'destination'
          : 'start',
      name: itineraryStartName,
      latitude: itineraryStartLatitude,
      longitude: itineraryStartLongitude,
      type: 'start',
    );
    final itineraryOrigin = previousDayEnd;

    Map<String, dynamic>? previousHotel;

    for (int dayNumber = 1; dayNumber <= numberOfDays; dayNumber++) {
      final date = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      ).add(Duration(days: dayNumber - 1));

      final cluster = clusters.firstWhere(
        (item) => item.dayNumber == dayNumber,
        orElse: () => DayCluster(
          dayNumber: dayNumber,
          places: const [],
          centerLatitude: itineraryStartLatitude,
          centerLongitude: itineraryStartLongitude,
        ),
      );

      final dayPlaces = List<PlannerPlace>.from(cluster.places);

      final hotelPlan = HotelPlan.forDay(hotelPlans, dayNumber);

      final currentHotel = hotelPlan?.hotel;

      final nextHotel = dayNumber < numberOfDays
          ? HotelPlan.forDay(hotelPlans, dayNumber + 1)?.hotel
          : null;

      final currentHotelKey = _placeKey(currentHotel);

      final previousHotelKey = _placeKey(previousHotel);

      final nextHotelKey = _placeKey(nextHotel);

      final hotelChangesToday =
          currentHotel != null && currentHotelKey != previousHotelKey;

      /*
       * A checkout is needed when the traveller leaves this hotel
       * after today, or when today is the final trip day.
       */
      final checkoutToday =
          currentHotel != null &&
          (dayNumber == numberOfDays || nextHotelKey != currentHotelKey);

      final restaurantPlansToday =
          restaurantPlans.where((plan) => plan.dayNumber == dayNumber).toList()
            ..sort(
              (a, b) => _mealStart(
                date,
                a.mealType,
              ).compareTo(_mealStart(date, b.mealType)),
            );

      final activities = <ItineraryActivity>[];

      var sequence = 1;

      var currentPoint = previousDayEnd;

      /*
       * Start the day early, but do not force a fixed lunch or
       * dinner clock time. The planner uses practical meal windows
       * and places the selected restaurant at the most natural point
       * in the route.
       */
      DateTime currentTime = DateTime(date.year, date.month, date.day, 7, 30);

      /*
       * --------------------------------------------------------
       * BREAKFAST
       * --------------------------------------------------------
       */

      final breakfastPlan = _findRestaurantPlan(
        restaurantPlansToday,
        MealType.breakfast,
      );

      if (breakfastPlan != null) {
        final breakfastPoint = _restaurantPoint(
          breakfastPlan.restaurant,
          fallbackId: 'breakfast_$dayNumber',
        );

        if (breakfastPoint != null) {
          final mealStart = DateTime(date.year, date.month, date.day, 8, 30);

          final mealEnd = mealStart.add(const Duration(minutes: 45));

          currentTime = await _travelAndAddAnchor(
            activities: activities,
            sequence: sequence,
            tripId: tripId,
            from: currentPoint,
            to: breakfastPoint,
            currentTime: currentTime,
            targetStart: mealStart,
            anchorEnd: mealEnd,
            anchorTitle:
                'Breakfast: ${PlaceMap.name(breakfastPlan.restaurant)}',
            anchorDescription: _mealDescription(
              breakfastPlan.restaurant,
              'Breakfast',
            ),
            anchorType: ActivityType.restaurant,
            mealType: 'breakfast',
            cost:
                PlaceMap.estimatedMealPerPerson(breakfastPlan.restaurant) *
                travelers,
          );

          sequence = activities.length + 1;

          currentPoint = breakfastPoint;
        }
      }

      /*
       * --------------------------------------------------------
       * MORNING SIGHTSEEING
       *
       * We reserve time required to reach the next fixed event:
       * checkout or lunch.
       * --------------------------------------------------------
       */

      if (dayPlaces.isNotEmpty) {
        final lunchExists =
            _findRestaurantPlan(restaurantPlansToday, MealType.lunch) != null;

        final morningDeadline = checkoutToday
            ? DateTime(date.year, date.month, date.day, 10, 45)
            : lunchExists
            ? DateTime(date.year, date.month, date.day, 15, 0)
            : DateTime(date.year, date.month, date.day, 14, 0);

        await _addPlacesUntil(
          places: dayPlaces,
          dayNumber: dayNumber,
          tripId: tripId,
          activities: activities,
          sequenceStart: sequence,
          currentPoint: currentPoint,
          currentTime: currentTime,
          deadline: morningDeadline,
          reservedEndTravelPoint: checkoutToday
              ? _hotelPoint(
                  currentHotel,
                  fallbackId: 'hotel_checkout_$dayNumber',
                )
              : _restaurantPoint(
                  _findRestaurantPlan(
                    restaurantPlansToday,
                    MealType.lunch,
                  )?.restaurant,
                  fallbackId: 'lunch_$dayNumber',
                ),
        ).then((result) {
          currentPoint = result.point;
          currentTime = result.time;
          sequence = result.sequence;
        });
      }

      /*
       * --------------------------------------------------------
       * HOTEL CHECK-OUT
       * --------------------------------------------------------
       *
       * Default planner time: 11:00 AM.
       * The current app data model does not store hotel-specific
       * checkout hours, so this is a planner default.
       * --------------------------------------------------------
       */

      if (checkoutToday) {
        final hotelPoint = _hotelPoint(
          currentHotel,
          fallbackId: 'hotel_checkout_$dayNumber',
        );

        if (hotelPoint != null) {
          final checkoutStart = DateTime(
            date.year,
            date.month,
            date.day,
            11,
            0,
          );

          final checkoutEnd = checkoutStart.add(const Duration(minutes: 15));

          currentTime = await _travelAndAddAnchor(
            activities: activities,
            sequence: sequence,
            tripId: tripId,
            from: currentPoint,
            to: hotelPoint,
            currentTime: currentTime,
            targetStart: checkoutStart,
            anchorEnd: checkoutEnd,
            anchorTitle: 'Hotel Check-out: ${PlaceMap.name(currentHotel)}',
            anchorDescription: 'Check-out from your selected hotel.',
            anchorType: ActivityType.hotel,
            mealType: null,
            cost: 0,
          );

          sequence = activities.length + 1;

          currentPoint = hotelPoint;
        }
      }

      /*
       * --------------------------------------------------------
       * LUNCH
       * --------------------------------------------------------
       * The selected restaurant stays the same, but the time is
       * chosen dynamically: not before 12:00 and not forced to 1:00.
       * --------------------------------------------------------
       */

      final lunchPlan = _findRestaurantPlan(
        restaurantPlansToday,
        MealType.lunch,
      );

      if (lunchPlan != null) {
        final lunchPoint = _restaurantPoint(
          lunchPlan.restaurant,
          fallbackId: 'lunch_$dayNumber',
        );

        if (lunchPoint != null) {
          final mealStart = DateTime(date.year, date.month, date.day, 12, 0);

          final mealEnd = mealStart.add(const Duration(minutes: 60));

          currentTime = await _travelAndAddAnchor(
            activities: activities,
            sequence: sequence,
            tripId: tripId,
            from: currentPoint,
            to: lunchPoint,
            currentTime: currentTime,
            targetStart: mealStart,
            anchorEnd: mealEnd,
            anchorTitle: 'Lunch: ${PlaceMap.name(lunchPlan.restaurant)}',
            anchorDescription: _mealDescription(lunchPlan.restaurant, 'Lunch'),
            anchorType: ActivityType.restaurant,
            mealType: 'lunch',
            cost:
                PlaceMap.estimatedMealPerPerson(lunchPlan.restaurant) *
                travelers,
          );

          sequence = activities.length + 1;

          currentPoint = lunchPoint;
        }
      }

      /*
       * --------------------------------------------------------
       * HOTEL CHECK-IN
       * --------------------------------------------------------
       *
       * Default planner time: 2:30 PM.
       *
       * If travel from lunch takes longer, check-in is moved to
       * the earliest practical time after the lunch transfer.
       * --------------------------------------------------------
       */

      if (hotelChangesToday) {
        final hotelPoint = _hotelPoint(
          currentHotel,
          fallbackId: 'hotel_checkin_$dayNumber',
        );

        if (hotelPoint != null) {
          final minimumCheckIn = DateTime(
            date.year,
            date.month,
            date.day,
            14,
            30,
          );

          final checkInEnd = minimumCheckIn.add(const Duration(minutes: 30));

          currentTime = await _travelAndAddAnchor(
            activities: activities,
            sequence: sequence,
            tripId: tripId,
            from: currentPoint,
            to: hotelPoint,
            currentTime: currentTime,
            targetStart: minimumCheckIn,
            anchorEnd: checkInEnd,
            anchorTitle: 'Hotel Check-in: ${PlaceMap.name(currentHotel)}',
            anchorDescription: 'Check-in and settle into your selected hotel.',
            anchorType: ActivityType.hotel,
            mealType: null,
            cost: PlaceMap.estimatedHotelPerNight(currentHotel),
          );

          sequence = activities.length + 1;

          currentPoint = hotelPoint;
        }
      }

      /*
       * --------------------------------------------------------
       * AFTERNOON / EVENING SIGHTSEEING
       *
       * Reserve the dinner window so a tourist visit never
       * overlaps the selected dinner.
       * --------------------------------------------------------
       */

      final dinnerPlan = _findRestaurantPlan(
        restaurantPlansToday,
        MealType.dinner,
      );

      final dinnerPoint = dinnerPlan == null
          ? null
          : _restaurantPoint(
              dinnerPlan.restaurant,
              fallbackId: 'dinner_$dayNumber',
            );

      final dinnerEarliest = DateTime(date.year, date.month, date.day, 18, 30);

      final dinnerLatest = DateTime(date.year, date.month, date.day, 21, 30);

      final afternoonDeadline = dinnerPoint != null
          ? dinnerLatest
          : DateTime(date.year, date.month, date.day, 20, 30);

      final remainingPlaces = dayPlaces
          .where((place) => !_hasPlaceActivity(activities, place.id))
          .toList();

      if (remainingPlaces.isNotEmpty) {
        final result = await _addPlacesUntil(
          places: remainingPlaces,
          dayNumber: dayNumber,
          tripId: tripId,
          activities: activities,
          sequenceStart: sequence,
          currentPoint: currentPoint,
          currentTime: currentTime,
          deadline: afternoonDeadline,
          reservedEndTravelPoint:
              dinnerPoint ??
              (checkoutToday
                  ? null
                  : _hotelPoint(
                      currentHotel,
                      fallbackId: 'hotel_return_$dayNumber',
                    )),
        );

        currentPoint = result.point;
        currentTime = result.time;
        sequence = result.sequence;
      }

      /*
       * --------------------------------------------------------
       * DINNER
       * --------------------------------------------------------
       * The selected restaurant stays the same, but the time is
       * chosen dynamically: not before 6:30 PM and not forced to 7:30 PM.
       * --------------------------------------------------------
       */

      if (dinnerPlan != null && dinnerPoint != null) {
        final mealEnd = dinnerEarliest.add(const Duration(minutes: 60));

        currentTime = await _travelAndAddAnchor(
          activities: activities,
          sequence: sequence,
          tripId: tripId,
          from: currentPoint,
          to: dinnerPoint,
          currentTime: currentTime,
          targetStart: dinnerEarliest,
          anchorEnd: mealEnd,
          anchorTitle: 'Dinner: ${PlaceMap.name(dinnerPlan.restaurant)}',
          anchorDescription: _mealDescription(dinnerPlan.restaurant, 'Dinner'),
          anchorType: ActivityType.restaurant,
          mealType: 'dinner',
          cost:
              PlaceMap.estimatedMealPerPerson(dinnerPlan.restaurant) *
              travelers,
        );

        sequence = activities.length + 1;

        currentPoint = dinnerPoint;
      }

      /*
       * --------------------------------------------------------
       * RETURN TO HOTEL
       *
       * If the traveller is staying at a hotel after today,
       * finish the day by returning there after dinner.
       * Do not add a return trip after final-day checkout.
       * --------------------------------------------------------
       */

      if (currentHotel != null && !checkoutToday) {
        final hotelPoint = _hotelPoint(
          currentHotel,
          fallbackId: 'hotel_return_$dayNumber',
        );

        if (hotelPoint != null) {
          final returnStart = currentTime.add(const Duration(minutes: 10));

          final travelMinutes = await _travelMinutes(currentPoint, hotelPoint);

          if (travelMinutes > 0) {
            final returnEnd = returnStart.add(Duration(minutes: travelMinutes));

            activities.add(
              _createTransportActivity(
                tripId: tripId,
                from: currentPoint,
                to: hotelPoint,
                startTime: returnStart,
                endTime: returnEnd,
                sequence: sequence++,
                description:
                    'Return to ${PlaceMap.name(currentHotel)} for the night.',
              ),
            );

            currentTime = returnEnd;
            currentPoint = hotelPoint;
          }
        }
      }

      /*
       * --------------------------------------------------------
       * IF THE FINAL HOTEL IS ALSO THE LAST DAY, checkout is
       * already scheduled at 11 AM, so the day does not finish
       * with a hotel return.
       * --------------------------------------------------------
       */

      activities.sort((a, b) => a.startTime.compareTo(b.startTime));

      for (var i = 0; i < activities.length; i++) {
        final old = activities[i];

        activities[i] = old.copyWith(dayNumber: dayNumber, sequence: i + 1);
      }

      days.add(
        DayItinerary(dayNumber: dayNumber, date: date, activities: activities),
      );

      previousDayEnd = currentPoint;

      previousHotel = currentHotel;
    }

    /*
     * ----------------------------------------------------------
     * VALIDATION
     * ----------------------------------------------------------
     */

    final scheduledPlaceIds = <String>{};

    for (final day in days) {
      for (final activity in day.activities) {
        if (activity.type == ActivityType.spot &&
            activity.placeId != null &&
            activity.placeId!.isNotEmpty) {
          scheduledPlaceIds.add(activity.placeId!);
        }
      }
    }

    final missingPlaces = places
        .where((place) => !scheduledPlaceIds.contains(place.id))
        .toList();

    final placesStillUnscheduled = await _scheduleMissingPlaces(
      places: missingPlaces,
      days: days,
      origin: itineraryOrigin,
      tripId: tripId,
    );

    for (final day in days) {
      day.activities.sort((a, b) => a.startTime.compareTo(b.startTime));
      for (var index = 0; index < day.activities.length; index++) {
        day.activities[index] = day.activities[index].copyWith(
          dayNumber: day.dayNumber,
          sequence: index + 1,
        );
      }
    }

    /*
     * Use otherwise-open days for any selected sightseeing stops that
     * could not fit around fixed meals or hotel events in their first
     * assigned day.
     */
    if (placesStillUnscheduled.isNotEmpty) {
      final names = placesStillUnscheduled.map((place) => place.name);

      throw Exception(
        'Not enough practical time to schedule all selected tourist places. '
        'These places could not fit: ${names.join(', ')}',
      );
    }

    final itinerary = FullItinerary(
      id: 'itinerary_$tripId',
      tripId: tripId,
      days: days,
    );

    await tripRef.set({
      'itinerary': itinerary.toJson(),
      'itineraryGenerated': true,
      'itineraryGeneratedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return itinerary;
  }

  Future<List<PlannerPlace>> _scheduleMissingPlaces({
    required List<PlannerPlace> places,
    required List<DayItinerary> days,
    required RoutePoint origin,
    required String tripId,
  }) async {
    final remaining = <PlannerPlace>[];

    for (final place in places) {
      final destination = RoutePoint(
        id: place.id,
        name: place.name,
        latitude: place.latitude,
        longitude: place.longitude,
        type: 'tourist_spot',
      );
      var scheduled = false;

      for (final day in days) {
        final events = List<ItineraryActivity>.from(day.activities)
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
        var cursor = DateTime(day.date.year, day.date.month, day.date.day, 8);
        var previousPoint = origin;
        if (day.dayNumber > 1) {
          final previousDay = days.firstWhere(
            (candidate) => candidate.dayNumber == day.dayNumber - 1,
          );
          for (final activity in previousDay.activities.reversed) {
            final point = _activityPoint(activity);
            if (point != null) {
              previousPoint = point;
              break;
            }
          }
        }

        for (final event in events) {
          if (!event.endTime.isAfter(cursor)) {
            previousPoint = _activityPoint(event) ?? previousPoint;
            continue;
          }

          final nextPoint = _activityPoint(event);
          final travelToPlace = await _travelMinutes(
            previousPoint,
            destination,
          );
          final visitStart = cursor.add(Duration(minutes: travelToPlace));
          final visitEnd = visitStart.add(_visitDuration(place.category));
          final travelToNext = nextPoint == null
              ? 0
              : await _travelMinutes(destination, nextPoint);
          final arrivalAtNext = visitEnd.add(Duration(minutes: travelToNext));

          if (!arrivalAtNext.isAfter(event.startTime)) {
            _insertRecoveredPlace(
              day: day,
              tripId: tripId,
              from: previousPoint,
              place: place,
              visitStart: visitStart,
              visitEnd: visitEnd,
              travelMinutes: travelToPlace,
              returnTo: nextPoint,
              returnTravelMinutes: travelToNext,
            );
            scheduled = true;
            break;
          }

          if (event.endTime.isAfter(cursor)) {
            cursor = event.endTime;
            previousPoint = nextPoint ?? previousPoint;
          }
        }

        if (scheduled) break;

        final deadline = DateTime(
          day.date.year,
          day.date.month,
          day.date.day,
          21,
          30,
        );
        final travelMinutes = await _travelMinutes(previousPoint, destination);
        final visitStart = cursor.add(Duration(minutes: travelMinutes));
        final visitEnd = visitStart.add(_visitDuration(place.category));
        if (!visitEnd.isAfter(deadline)) {
          _insertRecoveredPlace(
            day: day,
            tripId: tripId,
            from: previousPoint,
            place: place,
            visitStart: visitStart,
            visitEnd: visitEnd,
            travelMinutes: travelMinutes,
          );
          scheduled = true;
          break;
        }
      }

      if (!scheduled) remaining.add(place);
    }

    return remaining;
  }

  void _insertRecoveredPlace({
    required DayItinerary day,
    required String tripId,
    required RoutePoint from,
    required PlannerPlace place,
    required DateTime visitStart,
    required DateTime visitEnd,
    required int travelMinutes,
    RoutePoint? returnTo,
    int returnTravelMinutes = 0,
  }) {
    final destination = RoutePoint(
      id: place.id,
      name: place.name,
      latitude: place.latitude,
      longitude: place.longitude,
      type: 'tourist_spot',
    );
    final startTravel = visitStart.subtract(Duration(minutes: travelMinutes));
    if (travelMinutes > 0) {
      day.activities.add(
        _createTransportActivity(
          tripId: tripId,
          from: from,
          to: destination,
          startTime: startTravel,
          endTime: visitStart,
          sequence: 0,
          description: 'Travel to ${place.name}.',
        ),
      );
    }
    day.activities.add(
      _createSpotActivity(
        tripId: tripId,
        place: place,
        startTime: visitStart,
        endTime: visitEnd,
        sequence: 0,
        travelMinutes: travelMinutes,
      ),
    );
    if (returnTo != null && returnTravelMinutes > 0) {
      day.activities.add(
        _createTransportActivity(
          tripId: tripId,
          from: destination,
          to: returnTo,
          startTime: visitEnd,
          endTime: visitEnd.add(Duration(minutes: returnTravelMinutes)),
          sequence: 0,
          description: 'Travel to ${returnTo.name}.',
        ),
      );
    }
  }

  RoutePoint? _activityPoint(ItineraryActivity activity) {
    final latitude = activity.latitude;
    final longitude = activity.longitude;
    if (latitude == null || longitude == null) return null;
    return RoutePoint(
      id: activity.placeId ?? activity.id,
      name: activity.title,
      latitude: latitude,
      longitude: longitude,
      type: activity.type.name,
    );
  }

  /*
   * ============================================================
   * READ SELECTED PLACES
   * ============================================================
   */

  Future<List<Map<String, dynamic>>> _readSelectedPlaces(String tripId) async {
    final snapshot = await _firestore
        .collection('trips')
        .doc(tripId)
        .collection('selectedPlaces')
        .get();

    return snapshot.docs
        .map(
          (doc) => {
            ...doc.data(),
            if (!doc.data().containsKey('id')) 'id': doc.id,
          },
        )
        .toList();
  }

  /*
   * ============================================================
   * RESTAURANT PLAN HELPERS
   * ============================================================
   */

  RestaurantPlan? _findRestaurantPlan(
    List<RestaurantPlan> plans,
    MealType meal,
  ) {
    for (final plan in plans) {
      if (plan.mealType == meal) {
        return plan;
      }
    }
    return null;
  }

  DateTime _mealStart(DateTime date, MealType meal) {
    switch (meal) {
      case MealType.breakfast:
        return DateTime(date.year, date.month, date.day, 8, 30);

      case MealType.lunch:
        return DateTime(date.year, date.month, date.day, 12, 0);

      case MealType.dinner:
        return DateTime(date.year, date.month, date.day, 18, 30);
    }
  }

  String _mealDescription(Map<String, dynamic> restaurant, String mealName) {
    final address = PlaceMap.address(restaurant);

    if (address.trim().isEmpty) {
      return '$mealName at the selected restaurant.';
    }

    return '$mealName at the selected restaurant. $address';
  }

  /*
   * ============================================================
   * HOTEL HELPERS
   * ============================================================
   */

  RoutePoint? _hotelPoint(
    Map<String, dynamic>? hotel, {
    required String fallbackId,
  }) {
    if (hotel == null) {
      return null;
    }

    final latitude = PlaceMap.latitude(hotel);

    final longitude = PlaceMap.longitude(hotel);

    if (latitude == null || longitude == null) {
      return null;
    }

    return RoutePoint(
      id: PlaceMap.id(hotel).isEmpty ? fallbackId : PlaceMap.id(hotel),
      name: PlaceMap.name(hotel),
      latitude: latitude,
      longitude: longitude,
      type: 'hotel',
    );
  }

  /*
   * ============================================================
   * RESTAURANT HELPERS
   * ============================================================
   */

  RoutePoint? _restaurantPoint(
    Map<String, dynamic>? restaurant, {
    required String fallbackId,
  }) {
    if (restaurant == null) {
      return null;
    }

    final latitude = PlaceMap.latitude(restaurant);

    final longitude = PlaceMap.longitude(restaurant);

    if (latitude == null || longitude == null) {
      return null;
    }

    return RoutePoint(
      id: PlaceMap.id(restaurant).isEmpty
          ? fallbackId
          : PlaceMap.id(restaurant),
      name: PlaceMap.name(restaurant),
      latitude: latitude,
      longitude: longitude,
      type: 'restaurant',
    );
  }

  /*
   * ============================================================
   * SCHEDULING HELPERS
   * ============================================================
   */

  Future<_ScheduleResult> _addPlacesUntil({
    required List<PlannerPlace> places,
    required int dayNumber,
    required String tripId,
    required List<ItineraryActivity> activities,
    required int sequenceStart,
    required RoutePoint currentPoint,
    required DateTime currentTime,
    required DateTime deadline,
    required RoutePoint? reservedEndTravelPoint,
  }) async {
    var point = currentPoint;
    var time = currentTime;
    var sequence = sequenceStart;

    final remaining = List<PlannerPlace>.from(places);

    /*
     * Choose the next tourist place using the complete local route
     * cost instead of blindly following the cluster order.
     * When lunch, dinner, checkout or hotel is the next protected
     * point, a candidate is preferred when it keeps the route close
     * to that point. This prevents unnecessary backtracking.
     */
    while (remaining.isNotEmpty) {
      PlannerPlace? bestPlace;
      int bestScore = 1 << 30;
      int bestTravelMinutes = 0;
      DateTime? bestVisitStart;
      DateTime? bestVisitEnd;

      for (final place in remaining) {
        final destination = RoutePoint(
          id: place.id,
          name: place.name,
          latitude: place.latitude,
          longitude: place.longitude,
          type: 'tourist_spot',
        );

        final travelMinutes = await _travelMinutes(point, destination);

        final visitStart = time.add(Duration(minutes: travelMinutes));

        final visitDuration = _visitDuration(place.category);

        final visitEnd = visitStart.add(visitDuration);

        var travelToReserved = 0;

        if (reservedEndTravelPoint != null) {
          travelToReserved = await _travelMinutes(
            destination,
            reservedEndTravelPoint,
          );
        }

        final safeEnd = visitEnd.add(Duration(minutes: travelToReserved + 10));

        if (safeEnd.isAfter(deadline)) {
          continue;
        }

        final routeScore = travelMinutes + travelToReserved;

        if (routeScore < bestScore) {
          bestScore = routeScore;
          bestPlace = place;
          bestTravelMinutes = travelMinutes;
          bestVisitStart = visitStart;
          bestVisitEnd = visitEnd;
        }
      }

      if (bestPlace == null || bestVisitStart == null || bestVisitEnd == null) {
        break;
      }

      final destination = RoutePoint(
        id: bestPlace.id,
        name: bestPlace.name,
        latitude: bestPlace.latitude,
        longitude: bestPlace.longitude,
        type: 'tourist_spot',
      );

      if (bestTravelMinutes > 0) {
        activities.add(
          _createTransportActivity(
            tripId: tripId,
            from: point,
            to: destination,
            startTime: time,
            endTime: bestVisitStart,
            sequence: sequence++,
            description: 'Travel to ${bestPlace.name}.',
          ),
        );
      }

      activities.add(
        _createSpotActivity(
          tripId: tripId,
          place: bestPlace,
          startTime: bestVisitStart,
          endTime: bestVisitEnd,
          sequence: sequence++,
          travelMinutes: bestTravelMinutes,
        ),
      );

      time = bestVisitEnd.add(const Duration(minutes: 10));

      point = destination;
      remaining.remove(bestPlace);
    }

    return _ScheduleResult(point: point, time: time, sequence: sequence);
  }

  Future<DateTime> _travelAndAddAnchor({
    required List<ItineraryActivity> activities,
    required int sequence,
    required String tripId,
    required RoutePoint from,
    required RoutePoint to,
    required DateTime currentTime,
    required DateTime targetStart,
    required DateTime anchorEnd,
    required String anchorTitle,
    required String anchorDescription,
    required ActivityType anchorType,
    required String? mealType,
    required double cost,
  }) async {
    final travelMinutes = await _travelMinutes(from, to);

    final arrival = currentTime.add(Duration(minutes: travelMinutes));

    /*
     * Meals have a fixed target time.
     * Hotel check-in may use a later practical time.
     */
    final actualStart = targetStart.isAfter(arrival) ? targetStart : arrival;

    if (travelMinutes > 0) {
      activities.add(
        _createTransportActivity(
          tripId: tripId,
          from: from,
          to: to,
          startTime: currentTime,
          endTime: arrival,
          sequence: sequence,
          description: 'Travel to ${to.name}.',
        ),
      );
    }

    activities.add(
      ItineraryActivity(
        id: '${tripId}_${to.id}_${actualStart.millisecondsSinceEpoch}',
        title: anchorTitle,
        description: anchorDescription,
        startTime: actualStart,
        endTime: anchorEnd.isAfter(actualStart)
            ? anchorEnd
            : actualStart.add(anchorEnd.difference(targetStart)),
        cost: cost,
        type: anchorType,
        latitude: to.latitude,
        longitude: to.longitude,
        placeId: to.id,
        travelMinutesFromPrevious: travelMinutes,
        mealType: mealType,
      ),
    );

    return activities.last.endTime.add(const Duration(minutes: 10));
  }

  ItineraryActivity _createTransportActivity({
    required String tripId,
    required RoutePoint from,
    required RoutePoint to,
    required DateTime startTime,
    required DateTime endTime,
    required int sequence,
    required String description,
  }) {
    return ItineraryActivity(
      id: '${tripId}_travel_${from.id}_${to.id}_${startTime.millisecondsSinceEpoch}',
      title: 'Travel to ${to.name}',
      description: description,
      startTime: startTime,
      endTime: endTime,
      cost: 0,
      type: ActivityType.transport,
      latitude: to.latitude,
      longitude: to.longitude,
      dayNumber: null,
      sequence: sequence,
      placeId: to.id,
      travelMinutesFromPrevious: endTime.difference(startTime).inMinutes,
    );
  }

  ItineraryActivity _createSpotActivity({
    required String tripId,
    required PlannerPlace place,
    required DateTime startTime,
    required DateTime endTime,
    required int sequence,
    required int travelMinutes,
  }) {
    return ItineraryActivity(
      id: '${tripId}_${place.id}_${startTime.millisecondsSinceEpoch}',
      title: place.name,
      description: 'Tourist place visit',
      startTime: startTime,
      endTime: endTime,
      cost: 0,
      type: ActivityType.spot,
      latitude: place.latitude,
      longitude: place.longitude,
      placeId: place.id,
      travelMinutesFromPrevious: travelMinutes,
      sequence: sequence,
    );
  }

  Duration _visitDuration(String category) {
    final value = category.toLowerCase();

    if (value.contains('museum') || value.contains('historical')) {
      return const Duration(minutes: 120);
    }

    if (value.contains('park') ||
        value.contains('beach') ||
        value.contains('nature')) {
      return const Duration(minutes: 90);
    }

    return const Duration(minutes: 120);
  }

  bool _hasPlaceActivity(List<ItineraryActivity> activities, String placeId) {
    return activities.any(
      (activity) =>
          activity.type == ActivityType.spot && activity.placeId == placeId,
    );
  }

  /*
   * ============================================================
   * HOTEL / PLACE KEYS
   * ============================================================
   */

  String _placeKey(Map<String, dynamic>? place) {
    if (place == null) {
      return '';
    }

    final id = PlaceMap.id(place);

    if (id.isNotEmpty) {
      return id;
    }

    final lat = PlaceMap.latitude(place);

    final lng = PlaceMap.longitude(place);

    return [
      PlaceMap.name(place),
      lat?.toStringAsFixed(6) ?? '',
      lng?.toStringAsFixed(6) ?? '',
    ].join('|');
  }

  /*
   * ============================================================
   * ROUTE / TRAVEL TIME
   * ============================================================
   */

  Future<int> _travelMinutes(RoutePoint from, RoutePoint to) async {
    final key =
        '${from.latitude.toStringAsFixed(5)},'
        '${from.longitude.toStringAsFixed(5)}'
        '->'
        '${to.latitude.toStringAsFixed(5)},'
        '${to.longitude.toStringAsFixed(5)}';

    final cached = _travelMinutesCache[key];

    if (cached != null) {
      return cached;
    }

    try {
      final result = await _routeService.calculateRoute(
        origin: from,
        stops: [to],
      );

      final seconds = _durationToSeconds(result.duration);

      final minutes = (seconds / 60).ceil();

      _travelMinutesCache[key] = minutes;

      return minutes;
    } catch (_) {
      /*
       * Safe fallback so a temporary route API problem does not
       * completely destroy the itinerary.
       */
      const fallback = 20;

      _travelMinutesCache[key] = fallback;

      return fallback;
    }
  }

  int _durationToSeconds(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');

    return double.tryParse(cleaned)?.round() ?? 0;
  }

  /*
   * ============================================================
   * DATE
   * ============================================================
   */

  DateTime _readDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    final parsed = DateTime.tryParse(value?.toString() ?? '');

    if (parsed == null) {
      throw Exception('Invalid trip start date.');
    }

    return parsed;
  }
}

class _ScheduleResult {
  final RoutePoint point;
  final DateTime time;
  final int sequence;

  const _ScheduleResult({
    required this.point,
    required this.time,
    required this.sequence,
  });
}
