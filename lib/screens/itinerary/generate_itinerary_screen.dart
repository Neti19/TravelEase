import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../services/itinerary_generator_service.dart';
import '../../services/trip_service.dart';
import '../../widgets/dashboard_navigation_button.dart';

class GenerateItineraryScreen extends StatefulWidget {
  final String tripId;

  const GenerateItineraryScreen({super.key, required this.tripId});

  @override
  State<GenerateItineraryScreen> createState() =>
      _GenerateItineraryScreenState();
}

class _GenerateItineraryScreenState extends State<GenerateItineraryScreen> {
  final ItineraryGeneratorService _generatorService =
      ItineraryGeneratorService();
  final TripService _tripService = TripService();

  bool _generating = true;

  String? _error;

  Future<void> _editTripDays() async {
    try {
      final trip = await _tripService.getTrip(widget.tripId);
      if (trip == null) {
        throw Exception('Trip not found.');
      }
      if (!mounted) return;

      final controller = TextEditingController(
        text: trip.numberOfDays.toString(),
      );
      final formKey = GlobalKey<FormState>();
      final updatedDays = await showDialog<int>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Edit trip duration'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Number of days',
                suffixText: 'days',
              ),
              validator: (value) {
                final days = int.tryParse(value?.trim() ?? '');
                if (days == null || days < 1) {
                  return 'Enter at least 1 day.';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                Navigator.pop(
                  dialogContext,
                  int.parse(controller.text.trim()),
                );
              },
              child: const Text('Save and generate'),
            ),
          ],
        ),
      );
      controller.dispose();

      if (updatedDays == null || !mounted) return;

      final endDate = DateTime(
        trip.startDate.year,
        trip.startDate.month,
        trip.startDate.day,
      ).add(Duration(days: updatedDays - 1));
      await _tripService.updateTrip(widget.tripId, {
        'numberOfDays': updatedDays,
        'endDate': endDate.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      await _generate();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _error = 'Could not update trip duration: $e';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    if (mounted) {
      setState(() {
        _generating = true;
        _error = null;
      });
    }

    try {
      await _generatorService.generateForTrip(widget.tripId);

      if (!mounted) return;

      /*
       * The itinerary has been generated successfully.
       *
       * There is no need to show an intermediate
       * "Itinerary Ready" page.
       *
       * Go directly to the actual day-wise itinerary.
       */
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.dayWiseItinerary,
        arguments: {'tripId': widget.tripId},
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _generating = false;
        _error = e.toString();
      });
    }
  }

  bool get _notEnoughTime {
    final error = (_error ?? '').toLowerCase();

    return error.contains('not enough time') ||
        error.contains('not enough practical time') ||
        error.contains('schedule all selected tourist places') ||
        error.contains('cannot fit') ||
        error.contains('could not fit') ||
        error.contains('fit into');
  }

  String get _displayError {
    final error = (_error ?? '').trim();
    if (error.isEmpty) {
      return 'Something went wrong while preparing your trip. You can try again.';
    }

    return error.replaceFirst(RegExp(r'^(Exception|StateError):\s*'), '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        title: const Text(
          'Your Itinerary',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF102A43),
          ),
        ),
        backgroundColor: const Color(0xFFF7FAFC),
        foregroundColor: const Color(0xFF102A43),
        actions: const [DashboardNavigationButton()],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _generating
            ? _buildGenerating()
            : _error != null
            ? _buildError()
            : const SizedBox.shrink(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // GENERATING
  // ---------------------------------------------------------------------------

  Widget _buildGenerating() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        key: const ValueKey('generating'),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F3FF),
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
              'Creating your itinerary',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF102A43),
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'We are arranging your selected places into a practical day-wise plan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF627D98),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.route_rounded, size: 18, color: Color(0xFF1677FF)),
                  SizedBox(width: 8),
                  Text(
                    'Optimizing your route',
                    style: TextStyle(
                      color: Color(0xFF486581),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ERROR
  // ---------------------------------------------------------------------------

  Widget _buildError() {
    if (_notEnoughTime) {
      return _buildPlanningAdjustment();
    }

    return _buildGeneralError();
  }

  // ---------------------------------------------------------------------------
  // NOT ENOUGH TIME
  // ---------------------------------------------------------------------------

  Widget _buildPlanningAdjustment() {
    return SingleChildScrollView(
      key: const ValueKey('planning-adjustment'),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E8),
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(
                Icons.schedule_rounded,
                size: 42,
                color: Color(0xFFFF8A65),
              ),
            ),
          ),

          const SizedBox(height: 24),

          const Center(
            child: Text(
              'Your plan needs a little adjustment',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF102A43),
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),

          const SizedBox(height: 10),

          const Center(
            child: Text(
              'The places you selected cannot comfortably fit into your current trip duration.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF627D98),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 28),

          const Text(
            'What would you like to change?',
            style: TextStyle(
              color: Color(0xFF102A43),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 12),

          _buildActionCard(
            icon: Icons.calendar_month_rounded,
            iconBackground: const Color(0xFFE8F3FF),
            iconColor: const Color(0xFF1677FF),
            title: 'Increase trip days',
            subtitle:
                'Give yourself more time to explore the places you selected.',
            onTap: _editTripDays,
          ),

          const SizedBox(height: 12),

          _buildActionCard(
            icon: Icons.place_rounded,
            iconBackground: const Color(0xFFFFF1EC),
            iconColor: const Color(0xFFFF8A65),
            title: 'Edit selected places',
            subtitle:
                'Remove a few places or choose different places for your trip.',
            onTap: () {
              Navigator.pushNamed(
                context,
                AppRoutes.touristSpots,
                arguments: {'tripId': widget.tripId},
              );
            },
          ),

          const SizedBox(height: 12),

          _buildActionCard(
            icon: Icons.edit_calendar_rounded,
            iconBackground: const Color(0xFFFFF8DD),
            iconColor: const Color(0xFFE3A900),
            title: 'Review your trip',
            subtitle:
                'Go back and change the trip duration before generating again.',
            onTap: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: _generate,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1677FF),
                side: const BorderSide(color: Color(0xFF1677FF)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                'Try Generating Again',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // GENERAL ERROR
  // ---------------------------------------------------------------------------

  Widget _buildGeneralError() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        key: const ValueKey('general-error'),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEDEC),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 42,
                color: Color(0xFFD64545),
              ),
            ),

            const SizedBox(height: 22),

            const Text(
              'We could not create your itinerary',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF102A43),
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              _displayError,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF627D98),
                fontSize: 14,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 26),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _generate,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1677FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  'Try Again',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF486581),
                  side: const BorderSide(color: Color(0xFFD9E2EC)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  'Go Back',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ACTION CARD
  // ---------------------------------------------------------------------------

  Widget _buildActionCard({
    required IconData icon,
    required Color iconBackground,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(14),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF627D98),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: Color(0xFF9FB3C8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
