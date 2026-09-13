import 'package:flutter/material.dart';

// Auth Screen
import 'screens/auth/login_register_screen.dart';

// Home Screen
import 'screens/home/home_screen.dart';
import 'screens/expense/expense_tracker_screen.dart';

// Planning Screens
import 'screens/planning/trip_details_screen.dart';
import 'screens/planning/select_destination_screen.dart';
import 'screens/planning/select_preferences_screen.dart';
import 'screens/planning/tourist_spots_screen.dart';
import 'screens/planning/transport_selection_screen.dart';
import 'screens/planning/hotel_selection_screen.dart';
import 'screens/planning/restaurant_selection_screen.dart';

// Itinerary Screens
import 'screens/itinerary/generate_itinerary_screen.dart';
import 'screens/itinerary/day_wise_itinerary_screen.dart';
import 'screens/itinerary/customize_itinerary_screen.dart';
import 'screens/itinerary/notifications_screen.dart';

// Map Screen
import 'screens/map/map_navigation_screen.dart';

class AppRoutes {
  static const String login = '/';
  static const String home = '/home';
  static const String tripDetails = '/trip-details';
  static const String selectDestination = '/select-destination';
  static const String selectPreferences = '/select-preferences';
  static const String touristSpots = '/tourist-spots';
  static const String transportSelection = '/transport-selection';
  static const String hotelSelection = '/hotel-selection';
  static const String restaurantSelection = '/restaurant-selection';
  static const String generateItinerary = '/generate-itinerary';
  static const String dayWiseItinerary = '/day-wise-itinerary';
  static const String customizeItinerary = '/customize-itinerary';
  static const String notifications = '/notifications';
  static const String mapNavigation = '/map-navigation';
  static const String expenseTracker = '/expense-tracker';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginRegisterScreen());

      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());

      case tripDetails:
        return MaterialPageRoute(builder: (_) => const TripDetailsScreen());

      case selectDestination:
        final args = settings.arguments;
        String tripId = '';

        if (args is Map<String, dynamic> && args['tripId'] != null) {
          tripId = args['tripId'] as String;
        } else if (args is String) {
          tripId = args;
        }

        return MaterialPageRoute(
          builder: (_) => SelectDestinationScreen(tripId: tripId),
          settings: settings,
        );

      case selectPreferences:
        final args = settings.arguments;
        String tripId = '';

        if (args is Map<String, dynamic> && args['tripId'] != null) {
          tripId = args['tripId'] as String;
        } else if (args is String) {
          tripId = args;
        }

        return MaterialPageRoute(
          builder: (_) => SelectPreferencesScreen(tripId: tripId),
          settings: settings,
        );

      case touristSpots:
        return MaterialPageRoute(
          builder: (_) => const TouristSpotsScreen(),
          settings: settings,
        );

      case transportSelection:
        return MaterialPageRoute(builder: (_) => const TransportSelectionScreen());

      case hotelSelection:
        return MaterialPageRoute(builder: (_) => const HotelSelectionScreen());

      case restaurantSelection:
        return MaterialPageRoute(builder: (_) => const RestaurantSelectionScreen());

      case generateItinerary:
        return MaterialPageRoute(builder: (_) => const GenerateItineraryScreen());

      case dayWiseItinerary:
        return MaterialPageRoute(builder: (_) => const DayWiseItineraryScreen());

      case customizeItinerary:
        return MaterialPageRoute(builder: (_) => const CustomizeItineraryScreen());

      case notifications:
        return MaterialPageRoute(builder: (_) => const NotificationsScreen());

      case mapNavigation:
        return MaterialPageRoute(builder: (_) => const MapNavigationScreen());

      case expenseTracker:
        return MaterialPageRoute(
          builder: (_) => const ExpenseTrackerScreen(),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text("Route Not Found")),
          ),
        );
    }
  }
}