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
  final HotelService _hotelService = HotelService();
  final TripDestinationService _destinationService =
      TripDestinationService();
  final TripService _tripService = TripService();

  List<Map<String, dynamic>> _hotels = [];

  String? _selectedHotelId;

  bool _loading = true;
  double _maxPrice = 3000;

  @override
  void initState() {
    super.initState();
    _loadHotels();
  }

  Future<void> _loadHotels() async {
    try {
      final trip =
          await _tripService.getTrip(widget.tripId);

      if (trip == null) {
        throw Exception('Trip not found.');
      }

      final selectedPlaces =
          await _destinationService.getSelectedPlaces(
        widget.tripId,
      );

      final hotels =
          await _hotelService.getHotelsNearPlaces(
        selectedPlaces: selectedPlaces,
        maxPricePerNight: _maxPrice,
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

      _showMessage('Could not load hotels: $e');
    }
  }

  Future<void> _applyPriceFilter() async {
    setState(() {
      _loading = true;
    });

    await _loadHotels();
  }

  Future<void> _continue() async {
    if (_selectedHotelId == null) {
      _showMessage('Please select a hotel.');
      return;
    }

    final selectedHotel = _hotels.firstWhere(
      (hotel) => hotel['id'] == _selectedHotelId,
    );

    await _tripService.updateTrip(
      widget.tripId,
      {
        'selectedHotel': selectedHotel,
        'hotelSelected': true,
      },
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

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('5. Select Hotel'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Maximum price per night',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              min: 500,
                              max: 10000,
                              divisions: 19,
                              value: _maxPrice,
                              label:
                                  '₹${_maxPrice.toInt()}',
                              onChanged: (value) {
                                setState(() {
                                  _maxPrice = value;
                                });
                              },
                            ),
                          ),
                          Text(
                            '₹${_maxPrice.toInt()}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _applyPriceFilter,
                          child: const Text(
                            'Apply Price Filter',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _hotels.isEmpty
                      ? const Center(
                          child: Text(
                            'No hotels found within your price range.',
                          ),
                        )
                      : ListView.builder(
                          padding:
                              const EdgeInsets.all(16),
                          itemCount: _hotels.length,
                          itemBuilder:
                              (context, index) {
                            final hotel =
                                _hotels[index];

                            final id =
                                hotel['id'].toString();

                            final name =
                                hotel['name']
                                    ?.toString() ??
                                'Hotel';

                            final address =
                                hotel['address']
                                    ?.toString() ??
                                '';

                            final price =
                                (hotel['pricePerNight']
                                            as num?)
                                        ?.toDouble() ??
                                    0;

                            final rating =
                                (hotel['rating']
                                            as num?)
                                        ?.toDouble() ??
                                    0;

                            final distance =
                                (hotel[
                                            'distanceFromAttractionsKm']
                                        as num?)
                                    ?.toDouble() ??
                                0;

                            return Card(
                              margin:
                                  const EdgeInsets.only(
                                bottom: 12,
                              ),
                              child:
                                  RadioListTile<String>(
                                value: id,
                                groupValue:
                                    _selectedHotelId,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedHotelId =
                                        value;
                                  });
                                },
                                title: Text(
                                  name,
                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  '$address\n'
                                  '₹${price.toInt()} / night\n'
                                  '⭐ $rating • '
                                  '${distance.toStringAsFixed(1)} km from selected place',
                                ),
                                secondary: const Icon(
                                  Icons.hotel,
                                  color: Colors.teal,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _loading ? null : _continue,
          style: ElevatedButton.styleFrom(
            minimumSize:
                const Size(double.infinity, 50),
          ),
          child: const Text(
            'Next: Select Restaurant',
          ),
        ),
      ),
    );
  }
}