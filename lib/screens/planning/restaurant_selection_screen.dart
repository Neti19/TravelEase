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
  bool _saving = false;

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

      if (selectedPlaces.isEmpty) {
        throw Exception(
          'No tourist places selected.',
        );
      }

      final restaurants =
      await _restaurantService.getRestaurantsNearPlaces(
        selectedPlaces: selectedPlaces,
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

  Future<void> _continue() async {
    if (_saving) return;

    setState(() {
      _saving = true;
    });

    try {
      final data = <String, dynamic>{
        'restaurantSelected':
        _selectedRestaurantId != null,
        'updatedAt':
        DateTime.now().toIso8601String(),
      };

      if (_selectedRestaurantId != null) {
        final selectedRestaurant =
        _restaurants.firstWhere(
              (restaurant) =>
          restaurant['id']?.toString() ==
              _selectedRestaurantId,
        );

        data['selectedRestaurant'] =
            selectedRestaurant;
      }

      await _tripService.updateTrip(
        widget.tripId,
        data,
      );

      if (!mounted) return;

      Navigator.pushNamed(
        context,
        AppRoutes.transportSelection,
        arguments: {
          'tripId': widget.tripId,
        },
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Could not save restaurant selection: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
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
        restaurant['name']?.toString() ??
        'Restaurant';
  }

  String _getPrice(
      Map<String, dynamic> restaurant,
      ) {
    switch (
    restaurant['priceLevel']?.toString()) {
      case 'PRICE_LEVEL_FREE':
        return 'Free';

      case 'PRICE_LEVEL_INEXPENSIVE':
        return '₹ Budget';

      case 'PRICE_LEVEL_MODERATE':
        return '₹₹ Moderate';

      case 'PRICE_LEVEL_EXPENSIVE':
        return '₹₹₹ Premium';

      case 'PRICE_LEVEL_VERY_EXPENSIVE':
        return '₹₹₹₹ Fine Dining';

      default:
        return 'Price unavailable';
    }
  }

  String _getAddress(
      Map<String, dynamic> restaurant,
      ) {
    return restaurant['formattedAddress']
        ?.toString() ??
        restaurant['address']?.toString() ??
        'Address unavailable';
  }

  double _getRating(
      Map<String, dynamic> restaurant,
      ) {
    return (restaurant['rating'] as num?)
        ?.toDouble() ??
        0;
  }

  int _getReviewCount(
      Map<String, dynamic> restaurant,
      ) {
    return (restaurant['userRatingCount'] as num?)
        ?.toInt() ??
        0;
  }

  String _getNearPlace(
      Map<String, dynamic> restaurant,
      ) {
    return restaurant['nearPlace']
        ?.toString() ??
        '';
  }

  IconData _getRestaurantIcon(
      Map<String, dynamic> restaurant,
      ) {
    final price =
    restaurant['priceLevel']?.toString();

    switch (price) {
      case 'PRICE_LEVEL_VERY_EXPENSIVE':
        return Icons.auto_awesome_rounded;

      case 'PRICE_LEVEL_EXPENSIVE':
        return Icons.restaurant_rounded;

      default:
        return Icons.restaurant_menu_rounded;
    }
  }

  void _selectRestaurant(String restaurantId) {
    setState(() {
      if (_selectedRestaurantId ==
          restaurantId) {
        _selectedRestaurantId = null;
      } else {
        _selectedRestaurantId =
            restaurantId;
      }
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius:
          BorderRadius.circular(14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedRestaurant =
    _selectedRestaurantId == null
        ? null
        : _restaurants
        .cast<Map<String, dynamic>?>()
        .firstWhere(
          (restaurant) =>
      restaurant?['id']
          ?.toString() ==
          _selectedRestaurantId,
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor:
      const Color(0xFFF7FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        titleSpacing: 20,
        title: const Text(
          'Restaurants',
          style: TextStyle(
            color: Color(0xFF102A43),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _loading
          ? _buildLoading()
          : _restaurants.isEmpty
          ? _buildEmptyState()
          : Column(
        children: [
          Expanded(
            child: ListView(
              padding:
              const EdgeInsets.fromLTRB(
                20,
                18,
                20,
                140,
              ),
              children: [
                _buildHeader(),
                const SizedBox(height: 18),
                ..._restaurants.map(
                  _buildRestaurantCard,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar:
      _loading || _restaurants.isEmpty
          ? null
          : _buildBottomBar(
        selectedRestaurant,
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment:
        MainAxisAlignment.center,
        children: [
          Container(
            height: 70,
            width: 70,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEDE6),
              borderRadius:
              BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.restaurant_rounded,
              size: 34,
              color: Color(0xFFFF8A65),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Finding places to eat...',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF102A43),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Looking around your selected places',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 20),
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Color(0xFFFF8A65),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFF8A65),
            Color(0xFFFFB085),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius:
        BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8A65)
                .withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              color:
              Colors.white.withOpacity(0.2),
              borderRadius:
              BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.restaurant_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'Where will you eat?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Discover restaurants close to the places you want to visit.',
                  style: TextStyle(
                    color: Colors.white,
                    height: 1.4,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantCard(
      Map<String, dynamic> restaurant,
      ) {
    final id =
        restaurant['id']?.toString() ?? '';

    final selected =
        _selectedRestaurantId == id;

    final name =
    _getName(restaurant);
    final address =
    _getAddress(restaurant);
    final rating =
    _getRating(restaurant);
    final reviewCount =
    _getReviewCount(restaurant);
    final nearPlace =
    _getNearPlace(restaurant);
    final price =
    _getPrice(restaurant);

    return AnimatedContainer(
      duration:
      const Duration(milliseconds: 220),
      margin:
      const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(22),
        border: Border.all(
          color: selected
              ? const Color(0xFFFF8A65)
              : const Color(0xFFE6EDF3),
          width: selected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              selected ? 0.08 : 0.035,
            ),
            blurRadius:
            selected ? 18 : 10,
            offset:
            const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        borderRadius:
        BorderRadius.circular(22),
        onTap: () =>
            _selectRestaurant(id),
        child: Padding(
          padding:
          const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 62,
                    width: 62,
                    decoration:
                    BoxDecoration(
                      color: selected
                          ? const Color(
                        0xFFFFEDE6,
                      )
                          : const Color(
                        0xFFFFF6F1,
                      ),
                      borderRadius:
                      BorderRadius.circular(
                        18,
                      ),
                    ),
                    child: Icon(
                      _getRestaurantIcon(
                        restaurant,
                      ),
                      color: selected
                          ? const Color(
                        0xFFFF8A65,
                      )
                          : const Color(
                        0xFFE97855,
                      ),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow:
                          TextOverflow.ellipsis,
                          style:
                          const TextStyle(
                            color:
                            Color(0xFF102A43),
                            fontSize: 17,
                            fontWeight:
                            FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color:
                              Color(0xFFFFB703),
                              size: 18,
                            ),
                            const SizedBox(
                              width: 4,
                            ),
                            Text(
                              rating > 0
                                  ? rating
                                  .toStringAsFixed(
                                1,
                              )
                                  : 'N/A',
                              style:
                              const TextStyle(
                                fontWeight:
                                FontWeight.w700,
                                color:
                                Color(0xFF102A43),
                              ),
                            ),
                            if (reviewCount >
                                0) ...[
                              const SizedBox(
                                width: 4,
                              ),
                              Text(
                                '($reviewCount)',
                                style:
                                TextStyle(
                                  color: Colors
                                      .grey
                                      .shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration:
                    const Duration(
                      milliseconds: 180,
                    ),
                    height: 34,
                    width: 34,
                    decoration:
                    BoxDecoration(
                      color: selected
                          ? const Color(
                        0xFFFF8A65,
                      )
                          : const Color(
                        0xFFF1F5F8,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      selected
                          ? Icons.check_rounded
                          : Icons
                          .radio_button_unchecked_rounded,
                      color: selected
                          ? Colors.white
                          : const Color(
                        0xFF78909C,
                      ),
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color:
                    Color(0xFFFF8A65),
                    size: 19,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      address,
                      maxLines: 2,
                      overflow:
                      TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                        Colors.grey.shade700,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
              if (nearPlace.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.near_me_rounded,
                      color:
                      Color(0xFF1677FF),
                      size: 18,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Near $nearPlace',
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        style:
                        const TextStyle(
                          color:
                          Color(0xFF536B7A),
                          fontSize: 13,
                          fontWeight:
                          FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding:
                    const EdgeInsets
                        .symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration:
                    BoxDecoration(
                      color: const Color(
                        0xFFFFF4E8,
                      ),
                      borderRadius:
                      BorderRadius.circular(
                        10,
                      ),
                    ),
                    child: Text(
                      price,
                      style:
                      const TextStyle(
                        color:
                        Color(0xFFE76F00),
                        fontSize: 12,
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    selected
                        ? 'Selected'
                        : 'Tap to select',
                    style: TextStyle(
                      color: selected
                          ? const Color(
                        0xFFFF8A65,
                      )
                          : Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(
      Map<String, dynamic>?
      selectedRestaurant,
      ) {
    final hasSelection =
        _selectedRestaurantId != null;

    return SafeArea(
      child: Container(
        padding:
        const EdgeInsets.fromLTRB(
          20,
          12,
          20,
          16,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withOpacity(0.08),
              blurRadius: 18,
              offset:
              const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  hasSelection
                      ? Icons
                      .check_circle_rounded
                      : Icons
                      .info_outline_rounded,
                  color: hasSelection
                      ? const Color(
                    0xFFFF8A65,
                  )
                      : const Color(
                    0xFF78909C,
                  ),
                  size: 19,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasSelection
                        ? 'Restaurant selected for your trip'
                        : 'Restaurant selection is optional',
                    style: TextStyle(
                      color: hasSelection
                          ? const Color(
                        0xFF102A43,
                      )
                          : Colors.grey.shade700,
                      fontSize: 13,
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (selectedRestaurant !=
                null) ...[
              const SizedBox(height: 5),
              Align(
                alignment:
                Alignment.centerLeft,
                child: Text(
                  _getName(
                    selectedRestaurant,
                  ),
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style:
                  const TextStyle(
                    color:
                    Color(0xFFFF8A65),
                    fontSize: 12,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed:
                _saving ? null : _continue,
                style:
                ElevatedButton.styleFrom(
                  backgroundColor:
                  const Color(0xFFFF8A65),
                  foregroundColor:
                  Colors.white,
                  disabledBackgroundColor:
                  const Color(0xFFFFC5B2),
                  elevation: 0,
                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(
                      17,
                    ),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                  height: 22,
                  width: 22,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color:
                    Colors.white,
                  ),
                )
                    : const Row(
                  mainAxisAlignment:
                  MainAxisAlignment
                      .center,
                  children: [
                    Text(
                      'Continue to Transport',
                      style:
                      TextStyle(
                        fontSize: 15,
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons
                          .arrow_forward_rounded,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Container(
              height: 86,
              width: 86,
              decoration:
              BoxDecoration(
                color:
                const Color(0xFFFFEDE6),
                borderRadius:
                BorderRadius.circular(
                  28,
                ),
              ),
              child: const Icon(
                Icons.restaurant_outlined,
                size: 42,
                color:
                Color(0xFFFF8A65),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No restaurants found',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color:
                Color(0xFF102A43),
                fontSize: 21,
                fontWeight:
                FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We could not find nearby restaurants for your selected places.',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color:
                Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _loading = true;
                });
                _loadRestaurants();
              },
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text(
                'Try Again',
              ),
              style:
              OutlinedButton.styleFrom(
                foregroundColor:
                const Color(
                  0xFFFF8A65,
                ),
                side: const BorderSide(
                  color:
                  Color(0xFFFF8A65),
                ),
                padding:
                const EdgeInsets
                    .symmetric(
                  horizontal: 22,
                  vertical: 13,
                ),
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(
                    14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}