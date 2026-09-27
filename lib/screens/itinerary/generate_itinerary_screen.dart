import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../models/itinerary.dart';
import '../../services/itinerary_generator_service.dart';

class GenerateItineraryScreen extends StatefulWidget {
  final String tripId;

  const GenerateItineraryScreen({
    super.key,
    required this.tripId,
  });

  @override
  State<GenerateItineraryScreen> createState() =>
      _GenerateItineraryScreenState();
}

class _GenerateItineraryScreenState
    extends State<GenerateItineraryScreen> {
  final ItineraryGeneratorService
      _generatorService =
      ItineraryGeneratorService();

  bool _generating = true;

  String? _error;

  FullItinerary? _itinerary;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    try {
      setState(() {
        _generating = true;
        _error = null;
      });

      final itinerary =
          await _generatorService.generateForTrip(
        widget.tripId,
      );

      if (!mounted) return;

      setState(() {
        _itinerary = itinerary;
        _generating = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _generating = false;
        _error = e.toString();
      });
    }
  }

  int get _totalActivities {
    if (_itinerary == null) {
      return 0;
    }

    return _itinerary!.days.fold(
      0,
      (sum, day) =>
          sum + day.activities.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Generate Itinerary'),
      ),
      body: Padding(
        padding:
            const EdgeInsets.all(24),
        child: _generating
            ? _buildGenerating()
            : _error != null
                ? _buildError()
                : _buildSuccess(),
      ),
    );
  }

  Widget _buildGenerating() {
    return const Column(
      mainAxisAlignment:
          MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 24),
        Text(
          'Generating your itinerary...',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'Optimizing route order, calculating travel time and arranging activities day-wise.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 70,
          ),
          const SizedBox(height: 16),
          const Text(
            'Could not generate itinerary',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _error ?? '',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _generate,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    final itinerary =
        _itinerary!;

    return Column(
      children: [
        const Icon(
          Icons.check_circle,
          size: 80,
          color: Colors.green,
        ),
        const SizedBox(height: 16),
        const Text(
          'Itinerary Ready!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: Column(
            children: [
              ListTile(
                leading:
                    const Icon(Icons.calendar_month),
                title:
                    const Text('Trip Duration'),
                trailing: Text(
                  '${itinerary.days.length} Days',
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading:
                    const Icon(Icons.place),
                title:
                    const Text('Activities'),
                trailing: Text(
                  '$_totalActivities',
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading:
                    const Icon(Icons.route),
                title:
                    const Text('Planning'),
                trailing:
                    const Text(
                  'Optimized',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(
                context,
                AppRoutes.dayWiseItinerary,
                arguments: {
                  'tripId': widget.tripId,
                },
              );
            },
            style:
                ElevatedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(
                vertical: 16,
              ),
            ),
            child: const Text(
              'View Day-Wise Itinerary',
            ),
          ),
        ),
      ],
    );
  }
}