import 'package:flutter/material.dart';
import '../../app_routes.dart';

class TripDetailsScreen extends StatefulWidget {
  const TripDetailsScreen({super.key});

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _startLocationController = TextEditingController();
  final TextEditingController _daysController = TextEditingController(text: '3');
  final TextEditingController _travelersController = TextEditingController(text: '1');
  final TextEditingController _budgetController = TextEditingController(text: '1000');

  DateTime _startDate = DateTime.now().add(const Duration(days: 7));

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
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  void _proceed() {
    if (_formKey.currentState!.validate()) {
      Navigator.pushNamed(context, AppRoutes.selectDestination);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Step 1: Trip Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Basic Information',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _startLocationController,
                decoration: const InputDecoration(
                  labelText: 'Starting Location',
                  prefixIcon: Icon(Icons.my_location),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Enter starting point' : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start Date'),
                subtitle: Text('${_startDate.toLocal()}'.split(' ')[0]),
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
                validator: (v) => (v == null || int.tryParse(v) == null) ? 'Enter valid days' : null,
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
                validator: (v) => (v == null || int.tryParse(v) == null) ? 'Enter valid count' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _budgetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Estimated Budget (\$)',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || double.tryParse(v) == null) ? 'Enter valid budget' : null,
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _proceed,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('Next: Choose Destination'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}