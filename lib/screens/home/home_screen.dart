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
    _Destination('Goa', 'India', '🏖️', 'Beach • Food • Nightlife', 15000, Color(0xFFFFB000)),
    _Destination('Manali', 'India', '🏔️', 'Mountains • Adventure • Nature', 18000, Color(0xFF1677FF)),
    _Destination('Bali', 'Indonesia', '🌴', 'Beach • Food • Relax', 35000, Color(0xFF1FA7A0)),
    _Destination('Dubai', 'UAE', '🌆', 'City • Luxury • Shopping', 45000, Color(0xFFFF8A65)),
    _Destination('Tokyo', 'Japan', '⛩️', 'Culture • Food • City', 70000, Color(0xFF7B61FF)),
    _Destination('Paris', 'France', '🗼', 'Culture • Romance • Food', 85000, Color(0xFFE85D75)),
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
    _Traveler('The Explorer', 'Hidden gems and adventures', '🧭'),
    _Traveler('The Relaxer', 'Slow days and beautiful places', '🌊'),
    _Traveler('The Foodie', 'Local food is the priority', '🍜'),
    _Traveler('The Planner', 'Every detail neatly organized', '🗓️'),
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
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  void _scrollTo(GlobalKey key) {
    final target = key.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  _Destination _recommendedDestination() {
    final mood = _moods[_selectedMood].name.toLowerCase();
    final traveler = _travelers[_selectedTraveler].name.toLowerCase();

    int score(_Destination d) {
      final text = d.category.toLowerCase();
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
        if (text.contains(word)) value += 6;
      }

      if (traveler.contains('explorer') &&
          (text.contains('adventure') || text.contains('mountain') || text.contains('culture'))) {
        value += 3;
      }
      if (traveler.contains('relaxer') && (text.contains('beach') || text.contains('relax'))) {
        value += 3;
      }
      if (traveler.contains('foodie') && text.contains('food')) value += 4;
      if (traveler.contains('planner')) value += 1;

      if (d.budget <= _budget) {
        value += 4;
      } else if (d.budget <= _budget + 20000) {
        value += 1;
      } else {
        value -= 3;
      }

      return value;
    }

    final sorted = [..._destinations]..sort((a, b) => score(b).compareTo(score(a)));
    return sorted.first;
  }

  void _discover() {
    _requireLogin(() {
      final destination = _recommendedDestination();
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (sheetContext) => _RecommendationSheet(
          destination: destination,
          mood: _moods[_selectedMood].name,
          traveler: _travelers[_selectedTraveler].name,
          budget: _budget.round(),
          onPlan: () {
            Navigator.pop(sheetContext);
            _startPlanning();
          },
        ),
      );
    });
  }

  List<_Destination> get _filteredDestinations {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _destinations;
    return _destinations.where((d) {
      return d.name.toLowerCase().contains(query) ||
          d.country.toLowerCase().contains(query) ||
          d.category.toLowerCase().contains(query);
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

  Widget _pageSection({required Widget child, double top = 0}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, top == 0 ? 64 : top, 20, 64),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: child,
        ),
      ),
    );
  }

  Widget _buildNav() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Row(
            children: [
              _brand(),
              const Spacer(),
              if (MediaQuery.sizeOf(context).width >= 760) ...[
                _navButton('Explore', () => _scrollTo(_exploreKey)),
                _navButton('Discover', () => _scrollTo(_discoverKey)),
                _navButton('My Trips', _openMyTrips),
                const SizedBox(width: 8),
                _authButton(),
              ] else ...[
                IconButton(
                  onPressed: () => _showMobileMenu(),
                  icon: const Icon(Icons.menu_rounded),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _brand() {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _scrollController.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1677FF), Color(0xFF00A6A6)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.flight_takeoff_rounded, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Text('TravelEase', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Color(0xFF102A43))),
        ],
      ),
    );
  }

  Widget _navButton(String text, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      child: Text(text, style: const TextStyle(color: Color(0xFF486581), fontWeight: FontWeight.w700)),
    );
  }

  Widget _authButton() {
    return OutlinedButton.icon(
      onPressed: _isLoggedIn ? _logout : () => Navigator.pushNamed(context, AppRoutes.login),
      icon: Icon(_isLoggedIn ? Icons.logout_rounded : Icons.login_rounded, size: 18),
      label: Text(_isLoggedIn ? 'Logout' : 'Login'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF1677FF),
        side: const BorderSide(color: Color(0xFFD6E4F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
    );
  }

  void _showMobileMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(leading: const Icon(Icons.explore_rounded), title: const Text('Explore'), onTap: () { Navigator.pop(sheetContext); _scrollTo(_exploreKey); }),
              ListTile(leading: const Icon(Icons.auto_awesome_rounded), title: const Text('Discover'), onTap: () { Navigator.pop(sheetContext); _scrollTo(_discoverKey); }),
              ListTile(leading: const Icon(Icons.luggage_rounded), title: const Text('My Trips'), onTap: () { Navigator.pop(sheetContext); _openMyTrips(); }),
              ListTile(leading: Icon(_isLoggedIn ? Icons.logout : Icons.login), title: Text(_isLoggedIn ? 'Logout' : 'Login'), onTap: () { Navigator.pop(sheetContext); _isLoggedIn ? _logout() : Navigator.pushNamed(context, AppRoutes.login); }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF102A43), Color(0xFF1677FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 820;
                final content = _heroContent();
                final visual = _heroVisual();
                if (!wide) {
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [content, const SizedBox(height: 36), visual]);
                }
                return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Expanded(flex: 11, child: content), const SizedBox(width: 35), Expanded(flex: 8, child: visual)]);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroContent() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.white.withOpacity(.12), borderRadius: BorderRadius.circular(30)),
        child: const Text('YOUR NEXT ADVENTURE STARTS HERE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .8)),
      ),
      const SizedBox(height: 22),
      const Text('Plan less.\nExperience more.', style: TextStyle(color: Colors.white, fontSize: 44, height: 1.05, fontWeight: FontWeight.w900)),
      const SizedBox(height: 15),
      const Text('Discover destinations, build meaningful itineraries and keep your entire trip organized in one place.', style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5)),
      const SizedBox(height: 24),
      _searchBox(),
      const SizedBox(height: 13),
      Wrap(spacing: 10, runSpacing: 10, children: [
        _heroAction('✨ Help me discover', true, _discover),
        _heroAction('Plan my own trip →', false, _startPlanning),
      ]),
    ]);
  }

  Widget _searchBox() {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17)),
      child: Row(children: [
        const Icon(Icons.search_rounded, color: Color(0xFF829AB1)),
        const SizedBox(width: 9),
        Expanded(child: TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _scrollTo(_exploreKey),
          decoration: const InputDecoration(border: InputBorder.none, hintText: 'Where are you dreaming of going?'),
        )),
        if (_searchController.text.isNotEmpty) IconButton(onPressed: () { _searchController.clear(); setState(() {}); }, icon: const Icon(Icons.close_rounded)),
      ]),
    );
  }

  Widget _heroAction(String text, bool primary, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(color: primary ? const Color(0xFFFFD166) : Colors.white.withOpacity(.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: primary ? Colors.transparent : Colors.white24)),
          child: Text(text, style: TextStyle(color: primary ? const Color(0xFF102A43) : Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
        ),
      ),
    );
  }

  Widget _heroVisual() {
    return Center(
      child: Container(
        width: 270,
        height: 270,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(colors: [Color(0xFF73D5E8), Color(0xFF1677FF), Color(0xFF102A43)], center: Alignment(-.3, -.3)),
          border: Border.all(color: Colors.white24, width: 2),
        ),
        child: const Center(child: Text('🌍', style: TextStyle(fontSize: 105))),
      ),
    );
  }

  Widget _sectionTitle(String eyebrow, String title, String subtitle) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(eyebrow, style: const TextStyle(color: Color(0xFF1677FF), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
      const SizedBox(height: 7),
      Text(title, style: const TextStyle(color: Color(0xFF102A43), fontSize: 28, fontWeight: FontWeight.w900)),
      const SizedBox(height: 7),
      Text(subtitle, style: const TextStyle(color: Color(0xFF627D98), fontSize: 14, height: 1.5)),
    ]);
  }

  Widget _buildMoodSection() {
    return _pageSection(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('START WITH A VIBE', 'What kind of trip are you craving?', 'Pick a mood and TravelEase will use it when suggesting destinations.'),
      const SizedBox(height: 22),
      Wrap(spacing: 10, runSpacing: 10, children: List.generate(_moods.length, (i) {
        final selected = i == _selectedMood;
        return ChoiceChip(
          selected: selected,
          label: Text(_moods[i].name),
          avatar: Icon(_moods[i].icon, size: 18),
          onSelected: (_) => setState(() => _selectedMood = i),
          selectedColor: const Color(0xFF1677FF),
          labelStyle: TextStyle(color: selected ? Colors.white : const Color(0xFF486581), fontWeight: FontWeight.w700),
          side: const BorderSide(color: Color(0xFFDCE7F0)),
        );
      })),
    ]));
  }

  Widget _buildDiscoverSection() {
    final destination = _recommendedDestination();

    return Container(
      key: _discoverKey,
      color: const Color(0xFFEFF8FF),
      child: _pageSection(
        top: 58,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 800;

            final left = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(
                  'SMART DISCOVERY',
                  'Let TravelEase find a match.',
                  'Your mood, travel personality and budget all influence the recommendation.',
                ),

                const SizedBox(height: 22),

                _choiceRow(
                  'Travel style',
                  '${_travelers[_selectedTraveler].emoji}  ${_travelers[_selectedTraveler].name}',
                  Icons.person_outline_rounded,
                ),

                const SizedBox(height: 10),

                _choiceRow(
                  'Budget',
                  '₹${_budget.round()}',
                  Icons.account_balance_wallet_outlined,
                ),

                const SizedBox(height: 18),

                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _discover,
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Find my destination'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1677FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            );

            final right = Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: const Color(0xFFDCEAF5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CURRENT MATCH',
                    style: TextStyle(
                      color: Color(0xFF1677FF),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    destination.emoji,
                    style: const TextStyle(
                      fontSize: 55,
                    ),
                  ),

                  const SizedBox(height: 7),

                  Text(
                    destination.name,
                    style: const TextStyle(
                      color: Color(0xFF102A43),
                      fontSize: 25,
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
                    destination.category,
                    style: const TextStyle(
                      color: Color(0xFF486581),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: left,
                  ),
                  const SizedBox(width: 40),
                  Expanded(
                    child: right,
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                left,
                const SizedBox(height: 25),
                right,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _choiceRow(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Row(children: [Icon(icon, color: const Color(0xFF1677FF), size: 20), const SizedBox(width: 10), Text(label, style: const TextStyle(color: Color(0xFF829AB1), fontSize: 12)), const Spacer(), Flexible(child: Text(value, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF102A43), fontWeight: FontWeight.w800, fontSize: 12)))]),
    );
  }

  Widget _buildExploreSection() {
    final items = _filteredDestinations;
    return Container(
      key: _exploreKey,
      color: Colors.white,
      child: _pageSection(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle('EXPLORE', 'Places worth planning around.', 'Search a destination or browse ideas to start your trip.'),
        const SizedBox(height: 22),
        if (items.isEmpty)
          Container(width: double.infinity, padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: const Color(0xFFF7FAFC), borderRadius: BorderRadius.circular(20)), child: const Center(child: Text('No destinations found. Try another search.')))
        else
          LayoutBuilder(builder: (context, constraints) {
            int columns = constraints.maxWidth >= 1000 ? 3 : constraints.maxWidth >= 650 ? 2 : 1;
            final cardWidth = (constraints.maxWidth - (columns - 1) * 15) / columns;
            return Wrap(spacing: 15, runSpacing: 15, children: items.map((d) => SizedBox(width: cardWidth, child: _destinationCard(d))).toList());
          }),
      ])),
    );
  }

  Widget _destinationCard(_Destination d) {
    return InkWell(
      onTap: _startPlanning,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 235,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: const Color(0xFFF7FAFC), borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE1EAF2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: Text('₹${_formatBudget(d.budget)}+', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF102A43)))), const Spacer(), Text(d.emoji, style: const TextStyle(fontSize: 43))]),
          const Spacer(),
          Text(d.name, style: const TextStyle(color: Color(0xFF102A43), fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(d.country, style: const TextStyle(color: Color(0xFF829AB1), fontSize: 12)),
          const SizedBox(height: 8),
          Text(d.category, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF486581), fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          const Text('Plan this destination →', style: TextStyle(color: Color(0xFF1677FF), fontSize: 11, fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }

  String _formatBudget(int value) => value >= 1000 ? '${(value / 1000).round()}k' : value.toString();

  Widget _buildBudgetSection() {
    return _pageSection(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('YOUR RANGE', 'How much do you want to spend?', 'This helps TravelEase recommend destinations that fit your trip.'),
      const SizedBox(height: 20),
      Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE1EAF2))), child: Column(children: [
        Row(children: [const Text('Trip budget', style: TextStyle(color: Color(0xFF486581), fontWeight: FontWeight.w700)), const Spacer(), Text('₹${_budget.round()}', style: const TextStyle(color: Color(0xFF1677FF), fontSize: 22, fontWeight: FontWeight.w900))]),
        Slider(value: _budget, min: 10000, max: 120000, divisions: 22, label: '₹${_budget.round()}', onChanged: (v) => setState(() => _budget = v)),
        Align(alignment: Alignment.centerLeft, child: Text(_budgetLabel(), style: const TextStyle(color: Color(0xFF829AB1), fontSize: 12))),
      ])),
    ]));
  }

  String _budgetLabel() {
    if (_budget < 20000) return 'Budget-friendly escape';
    if (_budget < 40000) return 'Smart getaway';
    if (_budget < 70000) return 'Comfort trip';
    if (_budget < 100000) return 'Premium adventure';
    return 'Dream vacation';
  }

  Widget _buildTravelerSection() {
    return Container(color: const Color(0xFFF7FAFC), child: _pageSection(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('TRAVEL PERSONALITY', 'What kind of traveler are you?', 'Your style helps shape the recommendations.'),
      const SizedBox(height: 22),
      LayoutBuilder(builder: (context, constraints) {
        int columns = constraints.maxWidth >= 950 ? 4 : constraints.maxWidth >= 600 ? 2 : 1;
        final width = (constraints.maxWidth - (columns - 1) * 13) / columns;
        return Wrap(spacing: 13, runSpacing: 13, children: List.generate(_travelers.length, (i) {
          final selected = i == _selectedTraveler;
          final t = _travelers[i];
          return SizedBox(width: width, child: InkWell(borderRadius: BorderRadius.circular(20), onTap: () => setState(() => _selectedTraveler = i), child: AnimatedContainer(duration: const Duration(milliseconds: 180), padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: selected ? const Color(0xFF1677FF) : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: selected ? const Color(0xFF1677FF) : const Color(0xFFE1EAF2)),), child: Row(children: [Text(t.emoji, style: const TextStyle(fontSize: 30)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t.name, style: TextStyle(color: selected ? Colors.white : const Color(0xFF102A43), fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(t.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: selected ? Colors.white70 : const Color(0xFF829AB1), fontSize: 11))]))]))));
        }));
      }),
    ])));
  }

  Widget _buildHowItWorks() {
    final steps = const [
      ('01', 'Discover', 'Find a destination that fits your vibe.', '📍'),
      ('02', 'Plan', 'Build days around places you actually want.', '✨'),
      ('03', 'Optimize', 'Connect places into a smarter route.', '🗺️'),
      ('04', 'Travel', 'Keep your plans and trip details together.', '🧳'),
    ];
    return _pageSection(child: Column(children: [
      _sectionTitle('THE TRAVELEASE WAY', 'From idea to itinerary.', 'A single workspace for planning the trip you actually want.'),
      const SizedBox(height: 25),
      LayoutBuilder(builder: (context, constraints) {
        int columns = constraints.maxWidth >= 900 ? 4 : constraints.maxWidth >= 600 ? 2 : 1;
        final width = (constraints.maxWidth - (columns - 1) * 13) / columns;
        return Wrap(spacing: 13, runSpacing: 13, children: steps.map((s) => SizedBox(width: width, child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFFF7FAFC), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE1EAF2))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text(s.$4, style: const TextStyle(fontSize: 28)), const Spacer(), Text(s.$1, style: const TextStyle(color: Color(0xFFC4D0DC), fontWeight: FontWeight.w900))]), const SizedBox(height: 14), Text(s.$2, style: const TextStyle(color: Color(0xFF102A43), fontSize: 16, fontWeight: FontWeight.w900)), const SizedBox(height: 6), Text(s.$3, style: const TextStyle(color: Color(0xFF829AB1), fontSize: 12, height: 1.4))])))).toList());
      }),
    ]));
  }

  Widget _buildFinalCta() {
    return Container(
      color: const Color(0xFF102A43),
      child: _pageSection(
        child: Column(
          children: [
            const Text(
              'Ready to make your next trip easier?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Start with a destination or let TravelEase help you discover one.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _startPlanning,
              icon: const Icon(Icons.flight_takeoff_rounded),
              label: const Text('Start planning'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFD166),
                foregroundColor: const Color(0xFF102A43),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(color: const Color(0xFF0B2035), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25), child: const Center(child: Text('TravelEase • Plan less. Experience more.', style: TextStyle(color: Colors.white60, fontSize: 12))));
  }
}

class _RecommendationSheet extends StatelessWidget {
  final _Destination destination;
  final String mood;
  final String traveler;
  final int budget;
  final VoidCallback onPlan;

  const _RecommendationSheet({required this.destination, required this.mood, required this.traveler, required this.budget, required this.onPlan});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: const Color(0xFFD8E2ED), borderRadius: BorderRadius.circular(10)))),
        const SizedBox(height: 22),
        const Text('YOUR TRAVELEASE MATCH', style: TextStyle(color: Color(0xFF1677FF), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 10),
        Text(destination.emoji, style: const TextStyle(fontSize: 52)),
        const SizedBox(height: 5),
        Text(destination.name, style: const TextStyle(color: Color(0xFF102A43), fontSize: 28, fontWeight: FontWeight.w900)),
        Text(destination.country, style: const TextStyle(color: Color(0xFF829AB1))),
        const SizedBox(height: 12),
        Text(destination.category, style: const TextStyle(color: Color(0xFF486581), fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Based on your $mood mood, $traveler style and ₹$budget budget.', style: const TextStyle(color: Color(0xFF627D98), fontSize: 13, height: 1.45)),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: onPlan, icon: const Icon(Icons.flight_takeoff_rounded), label: Text('Plan ${destination.name} trip'), style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1677FF), padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
      ])),
    );
  }
}

class _Destination {
  final String name;
  final String country;
  final String emoji;
  final String category;
  final int budget;
  final Color color;

  const _Destination(this.name, this.country, this.emoji, this.category, this.budget, this.color);
}

class _Mood {
  final String name;
  final IconData icon;
  const _Mood(this.name, this.icon);
}

class _Traveler {
  final String name;
  final String subtitle;
  final String emoji;
  const _Traveler(this.name, this.subtitle, this.emoji);
}
