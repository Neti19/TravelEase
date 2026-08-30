import 'package:flutter/material.dart';
import 'app_routes.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TravelPlannerApp());
}

class TravelPlannerApp extends StatelessWidget {
  const TravelPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Travel Planner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      // Set initial screen route
      initialRoute: AppRoutes.login,
      // Connect dynamic routing handler
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}