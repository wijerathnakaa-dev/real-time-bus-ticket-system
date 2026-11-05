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

  String? initError;
  try {
    await Firebase.initializeApp();
  } catch (e) {
    initError = e.toString();
  }

  if (initError != null) {
    runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: Scaffold(
        appBar: AppBar(title: const Text('Initialization Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off, size: 64, color: AppTheme.occupiedRed),
                const SizedBox(height: 16),
                const Text(
                  'Firebase Setup Required',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'Firebase failed to initialize:\n$initError\n\nPlease add google-services.json to android/app and run "flutterfire configure".',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black87),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
    return;
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
