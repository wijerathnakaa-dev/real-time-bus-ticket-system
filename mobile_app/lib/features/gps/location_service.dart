import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/location_model.dart';
import '../buses/bus_service.dart';

/// Device GPS. When broadcasting for a bus, fixes are sent to the Go API, which
/// stores them, recomputes per-stop ETAs and pushes them to passengers.
class LocationService extends ChangeNotifier {
  final BusService _busService = BusService();

  LocationModel? _currentLocation;
  bool _isServiceEnabled = false;
  LocationPermission _permission = LocationPermission.denied;
  String? _errorMessage;
  String? _broadcastingBusId;
  DateTime? _lastSent;
  int _sentCount = 0;
  StreamSubscription<Position>? _positionStreamSubscription;

  /// Battery: send at most one fix per [minSendInterval] (RTBTS-73).
  static const minSendInterval = Duration(seconds: 5);

  LocationModel? get currentLocation => _currentLocation;
  bool get isServiceEnabled => _isServiceEnabled;
  LocationPermission get permission => _permission;
  String? get errorMessage => _errorMessage;
  String? get broadcastingBusId => _broadcastingBusId;
  DateTime? get lastSent => _lastSent;
  int get sentCount => _sentCount;

  bool isBroadcastingFor(String busId) => _broadcastingBusId == busId;

  Future<bool> checkAndRequestPermission() async {
    _isServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!_isServiceEnabled) {
      _errorMessage = 'GPS / Location services are disabled. Please enable them in settings.';
      notifyListeners();
      return false;
    }
    _permission = await Geolocator.checkPermission();
    if (_permission == LocationPermission.denied) {
      _permission = await Geolocator.requestPermission();
    }
    if (_permission == LocationPermission.denied || _permission == LocationPermission.deniedForever) {
      _errorMessage = _permission == LocationPermission.deniedForever
          ? 'Location permission is permanently denied. Enable it in the phone settings.'
          : 'Location permission was denied.';
      notifyListeners();
      return false;
    }
    _errorMessage = null;
    await getCurrentLocation();
    return true;
  }

  Future<LocationModel?> getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _currentLocation = _toModel(position);
      _errorMessage = null;
      notifyListeners();
      return _currentLocation;
    } catch (e) {
      _errorMessage = 'Failed to get current location: $e';
      notifyListeners();
      return null;
    }
  }

  Future<void> startTracking({String? busId, int distanceFilter = 20}) async {
    if (!await checkAndRequestPermission()) return;
    await _positionStreamSubscription?.cancel();
    _broadcastingBusId = busId;
    _sentCount = 0;

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: distanceFilter),
    ).listen((position) {
      _currentLocation = _toModel(position);
      notifyListeners();
      if (busId != null && busId.isNotEmpty) _send(busId, position);
    }, onError: (e) {
      _errorMessage = 'Error streaming GPS position: $e';
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> _send(String busId, Position p) async {
    final now = DateTime.now();
    if (_lastSent != null && now.difference(_lastSent!) < minSendInterval) return;
    _lastSent = now;
    try {
      await _busService.sendLocation(busId, lat: p.latitude, lng: p.longitude, accuracy: p.accuracy, speedKmh: p.speed * 3.6);
      _sentCount++;
      _errorMessage = null;
    } catch (e) {
      // Network loss: keep tracking; the next fix retries automatically.
      _errorMessage = 'GPS upload failed (will retry): $e';
    }
    notifyListeners();
  }

  LocationModel _toModel(Position p) => LocationModel(
        latitude: p.latitude,
        longitude: p.longitude,
        accuracy: p.accuracy,
        speed: p.speed,
        timestamp: p.timestamp,
      );

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
