import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'features/authentication/auth_service.dart';
import 'features/authentication/login_screen.dart';
import 'features/passenger/passenger_home_screen.dart';
import 'features/conductor/conductor_home_screen.dart';

class RealTimeBusApp extends StatelessWidget {
  const RealTimeBusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    if (authService.isAuthenticated && authService.currentUser != null) {
      final user = authService.currentUser!;
      if (user.role == AppConstants.roleConductor) {
        return const ConductorHomeScreen();
      } else {
        return const PassengerHomeScreen();
      }
    }

    return const LoginScreen();
  }
}

