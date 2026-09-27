import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/itinerary.dart';
import '../services/route_service.dart';

class ItineraryGeneratorService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final RouteService _routeService =
      RouteService();

  Future<FullItinerary> generateForTrip(
    String tripId,
  ) async {
    final tripRef =
        _firestore.collection('trips').doc(tripId);

    final tripSnapshot =
        await tripRef.get();

    if (!tripSnapshot.exists) {
      throw Exception('Trip not found.');
    }

    final trip =
        tripSnapshot.data()!;

    final startDate =
        _readDate(trip['startDate']);

    final numberOfDays =
        (trip['numberOfDays'] as num?)?.toInt() ?? 1;

    if (numberOfDays <= 0) {
      throw Exception('Invalid number of trip days.');
    }

    final routeData =
        trip['route'];

    if (routeData is! Map) {
      throw Exception(
        'Route is not generated yet. Please generate the main route first.',
      );
    }

    final orderedStopsRaw =
        routeData['orderedStops'];

    if (orderedStopsRaw is! List ||
        orderedStopsRaw.isEmpty) {
      throw Exception(
        'No ordered route stops found.',
      );
    }

    final routePoints =
        <RoutePoint>[];

    for (final item in orderedStopsRaw) {
      if (item is! Map) continue;

      final latitude =
          (item['latitude'] as num?)?.toDouble();

      final longitude =
          (item['longitude'] as num?)?.toDouble();

      if (latitude == null ||
          longitude == null) {
        continue;
      }

      routePoints.add(
        RoutePoint(
          id: item['id']?.toString() ?? '',
          name: item['name']?.toString() ??
              'Location',
          latitude: latitude,
          longitude: longitude,
          type: item['type']?.toString() ??
              'location',
        ),
      );
    }

    if (routePoints.length < 2) {
      throw Exception(
        'At least two route locations are required.',
      );
    }

    final days =
        <DayItinerary>[];

    int stopIndex = 1;

    RoutePoint previousPoint =
        routePoints.first;

    for (int day = 1;
        day <= numberOfDays;
        day++) {
      final date =
          DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      ).add(
        Duration(days: day - 1),
      );

      final activities =
          <ItineraryActivity>[];

      DateTime currentTime =
          DateTime(
        date.year,
        date.month,
        date.day,
        9,
        0,
      );

      final dayEnd =
          DateTime(
        date.year,
        date.month,
        date.day,
        18,
        0,
      );

      /*
       * Hotel check-in is added only on Day 1.
       */
      if (day == 1) {
        final hotel =
            _readSelectedPlace(
          trip['selectedHotel'],
          fallbackType: 'hotel',
        );

        if (hotel != null) {
          final end =
              currentTime.add(
            const Duration(minutes: 45),
          );

          activities.add(
            ItineraryActivity(
              id: 'hotel_checkin_$tripId',
              title:
                  'Hotel Check-in: ${hotel['name']}',
              description:
                  hotel['address'] ?? '',
              startTime: currentTime,
              endTime: end,
              cost: 0,
              type: ActivityType.hotel,
            ),
          );

          currentTime =
              end.add(
            const Duration(minutes: 15),
          );
        }
      }

      bool addedActivityToday = false;

      while (stopIndex < routePoints.length) {
        final currentPoint =
            routePoints[stopIndex];

        final travelDuration =
            await _getTravelDuration(
          previousPoint,
          currentPoint,
        );

        final arrivalTime =
            currentTime.add(
          travelDuration,
        );

        if (arrivalTime.isAfter(dayEnd)) {
          break;
        }

        final visitDuration =
            _visitDuration(
          currentPoint.type,
        );

        final activityEnd =
            arrivalTime.add(
          visitDuration,
        );

        if (activityEnd.isAfter(dayEnd)) {
          break;
        }

        final activity =
            _createActivity(
          tripId: tripId,
          point: currentPoint,
          startTime: arrivalTime,
          endTime: activityEnd,
        );

        activities.add(activity);

        currentTime =
            activityEnd.add(
          const Duration(minutes: 15),
        );

        previousPoint =
            currentPoint;

        stopIndex++;
        addedActivityToday = true;

        /*
         * Keep a reasonable number of activities
         * on one day.
         */
        if (activities.where(
              (item) =>
                  item.type ==
                  ActivityType.spot,
            ).length >=
            3) {
          break;
        }
      }

      /*
       * Add selected restaurant as lunch.
       *
       * It is added once, on the first day.
       */
      if (day == 1) {
        final restaurant =
            _readSelectedPlace(
          trip['selectedRestaurant'],
          fallbackType: 'restaurant',
        );

        if (restaurant != null) {
          final lunchStart =
              DateTime(
            date.year,
            date.month,
            date.day,
            13,
            0,
          );

          final lunchEnd =
              lunchStart.add(
            const Duration(hours: 1),
          );

          final alreadyOverlapping =
              activities.any(
            (activity) =>
                activity.overlapsWith(
              ItineraryActivity(
                id: 'temporary',
                title: '',
                description: '',
                startTime: lunchStart,
                endTime: lunchEnd,
                cost: 0,
                type: ActivityType.restaurant,
              ),
            ),
          );

          if (!alreadyOverlapping) {
            activities.add(
              ItineraryActivity(
                id:
                    'restaurant_$tripId',
                title:
                    'Lunch: ${restaurant['name']}',
                description:
                    restaurant['address'] ?? '',
                startTime:
                    lunchStart,
                endTime:
                    lunchEnd,
                cost: 0,
                type:
                    ActivityType.restaurant,
              ),
            );
          }
        }
      }

      activities.sort(
        (a, b) =>
            a.startTime.compareTo(
          b.startTime,
        ),
      );

      days.add(
        DayItinerary(
          dayNumber: day,
          date: date,
          activities: activities,
        ),
      );
    }

    if (stopIndex < routePoints.length) {
      throw Exception(
        'Not enough time to visit all selected places in $numberOfDays days.',
      );
    }

    final itinerary =
        FullItinerary(
      id: 'itinerary_$tripId',
      tripId: tripId,
      days: days,
    );

    await tripRef.set(
      {
        'itinerary': itinerary.toJson(),
        'itineraryGenerated': true,
        'itineraryGeneratedAt':
            FieldValue.serverTimestamp(),
        'updatedAt':
            FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    return itinerary;
  }

  Future<Duration> _getTravelDuration(
    RoutePoint from,
    RoutePoint to,
  ) async {
    try {
      final result =
          await _routeService.calculateRoute(
        origin: from,
        stops: [to],
      );

      return Duration(
        seconds:
            _durationToSeconds(
          result.duration,
        ),
      );
    } catch (_) {
      /*
       * Fallback when a leg cannot be calculated.
       */
      return const Duration(
        minutes: 30,
      );
    }
  }

  int _durationToSeconds(
    String value,
  ) {
    final cleaned =
        value.replaceAll('s', '');

    return double.tryParse(cleaned)
            ?.round() ??
        0;
  }

  Duration _visitDuration(
    String type,
  ) {
    switch (type) {
      case 'hotel':
        return const Duration(
          minutes: 45,
        );

      case 'restaurant':
        return const Duration(
          minutes: 60,
        );

      case 'tourist_spot':
        return const Duration(
          hours: 2,
        );

      default:
        return const Duration(
          hours: 1,
        );
    }
  }

  ItineraryActivity _createActivity({
    required String tripId,
    required RoutePoint point,
    required DateTime startTime,
    required DateTime endTime,
  }) {
    ActivityType type;

    switch (point.type) {
      case 'hotel':
        type = ActivityType.hotel;
        break;

      case 'restaurant':
        type = ActivityType.restaurant;
        break;

      case 'tourist_spot':
        type = ActivityType.spot;
        break;

      default:
        type = ActivityType.spot;
    }

    return ItineraryActivity(
      id:
          '${tripId}_${point.id}_${startTime.millisecondsSinceEpoch}',
      title: point.name,
      description:
          _descriptionForType(
        point.type,
      ),
      startTime: startTime,
      endTime: endTime,
      cost: 0,
      type: type,
    );
  }

  String _descriptionForType(
    String type,
  ) {
    switch (type) {
      case 'tourist_spot':
        return 'Tourist place visit';

      case 'hotel':
        return 'Hotel stay';

      case 'restaurant':
        return 'Meal';

      default:
        return 'Travel activity';
    }
  }

  Map<String, dynamic>? _readSelectedPlace(
    dynamic value, {
    required String fallbackType,
  }) {
    if (value is! Map) {
      return null;
    }

    final location =
        value['location'];

    if (location is! Map) {
      return null;
    }

    final latitude =
        (location['latitude'] as num?)
            ?.toDouble();

    final longitude =
        (location['longitude'] as num?)
            ?.toDouble();

    if (latitude == null ||
        longitude == null) {
      return null;
    }

    final displayName =
        value['displayName'];

    String name =
        'Selected Location';

    if (displayName is Map &&
        displayName['text'] != null) {
      name =
          displayName['text'].toString();
    }

    return {
      'id':
          value['id']?.toString() ??
              fallbackType,
      'name': name,
      'address':
          value['formattedAddress']
                  ?.toString() ??
              '',
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  DateTime _readDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    return DateTime.parse(
      value.toString(),
    );
  }
}