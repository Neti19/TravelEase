import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../services/trip_service.dart';

class TransportSelectionScreen extends StatefulWidget {
  final String tripId;

  const TransportSelectionScreen({
    super.key,
    required this.tripId,
  });

  @override
  State<TransportSelectionScreen> createState() =>
      _TransportSelectionScreenState();
}

class _TransportSelectionScreenState
    extends State<TransportSelectionScreen> {
  final TripService _tripService = TripService();

  int? _selectedIndex;
  bool _saving = false;

  final List<Map<String, dynamic>> _options = [
    {
      'type': 'Car / Self Drive',
      'description': 'Drive yourself during the trip',
      'icon': Icons.directions_car_rounded,
      'color': Color(0xFF1677FF),
    },
    {
      'type': 'Taxi / Cab',
      'description': 'Use taxis or ride services',
      'icon': Icons.local_taxi_rounded,
      'color': Color(0xFFFF8A65),
    },
    {
      'type': 'Public Transport',
      'description': 'Bus, metro or local transit',
      'icon': Icons.directions_bus_rounded,
      'color': Color(0xFF1677FF),
    },
    {
      'type': 'Rental Bike',
      'description': 'Explore using a rented bike',
      'icon': Icons.two_wheeler_rounded,
      'color': Color(0xFFFF8A65),
    },
    {
      'type': 'Walking',
      'description': 'Walk between nearby places',
      'icon': Icons.directions_walk_rounded,
      'color': Color(0xFF1677FF),
    },
  ];

  Future<void> _continue() async {
    if (_selectedIndex == null || _saving) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final selectedTransport =
      _options[_selectedIndex!];

      await _tripService.updateTrip(
        widget.tripId,
        {
          'transportSelected': true,
          'selectedTransport': {
            'type': selectedTransport['type'],
          },
          'updatedAt':
          DateTime.now().toIso8601String(),
        },
      );

      if (!mounted) return;

      Navigator.pushNamed(
        context,
        AppRoutes.mapNavigation,
        arguments: {
          'tripId': widget.tripId,
        },
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not save transportation: $e',
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        titleSpacing: 20,
        title: const Text(
          'Transportation',
          style: TextStyle(
            color: Color(0xFF102A43),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                30,
              ),
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                const Text(
                  'How will you get around?',
                  style: TextStyle(
                    color: Color(0xFF102A43),
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose the main transportation you plan to use during your trip.',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    height: 1.4,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(
                  _options.length,
                  _buildTransportCard,
                ),
              ],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1677FF),
            Color(0xFF45A9FF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color:
            const Color(0xFF1677FF).withOpacity(0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.directions_car_rounded,
              color: Colors.white,
              size: 29,
            ),
          ),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose your ride',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Tell us how you plan to move around your destination.',
                  style: TextStyle(
                    color: Colors.white,
                    height: 1.4,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransportCard(int index) {
    final option = _options[index];

    final selected = _selectedIndex == index;

    final color =
    option['color'] as Color;

    return AnimatedContainer(
      duration:
      const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? color
              : const Color(0xFFE6EDF3),
          width: selected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              selected ? 0.07 : 0.025,
            ),
            blurRadius: selected ? 14 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  color: selected
                      ? color.withOpacity(0.12)
                      : const Color(0xFFF2F6FA),
                  borderRadius:
                  BorderRadius.circular(17),
                ),
                child: Icon(
                  option['icon'] as IconData,
                  color: selected
                      ? color
                      : const Color(0xFF607D8B),
                  size: 28,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      option['type'] as String,
                      style: const TextStyle(
                        color: Color(0xFF102A43),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      option['description']
                      as String,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration:
                const Duration(milliseconds: 180),
                height: 30,
                width: 30,
                decoration: BoxDecoration(
                  color: selected
                      ? color
                      : const Color(0xFFF1F5F8),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  selected
                      ? Icons.check_rounded
                      : Icons
                      .radio_button_unchecked_rounded,
                  color: selected
                      ? Colors.white
                      : const Color(0xFF78909C),
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final hasSelection =
        _selectedIndex != null;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          20,
          12,
          20,
          16,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  hasSelection
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded,
                  color: hasSelection
                      ? const Color(0xFF1677FF)
                      : const Color(0xFF78909C),
                  size: 19,
                ),
                const SizedBox(width: 8),
                Text(
                  hasSelection
                      ? _options[_selectedIndex!]['type']
                  as String
                      : 'Select a transportation mode',
                  style: TextStyle(
                    color: hasSelection
                        ? const Color(0xFF102A43)
                        : Colors.grey.shade700,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed:
                hasSelection && !_saving
                    ? _continue
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  const Color(0xFF1677FF),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                  const Color(0xFFB8D6F7),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(17),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                  height: 22,
                  width: 22,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
                    : const Row(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continue to Route',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}