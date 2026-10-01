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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadHotels();
  }

  Future<void> _loadHotels() async {
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

      final hotels =
      await _hotelService.getHotelsNearPlaces(
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
    if (_saving) return;

    setState(() {
      _saving = true;
    });

    try {
      final data = <String, dynamic>{
        'hotelSelected': _selectedHotelId != null,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (_selectedHotelId != null) {
        final selectedHotel = _hotels.firstWhere(
              (hotel) =>
          hotel['id']?.toString() ==
              _selectedHotelId,
        );

        data['selectedHotel'] = selectedHotel;
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
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Could not save hotel selection: $e',
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
      Map<String, dynamic> hotel,
      ) {
    final displayName =
    hotel['displayName']
    as Map<String, dynamic>?;

    return displayName?['text']
        ?.toString() ??
        hotel['name']?.toString() ??
        'Hotel';
  }

  String _getPrice(
      Map<String, dynamic> hotel,
      ) {
    final price =
    hotel['priceLevel']?.toString();

    switch (price) {
      case 'PRICE_LEVEL_INEXPENSIVE':
        return '₹ Budget';

      case 'PRICE_LEVEL_MODERATE':
        return '₹₹ Moderate';

      case 'PRICE_LEVEL_EXPENSIVE':
        return '₹₹₹ Premium';

      case 'PRICE_LEVEL_VERY_EXPENSIVE':
        return '₹₹₹₹ Luxury';

      default:
        return 'Price unavailable';
    }
  }

  String _getAddress(
      Map<String, dynamic> hotel,
      ) {
    return hotel['formattedAddress']
        ?.toString() ??
        hotel['address']?.toString() ??
        'Address unavailable';
  }

  double _getRating(
      Map<String, dynamic> hotel,
      ) {
    return (hotel['rating'] as num?)
        ?.toDouble() ??
        0;
  }

  int _getReviewCount(
      Map<String, dynamic> hotel,
      ) {
    return (hotel['userRatingCount'] as num?)
        ?.toInt() ??
        0;
  }

  String _getNearPlace(
      Map<String, dynamic> hotel,
      ) {
    return hotel['nearPlace']
        ?.toString() ??
        '';
  }

  IconData _getHotelIcon(
      Map<String, dynamic> hotel,
      ) {
    final price =
    hotel['priceLevel']?.toString();

    switch (price) {
      case 'PRICE_LEVEL_VERY_EXPENSIVE':
        return Icons
            .workspace_premium_rounded;

      case 'PRICE_LEVEL_EXPENSIVE':
        return Icons
            .hotel_rounded;

      default:
        return Icons
            .bed_rounded;
    }
  }

  void _selectHotel(String hotelId) {
    setState(() {
      if (_selectedHotelId == hotelId) {
        _selectedHotelId = null;
      } else {
        _selectedHotelId = hotelId;
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
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedHotel = _selectedHotelId == null
        ? null
        : _hotels.cast<Map<String, dynamic>?>().firstWhere(
          (hotel) =>
      hotel?['id']?.toString() ==
          _selectedHotelId,
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        titleSpacing: 20,
        title: const Text(
          'Hotels',
          style: TextStyle(
            color: Color(0xFF102A43),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _loading
          ? _buildLoading()
          : _hotels.isEmpty
          ? _buildEmptyState()
          : Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                20,
                18,
                20,
                140,
              ),
              children: [
                _buildHeader(),
                const SizedBox(height: 18),
                ..._hotels.map(
                  _buildHotelCard,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar:
      _loading || _hotels.isEmpty
          ? null
          : _buildBottomBar(selectedHotel),
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
              color: const Color(0xFFDFF4FF),
              borderRadius:
              BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.hotel_rounded,
              size: 34,
              color: Color(0xFF1677FF),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Finding nearby stays...',
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
              color: Color(0xFF1677FF),
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
            Color(0xFF1677FF),
            Color(0xFF45A9FF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius:
        BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1677FF)
                .withOpacity(0.16),
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
              color: Colors.white
                  .withOpacity(0.18),
              borderRadius:
              BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.hotel_rounded,
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
                  'Where will you stay?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'We found stays close to the places in your itinerary.',
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

  Widget _buildHotelCard(
      Map<String, dynamic> hotel,
      ) {
    final id = hotel['id']?.toString() ?? '';

    final selected =
        _selectedHotelId == id;

    final name = _getName(hotel);
    final address = _getAddress(hotel);
    final rating = _getRating(hotel);
    final reviewCount =
    _getReviewCount(hotel);
    final nearPlace =
    _getNearPlace(hotel);
    final price = _getPrice(hotel);

    return AnimatedContainer(
      duration:
      const Duration(milliseconds: 220),
      margin: const EdgeInsets.only(
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(22),
        border: Border.all(
          color: selected
              ? const Color(0xFF1677FF)
              : const Color(0xFFE6EDF3),
          width: selected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(
              selected ? 0.08 : 0.035,
            ),
            blurRadius: selected ? 18 : 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        borderRadius:
        BorderRadius.circular(22),
        onTap: () => _selectHotel(id),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFDFF4FF)
                          : const Color(0xFFF2F7FB),
                      borderRadius:
                      BorderRadius.circular(18),
                    ),
                    child: Icon(
                      _getHotelIcon(hotel),
                      color: selected
                          ? const Color(0xFF1677FF)
                          : const Color(0xFF55758F),
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
                          style: const TextStyle(
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
                            const SizedBox(width: 4),
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
                            if (reviewCount > 0) ...[
                              const SizedBox(width: 4),
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
                    duration: const Duration(
                      milliseconds: 180,
                    ),
                    height: 34,
                    width: 34,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF1677FF)
                          : const Color(0xFFF1F5F8),
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
                    color: Color(0xFF1677FF),
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
                      color: Color(0xFFFF8A65),
                      size: 18,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Near $nearPlace',
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF536B7A),
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
                    const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color:
                      const Color(0xFFFFF4E8),
                      borderRadius:
                      BorderRadius.circular(10),
                    ),
                    child: Text(
                      price,
                      style: const TextStyle(
                        color: Color(0xFFE76F00),
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
                        0xFF1677FF,
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
      Map<String, dynamic>? selectedHotel,
      ) {
    final hasSelection =
        _selectedHotelId != null;

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
              offset: const Offset(0, -5),
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
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded,
                  color: hasSelection
                      ? const Color(0xFF1677FF)
                      : const Color(0xFF78909C),
                  size: 19,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasSelection
                        ? 'Hotel selected for your trip'
                        : 'Hotel selection is optional',
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
            if (selectedHotel != null) ...[
              const SizedBox(height: 5),
              Align(
                alignment:
                Alignment.centerLeft,
                child: Text(
                  _getName(selectedHotel),
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1677FF),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  const Color(0xFF1677FF),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                  const Color(0xFFB8D6F7),
                  elevation: 0,
                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(17),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                  height: 22,
                  width: 22,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
                    : const Row(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [
                    Text(
                      'Next: Restaurants',
                      style: TextStyle(
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
              decoration: BoxDecoration(
                color: const Color(0xFFDFF4FF),
                borderRadius:
                BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.hotel_outlined,
                size: 42,
                color: Color(0xFF1677FF),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No hotels found',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF102A43),
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We could not find nearby stays for your selected places.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _loading = true;
                });
                _loadHotels();
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
                const Color(0xFF1677FF),
                side: const BorderSide(
                  color: Color(0xFF1677FF),
                ),
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 13,
                ),
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}