import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_routes.dart';

class DashboardNavigationButton extends StatelessWidget {
  const DashboardNavigationButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) {
      return const SizedBox.shrink();
    }

    return IconButton(
      tooltip: 'Personal dashboard',
      onPressed: () {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.dashboard,
          (_) => false,
        );
      },
      icon: const Icon(Icons.home_rounded),
    );
  }
}
