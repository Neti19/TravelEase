import 'package:flutter/material.dart';
import 'screen/home_screen.dart';

void main() {
  runApp(const TripManagementApp());
}

class TripManagementApp extends StatelessWidget {
  const TripManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Trip Management System",
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomeScreen(),
    );
  }
}

  