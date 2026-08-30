import 'package:flutter/material.dart';
import '../../app_routes.dart';
import '../../models/mock_gujarat_data.dart';

class TouristSpotsScreen extends StatefulWidget {
  const TouristSpotsScreen({super.key});

  @override
  State<TouristSpotsScreen> createState() => _TouristSpotsScreenState();
}

class _TouristSpotsScreenState extends State<TouristSpotsScreen> {
  final Set<String> _selectedSpotIds = {'spot_1', 'spot_2'};

  @override
  Widget build(BuildContext context) {
    final spots = MockGujaratData.spots;

    return Scaffold(
      appBar: AppBar(title: const Text('2. Select Tourist Spots')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: spots.length,
        itemBuilder: (context, index) {
          final spot = spots[index];
          final isSelected = _selectedSpotIds.contains(spot.id);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: CheckboxListTile(
              value: isSelected,
              title: Text(spot.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${spot.category} | Entry Fee: ₹${spot.entryFee.toInt()}'),
              secondary: const Icon(Icons.place, color: Colors.blue),
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _selectedSpotIds.add(spot.id);
                  } else {
                    _selectedSpotIds.remove(spot.id);
                  }
                });
              },
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _selectedSpotIds.isEmpty
              ? null
              : () => Navigator.pushNamed(context, AppRoutes.hotelSelection),
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
          child: Text('Next: Select Hotel Stay (${_selectedSpotIds.length} Selected)'),
        ),
      ),
    );
  }
}