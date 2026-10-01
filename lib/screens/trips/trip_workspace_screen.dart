import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../models/trip.dart';
import '../../services/trip_service.dart';

class TripWorkspaceScreen extends StatefulWidget {
  final String tripId;

  const TripWorkspaceScreen({
    super.key,
    required this.tripId,
  });

  @override
  State<TripWorkspaceScreen> createState() =>
      _TripWorkspaceScreenState();
}

class _TripWorkspaceScreenState
    extends State<TripWorkspaceScreen> {
  final TripService _tripService = TripService();

  Trip? _trip;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    try {
      final trip = await _tripService.getTrip(widget.tripId);

      if (!mounted) return;

      if (trip == null) {
        setState(() {
          _loading = false;
          _error = 'This trip could not be found.';
        });
        return;
      }

      setState(() {
        _trip = trip;
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

  void _openFeature(String route) {
    Navigator.pushNamed(
      context,
      route,
      arguments: {
        'tripId': widget.tripId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF172033),
        elevation: 0,
        title: const Text(
          'Trip Workspace',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null || _trip == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 56,
              ),
              const SizedBox(height: 16),
              const Text(
                'Unable to open trip',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? 'Trip not found.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadTrip,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final trip = _trip!;

    final tripTitle = trip.name.trim().isEmpty
        ? (trip.destination.trim().isEmpty
        ? 'My Trip'
        : trip.destination)
        : trip.name;

    final destination = trip.destination.trim().isEmpty
        ? 'Destination not selected'
        : trip.destination;

    return RefreshIndicator(
      onRefresh: _loadTrip,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          20,
          20,
          20,
          32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTripHeader(
              trip,
              tripTitle,
              destination,
            ),

            const SizedBox(height: 24),

            const Text(
              'Plan your trip',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172033),
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Everything for this trip in one place.',
              style: TextStyle(
                color: Color(0xFF687386),
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 18),

            _buildFeatureGrid(),

            const SizedBox(height: 28),

            const Text(
              'Trip details',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172033),
              ),
            ),

            const SizedBox(height: 14),

            _buildDetailsCard(trip),
          ],
        ),
      ),
    );
  }

  Widget _buildTripHeader(
      Trip trip,
      String tripTitle,
      String destination,
      ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E88E5),
            Color(0xFF1565C0),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.20),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.flight_takeoff,
                  color: Colors.white,
                  size: 25,
                ),
              ),

              const Spacer(),

              const Icon(
                Icons.more_horiz,
                color: Colors.white70,
              ),
            ],
          ),

          const SizedBox(height: 22),

          Text(
            tripTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 6),

          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: Colors.white70,
                size: 18,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  destination,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _headerInfo(
                  Icons.calendar_today_outlined,
                  '${trip.numberOfDays} days',
                ),
              ),
              Expanded(
                child: _headerInfo(
                  Icons.people_outline,
                  '${trip.travelersCount} traveler'
                      '${trip.travelersCount == 1 ? '' : 's'}',
                ),
              ),
              Expanded(
                child: _headerInfo(
                  Icons.currency_rupee,
                  '₹${trip.budget.toStringAsFixed(0)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerInfo(
      IconData icon,
      String text,
      ) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white70,
          size: 17,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 1.35,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _featureCard(
          icon: Icons.auto_awesome,
          title: 'Itinerary',
          subtitle: 'Plan your days',
          onTap: () {
            _openFeature(AppRoutes.generateItinerary);
          },
        ),

        _featureCard(
          icon: Icons.explore_outlined,
          title: 'Find Places',
          subtitle: 'Discover attractions',
          onTap: () {
            _openFeature(AppRoutes.touristSpots);
          },
        ),

        _featureCard(
          icon: Icons.alt_route,
          title: 'Optimize Route',
          subtitle: 'Manage your route',
          onTap: () {
            _openFeature(AppRoutes.mapNavigation);
          },
        ),

        _featureCard(
          icon: Icons.hotel_outlined,
          title: 'Hotels',
          subtitle: 'Find accommodation',
          onTap: () {
            _openFeature(AppRoutes.hotelSelection);
          },
        ),

        _featureCard(
          icon: Icons.restaurant_outlined,
          title: 'Restaurants',
          subtitle: 'Find places to eat',
          onTap: () {
            _openFeature(AppRoutes.restaurantSelection);
          },
        ),

        _featureCard(
          icon: Icons.directions_car_outlined,
          title: 'Transport',
          subtitle: 'Choose transport',
          onTap: () {
            _openFeature(AppRoutes.transportSelection);
          },
        ),

        _featureCard(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Expenses',
          subtitle: 'Track trip spending',
          onTap: () {
            _openFeature(AppRoutes.expenseTracker);
          },
        ),
        _featureCard(
          icon: Icons.group_add_rounded,
          title: 'Invite Travelers',
          subtitle: 'Plan this trip together',
          onTap: () {
            _openFeature(AppRoutes.invitePeople);
          },
        ),
        _featureCard(
          icon: Icons.tune,
          title: 'Preferences',
          subtitle: 'Customize your trip',
          onTap: () {
            _openFeature(AppRoutes.selectPreferences);
          },
        ),
      ],
    );
  }

  Widget _featureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFE7EAF0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3FF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF1E88E5),
                  size: 22,
                ),
              ),

              const Spacer(),

              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF172033),
                ),
              ),

              const SizedBox(height: 3),

              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF7A8496),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsCard(Trip trip) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE7EAF0),
        ),
      ),
      child: Column(
        children: [
          _detailRow(
            Icons.location_on_outlined,
            'Starting from',
            trip.startLocation,
          ),

          const Divider(height: 24),

          _detailRow(
            Icons.calendar_month_outlined,
            'Travel dates',
            '${_formatDate(trip.startDate)} - '
                '${_formatDate(trip.endDate)}',
          ),

          const Divider(height: 24),

          _detailRow(
            Icons.people_outline,
            'Travelers',
            '${trip.travelersCount}',
          ),

          const Divider(height: 24),

          _detailRow(
            Icons.currency_rupee,
            'Budget',
            '₹${trip.budget.toStringAsFixed(0)}',
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
      IconData icon,
      String label,
      String value,
      ) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F4F9),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            size: 20,
            color: const Color(0xFF526071),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF7A8496),
                ),
              ),

              const SizedBox(height: 3),

              Text(
                value.isEmpty ? 'Not available' : value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF172033),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}