import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../models/itinerary.dart';

class DayWiseItineraryScreen
    extends StatefulWidget {
  final String tripId;

  const DayWiseItineraryScreen({
    super.key,
    required this.tripId,
  });

  @override
  State<DayWiseItineraryScreen>
  createState() =>
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
      final snapshot =
      await FirebaseFirestore
          .instance
          .collection('trips')
          .doc(widget.tripId)
          .get();

      if (!snapshot.exists) {
        throw Exception(
          'Trip not found.',
        );
      }

      final data =
      snapshot.data()!;

      final itineraryData =
      data['itinerary'];

      if (itineraryData is! Map) {
        throw Exception(
          'Itinerary has not been generated yet.',
        );
      }

      final itinerary =
      FullItinerary.fromJson(
        Map<String, dynamic>.from(
          itineraryData,
        ),
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

  String _formatTime(
      DateTime time,
      ) {
    final hour =
    time.hour == 0
        ? 12
        : time.hour > 12
        ? time.hour - 12
        : time.hour;

    final minute =
    time.minute.toString().padLeft(
      2,
      '0',
    );

    final period =
    time.hour >= 12
        ? 'PM'
        : 'AM';

    return '$hour:$minute $period';
  }

  String _typeText(
      ActivityType type,
      ) {
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

  IconData _typeIcon(
      ActivityType type,
      ) {
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

  @override
  Widget build(
      BuildContext context,
      ) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child:
          CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title:
          const Text('Your Trip Plan'),
        ),
        body: Center(
          child: Padding(
            padding:
            const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 60,
                ),
                const SizedBox(
                  height: 16,
                ),
                Text(
                  _error!,
                  textAlign:
                  TextAlign.center,
                ),
                const SizedBox(
                  height: 20,
                ),
                ElevatedButton(
                  onPressed:
                  _loadItinerary,
                  child:
                  const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final itinerary =
    _itinerary!;

    return DefaultTabController(
      length: itinerary.days.length,
      child: Scaffold(
        appBar: AppBar(
          title:
          const Text('Your Trip Plan'),
          actions: [
            IconButton(
              icon:
              const Icon(
                Icons.edit_calendar,
              ),
              tooltip:
              'Customize',
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.customizeItinerary,
                  arguments: {
                    'tripId':
                    widget.tripId,
                  },
                );
              },
            ),
          ],
          bottom: TabBar(
            isScrollable:
            itinerary.days.length > 4,
            tabs: itinerary.days
                .map(
                  (day) => Tab(
                text:
                'Day ${day.dayNumber}',
              ),
            )
                .toList(),
          ),
        ),
        body: TabBarView(
          children: itinerary.days
              .map(
                (day) =>
                _buildDaySchedule(day),
          )
              .toList(),
        ),
        bottomNavigationBar:
        SafeArea(
          child: Padding(
            padding:
            const EdgeInsets.all(16),
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                SizedBox(
                  width:
                  double.infinity,
                  child:
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.expenseTracker,
                        arguments: {
                          'tripId':
                          widget.tripId,
                        },
                      );
                    },
                    icon: const Icon(
                      Icons
                          .account_balance_wallet,
                    ),
                    label: const Text(
                      'Track Trip Expenses',
                    ),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                SizedBox(
                  width:
                  double.infinity,
                  child:
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.mapNavigation,
                        arguments: {
                          'tripId':
                          widget.tripId,
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

  Widget _buildDaySchedule(
      DayItinerary day,
      ) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding:
          const EdgeInsets.all(14),
          child: Text(
            'Day ${day.dayNumber} • '
                '${day.date.day}/'
                '${day.date.month}/'
                '${day.date.year}',
            style:
            const TextStyle(
              fontWeight:
              FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        Expanded(
          child: day.activities.isEmpty
              ? const Center(
            child: Text(
              'No activities scheduled for this day.',
            ),
          )
              : ListView.builder(
            padding:
            const EdgeInsets.fromLTRB(
              16,
              0,
              16,
              20,
            ),
            itemCount:
            day.activities.length,
            itemBuilder:
                (context, index) {
              final activity =
              day.activities[index];

              return Card(
                margin:
                const EdgeInsets.only(
                  bottom: 12,
                ),
                child: ListTile(
                  leading:
                  CircleAvatar(
                    child: Icon(
                      _typeIcon(
                        activity.type,
                      ),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    activity.title,
                    style:
                    const TextStyle(
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${_formatTime(activity.startTime)}'
                        ' - '
                        '${_formatTime(activity.endTime)}\n'
                        '${_typeText(activity.type)}\n'
                        '${activity.description}',
                  ),
                  isThreeLine: true,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}