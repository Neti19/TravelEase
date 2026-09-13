import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../app_routes.dart';

class SelectDestinationScreen extends StatefulWidget {
  final String? tripId;

  const SelectDestinationScreen({super.key, this.tripId});

  @override
  State<SelectDestinationScreen> createState() =>
      _SelectDestinationScreenState();
}

class _SelectDestinationScreenState extends State<SelectDestinationScreen> {
  String _selectedCity = 'Ahmedabad';
  String _selectedPreference = 'Heritage & Culture';
  String? _tripId;

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
  void initState() {
    super.initState();
    _tripId = widget.tripId;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_tripId == null || _tripId!.isEmpty) {
      final args = ModalRoute.of(context)?.settings.arguments;

      if (args is Map) {
        final id = args['tripId'];
        if (id != null && id.toString().isNotEmpty) {
          _tripId = id.toString();
        }
      } else if (args is String && args.isNotEmpty) {
        _tripId = args;
      }
    }

    if (_tripId == null || _tripId!.isEmpty) {
      _tripId = FirebaseFirestore.instance.collection('trips').doc().id;
    }
  }

  Future<void> _continue() async {
    final currentTripId = _tripId;

    if (currentTripId == null || currentTripId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trip ID could not be generated.'),
        ),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('trips')
          .doc(currentTripId)
          .set({
        'tripId': currentTripId,
        'destination': _selectedCity,
        'destinationPreference': _selectedPreference,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.pushNamed(
        context,
        AppRoutes.touristSpots,
        arguments: <String, dynamic>{
          'tripId': currentTripId,
        },
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to save destination: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '1. Destination & Preferences',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Destination in Gujarat',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedCity,
              decoration: const InputDecoration(
                labelText: 'Destination',
                border: OutlineInputBorder(),
              ),
              items: _gujaratCities.map((city) {
                return DropdownMenuItem<String>(
                  value: city,
                  child: Text(city),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCity = value;
                  });
                }
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Travel Preference',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _preferences.map((pref) {
                final isSelected = _selectedPreference == pref;

                return ChoiceChip(
                  label: Text(pref),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedPreference = pref;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _continue,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(
                  double.infinity,
                  50,
                ),
              ),
              child: const Text(
                'Next: Choose Tourist Spots',
              ),
            ),
          ],
        ),
      ),
    );
  }
}