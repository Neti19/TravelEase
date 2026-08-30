import 'package:flutter/material.dart';
import '../../app_routes.dart';
import '../../models/mock_gujarat_data.dart';

class HotelSelectionScreen extends StatefulWidget {
  const HotelSelectionScreen({super.key});

  @override
  State<HotelSelectionScreen> createState() => _HotelSelectionScreenState();
}

class _HotelSelectionScreenState extends State<HotelSelectionScreen> {
  String _selectedHotelId = 'hotel_1';

  @override
  Widget build(BuildContext context) {
    final hotels = MockGujaratData.hotels;

    return Scaffold(
      appBar: AppBar(title: const Text('3. Select Hotel')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: hotels.length,
        itemBuilder: (context, index) {
          final hotel = hotels[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: RadioListTile<String>(
              value: hotel.id,
              groupValue: _selectedHotelId,
              title: Text(hotel.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${hotel.address}\n₹${hotel.pricePerNight.toInt()} / night • Rating: ⭐ ${hotel.rating}'),
              secondary: const Icon(Icons.hotel, color: Colors.teal),
              onChanged: (val) => setState(() => _selectedHotelId = val!),
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () => Navigator.pushNamed(context, AppRoutes.restaurantSelection),
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
          child: const Text('Next: Choose Dining Options'),
        ),
      ),
    );
  }
}