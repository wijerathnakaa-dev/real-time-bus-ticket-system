import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/location_model.dart';

class LocationService extends ChangeNotifier {
  LocationModel? _currentLocation;
  bool _isServiceEnabled = false;
  LocationPermission _permission = LocationPermission.denied;
  String? _errorMessage;
  StreamSubscription<Position>? _positionStreamSubscription;

  LocationModel? get currentLocation => _currentLocation;
  bool get isServiceEnabled => _isServiceEnabled;
  LocationPermission get permission => _permission;
  String? get errorMessage => _errorMessage;

  Future<void> checkAndRequestPermission() async {
    _isServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!_isServiceEnabled) {
      _errorMessage = 'GPS / Location services are disabled. Please enable them in settings.';
      notifyListeners();
      return;
    }

    _permission = await Geolocator.checkPermission();
    if (_permission == LocationPermission.denied) {
      _permission = await Geolocator.requestPermission();
      if (_permission == LocationPermission.denied) {
        _errorMessage = 'Location permissions are denied.';
        notifyListeners();
        return;
      }
    }

    if (_permission == LocationPermission.deniedForever) {
      _errorMessage = 'Location permissions are permanently denied. Please enable via phone app settings.';
      notifyListeners();
      return;
    }

    _errorMessage = null;
    await getCurrentLocation();
  }

  Future<LocationModel?> getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _currentLocation = LocationModel(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        speed: position.speed,
        timestamp: position.timestamp,
      );
      _errorMessage = null;
      notifyListeners();
      return _currentLocation;
    } catch (e) {
      _errorMessage = 'Failed to get current location: $e';
      notifyListeners();
      return null;
    }
  }

  void startTracking({int distanceFilter = 10, int intervalSeconds = 3}) {
    _positionStreamSubscription?.cancel();
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilter,
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _currentLocation = LocationModel(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        speed: position.speed,
        timestamp: position.timestamp,
      );
      notifyListeners();
    }, onError: (e) {
      _errorMessage = 'Error streaming GPS position: $e';
      notifyListeners();
    });
  }

  void stopTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}
