import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../services/restaurant_service.dart';
import '../../services/trip_destination_service.dart';
import '../../services/trip_service.dart';

class RestaurantSelectionScreen extends StatefulWidget {
  final String tripId;

  const RestaurantSelectionScreen({
    super.key,
    required this.tripId,
  });

  @override
  State<RestaurantSelectionScreen> createState() =>
      _RestaurantSelectionScreenState();
}

class _RestaurantSelectionScreenState
    extends State<RestaurantSelectionScreen> {
  final RestaurantService _restaurantService =
      RestaurantService();

  final TripDestinationService _destinationService =
      TripDestinationService();

  final TripService _tripService = TripService();

  List<Map<String, dynamic>> _restaurants = [];

  String? _selectedRestaurantId;

  bool _loading = true;

  int _maxPriceLevel = 2;

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  Future<void> _loadRestaurants() async {
    try {
      final selectedPlaces =
          await _destinationService.getSelectedPlaces(
        widget.tripId,
      );

      final restaurants =
          await _restaurantService
              .getRestaurantsNearPlaces(
        selectedPlaces: selectedPlaces,
        maxPriceLevel: _maxPriceLevel,
      );

      if (!mounted) return;

      setState(() {
        _restaurants = restaurants;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage(
        'Could not load restaurants: $e',
      );
    }
  }

  String _priceText(int level) {
    switch (level) {
      case 0:
        return 'Free';
      case 1:
        return '₹ Inexpensive';
      case 2:
        return '₹₹ Moderate';
      case 3:
        return '₹₹₹ Expensive';
      case 4:
        return '₹₹₹₹ Very Expensive';
      default:
        return 'Unknown';
    }
  }

  Future<void> _continue() async {
    if (_selectedRestaurantId == null) {
      _showMessage('Please select a restaurant.');
      return;
    }

    final selectedRestaurant =
        _restaurants.firstWhere(
      (restaurant) =>
          restaurant['id'] ==
          _selectedRestaurantId,
    );

    await _tripService.updateTrip(
      widget.tripId,
      {
        'selectedRestaurant':
            selectedRestaurant,
        'restaurantSelected': true,
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
        title: const Text(
          '6. Select Restaurant',
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Maximum restaurant price',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium,
                      ),
                      DropdownButton<int>(
                        value: _maxPriceLevel,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: 1,
                            child:
                                Text('₹ Inexpensive'),
                          ),
                          DropdownMenuItem(
                            value: 2,
                            child:
                                Text('₹₹ Moderate'),
                          ),
                          DropdownMenuItem(
                            value: 3,
                            child:
                                Text('₹₹₹ Expensive'),
                          ),
                          DropdownMenuItem(
                            value: 4,
                            child:
                                Text('₹₹₹₹ Very Expensive'),
                          ),
                        ],
                        onChanged: (value) async {
                          if (value == null) return;

                          setState(() {
                            _maxPriceLevel =
                                value;
                            _loading = true;
                          });

                          await _loadRestaurants();
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _restaurants.isEmpty
                      ? const Center(
                          child: Text(
                            'No restaurants found within the selected price range.',
                          ),
                        )
                      : ListView.builder(
                          padding:
                              const EdgeInsets.all(16),
                          itemCount:
                              _restaurants.length,
                          itemBuilder:
                              (context, index) {
                            final restaurant =
                                _restaurants[index];

                            final id =
                                restaurant['id']
                                    .toString();

                            final displayName =
                                restaurant[
                                            'displayName']
                                        as Map<String,
                                            dynamic>?;

                            final name =
                                displayName?['text']
                                        ?.toString() ??
                                    'Restaurant';

                            final address =
                                restaurant[
                                            'formattedAddress']
                                        ?.toString() ??
                                    '';

                            final rating =
                                (restaurant[
                                            'rating']
                                        as num?)
                                    ?.toDouble() ??
                                0;

                            final distance =
                                (restaurant[
                                            'distanceFromPlaceKm']
                                        as num?)
                                    ?.toDouble() ??
                                0;

                            final priceLevel =
                                restaurant[
                                        'priceLevelNumber']
                                    as int? ??
                                2;

                            final nearPlace =
                                restaurant[
                                        'nearPlace']
                                    ?.toString() ??
                                '';

                            return Card(
                              margin:
                                  const EdgeInsets.only(
                                bottom: 12,
                              ),
                              child:
                                  RadioListTile<String>(
                                value: id,
                                groupValue:
                                    _selectedRestaurantId,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedRestaurantId =
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
                                  '${_priceText(priceLevel)} • '
                                  '⭐ $rating\n'
                                  '${distance.toStringAsFixed(1)} km from $nearPlace',
                                ),
                                secondary:
                                    const Icon(
                                  Icons.restaurant,
                                  color:
                                      Colors.deepOrange,
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
            'Complete & View Map',
          ),
        ),
      ),
    );
  }
}