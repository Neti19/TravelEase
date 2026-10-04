import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../widgets/dashboard_navigation_button.dart';

class HelpMeChooseScreen extends StatefulWidget {
  const HelpMeChooseScreen({super.key});

  @override
  State<HelpMeChooseScreen> createState() => _HelpMeChooseScreenState();
}

class _HelpMeChooseScreenState extends State<HelpMeChooseScreen> {
  final PageController _pageController = PageController();

  int _currentStep = 0;

  final Set<String> _selectedExperiences = {};
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
        return _selectedExperiences.isNotEmpty;
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
        if (!_selectedExperiences.add(value)) {
          _selectedExperiences.remove(value);
        }
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
        'experience': _selectedExperiences.join(', '),
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
      backgroundColor: const Color(0xFFF3F7FC),
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
      padding: EdgeInsets.symmetric(horizontal: isWide ? 48 : 20, vertical: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: _back,
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF17466F),
              fixedSize: const Size(44, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Help me choose',
                      style: TextStyle(
                        color: Color(0xFF102A43),
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: Color(0xFFFFA928),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _currentStep == 0
                      ? 'Your trip, your way'
                      : 'A few details for a better match',
                  style: const TextStyle(
                    color: Color(0xFF718096),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2EAF3)),
            ),
            child: Text(
              '0${_currentStep + 1} / 04',
              style: const TextStyle(
                color: Color(0xFF17466F),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const DashboardNavigationButton(),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Row(
        children: List.generate(4, (index) {
          final complete = index <= _currentStep;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              height: 5,
              margin: EdgeInsets.only(right: index == 3 ? 0 : 6),
              decoration: BoxDecoration(
                color: complete
                    ? const Color(0xFF1677FF)
                    : const Color(0xFFDDE7F1),
                borderRadius: BorderRadius.circular(10),
                boxShadow: complete
                    ? [
                        BoxShadow(
                          color: const Color(0xFF1677FF).withValues(alpha: 0.2),
                          blurRadius: 7,
                        ),
                      ]
                    : null,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildExperienceStep(bool isWide) {
    return _buildChoicePage(
      eyebrow: 'YOUR TRAVEL VIBE',
      title: 'What kind of trip\nsounds exciting?',
      subtitle: 'Choose all the experiences you would love to have.',
      choices: _experiences,
      selectedValue: _selectedExperiences.join(','),
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
      subtitle: 'Choose the trip length you have in mind.',
      choices: _durations,
      selectedValue: _duration,
      onSelected: _selectChoice,
      isWide: isWide,
    );
  }

  Widget _buildBudgetStep(bool isWide) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(isWide ? 48 : 20, 24, isWide ? 48 : 20, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
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
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0xFFE2EAF3)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF17466F).withValues(alpha: 0.07),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4D9),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Center(
                        child: Text('💰', style: TextStyle(fontSize: 34)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _formatBudget(),
                      style: const TextStyle(
                        color: Color(0xFF102A43),
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.2,
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
                    Icon(Icons.auto_awesome_rounded, color: Color(0xFF1677FF)),
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
      padding: EdgeInsets.fromLTRB(isWide ? 48 : 20, 26, isWide ? 48 : 20, 30),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFEAF4FF), Color(0xFFF5FAFF)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFDDEBFA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEyebrow(eyebrow),
                    const SizedBox(height: 13),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF102A43),
                        fontSize: 32,
                        height: 1.08,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.9,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF627D98),
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                    ),
                    if (_currentStep == 0) ...[
                      const SizedBox(height: 14),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _selectedExperiences.isEmpty
                            ? const Text(
                                'Pick as many as you like',
                                key: ValueKey('experience-hint'),
                                style: TextStyle(
                                  color: Color(0xFF1677FF),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              )
                            : Wrap(
                                key: ValueKey(_selectedExperiences.join('|')),
                                spacing: 6,
                                runSpacing: 6,
                                children: _selectedExperiences
                                    .map(
                                      (experience) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFC9DFF5),
                                          ),
                                        ),
                                        child: Text(
                                          experience,
                                          style: const TextStyle(
                                            color: Color(0xFF17466F),
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: choices.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isWide ? 2 : 1,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: isWide ? 2.75 : 3.0,
                ),
                itemBuilder: (context, index) {
                  final choice = choices[index];
                  final selected = (selectedValue ?? '')
                      .split(',')
                      .contains(choice.title);

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
    return AnimatedScale(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      scale: selected ? 1.015 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF9FCFF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF3389F5) : const Color(0xFFE2EAF2),
            width: selected ? 1.7 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? const Color(0xFF1677FF).withValues(alpha: 0.12)
                  : const Color(0xFF16324F).withValues(alpha: 0.045),
              blurRadius: selected ? 18 : 12,
              offset: Offset(0, selected ? 7 : 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: choice.color,
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Center(
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 220),
                        scale: selected ? 1.12 : 1,
                        curve: Curves.easeOutBack,
                        child: Text(
                          choice.emoji,
                          style: const TextStyle(fontSize: 27),
                        ),
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
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          choice.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF829AB1),
                            fontSize: 11,
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
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(scale: animation, child: child);
                      },
                      child: selected
                          ? const Icon(
                              Icons.check_rounded,
                              key: ValueKey('selected'),
                              size: 17,
                              color: Colors.white,
                            )
                          : const SizedBox(
                              key: ValueKey('unselected'),
                              width: 17,
                              height: 17,
                            ),
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

  Widget _buildEyebrow(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
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
      padding: EdgeInsets.fromLTRB(isWide ? 48 : 20, 12, isWide ? 48 : 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE7EEF5))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Row(
            children: [
              if (_currentStep > 0)
                TextButton.icon(
                  onPressed: _back,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Back'),
                ),
              if (_currentStep > 0) const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _canContinue ? _next : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1677FF),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFD9E4EF),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Text(
                          _currentStep == 3
                              ? 'Find My Destinations'
                              : 'Continue',
                          key: ValueKey(_currentStep),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _currentStep == 3
                            ? Icons.auto_awesome_rounded
                            : Icons.arrow_forward_rounded,
                        size: 18,
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
