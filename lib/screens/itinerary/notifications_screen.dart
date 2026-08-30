import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  final List<Map<String, String>> _notifications = const [
    {
      'title': 'Flight Reminder',
      'message': 'Your flight SkyExpress departure is scheduled for tomorrow at 08:00 AM.',
      'time': '2h ago',
      'type': 'reminder',
    },
    {
      'title': 'Budget Warning',
      'message': 'Added activity pushes overall cost close to budget threshold (\$780 / \$1,000).',
      'time': '1d ago',
      'type': 'alert',
    },
    {
      'title': 'Hotel Check-in Reminder',
      'message': 'Grand Central Hotel check-in time starts at 10:00 AM.',
      'time': '2d ago',
      'type': 'reminder',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications & Reminders')),
      body: _notifications.isEmpty
          ? const Center(child: Text('No notifications right now.'))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final item = _notifications[index];
          final isAlert = item['type'] == 'alert';
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isAlert ? Colors.amber.shade100 : Colors.blue.shade100,
                child: Icon(
                  isAlert ? Icons.warning_amber_rounded : Icons.notifications_active,
                  color: isAlert ? Colors.orange : Colors.blue,
                ),
              ),
              title: Text(item['title']!, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(item['message']!),
                  const SizedBox(height: 4),
                  Text(
                    item['time']!,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}