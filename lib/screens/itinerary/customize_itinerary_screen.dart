import 'package:flutter/material.dart';

class CustomizeItineraryScreen extends StatefulWidget {
  const CustomizeItineraryScreen({super.key});

  @override
  State<CustomizeItineraryScreen> createState() => _CustomizeItineraryScreenState();
}

class _CustomizeItineraryScreenState extends State<CustomizeItineraryScreen> {
  final List<Map<String, String>> _activities = [
    {'id': '1', 'time': '09:00 AM', 'title': 'Meiji Shrine Walking Tour'},
    {'id': '2', 'time': '12:30 PM', 'title': 'Lunch at Local Market'},
    {'id': '3', 'time': '03:00 PM', 'title': 'Shopping in Shibuya'},
  ];

  bool _hasConflict = false;

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _activities.removeAt(oldIndex);
      _activities.insert(newIndex, item);
      _hasConflict = true; // Trigger conflict detection warning demo
    });
  }

  void _removeItem(int index) {
    setState(() {
      _activities.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customize Day Schedule'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('SAVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_hasConflict)
            Container(
              color: Colors.amber.shade100,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Timing Conflict Detected! Check opening hours and travel duration.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          const Padding(
            padding: EdgeInsets.all(12.0),
            child: Text(
              'Drag and drop items to reorder the schedule.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _activities.length,
              onReorder: _onReorder,
              itemBuilder: (context, index) {
                final item = _activities[index];
                return Card(
                  key: ValueKey(item['id']),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.drag_handle),
                    title: Text(item['title']!),
                    subtitle: Text(item['time']!),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _removeItem(index),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Add Activity Dialog
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Activity'),
      ),
    );
  }
}