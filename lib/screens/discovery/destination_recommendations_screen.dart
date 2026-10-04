import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../services/destination_recommendation_service.dart';
import '../../services/help_me_choose_trip_service.dart';
import '../../widgets/dashboard_navigation_button.dart';

class DestinationRecommendationsScreen extends StatefulWidget {
  final String experience;
  final String travelerType;
  final String duration;
  final double budget;

  const DestinationRecommendationsScreen({
    super.key,
    required this.experience,
    required this.travelerType,
    required this.duration,
    required this.budget,
  });

  @override
  State<DestinationRecommendationsScreen> createState() =>
      _DestinationRecommendationsScreenState();
}

class _DestinationRecommendationsScreenState
    extends State<DestinationRecommendationsScreen>
    with SingleTickerProviderStateMixin {
  final DestinationRecommendationService _service =
  DestinationRecommendationService();

  late Future<List<RecommendedDestination>> _recommendationsFuture;

  late AnimationController _animationController;

  final HelpMeChooseTripService _tripPlanner =
  HelpMeChooseTripService();

  String? _planningDestinationId;

  @override
  void initState() {
    super.initState();

    _recommendationsFuture = _loadRecommendations();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _animationController.forward();
  }

  Future<List<RecommendedDestination>> _loadRecommendations() {
    return _service.getRecommendations(
      experience: widget.experience,
      travelerType: widget.travelerType,
      duration: widget.duration,
      budget: widget.budget,
    );
  }

  void _retry() {
    setState(() {
      _recommendationsFuture = _loadRecommendations();
    });
  }

  Future<void> _planTrip(RecommendedDestination destination) async {
    if (_planningDestinationId != null) {
      return;
    }

    setState(() {
      _planningDestinationId = destination.id;
    });

    try {
      final tripId =
      await _tripPlanner.createTripAndGenerateItinerary(
        destination: destination,
        experience: widget.experience,
        travelerType: widget.travelerType,
        duration: widget.duration,
        budget: widget.budget,
      );

      if (!mounted) return;

      Navigator.pushNamed(
        context,
        AppRoutes.dayWiseItinerary,
        arguments: {
          'tripId': tripId,
        },
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not create this trip: $e',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _planningDestinationId = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      body: SafeArea(
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerRight,
              child: DashboardNavigationButton(),
            ),
            Expanded(
              child: FutureBuilder<List<RecommendedDestination>>(
                future: _recommendationsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoading();
                  }

                  if (snapshot.hasError) {
                    return _buildError(snapshot.error);
                  }

                  final destinations = snapshot.data ?? [];

                  if (destinations.isEmpty) {
                    return _buildEmpty();
                  }

                  return _buildResults(destinations);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF4FF),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFF1677FF),
                ),
              ),
            ),

            const SizedBox(height: 28),

            const Text(
              'Finding your destinations...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF102A43),
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'TravelEase is searching real places and matching them with your preferences.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF627D98),
                fontSize: 14,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: 220,
              child: LinearProgressIndicator(
                minHeight: 6,
                borderRadius: BorderRadius.circular(20),
                backgroundColor: const Color(0xFFE1EAF2),
                color: const Color(0xFF1677FF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(Object? error) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1EF),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 42,
                color: Color(0xFFFF6B57),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'We couldn’t find your destinations',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF102A43),
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'Something went wrong while connecting to the destination service.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF627D98),
                fontSize: 14,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 12),

            if (error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFE1EAF2),
                  ),
                ),
                child: Text(
                  error.toString(),
                  style: const TextStyle(
                    color: Color(0xFF829AB1),
                    fontSize: 11,
                  ),
                ),
              ),

            const SizedBox(height: 22),

            FilledButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1677FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),

            const SizedBox(height: 12),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF4FF),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.travel_explore_rounded,
                size: 44,
                color: Color(0xFF1677FF),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'No matches found',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF102A43),
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'Try changing your preferences and we’ll search again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF627D98),
                fontSize: 14,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 24),

            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1677FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text('Change preferences'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(
      List<RecommendedDestination> destinations,
      ) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _buildTopHeader(destinations.length),
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 36),
          sliver: SliverList.separated(
            itemCount: destinations.length,
            separatorBuilder: (_, __) =>
            const SizedBox(height: 18),
            itemBuilder: (context, index) {
              return _buildDestinationCard(
                destinations[index],
                index,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopHeader(int count) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF1677FF),
            Color(0xFF45A8FF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.all(
          Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor:
                  Colors.white.withOpacity(0.16),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                ),
              ),

              const Spacer(),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count matches',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          const Text(
            '✨ Your travel matches',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Places picked for\nyour next adventure.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              height: 1.08,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'Based on ${widget.experience.toLowerCase()} • '
                '${widget.travelerType.toLowerCase()} • '
                '${widget.duration.toLowerCase()}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.88),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationCard(
      RecommendedDestination destination,
      int index,
      ) {
    final animation = CurvedAnimation(
      parent: _animationController,
      curve: Interval(
        (index * 0.08).clamp(0.0, 0.65),
        1.0,
        curve: Curves.easeOutCubic,
      ),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(
              0,
              24 * (1 - animation.value),
            ),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: const Color(0xFFE1EAF2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.045),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRankBadge(index),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          destination.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF102A43),
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Row(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 15,
                              color: Color(0xFF1677FF),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                destination.address.isEmpty
                                    ? 'Location available in Google Places'
                                    : destination.address,
                                maxLines: 2,
                                overflow:
                                TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF829AB1),
                                  fontSize: 11.5,
                                  height: 1.35,
                                  fontWeight:
                                  FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  _ratingBadge(destination),
                ],
              ),

              const SizedBox(height: 18),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _infoChip(
                    Icons.auto_awesome_rounded,
                    'Match ${destination.score.toStringAsFixed(0)}%',
                  ),
                  _infoChip(
                    Icons.star_rounded,
                    destination.rating > 0
                        ? destination.rating
                        .toStringAsFixed(1)
                        : 'No rating',
                  ),
                  _infoChip(
                    Icons.reviews_rounded,
                    _reviewText(
                      destination.reviewCount,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAFC),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.psychology_alt_rounded,
                      size: 18,
                      color: Color(0xFF1677FF),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _matchReason(destination),
                        style: const TextStyle(
                          color: Color(0xFF486581),
                          fontSize: 11.5,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _planningDestinationId == null
                      ? () => _planTrip(destination)
                      : null,
                  icon: _planningDestinationId == destination.id
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(
                    Icons.flight_takeoff_rounded,
                  ),
                  label: Text(
                    _planningDestinationId == destination.id
                        ? 'Building your trip...'
                        : 'Plan this trip',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                    const Color(0xFF1677FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRankBadge(int index) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFEAF4FF),
            Color(0xFFDFF4FF),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Text(
          '#${index + 1}',
          style: const TextStyle(
            color: Color(0xFF1677FF),
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _ratingBadge(
      RecommendedDestination destination,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5D9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.star_rounded,
            size: 15,
            color: Color(0xFFF2A900),
          ),
          const SizedBox(width: 3),
          Text(
            destination.rating > 0
                ? destination.rating.toStringAsFixed(1)
                : '—',
            style: const TextStyle(
              color: Color(0xFF7A5B00),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(
      IconData icon,
      String text,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: const Color(0xFF1677FF),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF486581),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _reviewText(int count) {
    if (count <= 0) {
      return 'No reviews';
    }

    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M reviews';
    }

    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K reviews';
    }

    return '$count reviews';
  }

  String _matchReason(
      RecommendedDestination destination,
      ) {
    if (destination.score >= 85) {
      return 'Strong match for your preferences with excellent place quality and relevance.';
    }

    if (destination.score >= 70) {
      return 'A good match based on your selected experience and real Google Places data.';
    }

    return 'This place matches some of your preferences and is worth exploring.';
  }
}
