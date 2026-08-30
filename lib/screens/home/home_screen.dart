import 'package:flutter/material.dart';
import '../../app_routes.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel Planner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.notifications);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready for your next trip?',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Customize your journey, select hotels, explore tourist spots, and view live routes on the map.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.selectDestination);
                      },
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: const Text('Start New Trip Plan'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Section Title
            Text(
              'Explore Services',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
            ),
            const SizedBox(height: 16),

            // Service Navigation Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: [
                _buildServiceCard(
                  context,
                  title: 'Trip Details',
                  icon: Icons.flight_takeoff,
                  color: Colors.blue,
                  routeName: AppRoutes.tripDetails,
                ),
                _buildServiceCard(
                  context,
                  title: 'Tourist Spots',
                  icon: Icons.place,
                  color: Colors.orange,
                  routeName: AppRoutes.touristSpots,
                ),
                _buildServiceCard(
                    context,
                    title: 'Start Gujarat Trip',
                    icon: Icons.map_outlined,
                    color: Colors.blue,
                    routeName: AppRoutes.selectDestination, // Starts destination flow
                  ),
                  _buildServiceCard(
                    context,
                    title: 'Hotels & Stay',
                    icon: Icons.hotel,
                    color: Colors.teal,
                    routeName: AppRoutes.hotelSelection, // Opens hotel selection directly
                  ),
                  _buildServiceCard(
                    context,
                    title: 'Restaurants',
                    icon: Icons.restaurant,
                    color: Colors.deepOrange,
                    routeName: AppRoutes.restaurantSelection, // Opens restaurant selection directly
                  ),
                _buildServiceCard(
                  context,
                  title: 'Map & Route',
                  icon: Icons.map_outlined,
                  color: Colors.purple,
                  routeName: AppRoutes.mapNavigation,
                ),
                _buildServiceCard(
                  context,
                  title: 'Day-Wise Plan',
                  icon: Icons.calendar_month,
                  color: Colors.green,
                  routeName: AppRoutes.dayWiseItinerary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required String routeName,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.pushNamed(context, routeName);
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                radius: 24,
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}