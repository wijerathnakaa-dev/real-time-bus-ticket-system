import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/location_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/passenger/passenger_home_screen.dart';
import 'screens/conductor/conductor_home_screen.dart';
import 'utils/app_theme.dart';
import 'utils/app_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Try initializing Firebase; handle local mock/offline state gracefully
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization note (config pending in Sprint 2): $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => LocationService()),
      ],
      child: const BusTicketApp(),
    ),
  );
}

class BusTicketApp extends StatelessWidget {
  const BusTicketApp({super.key});

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

/// The AuthGate decides whether to show the Login Screen or the Role-Based Home Screen.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    // If user is authenticated and user data is loaded
    if (authService.isAuthenticated && authService.currentUser != null) {
      final user = authService.currentUser!;
      if (user.role == AppConstants.roleConductor) {
        return const ConductorHomeScreen();
      } else {
        return const PassengerHomeScreen();
      }
    }

    // Default: Show login screen
    return const LoginScreen();
  }
}

