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
        title: const Text('TravelEase'),
        centerTitle: true,
        actions: [
          // Trip Expenses
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

          // Logout
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome to TravelEase!',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Plan your trip, manage your itinerary and track your expenses.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Services',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildServiceCard(
                  context,
                  title: 'Plan Trip',
                  icon: Icons.map,
                  color: Colors.blue,
                  routeName: AppRoutes.tripDetails,
                ),

                _buildServiceCard(
                  context,
                  title: 'Itinerary',
                  icon: Icons.event_note,
                  color: Colors.green,
                  routeName: AppRoutes.generateItinerary,
                ),

                _buildServiceCard(
                  context,
                  title: 'Hotels',
                  icon: Icons.hotel,
                  color: Colors.orange,
                  routeName: AppRoutes.hotelSelection,
                ),

                _buildServiceCard(
                  context,
                  title: 'Restaurants',
                  icon: Icons.restaurant,
                  color: Colors.red,
                  routeName: AppRoutes.restaurantSelection,
                ),

                _buildServiceCard(
                  context,
                  title: 'Transport',
                  icon: Icons.directions_car,
                  color: Colors.purple,
                  routeName: AppRoutes.transportSelection,
                ),

                _buildServiceCard(
                  context,
                  title: 'Tourist Spots',
                  icon: Icons.place,
                  color: Colors.teal,
                  routeName: AppRoutes.touristSpots,
                ),

                _buildServiceCard(
                  context,
                  title: 'Map Navigation',
                  icon: Icons.navigation,
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

  Widget _buildServiceCard(
      BuildContext context, {
        required String title,
        required IconData icon,
        required Color color,
        required String routeName,
      }) {
    return Card(
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.pushNamed(
            context,
            routeName,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 42,
                color: color,
              ),

              const SizedBox(height: 10),

              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}