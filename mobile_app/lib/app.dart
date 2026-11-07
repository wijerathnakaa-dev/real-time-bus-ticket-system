import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/authentication/auth_service.dart';
import 'features/authentication/login_screen.dart';
import 'features/conductor/admin_home_screen.dart';
import 'features/conductor/conductor_home_screen.dart';
import 'features/passenger/passenger_home_screen.dart';

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

/// One codebase, three roles: the role on the signed-in account decides the mode.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    if (auth.isRestoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final user = auth.currentUser;
    if (user == null) return const LoginScreen();
    switch (user.role) {
      case AppConstants.roleConductor:
        return const ConductorHomeScreen();
      case AppConstants.roleAdmin:
        return const AdminHomeScreen();
      default:
        return const PassengerHomeScreen();
    }
  }
}
