import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../services/hotel_service.dart';
import '../../services/trip_destination_service.dart';
import '../../services/trip_service.dart';

class HotelSelectionScreen extends StatefulWidget {
  final String tripId;

  const HotelSelectionScreen({
    super.key,
    required this.tripId,
  });

  @override
  State<HotelSelectionScreen> createState() =>
      _HotelSelectionScreenState();
}

class _HotelSelectionScreenState
    extends State<HotelSelectionScreen> {
  final HotelService _hotelService =
      HotelService();

  final TripDestinationService
      _destinationService =
      TripDestinationService();

  final TripService _tripService =
      TripService();

  List<Map<String, dynamic>> _hotels = [];

  String? _selectedHotelId;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHotels();
  }

  Future<void> _loadHotels() async {
    try {
      final selectedPlaces =
          await _destinationService
              .getSelectedPlaces(
        widget.tripId,
      );

      if (selectedPlaces.isEmpty) {
        throw Exception(
          'No tourist places selected.',
        );
      }

      final hotels =
          await _hotelService
              .getHotelsNearPlaces(
        selectedPlaces: selectedPlaces,
      );

      if (!mounted) return;

      setState(() {
        _hotels = hotels;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage(
        'Could not load hotels: $e',
      );
    }
  }

  Future<void> _continue() async {
    final data = <String, dynamic>{
      'hotelSelected':
          _selectedHotelId != null,
      'updatedAt':
          DateTime.now().toIso8601String(),
    };

    if (_selectedHotelId != null) {
      final selectedHotel =
          _hotels.firstWhere(
        (hotel) =>
            hotel['id'] ==
            _selectedHotelId,
      );

      data['selectedHotel'] =
          selectedHotel;
    }

    await _tripService.updateTrip(
      widget.tripId,
      data,
    );

    if (!mounted) return;

    Navigator.pushNamed(
      context,
      AppRoutes.restaurantSelection,
      arguments: {
        'tripId': widget.tripId,
      },
    );
  }

  String _getName(
    Map<String, dynamic> hotel,
  ) {
    final displayName =
        hotel['displayName']
            as Map<String, dynamic>?;

    return displayName?['text']
            ?.toString() ??
        'Hotel';
  }

  String _getPrice(
    Map<String, dynamic> hotel,
  ) {
    final price =
        hotel['priceLevel']
            ?.toString();

    switch (price) {
      case 'PRICE_LEVEL_INEXPENSIVE':
        return '₹ Inexpensive';

      case 'PRICE_LEVEL_MODERATE':
        return '₹₹ Moderate';

      case 'PRICE_LEVEL_EXPENSIVE':
        return '₹₹₹ Expensive';

      case 'PRICE_LEVEL_VERY_EXPENSIVE':
        return '₹₹₹₹ Very Expensive';

      default:
        return 'Price not available';
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('5. Nearby Hotels'),
      ),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : _hotels.isEmpty
              ? const Center(
                  child: Text(
                    'No nearby hotels found.',
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.all(16),
                  itemCount:
                      _hotels.length,
                  itemBuilder:
                      (context, index) {
                    final hotel =
                        _hotels[index];

                    final id =
                        hotel['id']
                            .toString();

                    final selected =
                        _selectedHotelId ==
                            id;

                    final address =
                        hotel[
                                    'formattedAddress']
                                ?.toString() ??
                            '';

                    final rating =
                        (hotel['rating']
                                    as num?)
                                ?.toDouble() ??
                            0;

                    final nearPlace =
                        hotel[
                                    'nearPlace']
                                ?.toString() ??
                            '';

                    return Card(
                      margin:
                          const EdgeInsets.only(
                        bottom: 12,
                      ),
                      child: ListTile(
                        leading: Icon(
                          selected
                              ? Icons
                                  .radio_button_checked
                              : Icons.hotel,
                          color: Colors.teal,
                        ),
                        title: Text(
                          _getName(hotel),
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '$address\n'
                          '${_getPrice(hotel)}\n'
                          '⭐ $rating\n'
                          'Near: $nearPlace',
                        ),
                        isThreeLine: true,
                        onTap: () {
                          setState(() {
                            // Tap again to unselect.
                            if (selected) {
                              _selectedHotelId =
                                  null;
                            } else {
                              _selectedHotelId =
                                  id;
                            }
                          });
                        },
                      ),
                    );
                  },
                ),
      bottomNavigationBar:
          Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Text(
              _selectedHotelId == null
                  ? 'No hotel selected (optional)'
                  : 'Hotel selected',
            ),
            const SizedBox(height: 8),
            SizedBox(
              width:
                  double.infinity,
              child: ElevatedButton(
                onPressed:
                    _loading
                        ? null
                        : _continue,
                child: const Text(
                  'Next: Restaurants',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}