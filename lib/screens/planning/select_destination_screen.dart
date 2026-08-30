import 'package:flutter/material.dart';
import '../../app_routes.dart';

class SelectDestinationScreen extends StatefulWidget {
  const SelectDestinationScreen({super.key});

  @override
  State<SelectDestinationScreen> createState() => _SelectDestinationScreenState();
}

class _SelectDestinationScreenState extends State<SelectDestinationScreen> {
  String _selectedCity = 'Ahmedabad';
  String _selectedPreference = 'Heritage & Culture';

  final List<String> _gujaratCities = [
    'Ahmedabad',
    'Kevadia (Statue of Unity)',
    'Gir Forest & Junagadh',
    'Kutch (Rann of Kutch)',
    'Dwarka & Somnath',
  ];

  final List<String> _preferences = [
    'Heritage & Culture',
    'Spiritual & Temples',
    'Wildlife & Nature',
    'Food & Culinary',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('1. Destination & Preferences')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Destination in Gujarat',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedCity,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: _gujaratCities.map((city) {
                return DropdownMenuItem(value: city, child: Text(city));
              }).toList(),
              onChanged: (val) => setState(() => _selectedCity = val!),
            ),
            const SizedBox(height: 24),
            const Text(
              'Travel Preference',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: _preferences.map((pref) {
                final isSelected = _selectedPreference == pref;
                return ChoiceChip(
                  label: Text(pref),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedPreference = pref);
                  },
                );
              }).toList(),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.touristSpots);
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Next: Choose Tourist Spots'),
            ),
          ],
        ),
      ),
    );
  }
}