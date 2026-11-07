import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/api/api_config.dart';
import '../../core/theme/app_theme.dart';
import '../../models/eta_model.dart';

/// Live bus position on Google Maps with the route's stops. Falls back to a
/// progress bar when no Maps API key is configured (MAPS_ENABLED=false).
class BusMapView extends StatefulWidget {
  final BusEta eta;
  final String plate;
  final double height;

  const BusMapView({super.key, required this.eta, required this.plate, this.height = 220});

  @override
  State<BusMapView> createState() => _BusMapViewState();
}

class _BusMapViewState extends State<BusMapView> {
  GoogleMapController? _map;

  @override
  void didUpdateWidget(covariant BusMapView old) {
    super.didUpdateWidget(old);
    final e = widget.eta;
    if (_map != null && e.latitude != null && (e.latitude != old.eta.latitude || e.longitude != old.eta.longitude)) {
      // Smoothly follow the bus as new GPS fixes arrive.
      _map!.animateCamera(CameraUpdate.newLatLng(LatLng(e.latitude!, e.longitude!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.eta;
    if (!ApiConfig.mapsEnabled) return _progress(e);

    final stops = e.stops;
    final center = e.latitude != null
        ? LatLng(e.latitude!, e.longitude!)
        : (stops.isNotEmpty ? LatLng(stops.first.latitude, stops.first.longitude) : const LatLng(6.9271, 79.8612));
    final markers = <Marker>{
      for (final s in stops)
        Marker(
          markerId: MarkerId(s.stopId),
          position: LatLng(s.latitude, s.longitude),
          infoWindow: InfoWindow(title: s.stopName, snippet: s.etaMinutes != null ? 'ETA ${s.etaMinutes!.toStringAsFixed(0)} min' : null),
          icon: BitmapDescriptor.defaultMarkerWithHue(s.state == 'departed' ? BitmapDescriptor.hueViolet : BitmapDescriptor.hueGreen),
        ),
      if (e.latitude != null)
        Marker(
          markerId: const MarkerId('bus'),
          position: LatLng(e.latitude!, e.longitude!),
          infoWindow: InfoWindow(title: widget.plate, snippet: '${e.speedKmh.toStringAsFixed(0)} km/h'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          zIndexInt: 2,
        ),
    };
    return SizedBox(
      height: widget.height,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(target: center, zoom: 11),
        markers: markers,
        polylines: {
          Polyline(
            polylineId: const PolylineId('route'),
            points: [for (final s in stops) LatLng(s.latitude, s.longitude)],
            color: AppTheme.primaryBlue,
            width: 4,
          ),
        },
        onMapCreated: (c) => _map = c,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
      ),
    );
  }

  Widget _progress(BusEta e) {
    final total = e.stops.length;
    final passed = e.stops.where((s) => s.state == 'departed').length;
    final next = e.nextStop;
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppTheme.primaryDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_bus, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  !e.onTrip ? '${widget.plate} is not on a trip' : (next != null ? 'Next: ${next.stopName}' : '${widget.plate} on trip'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              if (next?.etaMinutes != null)
                Text('${next!.etaMinutes!.toStringAsFixed(0)} min', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: total <= 1 ? 0 : passed / (total - 1),
            minHeight: 8,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation(Colors.lightGreenAccent),
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Text(
            e.latitude != null
                ? 'GPS ${e.latitude!.toStringAsFixed(4)}, ${e.longitude!.toStringAsFixed(4)} - ${e.speedKmh.toStringAsFixed(0)} km/h'
                : 'No GPS position yet',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
