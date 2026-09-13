import 'package:flutter/material.dart';
import '../../app_routes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SelectPreferencesScreen extends StatefulWidget {
  final String tripId;
  const SelectPreferencesScreen({super.key, required this.tripId});

  @override
  State<SelectPreferencesScreen> createState() => _SelectPreferencesScreenState();
}

class _SelectPreferencesScreenState extends State<SelectPreferencesScreen> {
  String? _effectiveTripId;

  final List<Map<String, dynamic>> _preferences = [
    {'name': 'Beaches', 'icon': Icons.beach_access, 'selected': false},
    {'name': 'Nature', 'icon': Icons.park, 'selected': false},
    {'name': 'History', 'icon': Icons.museum, 'selected': false},
    {'name': 'Adventure', 'icon': Icons.hiking, 'selected': false},
    {'name': 'Shopping', 'icon': Icons.shopping_bag, 'selected': false},
    {'name': 'Food & Drinks', 'icon': Icons.restaurant, 'selected': false},
    {'name': 'Entertainment', 'icon': Icons.theater_comedy, 'selected': false},
  ];

  @override
  void initState() {
    super.initState();
    _effectiveTripId = widget.tripId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Fallback: If tripId wasn't passed via constructor, check ModalRoute arguments
      if (_effectiveTripId == null || _effectiveTripId!.isEmpty) {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is Map<String, dynamic> && args['tripId'] != null) {
          setState(() {
            _effectiveTripId = args['tripId'] as String;
          });
        }
      }
    });
  }

  Future<void> _savePreferencesAndNavigate() async {
    final currentId = _effectiveTripId;

    if (currentId == null || currentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Trip ID is missing.')),
      );
      return;
    }

    // Extract selected preferences from UI state
    final selectedPreferences = _preferences
        .where((item) => item['selected'] == true)
        .map((item) => item['name'] as String)
        .toList();

    try {
      // 1. Update Firestore document with selected preferences
      await FirebaseFirestore.instance
          .collection('trips')
          .doc(currentId)
          .update({'preferences': selectedPreferences});

      // 2. Navigate to Tourist Spots screen, passing tripId in route arguments
      if (mounted) {
        Navigator.pushNamed(
          context,
          AppRoutes.touristSpots,
          arguments: <String, dynamic>{
            'tripId': currentId,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update trip: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Step 3: Travel Preferences')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What do you love exploring?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Select options to tailor your recommendations.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _preferences.length,
                itemBuilder: (context, index) {
                  final item = _preferences[index];
                  final isSelected = item['selected'] as bool;
                  return FilterChip(
                    avatar: Icon(item['icon'] as IconData, size: 18),
                    label: Text(item['name'] as String),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      setState(() {
                        _preferences[index]['selected'] = selected;
                      });
                    },
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: _savePreferencesAndNavigate,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Next: Explore Attractions'),
            ),
          ],
        ),
      ),
    );
  }
}