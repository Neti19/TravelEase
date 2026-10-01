import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../models/itinerary.dart';

class DayWiseItineraryScreen extends StatefulWidget {
  final String tripId;

  const DayWiseItineraryScreen({
    super.key,
    required this.tripId,
  });

  @override
  State<DayWiseItineraryScreen> createState() =>
      _DayWiseItineraryScreenState();
}

class _DayWiseItineraryScreenState
    extends State<DayWiseItineraryScreen> {
  FullItinerary? _itinerary;

  bool _loading = true;

  String? _error;

  @override
  void initState() {
    super.initState();
    _loadItinerary();
  }

  Future<void> _loadItinerary() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.tripId)
          .get();

      if (!snapshot.exists) {
        throw Exception('Trip not found.');
      }

      final data = snapshot.data()!;

      final itineraryData = data['itinerary'];

      if (itineraryData is! Map) {
        throw Exception(
          'Itinerary has not been generated yet.',
        );
      }

      final itinerary = FullItinerary.fromJson(
        Map<String, dynamic>.from(itineraryData),
      );

      if (!mounted) return;

      setState(() {
        _itinerary = itinerary;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _formatTime(DateTime time) {
    final hour = time.hour == 0
        ? 12
        : time.hour > 12
        ? time.hour - 12
        : time.hour;

    final minute = time.minute.toString().padLeft(2, '0');

    final period = time.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  String _typeText(ActivityType type) {
    switch (type) {
      case ActivityType.spot:
        return 'Tourist Place';

      case ActivityType.transport:
        return 'Transport';

      case ActivityType.hotel:
        return 'Hotel';

      case ActivityType.restaurant:
        return 'Restaurant';
    }
  }

  IconData _typeIcon(ActivityType type) {
    switch (type) {
      case ActivityType.spot:
        return Icons.place;

      case ActivityType.transport:
        return Icons.directions_car;

      case ActivityType.hotel:
        return Icons.hotel;

      case ActivityType.restaurant:
        return Icons.restaurant;
    }
  }

  String _timePeriod(DateTime time) {
    if (time.hour < 12) {
      return 'Morning';
    }

    if (time.hour < 17) {
      return 'Afternoon';
    }

    return 'Evening';
  }

  IconData _periodIcon(String period) {
    switch (period) {
      case 'Morning':
        return Icons.wb_sunny_outlined;

      case 'Afternoon':
        return Icons.wb_sunny;

      case 'Evening':
        return Icons.nights_stay_outlined;

      default:
        return Icons.schedule;
    }
  }

  Widget _buildPeriodSection({
    required String period,
    required List<ItineraryActivity> activities,
  }) {
    if (activities.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF3FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _periodIcon(period),
                color: const Color(0xFF1E88E5),
                size: 20,
              ),
            ),

            const SizedBox(width: 10),

            Text(
              period,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172033),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        ...activities.map(
              (activity) => _buildActivityCard(activity),
        ),

        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildActivityCard(ItineraryActivity activity) {
    final bool hasCost = activity.cost > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE7EAF0),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF3FF),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                _typeIcon(activity.type),
                color: const Color(0xFF1E88E5),
                size: 22,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF172033),
                    ),
                  ),

                  const SizedBox(height: 6),

                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 15,
                        color: Color(0xFF687386),
                      ),

                      const SizedBox(width: 5),

                      Expanded(
                        child: Text(
                          '${_formatTime(activity.startTime)} - '
                              '${_formatTime(activity.endTime)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF687386),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 5),

                  Text(
                    _typeText(activity.type),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1E88E5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  if (activity.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 7),

                    Text(
                      activity.description,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: Color(0xFF687386),
                      ),
                    ),
                  ],

                  // Only show cost when the activity actually has a cost.
                  if (hasCost) ...[
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        const Icon(
                          Icons.currency_rupee,
                          size: 14,
                          color: Color(0xFF687386),
                        ),

                        const SizedBox(width: 3),

                        Text(
                          activity.cost.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF687386),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Your Trip Plan'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 60,
                ),

                const SizedBox(height: 16),

                Text(
                  _error!,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });

                    _loadItinerary();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final itinerary = _itinerary!;

    if (itinerary.days.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Your Trip Plan'),
        ),
        body: const Center(
          child: Text(
            'No itinerary days are available.',
          ),
        ),
      );
    }

    return DefaultTabController(
      length: itinerary.days.length,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F8FC),

        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF172033),
          elevation: 0,

          title: const Text(
            'Your Trip Plan',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),

          actions: [
            IconButton(
              icon: const Icon(
                Icons.edit_calendar,
              ),
              tooltip: 'Customize',
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.customizeItinerary,
                  arguments: {
                    'tripId': widget.tripId,
                  },
                );
              },
            ),
          ],

          bottom: TabBar(
            isScrollable: itinerary.days.length > 4,
            tabs: itinerary.days
                .map(
                  (day) => Tab(
                text: 'Day ${day.dayNumber}',
              ),
            )
                .toList(),
          ),
        ),

        body: TabBarView(
          children: itinerary.days
              .map(
                (day) => _buildDaySchedule(day),
          )
              .toList(),
        ),

        bottomNavigationBar: SafeArea(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.expenseTracker,
                        arguments: {
                          'tripId': widget.tripId,
                        },
                      );
                    },
                    icon: const Icon(
                      Icons.account_balance_wallet,
                    ),
                    label: const Text(
                      'Track Trip Expenses',
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.mapNavigation,
                        arguments: {
                          'tripId': widget.tripId,
                        },
                      );
                    },
                    icon: const Icon(
                      Icons.map,
                    ),
                    label: const Text(
                      'Open Route Map',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDaySchedule(DayItinerary day) {
    final morningActivities = day.activities
        .where(
          (activity) =>
      _timePeriod(activity.startTime) == 'Morning',
    )
        .toList();

    final afternoonActivities = day.activities
        .where(
          (activity) =>
      _timePeriod(activity.startTime) == 'Afternoon',
    )
        .toList();

    final eveningActivities = day.activities
        .where(
          (activity) =>
      _timePeriod(activity.startTime) == 'Evening',
    )
        .toList();

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(
            20,
            16,
            20,
            16,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3FF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.calendar_today_outlined,
                  color: Color(0xFF1E88E5),
                ),
              ),

              const SizedBox(width: 12),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Day ${day.dayNumber}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF172033),
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    '${day.date.day}/'
                        '${day.date.month}/'
                        '${day.date.year}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF687386),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: day.activities.isEmpty
              ? const Center(
            child: Text(
              'No activities scheduled for this day.',
            ),
          )
              : ListView(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              24,
            ),
            children: [
              _buildPeriodSection(
                period: 'Morning',
                activities: morningActivities,
              ),

              _buildPeriodSection(
                period: 'Afternoon',
                activities: afternoonActivities,
              ),

              _buildPeriodSection(
                period: 'Evening',
                activities: eveningActivities,
              ),
            ],
          ),
        ),
      ],
    );
  }
}