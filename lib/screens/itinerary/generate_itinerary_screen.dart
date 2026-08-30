import 'package:flutter/material.dart';
import '../../app_routes.dart';

class GenerateItineraryScreen extends StatefulWidget {
  const GenerateItineraryScreen({super.key});

  @override
  State<GenerateItineraryScreen> createState() => _GenerateItineraryScreenState();
}

class _GenerateItineraryScreenState extends State<GenerateItineraryScreen> {
  bool _isGenerating = true;
  final List<String> _steps = [
    'Optimizing route order to reduce travel distance...',
    'Checking attraction opening hours & visit durations...',
    'Fitting transport, meal, and hotel schedules...',
    'Verifying overall budget limits...',
    'Itinerary successfully created!'
  ];
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _startGenerationProgress();
  }

  void _startGenerationProgress() async {
    for (int i = 0; i < _steps.length - 1; i++) {
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) {
        setState(() {
          _currentStep = i + 1;
        });
      }
    }
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generating Itinerary')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _isGenerating ? _buildLoadingState() : _buildSummaryState(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 32),
        Text(
          _steps[_currentStep],
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 24),
        LinearProgressIndicator(
          value: (_currentStep + 1) / _steps.length,
        ),
      ],
    );
  }

  Widget _buildSummaryState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle_outline, color: Colors.green, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Your Itinerary is Ready!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: const [
                ListTile(
                  leading: Icon(Icons.calendar_month),
                  title: Text('Trip Duration'),
                  trailing: Text('3 Days', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Divider(),
                ListTile(
                  leading: Icon(Icons.place),
                  title: Text('Spots Included'),
                  trailing: Text('6 Attractions', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Divider(),
                ListTile(
                  leading: Icon(Icons.attach_money),
                  title: Text('Estimated Total Cost'),
                  trailing: Text('\$780 / \$1,000', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: () => Navigator.pushNamed(context, AppRoutes.dayWiseItinerary),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text('View Day-Wise Itinerary'),
        ),
      ],
    );
  }
}