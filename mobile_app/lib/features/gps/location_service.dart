import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/location_model.dart';
import '../../core/constants/app_constants.dart';

class LocationService extends ChangeNotifier {
  LocationModel? _currentLocation;
  bool _isServiceEnabled = false;
  LocationPermission _permission = LocationPermission.denied;
  String? _errorMessage;
  String? _broadcastingBusId;
  StreamSubscription<Position>? _positionStreamSubscription;

  LocationModel? get currentLocation => _currentLocation;
  bool get isServiceEnabled => _isServiceEnabled;
  LocationPermission get permission => _permission;
  String? get errorMessage => _errorMessage;
  String? get broadcastingBusId => _broadcastingBusId;

  bool isBroadcastingFor(String busId) => _broadcastingBusId == busId;

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
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
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

  void startTracking({String? busId, int distanceFilter = 10}) {
    _positionStreamSubscription?.cancel();
    _broadcastingBusId = busId;

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
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

      // If broadcasting for a specific bus, publish to Cloud Firestore
      if (busId != null && busId.isNotEmpty) {
        FirebaseFirestore.instance
            .collection(AppConstants.colLocations)
            .doc(busId)
            .set({
          'busId': busId,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'speed': position.speed * 3.6, // m/s to km/h as defined in schema
          'timestamp': FieldValue.serverTimestamp(),
        }).catchError((e) {
          debugPrint('Firestore GPS broadcast failed: $e');
        });
      }
    }, onError: (e) {
      _errorMessage = 'Error streaming GPS position: $e';
      notifyListeners();
    });

    notifyListeners();
  }

  void stopTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _broadcastingBusId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}
