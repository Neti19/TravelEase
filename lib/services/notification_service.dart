import '../models/itinerary.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// Simulates local notification scheduling for itinerary events
  Future<void> scheduleItineraryReminders(FullItinerary itinerary) async {
    for (var day in itinerary.days) {
      for (var activity in day.activities) {
        // Schedule reminder 30 minutes before activity start time
        final reminderTime = activity.startTime.subtract(const Duration(minutes: 30));

        if (reminderTime.isAfter(DateTime.now())) {
          _scheduleNotification(
            id: activity.id.hashCode,
            title: 'Upcoming Activity: ${activity.title}',
            body: 'Starts at ${_formatTime(activity.startTime)}. Be prepared!',
            scheduledTime: reminderTime,
          );
        }
      }
    }
  }

  /// Sends immediate budget alert notification
  Future<void> sendBudgetAlert({required double currentTotal, required double maxBudget}) async {
    _scheduleNotification(
      id: 9999,
      title: 'Budget Threshold Exceeded!',
      body: 'Your estimated spending (\$${currentTotal.toStringAsFixed(2)}) exceeds target budget (\$${maxBudget.toStringAsFixed(2)}).',
      scheduledTime: DateTime.now(),
    );
  }

  void _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) {
    // Integration hook for flutter_local_notifications plugin
    print('Scheduled Notification [$id] "$title" at $scheduledTime');
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}