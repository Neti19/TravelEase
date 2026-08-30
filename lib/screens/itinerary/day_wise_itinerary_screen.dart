import 'package:flutter/material.dart';
import '../../app_routes.dart';

class DayWiseItineraryScreen extends StatelessWidget {
  const DayWiseItineraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Your Trip Plan'),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_calendar),
              tooltip: 'Customize',
              onPressed: () => Navigator.pushNamed(context, AppRoutes.customizeItinerary),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Day 1'),
              Tab(text: 'Day 2'),
              Tab(text: 'Day 3'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDaySchedule(context, dayNumber: 1),
            _buildDaySchedule(context, dayNumber: 2),
            _buildDaySchedule(context, dayNumber: 3),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Opening Navigation Map...')),
            );
          },
          icon: const Icon(Icons.map_outlined),
          label: const Text('Map View'),
        ),
      ),
    );
  }

  Widget _buildDaySchedule(BuildContext context, {required int dayNumber}) {
    final List<Map<String, String>> schedule = dayNumber == 1
        ? [
      {'time': '08:00 AM', 'title': 'Flight Arrival & Pickup', 'type': 'Transport', 'cost': '\$220'},
      {'time': '10:00 AM', 'title': 'Hotel Check-in (Grand Central)', 'type': 'Hotel', 'cost': '\$120'},
      {'time': '11:30 AM', 'title': 'Visit Senso-ji Temple', 'type': 'Spot', 'cost': '\$0'},
      {'time': '01:30 PM', 'title': 'Lunch at Sakura Ramen', 'type': 'Restaurant', 'cost': '\$15'},
      {'time': '03:30 PM', 'title': 'Tokyo Skytree Observation', 'type': 'Spot', 'cost': '\$20'},
    ]
        : [
      {'time': '09:00 AM', 'title': 'Meiji Shrine Walking Tour', 'type': 'Spot', 'cost': '\$0'},
      {'time': '12:30 PM', 'title': 'Lunch at Local Market', 'type': 'Restaurant', 'cost': '\$20'},
      {'time': '03:00 PM', 'title': 'Shopping in Shibuya', 'type': 'Spot', 'cost': '\$50'},
    ];

    return Column(
      children: [
        // Budget & Warning Banner
        Container(
          color: Colors.blue.shade50,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: const [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Route optimized to reduce travel time by 35 mins.',
                  style: TextStyle(fontSize: 13, color: Colors.purple),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: schedule.length,
            itemBuilder: (context, index) {
              final item = schedule[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item['time']!,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                  title: Text(item['title']!, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Type: ${item['type']}'),
                  trailing: Text(item['cost']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}