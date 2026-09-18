import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../app_routes.dart';

class SelectPreferencesScreen extends StatefulWidget {
  final String tripId;

  const SelectPreferencesScreen({super.key, required this.tripId});

  @override
  State<SelectPreferencesScreen> createState() =>
      _SelectPreferencesScreenState();
}

class _SelectPreferencesScreenState extends State<SelectPreferencesScreen> {
  final List<Map<String, dynamic>> _preferences = [
    {'name': 'Beaches', 'icon': Icons.beach_access},
    {'name': 'Nature', 'icon': Icons.park},
    {'name': 'History', 'icon': Icons.museum},
    {'name': 'Adventure', 'icon': Icons.hiking},
    {'name': 'Shopping', 'icon': Icons.shopping_bag},
    {'name': 'Food & Drinks', 'icon': Icons.restaurant},
    {'name': 'Entertainment', 'icon': Icons.theater_comedy},
  ];

  final Set<String> _selectedPreferences = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSavedPreferences();
  }

  Future<void> _loadSavedPreferences() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.tripId)
          .get();

      final values = List<String>.from(doc.data()?['preferences'] ?? []);

      if (!mounted) return;
      setState(() {
        _selectedPreferences.addAll(values);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load preferences: $e')),
      );
    }
  }

  Future<void> _continue() async {
    if (_selectedPreferences.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one preference.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.tripId)
          .set({
        'preferences': _selectedPreferences.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pushNamed(
        context,
        AppRoutes.touristSpots,
        arguments: {'tripId': widget.tripId},
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save preferences: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('3. Travel Preferences')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What do you want to visit?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Select one or more preferences. We will use them to recommend places near your selected destinations.',
              style: TextStyle(color: Colors.grey[700]),
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
                  final name = item['name'] as String;
                  final selected = _selectedPreferences.contains(name);

                  return FilterChip(
                    avatar: Icon(item['icon'] as IconData, size: 18),
                    label: Text(name),
                    selected: selected,
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          _selectedPreferences.add(name);
                        } else {
                          _selectedPreferences.remove(name);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _continue,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _saving
                    ? const CircularProgressIndicator()
                    : const Text('Next: Get Recommended Places'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
