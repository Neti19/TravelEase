import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../widgets/dashboard_navigation_button.dart';

class SelectPreferencesScreen extends StatefulWidget {
  final String tripId;

  const SelectPreferencesScreen({
    super.key,
    required this.tripId,
  });

  @override
  State<SelectPreferencesScreen> createState() =>
      _SelectPreferencesScreenState();
}

class _SelectPreferencesScreenState
    extends State<SelectPreferencesScreen> {
  final List<_Preference> _preferences = const [
    _Preference(
      name: 'Beach',
      description: 'Sun, sand & relaxing days',
      icon: Icons.beach_access_rounded,
      color: Color(0xFFFFD166),
    ),
    _Preference(
      name: 'Adventure',
      description: 'Thrills, hiking & exploration',
      icon: Icons.landscape_rounded,
      color: Color(0xFFFF8A65),
    ),
    _Preference(
      name: 'Food',
      description: 'Local flavours & great restaurants',
      icon: Icons.restaurant_rounded,
      color: Color(0xFFFFB74D),
    ),
    _Preference(
      name: 'Nature',
      description: 'Mountains, forests & fresh air',
      icon: Icons.park_rounded,
      color: Color(0xFF81C784),
    ),
    _Preference(
      name: 'Culture',
      description: 'History, art & local life',
      icon: Icons.museum_rounded,
      color: Color(0xFF9575CD),
    ),
    _Preference(
      name: 'Shopping',
      description: 'Markets, malls & local finds',
      icon: Icons.shopping_bag_rounded,
      color: Color(0xFF64B5F6),
    ),
    _Preference(
      name: 'Nightlife',
      description: 'Music, parties & evenings out',
      icon: Icons.nightlife_rounded,
      color: Color(0xFF7986CB),
    ),
    _Preference(
      name: 'Relaxation',
      description: 'Slow days, wellness & comfort',
      icon: Icons.spa_rounded,
      color: Color(0xFF4DB6AC),
    ),
  ];

  final Set<String> _selectedPreferences = {};

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSavedPreferences();
  }

  Future<void> _loadSavedPreferences() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.tripId)
          .get();

      final data = doc.data();

      final saved = data?['preferences'];

      if (saved is List) {
        _selectedPreferences.addAll(
          saved.whereType<String>(),
        );
      }

      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage('Could not load your previous choices.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.fixed,
        ),
      );
  }

  Future<void> _continue() async {
    if (_selectedPreferences.isEmpty) {
      _showMessage('Pick at least one experience you would love.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.tripId)
          .set(
        {
          'preferences': _selectedPreferences.toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      Navigator.pushNamed(
        context,
        AppRoutes.touristSpots,
        arguments: {
          'tripId': widget.tripId,
        },
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage('Something went wrong while saving your choices.');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _togglePreference(String name) {
    setState(() {
      if (_selectedPreferences.contains(name)) {
        _selectedPreferences.remove(name);
      } else {
        _selectedPreferences.add(name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7FAFC),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF1677FF),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7FAFC),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Help me choose',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF102A43),
          ),
        ),
        actions: const [DashboardNavigationButton()],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 1050,
            ),
            child: Column(
              children: [
                _buildProgress(),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      20,
                      20,
                      30,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),

                        const SizedBox(height: 30),

                        _buildPreferenceGrid(),

                        const SizedBox(height: 24),

                        _buildSelectionHint(),
                      ],
                    ),
                  ),
                ),

                _buildBottomBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgress() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFF1677FF),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFDCEAF5),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFDCEAF5),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            '1 of 3',
            style: TextStyle(
              color: Color(0xFF627D98),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0xFFDFF4FF),
            borderRadius: BorderRadius.circular(17),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Color(0xFF1677FF),
            size: 28,
          ),
        ),

        const SizedBox(height: 20),

        const Text(
          'What kind of trip\nsounds like you?',
          style: TextStyle(
            color: Color(0xFF102A43),
            fontSize: 34,
            height: 1.08,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 12),

        const Text(
          'Pick everything you would love to experience. '
              'TravelEase will use your choices to discover destinations '
              'that match your travel personality.',
          style: TextStyle(
            color: Color(0xFF627D98),
            fontSize: 15,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 14),

        Text(
          _selectedPreferences.isEmpty
              ? 'Choose as many as you like'
              : '${_selectedPreferences.length} selected',
          style: const TextStyle(
            color: Color(0xFF1677FF),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildPreferenceGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int columns;

        if (constraints.maxWidth >= 850) {
          columns = 4;
        } else if (constraints.maxWidth >= 560) {
          columns = 3;
        } else {
          columns = 2;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _preferences.length,
          gridDelegate:
          SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: columns == 2
                ? 0.78
                : columns == 3
                ? 0.9
                : 1.05,
          ),
          itemBuilder: (context, index) {
            return _buildPreferenceCard(
              _preferences[index],
            );
          },
        );
      },
    );
  }

  Widget _buildPreferenceCard(_Preference preference) {
    final selected =
    _selectedPreferences.contains(preference.name);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _togglePreference(preference.name),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFE8F3FF)
                : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? const Color(0xFF1677FF)
                  : const Color(0xFFE1EAF2),
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: selected ? 0.07 : 0.03,
                ),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: preference.color.withValues(
                        alpha: 0.18,
                      ),
                      borderRadius:
                      BorderRadius.circular(16),
                    ),
                    child: Icon(
                      preference.icon,
                      color: preference.color,
                      size: 27,
                    ),
                  ),
                  AnimatedContainer(
                    duration:
                    const Duration(milliseconds: 180),
                    width: 25,
                    height: 25,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF1677FF)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF1677FF)
                            : const Color(0xFFBCCCDC),
                        width: 1.5,
                      ),
                    ),
                    child: selected
                        ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 17,
                    )
                        : null,
                  ),
                ],
              ),

              const Spacer(),

              Text(
                preference.name,
                style: const TextStyle(
                  color: Color(0xFF102A43),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                preference.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF829AB1),
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionHint() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFE29A),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            color: Color(0xFFE09B00),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Not sure? That is completely fine. '
                  'Choose a few things that sound fun — '
                  'TravelEase will take care of the matching.',
              style: TextStyle(
                color: Color(0xFF7A5A00),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        20,
        14,
        20,
        18,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 1050,
        ),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton(
            onPressed:
            _saving ? null : _continue,
            style: FilledButton.styleFrom(
              backgroundColor:
              const Color(0xFF1677FF),
              disabledBackgroundColor:
              const Color(0xFFB7C9DB),
              shape: RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(16),
              ),
            ),
            child: _saving
                ? const SizedBox(
              width: 22,
              height: 22,
              child:
              CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
                : Row(
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: [
                const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Preference {
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  const _Preference({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });
}