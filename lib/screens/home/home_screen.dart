
import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../services/auth_service.dart';

class HomeScreen extends StatelessWidget {
const HomeScreen({super.key});

Future<void> _logout(BuildContext context) async {
await AuthService().logout();

if (!context.mounted) return;

Navigator.pushNamedAndRemoveUntil(
context,
AppRoutes.login,
(route) => false,
);
}

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: const Text(
'TravelEase',
style: TextStyle(
fontWeight: FontWeight.bold,
),
),
centerTitle: false,
actions: [
IconButton(
icon: const Icon(
Icons.account_balance_wallet_outlined,
),
tooltip: 'Trip Expenses',
onPressed: () {
Navigator.pushNamed(
context,
AppRoutes.expenseTracker,
);
},
),
IconButton(
icon: const Icon(Icons.logout),
tooltip: 'Logout',
onPressed: () => _logout(context),
),
],
),
body: SingleChildScrollView(
padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'Ready for your next trip?',
style: TextStyle(
fontSize: 28,
fontWeight: FontWeight.bold,
),
),

const SizedBox(height: 8),

const Text(
'Plan your journey, discover places and enjoy your trip.',
style: TextStyle(
fontSize: 15,
color: Colors.grey,
),
),

const SizedBox(height: 24),

// --------------------------------------------------
// PLAN TRIP
// --------------------------------------------------

InkWell(
borderRadius: BorderRadius.circular(24),
onTap: () {
Navigator.pushNamed(
context,
AppRoutes.tripDetails,
);
},
child: Container(
width: double.infinity,
padding: const EdgeInsets.all(24),
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(24),
gradient: const LinearGradient(
begin: Alignment.topLeft,
end: Alignment.bottomRight,
colors: [
Color(0xFF1565C0),
Color(0xFF42A5F5),
],
),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Container(
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color: Colors.white.withOpacity(0.18),
shape: BoxShape.circle,
),
child: const Icon(
Icons.flight_takeoff,
color: Colors.white,
size: 28,
),
),

const SizedBox(height: 22),

const Text(
'Plan Your Next Adventure',
style: TextStyle(
color: Colors.white,
fontSize: 24,
fontWeight: FontWeight.bold,
),
),

const SizedBox(height: 8),

const Text(
'Choose your destination and build your perfect trip.',
style: TextStyle(
color: Colors.white70,
fontSize: 14,
),
),

const SizedBox(height: 22),

Container(
padding: const EdgeInsets.symmetric(
horizontal: 18,
vertical: 11,
),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(30),
),
child: const Row(
mainAxisSize: MainAxisSize.min,
children: [
Text(
'Start Planning',
style: TextStyle(
color: Color(0xFF1565C0),
fontWeight: FontWeight.bold,
),
),
SizedBox(width: 8),
Icon(
Icons.arrow_forward,
color: Color(0xFF1565C0),
size: 18,
),
],
),
),
],
),
),
),

const SizedBox(height: 30),

const Text(
'Explore TravelEase',
style: TextStyle(
fontSize: 21,
fontWeight: FontWeight.bold,
),
),

const SizedBox(height: 14),

// --------------------------------------------------
// SERVICES
// --------------------------------------------------

GridView.count(
crossAxisCount: 2,
crossAxisSpacing: 14,
mainAxisSpacing: 14,
childAspectRatio: 1.35,
shrinkWrap: true,
physics: const NeverScrollableScrollPhysics(),
children: [
_buildServiceTile(
context,
title: 'Itinerary',
subtitle: 'Your trip plan',
icon: Icons.event_note_outlined,
color: Colors.green,
routeName: AppRoutes.generateItinerary,
),

_buildServiceTile(
context,
title: 'Hotels',
subtitle: 'Find a stay',
icon: Icons.hotel_outlined,
color: Colors.orange,
routeName: AppRoutes.hotelSelection,
),

_buildServiceTile(
context,
title: 'Restaurants',
subtitle: 'Places to eat',
icon: Icons.restaurant_outlined,
color: Colors.red,
routeName: AppRoutes.restaurantSelection,
),

_buildServiceTile(
context,
title: 'Transport',
subtitle: 'Travel options',
icon: Icons.directions_car_outlined,
color: Colors.purple,
routeName: AppRoutes.transportSelection,
),

_buildServiceTile(
context,
title: 'Tourist Spots',
subtitle: 'Explore places',
icon: Icons.explore_outlined,
color: Colors.teal,
routeName: AppRoutes.touristSpots,
),

_buildServiceTile(
context,
title: 'Map',
subtitle: 'Navigate your trip',
icon: Icons.navigation_outlined,
color: Colors.indigo,
routeName: AppRoutes.mapNavigation,
),
],
),
],
),
),
);
}

Widget _buildServiceTile(
BuildContext context, {
required String title,
required String subtitle,
required IconData icon,
required Color color,
required String routeName,
}) {
return InkWell(
borderRadius: BorderRadius.circular(20),
onTap: () {
Navigator.pushNamed(
context,
routeName,
);
},
child: Container(
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: Theme.of(context).cardColor,
borderRadius: BorderRadius.circular(20),
border: Border.all(
color: Colors.grey.withOpacity(0.15),
),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
mainAxisAlignment: MainAxisAlignment.center,
children: [
Container(
padding: const EdgeInsets.all(10),
decoration: BoxDecoration(
color: color.withOpacity(0.1),
borderRadius: BorderRadius.circular(14),
),
child: Icon(
icon,
color: color,
size: 26,
),
),

const SizedBox(height: 10),

Text(
title,
style: const TextStyle(
fontSize: 16,
fontWeight: FontWeight.bold,
),
),

const SizedBox(height: 3),

Text(
subtitle,
style: const TextStyle(
fontSize: 12,
color: Colors.grey,
),
),
],
),
),
);
}
}

