import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../services/restaurant_service.dart';
import '../../services/trip_destination_service.dart';
import '../../services/trip_service.dart';

class RestaurantSelectionScreen
    extends StatefulWidget {
  final String tripId;

  const RestaurantSelectionScreen({
    super.key,
    required this.tripId,
  });

  @override
  State<RestaurantSelectionScreen>
      createState() =>
          _RestaurantSelectionScreenState();
}

class _RestaurantSelectionScreenState
    extends State<
        RestaurantSelectionScreen> {
  final RestaurantService
      _restaurantService =
      RestaurantService();

  final TripDestinationService
      _destinationService =
      TripDestinationService();

  final TripService _tripService =
      TripService();

  List<Map<String, dynamic>>
      _restaurants = [];

  String? _selectedRestaurantId;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  Future<void> _loadRestaurants() async {
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

      final restaurants =
          await _restaurantService
              .getRestaurantsNearPlaces(
        selectedPlaces:
            selectedPlaces,
      );

      if (!mounted) return;

      setState(() {
        _restaurants =
            restaurants;
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

  String _getName(
    Map<String, dynamic> restaurant,
  ) {
    final displayName =
        restaurant['displayName']
            as Map<String, dynamic>?;

    return displayName?['text']
            ?.toString() ??
        'Restaurant';
  }

  String _getPrice(
    Map<String, dynamic> restaurant,
  ) {
    switch (
        restaurant['priceLevel']
            ?.toString()) {
      case 'PRICE_LEVEL_INEXPENSIVE':
        return '₹ Inexpensive';

      case 'PRICE_LEVEL_MODERATE':
        return '₹₹ Moderate';

      case 'PRICE_LEVEL_EXPENSIVE':
        return '₹₹₹ Expensive';

      case 'PRICE_LEVEL_VERY_EXPENSIVE':
        return '₹₹₹₹ Very Expensive';

      case 'PRICE_LEVEL_FREE':
        return 'Free';

      default:
        return 'Price not available';
    }
  }

  Future<void> _continue() async {
    final data =
        <String, dynamic>{
      'restaurantSelected':
          _selectedRestaurantId !=
              null,
      'updatedAt':
          DateTime.now()
              .toIso8601String(),
    };

    if (_selectedRestaurantId !=
        null) {
      final selectedRestaurant =
          _restaurants.firstWhere(
        (restaurant) =>
            restaurant['id'] ==
            _selectedRestaurantId,
      );

      data[
              'selectedRestaurant'] =
          selectedRestaurant;
    }

    await _tripService.updateTrip(
      widget.tripId,
      data,
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

  void _showMessage(
    String message,
  ) {
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
        title: const Text(
          '6. Nearby Restaurants',
        ),
      ),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : _restaurants.isEmpty
              ? const Center(
                  child: Text(
                    'No nearby restaurants found.',
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

                    final selected =
                        _selectedRestaurantId ==
                            id;

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
                      child: ListTile(
                        leading: Icon(
                          selected
                              ? Icons
                                  .radio_button_checked
                              : Icons.restaurant,
                          color:
                              Colors.deepOrange,
                        ),
                        title: Text(
                          _getName(
                            restaurant,
                          ),
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '$address\n'
                          '${_getPrice(restaurant)}\n'
                          '⭐ $rating\n'
                          'Near: $nearPlace',
                        ),
                        isThreeLine: true,
                        onTap: () {
                          setState(() {
                            if (selected) {
                              _selectedRestaurantId =
                                  null;
                            } else {
                              _selectedRestaurantId =
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
              _selectedRestaurantId ==
                      null
                  ? 'No restaurant selected (optional)'
                  : 'Restaurant selected',
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
                  'Continue',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}