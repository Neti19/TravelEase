import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../models/trip.dart';
import '../../services/trip_service.dart';
import '../../widgets/dashboard_navigation_button.dart';

class TripWorkspaceScreen extends StatefulWidget {
  final String tripId;

  const TripWorkspaceScreen({super.key, required this.tripId});

  @override
  State<TripWorkspaceScreen> createState() => _TripWorkspaceScreenState();
}

class _TripWorkspaceScreenState extends State<TripWorkspaceScreen> {
  final TripService _tripService = TripService();

  Trip? _trip;
  bool _isOwner = false;
  bool _loading = true;
  bool _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    try {
      if (mounted) {
        setState(() {
          _loading = true;
          _error = null;
        });
      }

      final trip = await _tripService.getTrip(widget.tripId);
      final isOwner = await _tripService.isTripOwner(widget.tripId);

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
        _isOwner = isOwner;
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
      arguments: {'tripId': widget.tripId},
    ).then((_) {
      _loadTrip();
    });
  }

  Future<void> _deleteTrip() async {
    if (!_canDeleteTrip || _deleting) return;

    final trip = _trip!;
    final tripName = trip.name.trim().isEmpty
        ? (trip.destination.trim().isEmpty ? 'this trip' : trip.destination)
        : trip.name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Delete Trip?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text('Are you sure you want to delete "$tripName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE5484D),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _deleting = true;
    });

    try {
      await _tripService.deleteTrip(widget.tripId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Failed to delete trip: $e'),
            behavior: SnackBarBehavior.fixed,
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _deleting = false;
        });
      }
    }
  }

  bool get _canDeleteTrip {
    final trip = _trip;
    if (!_isOwner || trip == null) return false;
    final status = _tripStatus(trip);
    return status == 'Planning' || status == 'Upcoming';
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: const Color(0xFF102A43),
        elevation: 0,
        titleSpacing: 20,
        title: const Text(
          'Trip workspace',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 21),
        ),
        actions: [
          if (_canDeleteTrip)
            IconButton(
              onPressed: _deleting ? null : _deleteTrip,
              tooltip: 'Delete trip',
              color: const Color(0xFFE5484D),
              icon: _deleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline_rounded),
            ),
          IconButton(
            onPressed: _loadTrip,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
          ),
          const DashboardNavigationButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1677FF)),
      );
    }

    if (_error != null || _trip == null) {
      return _buildErrorState();
    }

    final trip = _trip!;

    final tripTitle = trip.name.trim().isEmpty
        ? (trip.destination.trim().isEmpty ? 'My Trip' : trip.destination)
        : trip.name;

    final destination = trip.destination.trim().isEmpty
        ? 'Destination not selected'
        : trip.destination;

    return RefreshIndicator(
      color: const Color(0xFF1677FF),
      onRefresh: _loadTrip,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 940),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTripHero(trip, tripTitle, destination),

                const SizedBox(height: 18),

                _buildProgressSection(trip),

                const SizedBox(height: 28),

                _buildSectionHeading(
                  'Build your trip',
                  'Choose what you want to plan next.',
                ),

                const SizedBox(height: 14),

                _buildPlanningGrid(),

                const SizedBox(height: 28),

                _buildJourneySection(),

                const SizedBox(height: 28),

                _buildPeopleMoneySection(),

                const SizedBox(height: 26),

                _buildPreferencesTile(),

                const SizedBox(height: 26),

                _buildTripDetails(trip),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // HERO
  // ------------------------------------------------------------

  Widget _buildTripHero(Trip trip, String tripTitle, String destination) {
    final status = _tripStatus(trip);
    final statusData = _statusStyle(status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF124B83), Color(0xFF1677FF)],
        ),
        borderRadius: BorderRadius.circular(27),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1677FF).withValues(alpha: 0.20),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -35,
            top: -45,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            right: 45,
            bottom: -65,
            child: Container(
              width: 115,
              height: 115,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 47,
                    height: 47,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.flight_takeoff_rounded,
                      color: Colors.white,
                      size: 25,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          statusData['icon'] as IconData,
                          size: 13,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 21),

              Text(
                tripTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  height: 1.12,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 7),

              Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    color: Colors.white70,
                    size: 17,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      destination,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 19),

              _buildHeroRoute(trip),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroRoute(Trip trip) {
    final start = trip.startLocation.trim().isEmpty
        ? 'Starting point'
        : trip.startLocation.trim();

    final destination = trip.destination.trim().isEmpty
        ? 'Destination'
        : trip.destination.trim();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          const Icon(Icons.my_location_rounded, size: 16, color: Colors.white),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              start,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 7),
          const Icon(
            Icons.arrow_forward_rounded,
            size: 17,
            color: Colors.white70,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              destination,
              maxLines: 1,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 7),
          const Icon(
            Icons.location_on_rounded,
            size: 16,
            color: Color(0xFFFFB199),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // PROGRESS
  // ------------------------------------------------------------

  Widget _buildProgressSection(Trip trip) {
    final hasDestination = trip.destination.trim().isNotEmpty;

    final hasStart = trip.startLocation.trim().isNotEmpty;

    final completedSteps = (hasStart ? 1 : 0) + (hasDestination ? 1 : 0);

    const totalSteps = 5;

    final progress = completedSteps / totalSteps;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE6F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF4FF),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF1677FF),
              size: 22,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Planning progress',
                        style: TextStyle(
                          color: Color(0xFF102A43),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '$completedSteps/$totalSteps',
                      style: const TextStyle(
                        color: Color(0xFF1677FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE5EDF5),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF1677FF),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  hasDestination
                      ? 'Great start! Explore the tools below to finish planning.'
                      : 'Choose a destination to continue building your trip.',
                  style: const TextStyle(
                    color: Color(0xFF627D98),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // SECTION HEADING
  // ------------------------------------------------------------

  Widget _buildSectionHeading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF102A43),
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF718096), fontSize: 12.5),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // PLANNING GRID
  // ------------------------------------------------------------

  Widget _buildPlanningGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 460 ? 1 : 2;
        final tileWidth = (constraints.maxWidth - (columns - 1) * 12) / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: tileWidth,
              child: _buildPlanningTile(
                icon: Icons.explore_rounded,
                title: 'Places',
                subtitle: 'Discover points of interest',
                color: const Color(0xFF1677FF),
                background: const Color(0xFFEAF4FF),
                onTap: () => _openFeature(AppRoutes.touristSpots),
              ),
            ),
            SizedBox(
              width: tileWidth,
              child: _buildPlanningTile(
                icon: Icons.hotel_rounded,
                title: 'Stay',
                subtitle: 'Find hotels and stays',
                color: const Color(0xFF7257C7),
                background: const Color(0xFFF1ECFF),
                onTap: () => _openFeature(AppRoutes.hotelSelection),
              ),
            ),
            SizedBox(
              width: tileWidth,
              child: _buildPlanningTile(
                icon: Icons.restaurant_rounded,
                title: 'Food',
                subtitle: 'Choose where to eat',
                color: const Color(0xFFE07817),
                background: const Color(0xFFFFF2E6),
                onTap: () => _openFeature(AppRoutes.restaurantSelection),
              ),
            ),
            SizedBox(
              width: tileWidth,
              child: _buildPlanningTile(
                icon: Icons.directions_car_rounded,
                title: 'Transport',
                subtitle: 'Plan how to get around',
                color: const Color(0xFF16805C),
                background: const Color(0xFFEAF8F2),
                onTap: () => _openFeature(AppRoutes.transportSelection),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlanningTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color background,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 88,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE3E9F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF102A43),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF718096),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: color.withValues(alpha: 0.75),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // JOURNEY
  // ------------------------------------------------------------

  Widget _buildJourneySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeading(
          'Your journey',
          'Turn your plans into a smooth travel day.',
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: const Color(0xFFE3E9F0)),
          ),
          child: Column(
            children: [
              _buildJourneyRow(
                icon: Icons.auto_awesome_rounded,
                iconColor: const Color(0xFF7257C7),
                background: const Color(0xFFF1ECFF),
                title: 'Itinerary',
                subtitle: 'Build your day-by-day plan',
                trailing: 'Plan days',
                onTap: () {
                  _openFeature(AppRoutes.generateItinerary);
                },
              ),
              _journeyDivider(),
              _buildJourneyRow(
                icon: Icons.alt_route_rounded,
                iconColor: const Color(0xFF1677FF),
                background: const Color(0xFFEAF4FF),
                title: 'Route & Map',
                subtitle: 'Optimize stops and directions',
                trailing: 'Open map',
                onTap: () {
                  _openFeature(AppRoutes.mapNavigation);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildJourneyRow({
    required IconData icon,
    required Color iconColor,
    required Color background,
    required String title,
    required String subtitle,
    required String trailing,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(23),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 47,
                height: 47,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: iconColor, size: 23),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF102A43),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF7A8496),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  trailing,
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Color(0xFF9AA5B1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _journeyDivider() {
    return const Padding(
      padding: EdgeInsets.only(left: 75, right: 15),
      child: Divider(height: 1, color: Color(0xFFEDF1F5)),
    );
  }

  // ------------------------------------------------------------
  // PEOPLE + MONEY
  // ------------------------------------------------------------

  Widget _buildPeopleMoneySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeading(
          'Travel together',
          'Keep your people and spending organized.',
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _buildPeopleCard()),
            const SizedBox(width: 12),
            Expanded(child: _buildExpenseCard()),
          ],
        ),
      ],
    );
  }

  Widget _buildPeopleCard() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () {
          _openFeature(AppRoutes.invitePeople);
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 145,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE3E9F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF8F2),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.group_add_rounded,
                  color: Color(0xFF16805C),
                  size: 21,
                ),
              ),
              const Spacer(),
              const Text(
                'Invite Friends',
                style: TextStyle(
                  color: Color(0xFF102A43),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Plan together',
                style: TextStyle(color: Color(0xFF718096), fontSize: 10.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseCard() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () {
          _openFeature(AppRoutes.expenseTracker);
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 145,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE3E9F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF2E6),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Color(0xFFE07817),
                  size: 21,
                ),
              ),
              const Spacer(),
              const Text(
                'Split Expenses',
                style: TextStyle(
                  color: Color(0xFF102A43),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Share costs & settle up',
                style: TextStyle(color: Color(0xFF718096), fontSize: 10.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // PREFERENCES
  // ------------------------------------------------------------

  Widget _buildPreferencesTile() {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () {
          _openFeature(AppRoutes.selectPreferences);
        },
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: Color(0xFF526071),
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trip Preferences',
                      style: TextStyle(
                        color: Color(0xFF102A43),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Fine-tune what you want from your trip',
                      style: TextStyle(
                        color: Color(0xFF7A8496),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Color(0xFF9AA5B1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // TRIP DETAILS
  // ------------------------------------------------------------

  Widget _buildTripDetails(Trip trip) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeading(
          'Trip information',
          'A quick look at the basics you started with.',
        ),
        const SizedBox(height: 13),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: const Color(0xFFE3E9F0)),
          ),
          child: Column(
            children: [
              _detailRow(
                icon: Icons.my_location_rounded,
                iconColor: const Color(0xFF1677FF),
                background: const Color(0xFFEAF4FF),
                label: 'Starting from',
                value: trip.startLocation,
              ),
              const SizedBox(height: 13),
              _detailDivider(),
              const SizedBox(height: 13),
              _detailRow(
                icon: Icons.calendar_month_rounded,
                iconColor: const Color(0xFFE07817),
                background: const Color(0xFFFFF2E6),
                label: 'Travel dates',
                value:
                    '${_formatDate(trip.startDate)} - '
                    '${_formatDate(trip.endDate)}',
              ),
              const SizedBox(height: 13),
              _detailDivider(),
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(
                    child: _miniDetail(
                      Icons.people_alt_rounded,
                      '${trip.travelersCount}',
                      'Travelers',
                      const Color(0xFF16805C),
                      const Color(0xFFEAF8F2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _miniDetail(
                      Icons.currency_rupee_rounded,
                      '₹${trip.budget.toStringAsFixed(0)}',
                      'Budget',
                      const Color(0xFF7257C7),
                      const Color(0xFFF1ECFF),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailRow({
    required IconData icon,
    required Color iconColor,
    required Color background,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF8290A3),
                  fontSize: 10.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value.isEmpty ? 'Not available' : value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF102A43),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _miniDetail(
    IconData icon,
    String value,
    String label,
    Color color,
    Color background,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.70),
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailDivider() {
    return const Divider(height: 1, color: Color(0xFFEDF1F5));
  }

  // ------------------------------------------------------------
  // ERROR
  // ------------------------------------------------------------

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEEE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 36,
                color: Color(0xFFE5484D),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Unable to open trip',
              style: TextStyle(
                color: Color(0xFF102A43),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Trip not found.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF718096), fontSize: 13),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _loadTrip,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // STATUS
  // ------------------------------------------------------------

  String _tripStatus(Trip trip) {
    final now = DateTime.now();

    final start = DateTime(
      trip.startDate.year,
      trip.startDate.month,
      trip.startDate.day,
    );

    final end = DateTime(
      trip.endDate.year,
      trip.endDate.month,
      trip.endDate.day,
    );

    final today = DateTime(now.year, now.month, now.day);

    if (today.isAfter(end)) {
      return 'Completed';
    }

    if (!today.isBefore(start) && !today.isAfter(end)) {
      return 'Ongoing';
    }

    if (trip.destination.trim().isEmpty) {
      return 'Planning';
    }

    return 'Upcoming';
  }

  Map<String, dynamic> _statusStyle(String status) {
    switch (status) {
      case 'Completed':
        return {'icon': Icons.check_circle_rounded};

      case 'Ongoing':
        return {'icon': Icons.flight_takeoff_rounded};

      case 'Upcoming':
        return {'icon': Icons.event_available_rounded};

      default:
        return {'icon': Icons.edit_calendar_rounded};
    }
  }

  // ------------------------------------------------------------
  // DATE
  // ------------------------------------------------------------

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} '
        '${months[date.month - 1]} '
        '${date.year}';
  }
}
