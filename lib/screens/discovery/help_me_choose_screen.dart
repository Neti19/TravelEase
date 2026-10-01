import 'package:flutter/material.dart';

import '../../app_routes.dart';

class HelpMeChooseScreen extends StatefulWidget {
  const HelpMeChooseScreen({super.key});

  @override
  State<HelpMeChooseScreen> createState() => _HelpMeChooseScreenState();
}

class _HelpMeChooseScreenState extends State<HelpMeChooseScreen> {
  final PageController _pageController = PageController();

  int _currentStep = 0;

  String? _experience;
  String? _travelerType;
  String? _duration;

  double _budget = 30000;

  final List<_Choice> _experiences = const [
    _Choice(
      title: 'Beach',
      subtitle: 'Sun, sea & relaxing days',
      emoji: '🏖️',
      color: Color(0xFFE3F7FF),
    ),
    _Choice(
      title: 'Adventure',
      subtitle: 'Thrills, activities & exploration',
      emoji: '🧗',
      color: Color(0xFFFFEEE8),
    ),
    _Choice(
      title: 'Nature',
      subtitle: 'Mountains, forests & calm',
      emoji: '🌿',
      color: Color(0xFFE9F8EF),
    ),
    _Choice(
      title: 'Food',
      subtitle: 'Local flavours & food experiences',
      emoji: '🍜',
      color: Color(0xFFFFF5D9),
    ),
    _Choice(
      title: 'Culture',
      subtitle: 'History, art & local life',
      emoji: '🏛️',
      color: Color(0xFFF0EAFF),
    ),
    _Choice(
      title: 'Nightlife',
      subtitle: 'Music, events & vibrant nights',
      emoji: '🌃',
      color: Color(0xFFECEBFF),
    ),
    _Choice(
      title: 'Relaxation',
      subtitle: 'Slow days, wellness & comfort',
      emoji: '🧘',
      color: Color(0xFFE6F8F5),
    ),
    _Choice(
      title: 'Shopping',
      subtitle: 'Markets, malls & local finds',
      emoji: '🛍️',
      color: Color(0xFFFFEAF3),
    ),
  ];

  final List<_Choice> _travelerTypes = const [
    _Choice(
      title: 'Solo',
      subtitle: 'Just me',
      emoji: '🎒',
      color: Color(0xFFEAF4FF),
    ),
    _Choice(
      title: 'Couple',
      subtitle: 'A trip for two',
      emoji: '💑',
      color: Color(0xFFFFEAF0),
    ),
    _Choice(
      title: 'Friends',
      subtitle: 'Good times together',
      emoji: '👯',
      color: Color(0xFFFFF3DC),
    ),
    _Choice(
      title: 'Family',
      subtitle: 'Fun for everyone',
      emoji: '👨‍👩‍👧‍👦',
      color: Color(0xFFEAF8EE),
    ),
  ];

  final List<_Choice> _durations = const [
    _Choice(
      title: 'Weekend',
      subtitle: '1–2 days',
      emoji: '⚡',
      color: Color(0xFFFFF1DC),
    ),
    _Choice(
      title: 'Short trip',
      subtitle: '3–5 days',
      emoji: '🌤️',
      color: Color(0xFFE6F5FF),
    ),
    _Choice(
      title: 'One week',
      subtitle: '6–8 days',
      emoji: '🗓️',
      color: Color(0xFFEAF8EE),
    ),
    _Choice(
      title: 'Long escape',
      subtitle: '9+ days',
      emoji: '✈️',
      color: Color(0xFFF0EAFF),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _canContinue {
    switch (_currentStep) {
      case 0:
        return _experience != null;
      case 1:
        return _travelerType != null;
      case 2:
        return _duration != null;
      case 3:
        return true;
      default:
        return false;
    }
  }

  void _selectChoice(String value) {
    setState(() {
      if (_currentStep == 0) {
        _experience = value;
      } else if (_currentStep == 1) {
        _travelerType = value;
      } else if (_currentStep == 2) {
        _duration = value;
      }
    });
  }

  Future<void> _next() async {
    if (!_canContinue) {
      return;
    }

    if (_currentStep < 3) {
      setState(() {
        _currentStep++;
      });

      await _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );

      return;
    }

    _showComingSoon();
  }

  Future<void> _back() async {
    if (_currentStep == 0) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _currentStep--;
    });

    await _pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void _showComingSoon() {
    Navigator.pushNamed(
      context,
      AppRoutes.destinationRecommendations,
      arguments: <String, dynamic>{
        'experience': _experience!,
        'travelerType': _travelerType!,
        'duration': _duration!,
        'budget': _budget,
      },
    );
  }

  String _budgetLabel() {
    if (_budget < 15000) {
      return 'Budget escape';
    }

    if (_budget < 30000) {
      return 'Smart getaway';
    }

    if (_budget < 60000) {
      return 'Comfort trip';
    }

    if (_budget < 100000) {
      return 'Premium adventure';
    }

    return 'Dream vacation';
  }

