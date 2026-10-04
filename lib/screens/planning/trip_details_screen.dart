import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../models/trip.dart';
import '../../services/trip_service.dart';
import '../../widgets/dashboard_navigation_button.dart';
import '../map/starting_location_picker_screen.dart';

class TripDetailsScreen extends StatefulWidget {
  const TripDetailsScreen({super.key});

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _startLocationController =
      TextEditingController();

  final TextEditingController _tripNameController = TextEditingController();

  final TextEditingController _daysController = TextEditingController(
    text: '3',
  );

  final TextEditingController _travelersController = TextEditingController(
    text: '1',
  );

  final TextEditingController _budgetController = TextEditingController(
    text: '1000',
  );

  DateTime _startDate = DateTime.now().add(const Duration(days: 7));

  double? _startLatitude;
  double? _startLongitude;

  bool _isSaving = false;

  @override
  void dispose() {
    _startLocationController.dispose();
    _tripNameController.dispose();
    _daysController.dispose();
    _travelersController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF1677FF)),
          ),
          child: child!,
        );
      },
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
      MaterialPageRoute(builder: (_) => const StartingLocationPickerScreen()),
    );

    if (result != null && result is Map) {
      setState(() {
        _startLocationController.text = result['address']?.toString() ?? '';

        _startLatitude = (result['latitude'] as num?)?.toDouble();

        _startLongitude = (result['longitude'] as num?)?.toDouble();
      });
    }
  }

  Future<void> _proceed() async {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_startLatitude == null || _startLongitude == null) {
      _showMessage('Please select your starting location from the map.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('Please login before creating a trip.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final numberOfDays = int.parse(_daysController.text.trim());

      final travelers = int.parse(_travelersController.text.trim());

      final budget = double.parse(_budgetController.text.trim());

      final trip = Trip(
        id: '',
        name: _tripNameController.text.trim(),
        startLocation: _startLocationController.text.trim(),
        startLatitude: _startLatitude!,
        startLongitude: _startLongitude!,
        destination: '',
        startDate: _startDate,
        endDate: _startDate.add(Duration(days: numberOfDays - 1)),
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
        arguments: <String, dynamic>{'tripId': tripId},
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      _showMessage('Failed to save trip: $e');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message.replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.fixed,
        ),
      );
  }

  String get _formattedDate {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${_startDate.day} '
        '${months[_startDate.month - 1]} '
        '${_startDate.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7FAFC),
        title: const Text(
          'Plan your trip',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF102A43),
          ),
        ),
        actions: const [DashboardNavigationButton()],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHero(),

                      const SizedBox(height: 24),

                      _buildSectionTitle(
                        'Let’s start with the basics',
                        'Tell us a little about your trip.',
                      ),

                      const SizedBox(height: 16),

                      _buildTripNameField(),

                      const SizedBox(height: 14),

                      _buildStartingLocation(),

                      const SizedBox(height: 14),

                      _buildDateCard(),

                      const SizedBox(height: 14),

                      _buildTripStats(),

                      const SizedBox(height: 24),

                      _buildPlanningTip(),
                    ],
                  ),
                ),
              ),

              _buildBottomButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1677FF), Color(0xFF4BA3FF)],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -25,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.10),
              ),
            ),
          ),
          Positioned(
            right: 35,
            bottom: -45,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.flight_takeoff_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Your next story\nstarts here.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                'Set the basics first. '
                'You’ll choose your destination next.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.88),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF102A43),
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildTripNameField() {
    return TextFormField(
      controller: _tripNameController,
      textCapitalization: TextCapitalization.words,
      decoration: _inputDecoration(
        label: 'Trip name',
        hint: 'e.g. Summer in Gujarat',
        icon: Icons.badge_outlined,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Enter a name for this trip';
        }

        return null;
      },
    );
  }

  Widget _buildStartingLocation() {
    final hasLocation = _startLocationController.text.trim().isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: _isSaving ? null : _selectStartingLocation,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasLocation ? const Color(0xFF1677FF) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF4FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: Color(0xFF1677FF),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Starting from',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hasLocation
                        ? _startLocationController.text
                        : 'Choose a location on the map',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF102A43),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              hasLocation
                  ? Icons.check_circle_rounded
                  : Icons.arrow_forward_ios_rounded,
              size: hasLocation ? 23 : 17,
              color: hasLocation
                  ? const Color(0xFF19A974)
                  : const Color(0xFF1677FF),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateCard() {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: _isSaving ? null : () => _selectDate(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF2EC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: Color(0xFFFF8A65),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Starting date',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formattedDate,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF102A43),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_calendar_rounded, color: Color(0xFF1677FF)),
          ],
        ),
      ),
    );
  }

  Widget _buildTripStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatField(
            controller: _daysController,
            label: 'Days',
            icon: Icons.wb_sunny_outlined,
            validator: (value) {
              final days = int.tryParse(value ?? '');

              if (days == null || days <= 0) {
                return 'Invalid';
              }

              return null;
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatField(
            controller: _travelersController,
            label: 'Travelers',
            icon: Icons.people_outline_rounded,
            validator: (value) {
              final travelers = int.tryParse(value ?? '');

              if (travelers == null || travelers <= 0) {
                return 'Invalid';
              }

              return null;
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatField(
            controller: _budgetController,
            label: 'Budget ₹',
            icon: Icons.currency_rupee_rounded,
            validator: (value) {
              final budget = double.tryParse(value ?? '');

              if (budget == null || budget <= 0) {
                return 'Invalid';
              }

              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 19),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF1677FF), width: 1.5),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildPlanningTip() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFF2A900)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TravelEase tip',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B4F00),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your starting point helps us '
                  'estimate distances and build a '
                  'smarter route later.',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton(
          onPressed: _isSaving ? null : _proceed,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1677FF),
            disabledBackgroundColor: Colors.grey.shade300,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _isSaving
              ? const SizedBox(
                  height: 23,
                  width: 23,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Choose Destination',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 9),
                    Icon(Icons.arrow_forward_rounded),
                  ],
                ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF1677FF)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF1677FF), width: 1.5),
      ),
    );
  }
}
