import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../services/trip_service.dart';

class TransportSelectionScreen
    extends StatefulWidget {
  final String tripId;

  const TransportSelectionScreen({
    super.key,
    required this.tripId,
  });

  @override
  State<TransportSelectionScreen>
  createState() =>
      _TransportSelectionScreenState();
}

class _TransportSelectionScreenState
    extends State<TransportSelectionScreen> {
  final TripService _tripService =
  TripService();

  int _selectedIndex = 0;

  final List<Map<String, String>> _options = [
    {
      'type': 'Flight',
      'provider': 'SkyExpress Airlines',
      'departure': '08:00 AM',
      'arrival': '11:30 AM',
      'duration': '3h 30m',
      'cost': '\$220',
    },
    {
      'type': 'Train',
      'provider': 'Shinkansen Bullet Train',
      'departure': '09:15 AM',
      'arrival': '01:45 PM',
      'duration': '4h 30m',
      'cost': '\$130',
    },
    {
      'type': 'Bus',
      'provider': 'InterCity Express',
      'departure': '07:00 AM',
      'arrival': '03:00 PM',
      'duration': '8h 00m',
      'cost': '\$45',
    },
  ];

  Future<void> _continue() async {
    final selectedTransport =
    _options[_selectedIndex];

    await _tripService.updateTrip(
      widget.tripId,
      {
        'transportSelected': true,
        'selectedTransport':
        selectedTransport,
        'updatedAt':
        DateTime.now()
            .toIso8601String(),
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
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '7. Select Transport',
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding:
              const EdgeInsets.all(16),
              itemCount:
              _options.length,
              itemBuilder:
                  (context, index) {
                final item =
                _options[index];

                return Card(
                  margin:
                  const EdgeInsets.only(
                    bottom: 12,
                  ),
                  child:
                  RadioListTile<int>(
                    value: index,
                    groupValue:
                    _selectedIndex,
                    onChanged:
                        (val) {
                      if (val == null) {
                        return;
                      }

                      setState(() {
                        _selectedIndex =
                            val;
                      });
                    },
                    title: Text(
                      '${item['type']} - ${item['provider']}',
                      style:
                      const TextStyle(
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Dep: ${item['departure']} → '
                          'Arr: ${item['arrival']} '
                          '(${item['duration']})',
                    ),
                    secondary: Text(
                      item['cost']!,
                      style:
                      const TextStyle(
                        fontSize: 16,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding:
            const EdgeInsets.all(16),
            child:
            ElevatedButton(
              onPressed:
              _continue,
              style:
              ElevatedButton.styleFrom(
                minimumSize:
                const Size(
                  double.infinity,
                  50,
                ),
              ),
              child: const Text(
                'Continue to Main Route',
              ),
            ),
          ),
        ],
      ),
    );
  }
}