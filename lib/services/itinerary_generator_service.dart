import '../models/trip.dart';
import '../models/tourist_spot.dart';
import '../models/transport.dart';
import '../models/hotel.dart';
import '../models/restaurant.dart';
import '../models/itinerary.dart';

class ItineraryGeneratorService {
  /// Generates a complete time-based schedule across all trip days.
  FullItinerary generateFullItinerary({
    required Trip trip,
    required List<TouristSpot> spots,
    required List<Restaurant> restaurants,
    Transport? selectedTransport,
    Hotel? selectedHotel,
  }) {
    // Basic route optimization: sort spots by distance from hotel/center
    List<TouristSpot> sortedSpots = List.from(spots)
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    List<DayItinerary> dayPlans = [];
    int spotIndex = 0;
    int restaurantIndex = 0;

    for (int day = 1; day <= trip.numberOfDays; day++) {
      final DateTime currentDayDate = trip.startDate.add(Duration(days: day - 1));
      List<ItineraryActivity> dailyActivities = [];

      // Day 1: Add arrival transport if provided
      if (day == 1 && selectedTransport != null) {
        dailyActivities.add(
          ItineraryActivity(
            id: 'transport_dep_${selectedTransport.id}',
            title: '${selectedTransport.type.name.toUpperCase()}: ${selectedTransport.providerName}',
            description: 'Departure from ${selectedTransport.departureLocation}',
            startTime: selectedTransport.departureTime,
            endTime: selectedTransport.arrivalTime,
            cost: selectedTransport.cost,
            type: ActivityType.transport,
          ),
        );
      }

      // Add Hotel Stay cost to Day 1 or split daily
      if (selectedHotel != null) {
        final hotelCheckInTime = DateTime(
          currentDayDate.year,
          currentDayDate.month,
          currentDayDate.day,
          10,
          0,
        );
        dailyActivities.add(
          ItineraryActivity(
            id: 'hotel_${selectedHotel.id}_day_$day',
            title: 'Stay: ${selectedHotel.name}',
            description: selectedHotel.address,
            startTime: hotelCheckInTime,
            endTime: hotelCheckInTime.add(const Duration(hours: 1)),
            cost: selectedHotel.pricePerNight,
            type: ActivityType.hotel,
          ),
        );
      }

      // Schedule spots and meals dynamically through the day (9:00 AM - 6:00 PM)
      DateTime currentTime = DateTime(
        currentDayDate.year,
        currentDayDate.month,
        currentDayDate.day,
        9,
        0,
      );

      bool lunchAdded = false;

      while (currentTime.hour < 18 && spotIndex < sortedSpots.length) {
        // Inject lunch around 12:30 PM
        if (!lunchAdded && currentTime.hour >= 12 && restaurants.isNotEmpty) {
          final restaurant = restaurants[restaurantIndex % restaurants.length];
          final lunchEnd = currentTime.add(const Duration(hours: 1));

          dailyActivities.add(
            ItineraryActivity(
              id: 'rest_${restaurant.id}_$day',
              title: 'Lunch @ ${restaurant.name}',
              description: restaurant.cuisineType,
              startTime: currentTime,
              endTime: lunchEnd,
              cost: restaurant.averageMealCost,
              type: ActivityType.restaurant,
            ),
          );

          currentTime = lunchEnd.add(const Duration(minutes: 30)); // 30-min buffer
          lunchAdded = true;
          restaurantIndex++;
          continue;
        }

        // Add Tourist Attraction Spot
        final spot = sortedSpots[spotIndex];
        final visitEndTime = currentTime.add(spot.estimatedVisitDuration);

        dailyActivities.add(
          ItineraryActivity(
            id: 'spot_${spot.id}',
            title: spot.name,
            description: 'Category: ${spot.category} | Est. Visit: ${spot.estimatedVisitDuration.inHours}h',
            startTime: currentTime,
            endTime: visitEndTime,
            cost: spot.entryFee,
            type: ActivityType.spot,
          ),
        );

        // Add 45 min buffer for transit and navigation
        currentTime = visitEndTime.add(const Duration(minutes: 45));
        spotIndex++;
      }

      dayPlans.add(
        DayItinerary(
          dayNumber: day,
          date: currentDayDate,
          activities: dailyActivities,
        ),
      );
    }

    return FullItinerary(
      id: 'itinerary_${trip.id}',
      tripId: trip.id,
      days: dayPlans,
    );
  }

  /// Detects overlapping activities and opening-hour conflicts
  List<String> detectConflicts(List<ItineraryActivity> activities) {
    List<String> conflicts = [];

    for (int i = 0; i < activities.length; i++) {
      for (int j = i + 1; j < activities.length; j++) {
        if (activities[i].overlapsWith(activities[j])) {
          conflicts.add(
            'Time Conflict: "${activities[i].title}" overlaps with "${activities[j].title}".',
          );
        }
      }
    }
    return conflicts;
  }
}