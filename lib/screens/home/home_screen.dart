import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final GlobalKey _discoverKey = GlobalKey();
  final GlobalKey _exploreKey = GlobalKey();

  int _selectedMood = 0;
  int _selectedTraveler = 0;
  double _budget = 30000;

  final List<_Destination> _destinations = const [
    _Destination(
      'Goa',
      'India',
      'Beach • Food • Nightlife',
      15000,
      'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2?auto=format&fit=crop&w=1200&q=85',
      'Perfect for sunsets, seafood and spontaneous plans.',
    ),
    _Destination(
      'Manali',
      'India',
      'Mountains • Adventure • Nature',
      18000,
      'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?auto=format&fit=crop&w=1200&q=85',
      'Cool mountain air, scenic roads and unforgettable views.',
    ),
    _Destination(
      'Bali',
      'Indonesia',
      'Beach • Food • Relax',
      35000,
      'https://images.unsplash.com/photo-1537996194471-e657df975ab4?auto=format&fit=crop&w=1200&q=85',
      'Tropical mornings, hidden cafés and slow island days.',
    ),
    _Destination(
      'Dubai',
      'UAE',
      'City • Luxury • Shopping',
      45000,
      'https://images.unsplash.com/photo-1518684079-3c830dcef090?auto=format&fit=crop&w=1200&q=85',
      'A high-energy escape filled with architecture and experiences.',
    ),
    _Destination(
      'Tokyo',
      'Japan',
      'Culture • Food • City',
      70000,
      'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?auto=format&fit=crop&w=1200&q=85',
      'Ancient traditions meet neon streets and incredible food.',
    ),
    _Destination(
      'Paris',
      'France',
      'Culture • Romance • Food',
      85000,
      'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?auto=format&fit=crop&w=1200&q=85',
      'Art, cafés, beautiful streets and timeless evenings.',
    ),
  ];

  final List<_Mood> _moods = const [
    _Mood('Beach', Icons.beach_access_rounded),
    _Mood('Adventure', Icons.landscape_rounded),
    _Mood('Food', Icons.restaurant_rounded),
    _Mood('City', Icons.location_city_rounded),
    _Mood('Romantic', Icons.favorite_rounded),
    _Mood('Nature', Icons.forest_rounded),
  ];

  final List<_Traveler> _travelers = const [
    _Traveler(
      'The Explorer',
      'Hidden gems and adventures',
      '🧭',
    ),
    _Traveler(
      'The Relaxer',
      'Slow days and beautiful places',
      '🌊',
    ),
    _Traveler(
      'The Foodie',
      'Local food is the priority',
      '🍜',
    ),
    _Traveler(
      'The Planner',
      'Every detail neatly organized',
      '🗓️',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isLoggedIn => FirebaseAuth.instance.currentUser != null;

  void _requireLogin(VoidCallback action) {
    if (!_isLoggedIn) {
      Navigator.pushNamed(context, AppRoutes.login);
      return;
    }

    action();
  }

  void _startPlanning() {
    _requireLogin(() {
      Navigator.pushNamed(context, AppRoutes.tripDetails);
    });
  }

  void _openMyTrips() {
    _requireLogin(() {
      Navigator.pushNamed(context, AppRoutes.myTrips);
    });
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

  void _scrollTo(GlobalKey key) {
    final target = key.currentContext;

    if (target == null) return;

    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  _Destination _recommendedDestination() {
    final mood = _moods[_selectedMood].name.toLowerCase();
    final traveler = _travelers[_selectedTraveler].name.toLowerCase();

    int score(_Destination destination) {
      final text = destination.category.toLowerCase();
      int value = 0;

      final moodWords = <String, List<String>>{
        'beach': ['beach', 'relax'],
        'adventure': ['adventure', 'mountain'],
        'food': ['food'],
        'city': ['city', 'shopping', 'luxury'],
        'romantic': ['romance'],
        'nature': ['nature', 'mountain', 'beach'],
      };

      for (final word in moodWords[mood] ?? const <String>[]) {
        if (text.contains(word)) {
          value += 6;
        }
      }

      if (traveler.contains('explorer') &&
          (text.contains('adventure') ||
              text.contains('mountain') ||
              text.contains('culture'))) {
        value += 3;
      }

      if (traveler.contains('relaxer') &&
          (text.contains('beach') || text.contains('relax'))) {
        value += 3;
      }

      if (traveler.contains('foodie') && text.contains('food')) {
        value += 4;
      }

      if (traveler.contains('planner')) {
        value += 1;
      }

      if (destination.budget <= _budget) {
        value += 4;
      } else if (destination.budget <= _budget + 20000) {
        value += 1;
      } else {
        value -= 3;
      }

      return value;
    }

    final sorted = [..._destinations]
      ..sort((a, b) => score(b).compareTo(score(a)));

    return sorted.first;
  }

  void _discover() {
    _requireLogin(() {
      final destination = _recommendedDestination();

      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (sheetContext) {
          return _RecommendationSheet(
            destination: destination,
            mood: _moods[_selectedMood].name,
            traveler: _travelers[_selectedTraveler].name,
            budget: _budget.round(),
            onPlan: () {
              Navigator.pop(sheetContext);
              _startPlanning();
            },
          );
        },
      );
    });
  }

  List<_Destination> get _filteredDestinations {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return _destinations;
    }

    return _destinations.where((destination) {
      return destination.name.toLowerCase().contains(query) ||
          destination.country.toLowerCase().contains(query) ||
          destination.category.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              _buildNav(),
              _buildHero(),
              _buildTravelTicker(),
              _buildMoodSection(),
              _buildDiscoverSection(),
              _buildExploreSection(),
              _buildBudgetSection(),
              _buildTravelerSection(),
              _buildHowItWorks(),
              _buildFinalCta(),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNav() {
    return Container(
      color: const Color(0xFFF7FAFC),
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Row(
            children: [
              _brand(),
              const Spacer(),
              if (MediaQuery.sizeOf(context).width >= 760) ...[
                _navButton(
                  'Explore',
                      () => _scrollTo(_exploreKey),
                ),
                _navButton(
                  'Discover',
                      () => _scrollTo(_discoverKey),
                ),
                _navButton(
                  'My Trips',
                  _openMyTrips,
                ),
                const SizedBox(width: 12),
                _authButton(),
              ] else
                IconButton(
                  onPressed: _showMobileMenu,
                  icon: const Icon(Icons.menu_rounded),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _brand() {
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: () {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1677FF),
                  Color(0xFF00A6A6),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.flight_takeoff_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'TravelEase',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: Color(0xFF102A43),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navButton(
      String text,
      VoidCallback onTap,
      ) {
    return TextButton(
      onPressed: onTap,
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF486581),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _authButton() {
    return OutlinedButton.icon(
      onPressed: _isLoggedIn
          ? _logout
          : () => Navigator.pushNamed(
        context,
        AppRoutes.login,
      ),
      icon: Icon(
        _isLoggedIn
            ? Icons.logout_rounded
            : Icons.login_rounded,
        size: 18,
      ),
      label: Text(
        _isLoggedIn ? 'Logout' : 'Login',
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF1677FF),
        side: const BorderSide(
          color: Color(0xFFD6E4F0),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
        ),
      ),
    );
  }

  void _showMobileMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8E2ED),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 18),
                ListTile(
                  leading: const Icon(
                    Icons.explore_rounded,
                    color: Color(0xFF1677FF),
                  ),
                  title: const Text('Explore'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _scrollTo(_exploreKey);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF1677FF),
                  ),
                  title: const Text('Discover'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _scrollTo(_discoverKey);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.luggage_rounded,
                    color: Color(0xFF1677FF),
                  ),
                  title: const Text('My Trips'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openMyTrips();
                  },
                ),
                ListTile(
                  leading: Icon(
                    _isLoggedIn
                        ? Icons.logout_rounded
                        : Icons.login_rounded,
                  ),
                  title: Text(
                    _isLoggedIn ? 'Logout' : 'Login',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);

                    if (_isLoggedIn) {
                      _logout();
                    } else {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.login,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // HERO
  // ---------------------------------------------------------------------------

  Widget _buildHero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1240,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(34),
            child: SizedBox(
              width: double.infinity,
              height: MediaQuery.sizeOf(context).width < 700
                  ? 650
                  : 610,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    'https://images.unsplash.com/photo-1500534623283-312aade485b7?auto=format&fit=crop&w=1800&q=90',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return Container(
                        color: const Color(0xFF102A43),
                      );
                    },
                  ),

                  // Image darkening layer.
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x33102A43),
                          Color(0x99102A43),
                          Color(0xE6102A43),
                        ],
                        stops: [0, .45, 1],
                      ),
                    ),
                  ),

                  // Blue glow.
                  Positioned(
                    right: -100,
                    top: -120,
                    child: Container(
                      width: 350,
                      height: 350,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1677FF)
                            .withOpacity(.22),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(28),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact =
                            constraints.maxWidth < 760;

                        if (compact) {
                          return Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              _heroBadge(),
                              const Spacer(),
                              _heroText(),
                              const SizedBox(height: 25),
                              _heroSearch(),
                              const SizedBox(height: 13),
                              _heroButtons(),
                              const SizedBox(height: 25),
                              _heroFloatingInfo(),
                            ],
                          );
                        }

                        return Stack(
                          children: [
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: SizedBox(
                                width: 700,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    _heroBadge(),
                                    const SizedBox(height: 20),
                                    _heroText(),
                                    const SizedBox(height: 27),
                                    _heroSearch(),
                                    const SizedBox(height: 13),
                                    _heroButtons(),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              top: 18,
                              right: 12,
                              child: _heroFloatingInfo(),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.15),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withOpacity(.22),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.explore_rounded,
            color: Color(0xFFFFD166),
            size: 16,
          ),
          SizedBox(width: 7),
          Text(
            'YOUR NEXT ADVENTURE STARTS HERE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: .9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Go somewhere\nworth remembering.',
          style: TextStyle(
            color: Colors.white,
            fontSize: MediaQuery.sizeOf(context).width < 500
                ? 43
                : 58,
            height: 1.0,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.8,
          ),
        ),
        const SizedBox(height: 17),
        const Text(
          'Discover places you will love, build your perfect itinerary, '
              'and keep every part of your journey in one place.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 15,
            height: 1.55,
          ),
        ),
      ],
    );
  }

  Widget _heroSearch() {
    return Container(
      height: 62,
      padding: const EdgeInsets.only(
        left: 18,
        right: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.15),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            color: Color(0xFF829AB1),
            size: 23,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _scrollTo(_exploreKey),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Where do you want to go?',
                hintStyle: TextStyle(
                  color: Color(0xFF9FB3C8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              onPressed: () {
                _searchController.clear();
                setState(() {});
              },
              icon: const Icon(
                Icons.close_rounded,
              ),
            ),
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1677FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text(
                'Search',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroButtons() {
    return Wrap(
      spacing: 11,
      runSpacing: 10,
      children: [
        _heroAction(
          '✨ Help me discover',
          true,
          _discover,
        ),
        _heroAction(
          'Plan my own trip',
          false,
          _startPlanning,
        ),
      ],
    );
  }

  Widget _heroAction(
      String text,
      bool primary,
      VoidCallback onTap,
      ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 17,
            vertical: 13,
          ),
          decoration: BoxDecoration(
            color: primary
                ? const Color(0xFFFFD166)
                : Colors.white.withOpacity(.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: primary
                  ? Colors.transparent
                  : Colors.white.withOpacity(.3),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: primary
                  ? const Color(0xFF102A43)
                  : Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroFloatingInfo() {
    return Container(
      width: 225,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.92),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.12),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: Color(0xFFDFF4FF),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF1677FF),
                  size: 18,
                ),
              ),
              SizedBox(width: 9),
              Text(
                'TravelEase picks',
                style: TextStyle(
                  color: Color(0xFF102A43),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          SizedBox(height: 13),
          Text(
            'Tell us your vibe.\nWe’ll help with the rest.',
            style: TextStyle(
              color: Color(0xFF486581),
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TICKER
  // ---------------------------------------------------------------------------

  Widget _buildTravelTicker() {
    return SizedBox(
      height: 78,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        children: const [
          _TickerItem(
            icon: Icons.wb_sunny_rounded,
            text: 'Chase the sun',
          ),
          _TickerItem(
            icon: Icons.restaurant_rounded,
            text: 'Eat somewhere new',
          ),
          _TickerItem(
            icon: Icons.landscape_rounded,
            text: 'Take the scenic route',
          ),
          _TickerItem(
            icon: Icons.camera_alt_rounded,
            text: 'Collect memories',
          ),
          _TickerItem(
            icon: Icons.flight_rounded,
            text: 'Go further',
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MOOD
  // ---------------------------------------------------------------------------

  Widget _buildMoodSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(
        20,
        52,
        20,
        55,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1180,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(
                'START WITH A FEELING',
                'What are you craving?',
                'A trip can start with a destination. Or it can start with a feeling.',
              ),
              const SizedBox(height: 25),
              SizedBox(
                height: 55,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _moods.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final mood = _moods[index];
                    final selected = index == _selectedMood;

                    return InkWell(
                      borderRadius: BorderRadius.circular(30),
                      onTap: () {
                        setState(() {
                          _selectedMood = index;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(
                          milliseconds: 200,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF1677FF)
                              : const Color(0xFFF7FAFC),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF1677FF)
                                : const Color(0xFFE1EAF2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              mood.icon,
                              size: 19,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF1677FF),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              mood.name,
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF486581),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DISCOVER
  // ---------------------------------------------------------------------------

  Widget _buildDiscoverSection() {
    final destination = _recommendedDestination();

    return Container(
      key: _discoverKey,
      color: const Color(0xFFEAF7FF),
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 70,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1180,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 800;

              final controls = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(
                    'TRAVELEASE DISCOVERY',
                    'Not sure where to go?',
                    'Tell us how you want your trip to feel and we’ll find a destination that fits.',
                  ),
                  const SizedBox(height: 28),
                  _discoveryControl(
                    icon: Icons.person_outline_rounded,
                    label: 'Your travel style',
                    value:
                    '${_travelers[_selectedTraveler].emoji}  ${_travelers[_selectedTraveler].name}',
                    onTap: _showTravelerPicker,
                  ),
                  const SizedBox(height: 12),
                  _discoveryControl(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Your budget',
                    value: '₹${_formatBudget(_budget.round())}',
                    onTap: _showBudgetPicker,
                  ),
                  const SizedBox(height: 23),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _discover,
                      icon: const Icon(
                        Icons.auto_awesome_rounded,
                      ),
                      label: const Text(
                        'Find my destination',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor:
                        const Color(0xFF1677FF),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),
                ],
              );

              final match = _discoveryMatch(destination);

              if (!wide) {
                return Column(
                  children: [
                    controls,
                    const SizedBox(height: 35),
                    match,
                  ],
                );
              }

              return Row(
                crossAxisAlignment:
                CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: controls,
                  ),
                  const SizedBox(width: 70),
                  Expanded(
                    child: match,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _discoveryMatch(
      _Destination destination,
      ) {
    return SizedBox(
      height: 400,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              destination.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return Container(
                  color: const Color(0xFF1677FF),
                );
              },
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(0xDD102A43),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 22,
              right: 22,
              bottom: 22,
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD166),
                      borderRadius:
                      BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'YOUR MATCH',
                      style: TextStyle(
                        color: Color(0xFF102A43),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    destination.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    destination.country,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    destination.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _discoveryControl({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 17,
          vertical: 15,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFF1677FF),
              size: 21,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF829AB1),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF102A43),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF9FB3C8),
            ),
          ],
        ),
      ),
    );
  }

  void _showTravelerPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Text(
                  'What kind of traveler are you?',
                  style: TextStyle(
                    color: Color(0xFF102A43),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 15),
                ...List.generate(
                  _travelers.length,
                      (index) {
                    final traveler = _travelers[index];

                    return ListTile(
                      contentPadding:
                      const EdgeInsets.symmetric(
                        horizontal: 4,
                      ),
                      leading: Text(
                        traveler.emoji,
                        style: const TextStyle(
                          fontSize: 28,
                        ),
                      ),
                      title: Text(
                        traveler.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        traveler.subtitle,
                      ),
                      trailing: index ==
                          _selectedTraveler
                          ? const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF1677FF),
                      )
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedTraveler = index;
                        });
                        Navigator.pop(sheetContext);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBudgetPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  22,
                  25,
                  22,
                  28,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What is your trip budget?',
                      style: TextStyle(
                        color: Color(0xFF102A43),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₹${_budget.round()}',
                      style: const TextStyle(
                        color: Color(0xFF1677FF),
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Slider(
                      value: _budget,
                      min: 10000,
                      max: 120000,
                      divisions: 22,
                      label: '₹${_budget.round()}',
                      onChanged: (value) {
                        setSheetState(() {
                          _budget = value;
                        });
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor:
                          const Color(0xFF1677FF),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          'Done',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // EXPLORE
  // ---------------------------------------------------------------------------

  Widget _buildExploreSection() {
    final destinations = _filteredDestinations;

    return Container(
      key: _exploreKey,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(
        20,
        75,
        20,
        80,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1180,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment:
                CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _sectionTitle(
                      'GO SOMEWHERE',
                      'Places worth dreaming about.',
                      'A little inspiration for your next escape.',
                    ),
                  ),
                  if (MediaQuery.sizeOf(context).width >=
                      650)
                    TextButton.icon(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(
                        Icons.refresh_rounded,
                        size: 17,
                      ),
                      label: const Text('View all'),
                    ),
                ],
              ),
              const SizedBox(height: 30),
              if (destinations.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: 50,
                  ),
                  child: Center(
                    child: Text(
                      'No destinations found. Try another search.',
                    ),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns =
                    constraints.maxWidth >= 950
                        ? 3
                        : constraints.maxWidth >= 600
                        ? 2
                        : 1;

                    final width =
                        (constraints.maxWidth -
                            ((columns - 1) * 18)) /
                            columns;

                    return Wrap(
                      spacing: 18,
                      runSpacing: 20,
                      children: destinations.map(
                            (destination) {
                          return SizedBox(
                            width: width,
                            child: _destinationCard(
                              destination,
                            ),
                          );
                        },
                      ).toList(),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _destinationCard(
      _Destination destination,
      ) {
    return InkWell(
      onTap: _startPlanning,
      borderRadius: BorderRadius.circular(25),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: SizedBox(
          height: 330,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                destination.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Container(
                    color: const Color(0xFFDFF4FF),
                  );
                },
              ),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x22000000),
                      Color(0x33000000),
                      Color(0xE6102A43),
                    ],
                    stops: [0, .35, 1],
                  ),
                ),
              ),
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.92),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '₹${_formatBudget(destination.budget)}+',
                    style: const TextStyle(
                      color: Color(0xFF102A43),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(.35),
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_outward_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 19,
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      destination.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      destination.country,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      destination.category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Text(
                          'Plan this escape',
                          style: TextStyle(
                            color: Color(0xFFFFD166),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(width: 5),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Color(0xFFFFD166),
                          size: 15,
                        ),
                      ],
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

  // ---------------------------------------------------------------------------
  // BUDGET
  // ---------------------------------------------------------------------------

  Widget _buildBudgetSection() {
    return Container(
      color: const Color(0xFFF7FAFC),
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 75,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1180,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 800;

              final slider = Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  _sectionTitle(
                    'MAKE IT YOURS',
                    'What does your dream trip look like?',
                    'Set your budget and let the possibilities change with you.',
                  ),
                  const SizedBox(height: 28),
                  Row(
                    crossAxisAlignment:
                    CrossAxisAlignment.end,
                    children: [
                      const Text(
                        '₹',
                        style: TextStyle(
                          color: Color(0xFF1677FF),
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        _budget.round().toString(),
                        style: const TextStyle(
                          color: Color(0xFF102A43),
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _budgetLabel(),
                    style: const TextStyle(
                      color: Color(0xFF829AB1),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Slider(
                    value: _budget,
                    min: 10000,
                    max: 120000,
                    divisions: 22,
                    label: '₹${_budget.round()}',
                    onChanged: (value) {
                      setState(() {
                        _budget = value;
                      });
                    },
                  ),
                ],
              );

              final quote = Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF102A43),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.format_quote_rounded,
                      color: Color(0xFFFFD166),
                      size: 38,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'The best trips are not always the farthest ones.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        height: 1.25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 13),
                    Text(
                      'Sometimes all you need is a reason to go.',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );

              if (!wide) {
                return Column(
                  children: [
                    slider,
                    const SizedBox(height: 30),
                    quote,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: slider,
                  ),
                  const SizedBox(width: 80),
                  SizedBox(
                    width: 360,
                    child: quote,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _budgetLabel() {
    if (_budget < 20000) {
      return 'Budget-friendly escape';
    }

    if (_budget < 40000) {
      return 'Smart getaway';
    }

    if (_budget < 70000) {
      return 'Comfort trip';
    }

    if (_budget < 100000) {
      return 'Premium adventure';
    }

    return 'Dream vacation';
  }

  // ---------------------------------------------------------------------------
  // TRAVELER
  // ---------------------------------------------------------------------------

  Widget _buildTravelerSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 75,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1180,
          ),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              _sectionTitle(
                'TRAVEL PERSONALITY',
                'Every traveler has a different rhythm.',
                'Choose the one that sounds most like you.',
              ),
              const SizedBox(height: 30),
              SizedBox(
                height: 180,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _travelers.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(width: 15),
                  itemBuilder: (context, index) {
                    final traveler = _travelers[index];
                    final selected =
                        index == _selectedTraveler;

                    return InkWell(
                      borderRadius:
                      BorderRadius.circular(24),
                      onTap: () {
                        setState(() {
                          _selectedTraveler = index;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(
                          milliseconds: 220,
                        ),
                        width: 245,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF1677FF)
                              : const Color(0xFFF7FAFC),
                          borderRadius:
                          BorderRadius.circular(24),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF1677FF)
                                : const Color(0xFFE1EAF2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              traveler.emoji,
                              style: const TextStyle(
                                fontSize: 34,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              traveler.name,
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF102A43),
                                fontSize: 16,
                                fontWeight:
                                FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              traveler.subtitle,
                              maxLines: 2,
                              overflow:
                              TextOverflow.ellipsis,
                              style: TextStyle(
                                color: selected
                                    ? Colors.white70
                                    : const Color(0xFF829AB1),
                                fontSize: 11,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HOW IT WORKS
  // ---------------------------------------------------------------------------

  Widget _buildHowItWorks() {
    final steps = const [
      (
      '01',
      'Discover',
      'Find a destination that fits your vibe.',
      Icons.explore_rounded,
      ),
      (
      '02',
      'Build',
      'Choose the places you actually want to see.',
      Icons.add_location_alt_rounded,
      ),
      (
      '03',
      'Optimize',
      'Turn your stops into a smarter route.',
      Icons.alt_route_rounded,
      ),
      (
      '04',
      'Travel',
      'Keep your itinerary, expenses and trip together.',
      Icons.luggage_rounded,
      ),
    ];

    return Container(
      color: const Color(0xFFEAF7FF),
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 78,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1180,
          ),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              _sectionTitle(
                'THE TRAVELEASE WAY',
                'From “where should we go?” to “let’s go.”',
                'One place to turn an idea into a trip.',
              ),
              const SizedBox(height: 35),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide =
                      constraints.maxWidth >= 900;

                  if (!wide) {
                    return Column(
                      children: List.generate(
                        steps.length,
                            (index) {
                          return Padding(
                            padding:
                            const EdgeInsets.only(
                              bottom: 16,
                            ),
                            child: _step(
                              steps[index],
                              index ==
                                  steps.length - 1,
                            ),
                          );
                        },
                      ),
                    );
                  }

                  return Row(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: List.generate(
                      steps.length,
                          (index) {
                        return Expanded(
                          child: Padding(
                            padding:
                            EdgeInsets.only(
                              right:
                              index == steps.length - 1
                                  ? 0
                                  : 18,
                            ),
                            child: _step(
                              steps[index],
                              index ==
                                  steps.length - 1,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _step(
      (
      String,
      String,
      String,
      IconData
      ) data,
      bool last,
      ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF1677FF),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Icon(
            data.$4,
            color: Colors.white,
            size: 23,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                data.$1,
                style: const TextStyle(
                  color: Color(0xFF9FB3C8),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data.$2,
                style: const TextStyle(
                  color: Color(0xFF102A43),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                data.$3,
                style: const TextStyle(
                  color: Color(0xFF627D98),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // CTA
  // ---------------------------------------------------------------------------

  Widget _buildFinalCta() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: SizedBox(
          height: 410,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?auto=format&fit=crop&w=1600&q=90',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Container(
                    color: const Color(0xFF102A43),
                  );
                },
              ),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x33102A43),
                      Color(0xE6102A43),
                    ],
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'YOUR NEXT STORY\nSTARTS WITH A YES.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          height: 1.0,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Pick a place. Pick a feeling. Or just start exploring.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _startPlanning,
                        icon: const Icon(
                          Icons.flight_takeoff_rounded,
                        ),
                        label: const Text(
                          'Start planning',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor:
                          const Color(0xFFFFD166),
                          foregroundColor:
                          Color(0xFF102A43),
                          padding:
                          const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      color: const Color(0xFF0B2035),
      padding: const EdgeInsets.symmetric(
        horizontal: 25,
        vertical: 35,
      ),
      child: Center(
        child: Column(
          children: [
            const Row(
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.flight_takeoff_rounded,
                  color: Color(0xFFFFD166),
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'TravelEase',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Plan less. Experience more.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '© ${DateTime.now().year} TravelEase',
              style: const TextStyle(
                color: Colors.white30,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  Widget _sectionTitle(
      String eyebrow,
      String title,
      String subtitle,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: Color(0xFF1677FF),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            color: const Color(0xFF102A43),
            fontSize: MediaQuery.sizeOf(context).width < 500
                ? 27
                : 32,
            height: 1.1,
            fontWeight: FontWeight.w900,
            letterSpacing: -.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF627D98),
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  String _formatBudget(int value) {
    if (value >= 1000) {
      return '${(value / 1000).round()}k';
    }

    return value.toString();
  }
}

class _TickerItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TickerItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFC),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFF1677FF),
            size: 17,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF486581),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationSheet extends StatelessWidget {
  final _Destination destination;
  final String mood;
  final String traveler;
  final int budget;
  final VoidCallback onPlan;

  const _RecommendationSheet({
    required this.destination,
    required this.mood,
    required this.traveler,
    required this.budget,
    required this.onPlan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        22,
        12,
        22,
        28,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8E2ED),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: SizedBox(
                height: 190,
                width: double.infinity,
                child: Image.network(
                  destination.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return Container(
                      color: const Color(0xFFDFF4FF),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'YOUR TRAVELEASE MATCH',
              style: TextStyle(
                color: Color(0xFF1677FF),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              destination.name,
              style: const TextStyle(
                color: Color(0xFF102A43),
                fontSize: 29,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              destination.country,
              style: const TextStyle(
                color: Color(0xFF829AB1),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Based on your $mood mood, '
                  '$traveler style and ₹$budget budget.',
              style: const TextStyle(
                color: Color(0xFF627D98),
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onPlan,
                icon: const Icon(
                  Icons.flight_takeoff_rounded,
                ),
                label: Text(
                  'Plan ${destination.name} trip',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor:
                  const Color(0xFF1677FF),
                  padding:
                  const EdgeInsets.symmetric(
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Destination {
  final String name;
  final String country;
  final String category;
  final int budget;
  final String imageUrl;
  final String description;

  const _Destination(
      this.name,
      this.country,
      this.category,
      this.budget,
      this.imageUrl,
      this.description,
      );
}

class _Mood {
  final String name;
  final IconData icon;

  const _Mood(
      this.name,
      this.icon,
      );
}

class _Traveler {
  final String name;
  final String subtitle;
  final String emoji;

  const _Traveler(
      this.name,
      this.subtitle,
      this.emoji,
      );
}