import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../app_routes.dart';
import '../map/starting_location_picker_screen.dart';
import '../../services/trip_service.dart';
import '../../models/trip.dart';

class TripDetailsScreen extends StatefulWidget {
  const TripDetailsScreen({super.key});

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _startLocationController =
      TextEditingController();

  final TextEditingController _daysController =
      TextEditingController(text: '3');

  final TextEditingController _travelersController =
      TextEditingController(text: '1');

  final TextEditingController _budgetController =
      TextEditingController(text: '1000');

  DateTime _startDate = DateTime.now().add(const Duration(days: 7));

  double? _startLatitude;
  double? _startLongitude;

  @override
  void dispose() {
    _startLocationController.dispose();
    _daysController.dispose();
    _travelersController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectStartingLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const StartingLocationPickerScreen(),
      ),
    );

    if (result != null && result is Map) {
      setState(() {
        _startLocationController.text =
            result['address']?.toString() ?? '';

        _startLatitude =
            (result['latitude'] as num?)?.toDouble();

        _startLongitude =
            (result['longitude'] as num?)?.toDouble();
      });
    }
  }

  Future<void> _proceed() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_startLatitude == null || _startLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select your starting location from the map.',
          ),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login before creating a trip.'),
        ),
      );
      return;
    }

    try {
      final numberOfDays = int.parse(_daysController.text);
      final travelers = int.parse(_travelersController.text);
      final budget = double.parse(_budgetController.text);

      final trip = Trip(
        id: '',
        startLocation: _startLocationController.text,
        startLatitude: _startLatitude!,
        startLongitude: _startLongitude!,
        destination: '',
        startDate: _startDate,
        endDate: _startDate.add(
          Duration(days: numberOfDays - 1),
        ),
        numberOfDays: numberOfDays,
        travelersCount: travelers,
        budget: budget,
        selectedPreferenceIds: [],
      );

      final tripId = await TripService().saveTrip(trip);

      if (!mounted) return;

      Navigator.pushNamed(
        context,
        AppRoutes.selectDestination,
        arguments: <String, dynamic>{
          'tripId': tripId,
        },
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save trip: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 1: Trip Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Basic Information',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              InkWell(
                onTap: _selectStartingLocation,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Starting Location',
                    prefixIcon: Icon(Icons.location_on),
                    suffixIcon: Icon(Icons.map),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _startLocationController.text.isEmpty
                        ? 'Select location from map'
                        : _startLocationController.text,
                    style: TextStyle(
                      color: _startLocationController.text.isEmpty
                          ? Colors.grey
                          : Colors.black,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start Date'),
                subtitle: Text(
                  '${_startDate.toLocal()}'.split(' ')[0],
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _daysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Number of Days',
                  prefixIcon: Icon(Icons.wb_sunny_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null ||
                      int.tryParse(value) == null) {
                    return 'Enter valid days';
                  }

                  if (int.parse(value) <= 0) {
                    return 'Days must be greater than 0';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _travelersController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Number of Travelers',
                  prefixIcon: Icon(Icons.people_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null ||
                      int.tryParse(value) == null) {
                    return 'Enter valid count';
                  }

                  if (int.parse(value) <= 0) {
                    return 'Travelers must be greater than 0';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _budgetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Estimated Budget (₹)',
                  prefixIcon: Icon(Icons.currency_rupee),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null ||
                      double.tryParse(value) == null) {
                    return 'Enter valid budget';
                  }

                  if (double.parse(value) <= 0) {
                    return 'Budget must be greater than 0';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 28),

              ElevatedButton(
                onPressed: _proceed,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Next: Choose Destination',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}