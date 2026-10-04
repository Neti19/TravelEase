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

class _PersonalDashboardScreenState extends State<PersonalDashboardScreen> {
  static const _ink = Color(0xFF102A43);
  static const _muted = Color(0xFF63758A);
  static const _blue = Color(0xFF2878E5);
  static const _teal = Color(0xFF16A68A);
  static const _canvas = Color(0xFFF5F8FC);

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

  void _openPlanTrip() {
    Navigator.pushNamed(context, AppRoutes.tripDetails);
  }

  void _openMyTrips() {
    Navigator.pushNamed(context, AppRoutes.myTrips);
  }

  void _openHelpMeChoose() {
    Navigator.pushNamed(context, AppRoutes.helpMeChoose);
  }

  void _openExplore() {
    Navigator.pushNamed(context, AppRoutes.home);
  }

  Future<void> _logout() async {
    await AuthService().logout();

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = constraints.maxWidth > 1080
                ? 1000.0
                : constraints.maxWidth;

            return Center(
              child: SizedBox(
                width: contentWidth,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildTopBar()),
                    SliverToBoxAdapter(child: _buildHero()),
                    SliverToBoxAdapter(child: _buildSectionHeading()),
                    SliverToBoxAdapter(child: _buildActionCards(contentWidth)),
                    SliverToBoxAdapter(child: _buildInspirationCard()),
                    const SliverToBoxAdapter(child: SizedBox(height: 28)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_blue, Color(0xFF4EA8F5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.travel_explore_rounded,
              color: Colors.white,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'TravelEase',
              style: TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Account options',
            icon: const Icon(Icons.more_horiz_rounded, color: _ink),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (value) {
              if (value == 'explore') _openExplore();
              if (value == 'logout') _logout();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'explore',
                child: Row(
                  children: [
                    Icon(Icons.explore_outlined, size: 20),
                    SizedBox(width: 10),
                    Text('Explore'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 20),
                    SizedBox(width: 10),
                    Text('Log out'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Container(
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF123D65), Color(0xFF176C91)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24123D65),
              blurRadius: 25,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -52,
              top: -65,
              child: _heroCircle(190, Colors.white.withValues(alpha: 0.055)),
            ),
            Positioned(
              right: 48,
              bottom: -100,
              child: _heroCircle(170, Colors.white.withValues(alpha: 0.055)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.wb_sunny_rounded,
                        color: Color(0xFFFFD166),
                        size: 15,
                      ),
                      SizedBox(width: 7),
                      Text(
                        'YOUR TRAVEL DASHBOARD',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Hello, $_firstName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'A little planning today, a great story tomorrow.',
                  style: TextStyle(
                    color: Color(0xFFD9EAF5),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: _openPlanTrip,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Plan a trip'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC857),
                    foregroundColor: _ink,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 19,
                      vertical: 14,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildSectionHeading() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Make it your kind of trip',
            style: TextStyle(
              color: _ink,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Pick up where you are, or find a new direction.',
            style: TextStyle(color: _muted, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCards(double contentWidth) {
    final horizontalPadding = 48.0;
    final availableWidth = contentWidth - horizontalPadding;
    final columns = availableWidth >= 690 ? 4 : 2;
    final cardWidth = (availableWidth - (columns - 1) * 12) / columns;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: cardWidth,
            child: _actionCard(
              title: 'My trips',
              description: 'See your planned journeys',
              icon: Icons.luggage_rounded,
              color: const Color(0xFFEF8354),
              onTap: _openMyTrips,
            ),
          ),
          SizedBox(
            width: cardWidth,
            child: _actionCard(
              title: 'Help me choose',
              description: 'Find a trip that fits you',
              icon: Icons.auto_awesome_rounded,
              color: const Color(0xFF8067D8),
              onTap: _openHelpMeChoose,
            ),
          ),
          SizedBox(
            width: cardWidth,
            child: _actionCard(
              title: 'Explore',
              description: 'Browse travel inspiration',
              icon: Icons.explore_rounded,
              color: _blue,
              onTap: _openExplore,
            ),
          ),
          SizedBox(
            width: cardWidth,
            child: _actionCard(
              title: 'Plan a trip',
              description: 'Build your next itinerary',
              icon: Icons.add_location_alt_rounded,
              color: _teal,
              onTap: _openPlanTrip,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(minHeight: 154),
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5EBF2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 15),
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                description,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.bottomRight,
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: color,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInspirationCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Material(
        color: const Color(0xFFE8F5F2),
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(19),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.format_quote_rounded,
                  color: _teal,
                  size: 27,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'The world is your story.',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Take the scenic route and make every journey count.',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
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
}
