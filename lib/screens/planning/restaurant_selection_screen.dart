import 'package:flutter/material.dart';
import '../../app_routes.dart';
import '../../models/mock_gujarat_data.dart';

class RestaurantSelectionScreen extends StatefulWidget {
  const RestaurantSelectionScreen({super.key});

  @override
  State<RestaurantSelectionScreen> createState() =>
      _RestaurantSelectionScreenState();
}

class _RestaurantSelectionScreenState
    extends State<RestaurantSelectionScreen> {
  String _selectedRestaurantId = 'rest_1';

  @override
  Widget build(BuildContext context) {
    final restaurants = MockGujaratData.restaurants;

    return Scaffold(
      appBar: AppBar(
        title: const Text('4. Select Restaurant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_calendar),
            tooltip: 'View Trip Details',
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.tripDetails);
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: restaurants.length,
        itemBuilder: (context, index) {
          final rest = restaurants[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: RadioListTile<String>(
              value: rest.id,
              groupValue: _selectedRestaurantId,
              title: Text(
                rest.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${rest.cuisineType}\nAvg Cost: ₹${rest.averageMealCost.toInt()} • Rating: ⭐ ${rest.rating}',
              ),
              secondary:
                  const Icon(Icons.restaurant, color: Colors.deepOrange),
              onChanged: (val) =>
                  setState(() => _selectedRestaurantId = val!),
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.mapNavigation),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('Complete & Live Map'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}