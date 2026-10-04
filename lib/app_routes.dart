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

// Map Screen
import 'screens/map/map_navigation_screen.dart';

import 'screens/trips/my_trips_screen.dart';
import 'screens/trips/trip_workspace_screen.dart';
import 'screens/dashboard/personal_dashboard_screen.dart';
import 'screens/discovery/help_me_choose_screen.dart';
import 'screens/discovery/destination_recommendations_screen.dart';
import 'screens/trips/invite_people_screen.dart';
import 'screens/trips/join_trip_screen.dart';

class AppRoutes {
  static const String login = '/';
  static const String home = '/home';
  static const String tripDetails = '/trip-details';
  static const String selectDestination =
      '/select-destination';
  static const String selectPreferences =
      '/select-preferences';
  static const String touristSpots =
      '/tourist-spots';
  static const String transportSelection =
      '/transport-selection';
  static const String hotelSelection =
      '/hotel-selection';
  static const String restaurantSelection =
      '/restaurant-selection';
  static const String generateItinerary =
      '/generate-itinerary';
  static const String dayWiseItinerary =
      '/day-wise-itinerary';
  static const String mapNavigation =
      '/map-navigation';
  static const String expenseTracker =
      '/expense-tracker';
  static const String myTrips = '/my-trips';
  static const String tripWorkspace = '/trip-workspace';
  static const String invitePeople = '/invite-people';
  static const String joinTrip = '/join-trip';
  static const String dashboard = '/dashboard';
  static const String helpMeChoose = '/help-me-choose';
  static const String destinationRecommendations =
      '/destination-recommendations';

  static Route<dynamic> generateRoute(
      RouteSettings settings,
      ) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(
          builder: (_) =>
          const LoginRegisterScreen(),
        );

      case home:
        return MaterialPageRoute(
          builder: (_) =>
          const HomeScreen(),
        );

      case tripDetails:
        return MaterialPageRoute(
          builder: (_) =>
          const TripDetailsScreen(),
        );

      case selectDestination:
        final args =
            settings.arguments;

        String tripId = '';

        if (args is Map<String, dynamic> &&
            args['tripId'] != null) {
          tripId =
          args['tripId'] as String;
        } else if (args is String) {
          tripId = args;
        }

        return MaterialPageRoute(
          builder: (_) =>
              SelectDestinationScreen(
                tripId: tripId,
              ),
          settings: settings,
        );

      case selectPreferences:
        final args =
            settings.arguments;

        String tripId = '';

        if (args is Map<String, dynamic> &&
            args['tripId'] != null) {
          tripId =
          args['tripId'] as String;
        } else if (args is String) {
          tripId = args;
        }

        return MaterialPageRoute(
          builder: (_) =>
              SelectPreferencesScreen(
                tripId: tripId,
              ),
          settings: settings,
        );

      case touristSpots:
        final args =
            settings.arguments;

        String tripId = '';

        if (args is Map &&
            args['tripId'] != null) {
          tripId =
              args['tripId'].toString();
        } else if (args is String) {
          tripId = args;
        }

        return MaterialPageRoute(
          builder: (_) =>
              TouristSpotsScreen(
                tripId: tripId,
              ),
          settings: settings,
        );

      case transportSelection:
        final args =
            settings.arguments;

        String tripId = '';

        if (args is Map &&
            args['tripId'] != null) {
          tripId =
              args['tripId'].toString();
        } else if (args is String) {
          tripId = args;
        }

        if (tripId.isEmpty) {
          return MaterialPageRoute(
            builder: (_) =>
            const Scaffold(
              body: Center(
                child: Text(
                  'Trip ID is missing.',
                  textAlign:
                  TextAlign.center,
                ),
              ),
            ),
          );
        }

        return MaterialPageRoute(
          builder: (_) =>
              TransportSelectionScreen(
                tripId: tripId,
              ),
          settings: settings,
        );

      case hotelSelection:
        final args =
            settings.arguments;

        String tripId = '';

        if (args is Map &&
            args['tripId'] != null) {
          tripId =
              args['tripId'].toString();
        } else if (args is String) {
          tripId = args;
        }

        return MaterialPageRoute(
          builder: (_) =>
              HotelSelectionScreen(
                tripId: tripId,
              ),
          settings: settings,
        );

      case restaurantSelection:
        final args =
            settings.arguments;

        String tripId = '';

        if (args is Map &&
            args['tripId'] != null) {
          tripId =
              args['tripId'].toString();
        } else if (args is String) {
          tripId = args;
        }

        return MaterialPageRoute(
          builder: (_) =>
              RestaurantSelectionScreen(
                tripId: tripId,
              ),
          settings: settings,
        );

      case generateItinerary:
        final args =
            settings.arguments;

        String tripId = '';

        if (args is Map &&
            args['tripId'] != null) {
          tripId =
              args['tripId']
                  .toString()
                  .trim();
        } else if (args is String) {
          tripId = args.trim();
        }

