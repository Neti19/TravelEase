import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../models/trip.dart';
import '../../services/trip_service.dart';
import '../../widgets/dashboard_navigation_button.dart';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> {
  final TripService _tripService = TripService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Trip> _trips = [];
  final Map<String, bool> _ownership = {};

  bool _loading = true;
  String? _error;

  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // LOAD TRIPS
  // ------------------------------------------------------------

  Future<void> _loadTrips() async {
    try {
      if (mounted) {
        setState(() {
          _loading = true;
          _error = null;
        });
      }

      final trips = await _tripService.getUserTrips();

      final user = _auth.currentUser;
      final ownership = <String, bool>{};

      if (user != null) {
        for (final trip in trips) {
          ownership[trip.id] = await _isTripOwner(trip.id, user.uid);
        }
      }

      if (!mounted) return;

      setState(() {
        _trips = trips;
        _ownership
          ..clear()
          ..addAll(ownership);
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

  // ------------------------------------------------------------
  // CHECK OWNER
  // ------------------------------------------------------------

  Future<bool> _isTripOwner(String tripId, String userId) async {
    final snapshot = await _firestore.collection('trips').doc(tripId).get();

    if (!snapshot.exists) {
      return false;
    }

    final data = snapshot.data();

    return data?['userId']?.toString() == userId;
  }

  // ------------------------------------------------------------
  // DELETE TRIP
  // ------------------------------------------------------------

  Future<void> _deleteTrip(Trip trip) async {
    if (!_canDeleteTrip(trip)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Only the owner can delete a planning or upcoming trip.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Delete Trip?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Text(
            'Are you sure you want to delete '
            '"${trip.name.isEmpty ? trip.destination : trip.name}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE5484D),
              ),
              onPressed: () {
                Navigator.pop(context, true);
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
      await _tripService.deleteTrip(trip.id);

      if (!mounted) return;

      setState(() {
        _trips.removeWhere((item) => item.id == trip.id);

        _ownership.remove(trip.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trip deleted successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete trip: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  bool _canDeleteTrip(Trip trip) {
    final status = _tripStatus(trip);
    return _ownership[trip.id] == true &&
        (status == 'Planning' || status == 'Upcoming');
  }

  // ------------------------------------------------------------
  // OPEN TRIP
  // ------------------------------------------------------------

  void _openTrip(Trip trip) {
    if (trip.id.isEmpty) {
      return;
    }

    Navigator.pushNamed(
      context,
      AppRoutes.tripWorkspace,
      arguments: {'tripId': trip.id},
    ).then((_) => _loadTrips());
  }

  // ------------------------------------------------------------
  // NEW TRIP / JOIN TRIP
  // ------------------------------------------------------------

  void _showTripActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9E2EC),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'What would you like to do?',
                style: TextStyle(
                  color: Color(0xFF102A43),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),

              _actionSheetTile(
                icon: Icons.add_rounded,
                iconColor: const Color(0xFF1677FF),
                iconBackground: const Color(0xFFEAF3FF),
                title: 'Create New Trip',
                subtitle: 'Plan your own adventure',
                onTap: () {
                  Navigator.pop(sheetContext);

                  Navigator.pushNamed(context, AppRoutes.tripDetails).then((_) {
                    _loadTrips();
                  });
                },
              ),

              const SizedBox(height: 8),

              _actionSheetTile(
                icon: Icons.group_add_rounded,
                iconColor: const Color(0xFF16805C),
                iconBackground: const Color(0xFFEAF8F2),
                title: 'Join a Trip',
                subtitle: 'Enter a trip code from a friend',
                onTap: () async {
                  Navigator.pop(sheetContext);

                  final result = await Navigator.pushNamed(
                    context,
                    AppRoutes.joinTrip,
                  );

                  if (result != null) {
                    await _loadTrips();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _actionSheetTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFF7FAFC),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: iconColor, size: 24),
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
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF718096),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: Color(0xFF9AA5B1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // DATE / STATUS
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

    return '${date.day} ${months[date.month - 1]}';
  }

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

  List<Trip> get _filteredTrips {
    final query = _searchController.text.trim().toLowerCase();

    return _trips.where((trip) {
      final matchesStatus =
          _selectedFilter == 'All' || _tripStatus(trip) == _selectedFilter;
      final matchesSearch =
          query.isEmpty ||
          trip.name.toLowerCase().contains(query) ||
          trip.destination.toLowerCase().contains(query);

      return matchesStatus && matchesSearch;
    }).toList();
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7FAFC),
        foregroundColor: const Color(0xFF102A43),
        elevation: 0,
        titleSpacing: 20,
        title: const Text(
          'My Trips',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
        ),
        actions: [
          const DashboardNavigationButton(),
          IconButton(
            onPressed: _loadTrips,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showTripActions,
        backgroundColor: const Color(0xFF1677FF),
        foregroundColor: Colors.white,
        elevation: 5,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Trip',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // BODY
  // ------------------------------------------------------------

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1677FF)),
      );
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_trips.isEmpty) {
      return _buildEmptyState();
    }

    final trips = _filteredTrips;

    return RefreshIndicator(
      color: const Color(0xFF1677FF),
      onRefresh: _loadTrips,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
        children: [
          _buildIntro(),

          const SizedBox(height: 20),

          _buildTripSearch(),

          const SizedBox(height: 14),

          _buildFilters(),

          const SizedBox(height: 20),

          if (trips.isEmpty)
            _buildFilterEmpty()
          else
            ...trips.map(
              (trip) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildTripCard(trip),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTripSearch() {
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search trips by name or destination',
        hintStyle: const TextStyle(color: Color(0xFF8290A3), fontSize: 13),
        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF627D98)),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  _searchController.clear();
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE1E7EF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF1677FF), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildIntro() {
    final upcomingCount = _trips.where((trip) {
      final status = _tripStatus(trip);
      return status == 'Upcoming' ||
          status == 'Planning' ||
          status == 'Ongoing';
    }).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEAF4FF), Color(0xFFF3F9FF)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD7E9FF)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(17),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1677FF).withValues(alpha: 0.10),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.luggage_rounded,
              color: Color(0xFF1677FF),
              size: 27,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your travel board',
                  style: TextStyle(
                    color: Color(0xFF102A43),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  upcomingCount == 0
                      ? 'Ready when you are for your next adventure.'
                      : '$upcomingCount active trip'
                            '${upcomingCount == 1 ? '' : 's'} in your plans.',
                  style: const TextStyle(
                    color: Color(0xFF627D98),
                    fontSize: 12.5,
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

  Widget _buildFilters() {
    final filters = ['All', 'Planning', 'Upcoming', 'Ongoing', 'Completed'];

    return SizedBox(
      height: 39,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) {
          return const SizedBox(width: 8);
        },
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected = _selectedFilter == filter;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = filter;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF1677FF) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF1677FF)
                      : const Color(0xFFE1E7EF),
                ),
              ),
              child: Center(
                child: Text(
                  filter,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF526071),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // TRIP CARD
  // ------------------------------------------------------------

  Widget _buildTripCard(Trip trip) {
    final destination = trip.destination.trim().isEmpty
        ? 'Destination not selected'
        : trip.destination.trim();

    final title = trip.name.trim().isEmpty ? destination : trip.name.trim();

    final status = _tripStatus(trip);

    final hasDestination = trip.destination.trim().isNotEmpty;

    final progress = hasDestination ? 0.45 : 0.18;

    final statusData = _statusStyle(status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openTrip(trip),
        borderRadius: BorderRadius.circular(25),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: const Color(0xFFE4EAF1)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF102A43).withValues(alpha: 0.055),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildCardTopStrip(
                trip: trip,
                status: status,
                statusData: statusData,
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(18, 17, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF102A43),
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_rounded,
                                    size: 15,
                                    color: Color(0xFF1677FF),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      destination,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF627D98),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    _buildRouteLine(trip: trip, destination: destination),

                    const SizedBox(height: 18),

                    _buildTripStats(trip),

                    const SizedBox(height: 17),

                    _buildPlanningProgress(
                      progress: progress,
                      hasDestination: hasDestination,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardTopStrip({
    required Trip trip,
    required String status,
    required Map<String, dynamic> statusData,
  }) {
    final isOwner = _ownership[trip.id] == true;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 13, 14, 13),
      decoration: BoxDecoration(
        color: statusData['background'] as Color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Row(
        children: [
          Icon(
            statusData['icon'] as IconData,
            size: 16,
            color: statusData['foreground'] as Color,
          ),
          const SizedBox(width: 7),
          Text(
            status,
            style: TextStyle(
              color: statusData['foreground'] as Color,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  isOwner ? Icons.person_rounded : Icons.group_rounded,
                  size: 13,
                  color: isOwner
                      ? const Color(0xFF1677FF)
                      : const Color(0xFF16805C),
                ),
                const SizedBox(width: 4),
                Text(
                  isOwner ? 'Owner' : 'Joined',
                  style: TextStyle(
                    color: isOwner
                        ? const Color(0xFF1677FF)
                        : const Color(0xFF16805C),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if (_canDeleteTrip(trip)) ...[
            const SizedBox(width: 8),
            SizedBox(
              height: 30,
              child: FilledButton.icon(
                onPressed: () => _deleteTrip(trip),
                icon: const Icon(Icons.delete_outline_rounded, size: 14),
                label: const Text('Delete'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE5484D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Map<String, dynamic> _statusStyle(String status) {
    switch (status) {
      case 'Completed':
        return {
          'background': const Color(0xFFEAF8F2),
          'foreground': const Color(0xFF16805C),
          'icon': Icons.check_circle_rounded,
        };

      case 'Ongoing':
        return {
          'background': const Color(0xFFFFF4E8),
          'foreground': const Color(0xFFE07817),
          'icon': Icons.flight_takeoff_rounded,
        };

      case 'Upcoming':
        return {
          'background': const Color(0xFFEAF3FF),
          'foreground': const Color(0xFF1677FF),
          'icon': Icons.event_available_rounded,
        };

      default:
        return {
          'background': const Color(0xFFF2EEFF),
          'foreground': const Color(0xFF7257C7),
          'icon': Icons.edit_calendar_rounded,
        };
    }
  }

  Widget _buildRouteLine({required Trip trip, required String destination}) {
    final start = trip.startLocation.trim().isEmpty
        ? 'Starting point'
        : trip.startLocation.trim();

    return Row(
      children: [
        _routePoint(
          color: const Color(0xFF1677FF),
          icon: Icons.my_location_rounded,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: const Color(0xFFBBD8FF),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 7),
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF4FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.flight_rounded,
                      size: 14,
                      color: Color(0xFF1677FF),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: const Color(0xFFBBD8FF),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      start,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF627D98),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      destination,
                      maxLines: 1,
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF627D98),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 9),
        _routePoint(
          color: const Color(0xFFFF8A65),
          icon: Icons.location_on_rounded,
        ),
      ],
    );
  }

  Widget _routePoint({required Color color, required IconData icon}) {
    return Container(
      width: 31,
      height: 31,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }

  Widget _buildTripStats(Trip trip) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFEDF1F5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _compactStat(
              Icons.calendar_month_rounded,
              '${_formatDate(trip.startDate)}',
              'Start',
            ),
          ),
          _statDivider(),
          Expanded(
            child: _compactStat(
              Icons.wb_sunny_rounded,
              '${trip.numberOfDays} day'
                  '${trip.numberOfDays == 1 ? '' : 's'}',
              'Duration',
            ),
          ),
          _statDivider(),
          Expanded(
            child: _compactStat(
              Icons.people_alt_rounded,
              '${trip.travelersCount}',
              'Travelers',
            ),
          ),
          _statDivider(),
          Expanded(
            child: _compactStat(
              Icons.currency_rupee_rounded,
              '₹${trip.budget.toStringAsFixed(0)}',
              'Budget',
            ),
          ),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(width: 1, height: 30, color: const Color(0xFFE2E8F0));
  }

  Widget _compactStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF1677FF)),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF102A43),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8290A3), fontSize: 9.5),
        ),
      ],
    );
  }

  Widget _buildPlanningProgress({
    required double progress,
    required bool hasDestination,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Trip setup',
              style: TextStyle(
                color: Color(0xFF526071),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              hasDestination
                  ? 'Destination selected'
                  : 'Choose a destination next',
              style: TextStyle(
                color: hasDestination
                    ? const Color(0xFF16805C)
                    : const Color(0xFFE07817),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: const Color(0xFFE8EDF3),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1677FF)),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // EMPTY / ERROR
  // ------------------------------------------------------------

  Widget _buildFilterEmpty() {
    final searching = _searchController.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE3E9F0)),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF4FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              searching
                  ? Icons.search_off_rounded
                  : Icons.filter_alt_off_rounded,
              color: const Color(0xFF1677FF),
              size: 28,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            searching ? 'No matching trips' : 'No trips in this category',
            style: TextStyle(
              color: Color(0xFF102A43),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            searching
                ? 'Try a different name or destination, or clear your search.'
                : 'Try another filter to see your trips.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF718096), fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF4FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.travel_explore_rounded,
                size: 48,
                color: Color(0xFF1677FF),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Your travel board is empty',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF102A43),
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 9),
            const Text(
              'Create a trip or join one from a friend. '
              'Your adventures will live here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF718096),
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _showTripActions,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1677FF),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Start a Trip',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEEE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 35,
                color: Color(0xFFE5484D),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Unable to load trips',
              style: TextStyle(
                color: Color(0xFF102A43),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF718096), fontSize: 13),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _loadTrips,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
