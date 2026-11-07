import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/notifications/push_service.dart';
import 'features/authentication/auth_service.dart';
import 'features/gps/location_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase is optional: without google-services.json the app runs fully on the
  // Go API + WebSocket and only push notifications are disabled.
  await PushService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => LocationService()),
      ],
      child: const RealTimeBusApp(),
    ),
  );
}
