import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiKeys {
  static String get placesApiKey =>
      dotenv.env['PLACES_API_KEY'] ?? '';

  static String get routesApiKey =>
      dotenv.env['ROUTES_API_KEY'] ?? '';
}