        if (tripId.isEmpty) {
          return MaterialPageRoute(
            builder: (_) =>
            const Scaffold(
              body: Center(
                child: Text(
                  'Trip ID is missing.',
                  textAlign:
                  TextAlign.center,
                ),
              ),
            ),
          );
        }

        return MaterialPageRoute(
          builder: (_) =>
              GenerateItineraryScreen(
                tripId: tripId,
              ),
          settings: settings,
        );

      case dayWiseItinerary:
        final args =
            settings.arguments;

        String tripId = '';

        if (args is Map &&
            args['tripId'] != null) {
          tripId =
              args['tripId']
                  .toString()
                  .trim();
        } else if (args is String) {
          tripId = args.trim();
        }

        if (tripId.isEmpty) {
          return MaterialPageRoute(
            builder: (_) =>
            const Scaffold(
              body: Center(
                child: Text(
                  'Trip ID is missing.',
                  textAlign:
                  TextAlign.center,
                ),
              ),
            ),
          );
        }

        return MaterialPageRoute(
          builder: (_) =>
              DayWiseItineraryScreen(
                tripId: tripId,
              ),
          settings: settings,
        );

      case expenseTracker:
        final args =
            settings.arguments;

        String tripId = '';

        if (args is Map &&
            args['tripId'] != null) {
          tripId =
              args['tripId']
                  .toString()
                  .trim();
        } else if (args is String) {
          tripId = args.trim();
        }

        if (tripId.isEmpty) {
          return MaterialPageRoute(
            builder: (_) =>
            const Scaffold(
              body: Center(
                child: Text(
                  'Trip ID is missing.',
                  textAlign:
                  TextAlign.center,
                ),
              ),
            ),
          );
        }

        return MaterialPageRoute(
          builder: (_) =>
              ExpenseTrackerScreen(
                tripId: tripId,
              ),
          settings: settings,
        );

      case mapNavigation:
        final args =
            settings.arguments;

        String? tripId;

        if (args is Map) {
          final value =
          args['tripId'];

          if (value != null) {
            tripId =
                value.toString().trim();
          }
        } else if (args is String) {
          tripId = args.trim();
        }

        if (tripId == null ||
            tripId!.isEmpty) {
          return MaterialPageRoute(
            builder: (_) =>
            const Scaffold(
              body: Center(
                child: Text(
                  'Trip ID is missing.\n'
                      'Please open Main Route from your trip.',
                  textAlign:
                  TextAlign.center,
                ),
              ),
            ),
          );
        }

        return MaterialPageRoute(
          builder: (_) =>
              MapNavigationScreen(
                tripId: tripId!,
              ),
          settings: settings,
        );

      case myTrips:
        return MaterialPageRoute(
          builder: (_) =>
          const MyTripsScreen(),
        );

      case tripWorkspace:
        final args = settings.arguments;

        String tripId = '';

        if (args is Map && args['tripId'] != null) {
          tripId = args['tripId'].toString().trim();
        } else if (args is String) {
          tripId = args.trim();
        }

        if (tripId.isEmpty) {
          return MaterialPageRoute(
            builder: (_) => const Scaffold(
              body: Center(
                child: Text(
                  'Trip ID is missing.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return MaterialPageRoute(
          builder: (_) => TripWorkspaceScreen(
            tripId: tripId,
          ),
          settings: settings,
        );
      case invitePeople:
        final args = settings.arguments;

        String tripId = '';

        if (args is Map && args['tripId'] != null) {
          tripId = args['tripId'].toString().trim();
        } else if (args is String) {
          tripId = args.trim();
        }

        if (tripId.isEmpty) {
          return MaterialPageRoute(
            builder: (_) => const Scaffold(
              body: Center(
                child: Text(
                  'Trip ID is missing.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return MaterialPageRoute(
          builder: (_) => InvitePeopleScreen(
            tripId: tripId,
          ),
          settings: settings,
        );
      case joinTrip:
        return MaterialPageRoute(
          builder: (_) => const JoinTripScreen(),
          settings: settings,
        );
      case dashboard:
        return MaterialPageRoute(
          builder: (_) => const PersonalDashboardScreen(),
        );
      case helpMeChoose:
        return MaterialPageRoute(
          builder: (_) => const HelpMeChooseScreen(),
          settings: settings,
        );
      case destinationRecommendations:
        final args = settings.arguments as Map<String, dynamic>;

        return MaterialPageRoute(
          builder: (_) => DestinationRecommendationsScreen(
            experience: args['experience'] as String,
            travelerType: args['travelerType'] as String,
            duration: args['duration'] as String,
            budget: (args['budget'] as num).toDouble(),
          ),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) =>
          const Scaffold(
            body: Center(
              child: Text(
                "Route Not Found",
              ),
            ),
          ),
        );
    }
  }
}