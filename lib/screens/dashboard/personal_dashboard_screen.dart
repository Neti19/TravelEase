import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../services/auth_service.dart';

class PersonalDashboardScreen extends StatefulWidget {
  const PersonalDashboardScreen({super.key});

  @override
  State<PersonalDashboardScreen> createState() =>
      _PersonalDashboardScreenState();
}

class _PersonalDashboardScreenState
    extends State<PersonalDashboardScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _floatController;

  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  final User? _user = FirebaseAuth.instance.currentUser;

  String get _firstName {
    final name = _user?.displayName?.trim();

    if (name != null && name.isNotEmpty) {
      return name.split(' ').first;
    }

    final email = _user?.email ?? '';

    if (email.contains('@')) {
      return email.split('@').first;
    }

    return 'Traveler';
  }

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOutCubic,
      ),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _openPlanTrip() {
    Navigator.pushNamed(
      context,
      AppRoutes.tripDetails,
    );
  }

  void _openMyTrips() {
    Navigator.pushNamed(
      context,
      AppRoutes.myTrips,
    );
  }

  void _openHelpMeChoose() {
    Navigator.pushNamed(
      context,
      AppRoutes.helpMeChoose,
    );
  }

  void _openExplore() {
    Navigator.pushNamed(
      context,
      AppRoutes.home,
    );
  }

  Future<void> _logout() async {
    await AuthService().logout();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
          (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      body: Stack(
        children: [
          _buildBackground(),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildTopBar(),
                    ),

                    SliverToBoxAdapter(
                      child: _buildHero(),
                    ),

                    SliverToBoxAdapter(
                      child: _buildQuickActions(),
                    ),

                    SliverToBoxAdapter(
                      child: _buildContinuePlanning(),
                    ),

                    SliverToBoxAdapter(
                      child: _buildTravelMood(),
                    ),

                    SliverToBoxAdapter(
                      child: _buildStats(),
                    ),

                    SliverToBoxAdapter(
                      child: _buildExploreCard(),
                    ),

                    SliverToBoxAdapter(
                      child: _buildBottomSpace(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -130,
            right: -80,
            child: _softCircle(
              300,
              const Color(0xFFDFF4FF),
            ),
          ),
          Positioned(
            top: 330,
            left: -130,
            child: _softCircle(
              260,
              const Color(0xFFFFE9DF),
            ),
          ),
          Positioned(
            bottom: -150,
            right: -100,
            child: _softCircle(
              280,
              const Color(0xFFE8E3FF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _softCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        14,
        20,
        10,
      ),
      child: Row(
        children: [
          Container(
            width: 47,
            height: 47,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1677FF),
                  Color(0xFF45AEFF),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x261677FF),
                  blurRadius: 16,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: const Icon(
              Icons.travel_explore_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),

          const SizedBox(width: 12),

          const Expanded(
            child: Text(
              'TravelEase',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                color: Color(0xFF102A43),
              ),
            ),
          ),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFE7EAF0),
              ),
            ),
            child: PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_horiz_rounded,
                color: Color(0xFF344054),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onSelected: (value) {
                if (value == 'logout') {
                  _logout();
                }

                if (value == 'explore') {
                  _openExplore();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'explore',
                  child: Row(
                    children: [
                      Icon(
                        Icons.explore_outlined,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Text('Explore'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Text('Logout'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        12,
        20,
        22,
      ),
      child: AnimatedBuilder(
        animation: _floatController,
        builder: (context, child) {
          final value =
          math.sin(_floatController.value * math.pi);

          return Transform.translate(
            offset: Offset(0, value * 3),
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF0D6EFD),
                Color(0xFF36A8FF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Color(0x331677FF),
                blurRadius: 28,
                offset: Offset(0, 15),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -25,
                child: _heroBubble(
                  105,
                  Colors.white.withOpacity(0.10),
                ),
              ),
              Positioned(
                right: 40,
                bottom: -45,
                child: _heroBubble(
                  120,
                  Colors.white.withOpacity(0.08),
                ),
              ),

              Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                          Colors.white.withOpacity(0.16),
                          borderRadius:
                          BorderRadius.circular(30),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.wb_sunny_rounded,
                              color: Colors.white,
                              size: 15,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'YOUR TRAVEL SPACE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight:
                                FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  Text(
                    'Hey $_firstName! 👋',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 29,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Where will your next story take you?',
                    style: TextStyle(
                      color: Color(0xFFEAF6FF),
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),

                  const SizedBox(height: 22),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _openPlanTrip,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor:
                        const Color(0xFF1677FF),
                        elevation: 0,
                        padding:
                        const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(16),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment:
                        MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_location_alt_rounded,
                          ),
                          SizedBox(width: 9),
                          Text(
                            'Plan a New Trip',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroBubble(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        0,
        20,
        25,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Make your next move',
            'Everything you need to start planning.',
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _actionCard(
                  title: 'Help me choose',
                  subtitle: 'Not sure where to go?',
                  icon: Icons.auto_awesome_rounded,
                  color: const Color(0xFF7B61FF),
                  onTap: _openHelpMeChoose,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _actionCard(
                  title: 'My trips',
                  subtitle: 'View your journeys',
                  icon: Icons.luggage_rounded,
                  color: const Color(0xFFFF8A65),
                  onTap: _openMyTrips,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFFE7EAF0),
            ),
          ),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Container(
                width: 47,
                height: 47,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.11),
                  borderRadius:
                  BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),

              const SizedBox(height: 14),

              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF172033),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF667085),
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 12),

              Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContinuePlanning() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        0,
        20,
        25,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: _openPlanTrip,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(19),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFE7EAF0),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFB000),
                        Color(0xFFFFD166),
                      ],
                    ),
                    borderRadius:
                    BorderRadius.circular(17),
                  ),
                  child: const Icon(
                    Icons.explore_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),

                const SizedBox(width: 14),

                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Know where you want to go?',
                        style: TextStyle(
                          color: Color(0xFF172033),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Search a destination and build your trip.',
                        style: TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF98A2B3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTravelMood() {
    final moods = [
      (
      'Beach',
      Icons.beach_access_rounded,
      const Color(0xFF00A6A6),
      ),
      (
      'Adventure',
      Icons.landscape_rounded,
      const Color(0xFF1677FF),
      ),
      (
      'Food',
      Icons.restaurant_rounded,
      const Color(0xFFFF8A65),
      ),
      (
      'Nature',
      Icons.forest_rounded,
      const Color(0xFF2E9D63),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        0,
        20,
        25,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'What are you feeling?',
            'Choose a mood and let the journey begin.',
          ),

          const SizedBox(height: 14),

          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: moods.length,
              separatorBuilder: (_, __) =>
              const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final mood = moods[index];

                return Container(
                  width: 105,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                    BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFE7EAF0),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    children: [
                      Icon(
                        mood.$2,
                        color: mood.$3,
                        size: 25,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        mood.$1,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF344054),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        0,
        20,
        25,
      ),
      child: Container(
        padding: const EdgeInsets.all(19),
        decoration: BoxDecoration(
          color: const Color(0xFF102A43),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            _statItem(
              icon: Icons.flight_takeoff_rounded,
              value: '0',
              label: 'Trips',
            ),
            _verticalDivider(),
            _statItem(
              icon: Icons.place_rounded,
              value: '0',
              label: 'Places',
            ),
            _verticalDivider(),
            _statItem(
              icon: Icons.favorite_rounded,
              value: '0',
              label: 'Saved',
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            color: const Color(0xFF7CC7FF),
            size: 21,
          ),
          const SizedBox(height: 7),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFB8C7D9),
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      height: 42,
      width: 1,
      color: Colors.white.withOpacity(0.12),
    );
  }

  Widget _buildExploreCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        0,
        20,
        25,
      ),
      child: Container(
        padding: const EdgeInsets.all(21),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFF8A65),
              Color(0xFFFFB199),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Need inspiration?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Explore destinations and discover your next adventure.',
                    style: TextStyle(
                      color: Color(0xFFFFF3EF),
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _openExplore,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor:
                      const Color(0xFFE66A49),
                      elevation: 0,
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 11,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(13),
                      ),
                    ),
                    child: const Text(
                      'Explore',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            AnimatedBuilder(
              animation: _floatController,
              builder: (context, child) {
                final value = math.sin(
                  _floatController.value * math.pi,
                );

                return Transform.translate(
                  offset: Offset(0, value * 5),
                  child: child,
                );
              },
              child: const Text(
                '🌍',
                style: TextStyle(fontSize: 65),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(
      String title,
      String subtitle,
      ) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF172033),
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF667085),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSpace() {
    return const SizedBox(height: 30);
  }
}