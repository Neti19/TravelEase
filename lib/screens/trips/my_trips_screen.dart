import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../models/trip.dart';
import '../../services/trip_service.dart';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() =>
      _MyTripsScreenState();
}

class _MyTripsScreenState
    extends State<MyTripsScreen> {
  final TripService _tripService =
      TripService();

  List<Trip> _trips = [];

  bool _loading = true;

  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final trips =
          await _tripService.getUserTrips();

      if (!mounted) return;

      setState(() {
        _trips = trips;
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _deleteTrip(Trip trip) async {
    final confirm =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Delete Trip?',
          ),
          content: Text(
            'Are you sure you want to delete '
            'the trip from ${trip.startLocation} '
            'to ${trip.destination.isEmpty ? 'your destination' : trip.destination}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      await _tripService.deleteTrip(
        trip.id,
      );

      if (!mounted) return;

      setState(() {
        _trips.removeWhere(
          (item) => item.id == trip.id,
        );
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Trip deleted successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete trip: $e',
          ),
        ),
      );
    }
  }

  void _openItinerary(Trip trip) {
    Navigator.pushNamed(
      context,
      AppRoutes.dayWiseItinerary,
      arguments: {
        'tripId': trip.id,
      },
    );
  }

  void _openTrip(Trip trip) {
    if (trip.id.isEmpty) {
      return;
    }

    _openItinerary(trip);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Trips',
        ),
        actions: [
          IconButton(
            onPressed: _loadTrips,
            icon: const Icon(
              Icons.refresh,
            ),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(
            context,
            AppRoutes.tripDetails,
          ).then((_) {
            _loadTrips();
          });
        },
        icon: const Icon(
          Icons.add,
        ),
        label: const Text(
          'New Trip',
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
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
              const Text(
                'Unable to load trips',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              const SizedBox(
                height: 12,
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
                onPressed: _loadTrips,
                child:
                    const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_trips.isEmpty) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.luggage_outlined,
                size: 80,
              ),
              const SizedBox(
                height: 20,
              ),
              const Text(
                'No Trips Yet',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              const Text(
                'Create your first trip and your itinerary will appear here.',
                textAlign:
                    TextAlign.center,
              ),
              const SizedBox(
                height: 24,
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.tripDetails,
                  ).then((_) {
                    _loadTrips();
                  });
                },
                icon: const Icon(
                  Icons.add,
                ),
                label: const Text(
                  'Plan New Trip',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTrips,
      child: ListView.builder(
        padding:
            const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          100,
        ),
        itemCount: _trips.length,
        itemBuilder:
            (context, index) {
          final trip = _trips[index];

          return _buildTripCard(trip);
        },
      ),
    );
  }

  Widget _buildTripCard(Trip trip) {
    final destination =
        trip.destination.isEmpty
            ? 'Destination not selected'
            : trip.destination;

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 16,
      ),
      elevation: 3,
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  child: const Icon(
                    Icons.flight_takeoff,
                  ),
                ),
                const SizedBox(
                  width: 12,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        destination,
                        style:
                            const TextStyle(
                          fontSize: 19,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        'From: ${trip.startLocation}',
                        maxLines: 2,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value ==
                        'delete') {
                      _deleteTrip(trip);
                    }
                  },
                  itemBuilder:
                      (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                          ),
                          SizedBox(
                            width: 8,
                          ),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(
              height: 16,
            ),

            const Divider(),

            const SizedBox(
              height: 8,
            ),

            Row(
              children: [
                Expanded(
                  child: _infoItem(
                    Icons.calendar_today,
                    '${_formatDate(trip.startDate)}'
                    ' - '
                    '${_formatDate(trip.endDate)}',
                  ),
                ),
                Expanded(
                  child: _infoItem(
                    Icons.wb_sunny_outlined,
                    '${trip.numberOfDays} days',
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 12,
            ),

            Row(
              children: [
                Expanded(
                  child: _infoItem(
                    Icons.people_outline,
                    '${trip.travelersCount} traveler'
                    '${trip.travelersCount == 1 ? '' : 's'}',
                  ),
                ),
                Expanded(
                  child: _infoItem(
                    Icons.currency_rupee,
                    '₹${trip.budget.toStringAsFixed(0)}',
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 16,
            ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    () => _openTrip(trip),
                icon: const Icon(
                  Icons.event_note,
                ),
                label: const Text(
                  'View Itinerary',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoItem(
    IconData icon,
    String text,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.blue,
        ),
        const SizedBox(
          width: 8,
        ),
        Expanded(
          child: Text(
            text,
            overflow:
                TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}