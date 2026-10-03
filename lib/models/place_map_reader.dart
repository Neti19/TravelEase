import 'dart:math';

/// Read-only helpers for the raw Google Places API (v1) maps that the app
/// already stores in Firestore (selectedHotel, selectedRestaurant, etc.).
///
/// Nothing here changes the stored shape. It only makes reading it safe.
class PlaceMap {
  PlaceMap._();

  static String id(Map<String, dynamic> place) =>
      place['id']?.toString() ?? place['placeId']?.toString() ?? '';

  static String name(Map<String, dynamic> place) {
    final displayName = place['displayName'];
    if (displayName is Map && displayName['text'] != null) {
      return displayName['text'].toString();
    }
    final plain = place['name']?.toString();
    return (plain == null || plain.trim().isEmpty) ? 'Unnamed place' : plain;
  }

  static String address(Map<String, dynamic> place) =>
      place['formattedAddress']?.toString() ??
      place['address']?.toString() ??
      '';

  static double? latitude(Map<String, dynamic> place) {
    final location = place['location'];
    if (location is Map && location['latitude'] is num) {
      return (location['latitude'] as num).toDouble();
    }
    final alt = place['hotelLatitude'] ??
        place['restaurantLatitude'] ??
        place['latitude'];
    return alt is num ? alt.toDouble() : null;
  }

  static double? longitude(Map<String, dynamic> place) {
    final location = place['location'];
    if (location is Map && location['longitude'] is num) {
      return (location['longitude'] as num).toDouble();
    }
    final alt = place['hotelLongitude'] ??
        place['restaurantLongitude'] ??
        place['longitude'];
    return alt is num ? alt.toDouble() : null;
  }

  static double rating(Map<String, dynamic> place) =>
      (place['rating'] as num?)?.toDouble() ?? 0.0;

  /// 0 (free) .. 4 (very expensive), or null when Google gave no level.
  static int? priceLevelIndex(Map<String, dynamic> place) {
    switch (place['priceLevel']?.toString()) {
      case 'PRICE_LEVEL_FREE':
        return 0;
      case 'PRICE_LEVEL_INEXPENSIVE':
        return 1;
      case 'PRICE_LEVEL_MODERATE':
        return 2;
      case 'PRICE_LEVEL_EXPENSIVE':
        return 3;
      case 'PRICE_LEVEL_VERY_EXPENSIVE':
        return 4;
      default:
        return null;
    }
  }

  static String priceLevelLabel(Map<String, dynamic> place) {
    switch (priceLevelIndex(place)) {
      case 0:
        return 'Free';
      case 1:
        return '\u20B9';
      case 2:
        return '\u20B9\u20B9';
      case 3:
        return '\u20B9\u20B9\u20B9';
      case 4:
        return '\u20B9\u20B9\u20B9\u20B9';
      default:
        return 'Price n/a';
    }
  }

  /// Midpoint of Google's priceRange (start/end "units"), if present.
  static double? _priceRangeMidpoint(Map<String, dynamic> place) {
    final range = place['priceRange'];
    if (range is! Map) return null;
    double? read(dynamic v) {
      if (v is! Map) return null;
      final units = v['units'];
      if (units is num) return units.toDouble();
      return double.tryParse(units?.toString() ?? '');
    }

    final start = read(range['startPrice']);
    final end = read(range['endPrice']);
    if (start != null && end != null) return (start + end) / 2;
    return start ?? end;
  }

  /// ESTIMATE of one room for one night (INR). Google rarely returns exact
  /// prices, so this uses priceRange if present, else a price-level table.
  static double estimatedHotelPerNight(Map<String, dynamic> place) {
    final fromRange = _priceRangeMidpoint(place);
    if (fromRange != null && fromRange > 0) return fromRange;
    switch (priceLevelIndex(place)) {
      case 1:
        return 1800;
      case 2:
        return 3500;
      case 3:
        return 7000;
      case 4:
        return 14000;
      default:
        return 3000;
    }
  }

  /// ESTIMATE of one meal for one person (INR).
  static double estimatedMealPerPerson(Map<String, dynamic> place) {
    final fromRange = _priceRangeMidpoint(place);
    if (fromRange != null && fromRange > 0) return fromRange;
    switch (priceLevelIndex(place)) {
      case 1:
        return 200;
      case 2:
        return 450;
      case 3:
        return 1000;
      case 4:
        return 2200;
      default:
        return 400;
    }
  }

  /// true / false when opening hours are known, null when unknown.
  /// Google's regularOpeningHours uses day 0 = Sunday.
  static bool? isOpenAt(Map<String, dynamic> place, DateTime when) {
    final hours = place['regularOpeningHours'];
    if (hours is! Map) return null;
    final periods = hours['periods'];
    if (periods is! List || periods.isEmpty) return null;

    int? minuteOfWeek(dynamic point) {
      if (point is! Map) return null;
      final d = point['day'];
      final h = point['hour'];
      final m = point['minute'];
      if (d is! num || h is! num) return null;
      return d.toInt() * 1440 + h.toInt() * 60 + ((m as num?)?.toInt() ?? 0);
    }

    final t = (when.weekday % 7) * 1440 + when.hour * 60 + when.minute;
    const week = 10080;

    for (final period in periods) {
      if (period is! Map) continue;
      final o = minuteOfWeek(period['open']);
      if (o == null) continue;
      var c = minuteOfWeek(period['close']);
      if (c == null) return true; // open 24h
      if (c <= o) c += week;
      if ((t >= o && t < c) || (t + week >= o && t + week < c)) return true;
    }
    return false;
  }

  static double distanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    double rad(double d) => d * pi / 180.0;
    final dLat = rad(lat2 - lat1);
    final dLon = rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(rad(lat1)) * cos(rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return 2 * earthRadiusKm * asin(min(1.0, sqrt(a)));
  }
}