  String _formatBudget() {
    if (_budget >= 100000) {
      return '₹${(_budget / 100000).toStringAsFixed(1)}L';
    }

    return '₹${_budget.toInt()}';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(isWide),
            _buildProgress(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildExperienceStep(isWide),
                  _buildTravelerStep(isWide),
                  _buildDurationStep(isWide),
                  _buildBudgetStep(isWide),
                ],
              ),
            ),
            _buildBottomBar(isWide),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isWide) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 48 : 20,
        vertical: 16,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _back,
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Help me choose',
                  style: TextStyle(
                    color: Color(0xFF102A43),
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Tell us your travel vibe',
                  style: TextStyle(
                    color: Color(0xFF627D98),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FF),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              '${_currentStep + 1} of 4',
              style: const TextStyle(
                color: Color(0xFF1677FF),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: LinearProgressIndicator(
          value: (_currentStep + 1) / 4,
          minHeight: 5,
          backgroundColor: const Color(0xFFE3EAF2),
          valueColor: const AlwaysStoppedAnimation<Color>(
            Color(0xFF1677FF),
          ),
        ),
      ),
    );
  }

  Widget _buildExperienceStep(bool isWide) {
    return _buildChoicePage(
      eyebrow: 'YOUR TRAVEL VIBE',
      title: 'What kind of trip\nsounds exciting?',
      subtitle:
      'Pick the experience you would love to have. You can change this later.',
      choices: _experiences,
      selectedValue: _experience,
      onSelected: _selectChoice,
      isWide: isWide,
    );
  }

  Widget _buildTravelerStep(bool isWide) {
    return _buildChoicePage(
      eyebrow: 'YOUR CREW',
      title: 'Who are you\ntravelling with?',
      subtitle:
      'This helps TravelEase suggest destinations that fit your trip style.',
      choices: _travelerTypes,
      selectedValue: _travelerType,
      onSelected: _selectChoice,
      isWide: isWide,
    );
  }

  Widget _buildDurationStep(bool isWide) {
    return _buildChoicePage(
      eyebrow: 'YOUR TIME',
      title: 'How long do you\nwant to escape?',
      subtitle:
      'Choose the trip length you have in mind.',
      choices: _durations,
      selectedValue: _duration,
      onSelected: _selectChoice,
      isWide: isWide,
    );
  }

  Widget _buildBudgetStep(bool isWide) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 48 : 20,
        vertical: 28,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 760,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEyebrow('YOUR BUDGET'),
              const SizedBox(height: 12),
              const Text(
                'What do you want\nto spend?',
                style: TextStyle(
                  color: Color(0xFF102A43),
                  fontSize: 34,
                  height: 1.08,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Set an approximate total budget for your trip. '
                    'We will use it when suggesting destinations.',
                style: TextStyle(
                  color: Color(0xFF627D98),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: const Color(0xFFE1EAF2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3D6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Text(
                          '💰',
                          style: TextStyle(fontSize: 34),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _formatBudget(),
                      style: const TextStyle(
                        color: Color(0xFF102A43),
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _budgetLabel(),
                      style: const TextStyle(
                        color: Color(0xFF1677FF),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Slider(
                      value: _budget,
                      min: 10000,
                      max: 200000,
                      divisions: 38,
                      activeColor: const Color(0xFF1677FF),
                      inactiveColor: const Color(0xFFDDE9F5),
                      onChanged: (value) {
                        setState(() {
                          _budget = value;
                        });
                      },
                    ),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹10K',
                          style: TextStyle(
                            color: Color(0xFF829AB1),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '₹2L+',
                          style: TextStyle(
                            color: Color(0xFF829AB1),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFF1677FF),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your budget is used as a guide. '
                            'You can always adjust the plan later.',
                        style: TextStyle(
                          color: Color(0xFF486581),
                          fontSize: 12.5,
                          height: 1.4,
                        ),
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

  Widget _buildChoicePage({
    required String eyebrow,
    required String title,
    required String subtitle,
    required List<_Choice> choices,
    required String? selectedValue,
    required ValueChanged<String> onSelected,
    required bool isWide,
  }) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 48 : 20,
        vertical: 28,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 850,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEyebrow(eyebrow),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF102A43),
                  fontSize: 34,
                  height: 1.08,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF627D98),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: choices.length,
                gridDelegate:
                SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isWide ? 2 : 1,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: isWide ? 2.6 : 2.8,
                ),
                itemBuilder: (context, index) {
                  final choice = choices[index];
                  final selected = selectedValue == choice.title;

                  return _buildChoiceCard(
                    choice: choice,
                    selected: selected,
                    onTap: () => onSelected(choice.title),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceCard({
    required _Choice choice,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected
              ? const Color(0xFF1677FF)
              : const Color(0xFFE1EAF2),
          width: selected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: selected
                ? const Color(0xFF1677FF).withOpacity(0.10)
                : Colors.black.withOpacity(0.035),
            blurRadius: selected ? 18 : 12,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: choice.color,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Center(
                    child: Text(
                      choice.emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        choice.title,
                        style: const TextStyle(
                          color: Color(0xFF102A43),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        choice.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF829AB1),
                          fontSize: 11.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? const Color(0xFF1677FF)
                        : Colors.transparent,
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF1677FF)
                          : const Color(0xFFBCCCDC),
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? const Icon(
                    Icons.check_rounded,
                    size: 17,
                    color: Colors.white,
                  )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEyebrow(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF1677FF),
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool isWide) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        isWide ? 48 : 20,
        12,
        isWide ? 48 : 20,
        16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(
            color: Color(0xFFE7EEF5),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 850,
          ),
          child: Row(
            children: [
              if (_currentStep > 0)
                TextButton.icon(
                  onPressed: _back,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Back'),
                ),
              if (_currentStep > 0)
                const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _canContinue ? _next : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1677FF),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                    const Color(0xFFD9E4EF),
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _currentStep == 3
                        ? 'Find My Destinations ✨'
                        : 'Continue',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
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
}

class _Choice {
  final String title;
  final String subtitle;
  final String emoji;
  final Color color;

  const _Choice({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.color,
  });
}