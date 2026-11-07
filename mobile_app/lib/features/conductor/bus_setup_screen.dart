import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/bus_model.dart';
import '../../models/route_model.dart';
import '../../shared/widgets/loading_overlay.dart';
import '../buses/bus_service.dart';
import '../buses/number_plate_ocr_service.dart';

/// Conductor's bus profile: number plate (typed or scanned), seat count, photo URL and route.
/// The conductor can pick an existing expressway route or define their own.
class BusSetupScreen extends StatefulWidget {
  final BusModel? existing;
  const BusSetupScreen({super.key, this.existing});

  @override
  State<BusSetupScreen> createState() => _BusSetupScreenState();
}

class _BusSetupScreenState extends State<BusSetupScreen> {
  final _service = BusService();
  final _ocr = NumberPlateOcrService();
  final _plate = TextEditingController();
  final _seats = TextEditingController(text: '40');
  final _photo = TextEditingController();
  List<RouteModel> _routes = [];
  String? _routeId;
  bool _busy = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final b = widget.existing;
    if (b != null) {
      _plate.text = b.plateNumber;
      _seats.text = '${b.totalSeats}';
      _photo.text = b.photoUrl ?? '';
      _routeId = b.routeId;
    }
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    try {
      final r = await _service.listRoutes();
      if (mounted) setState(() => _routes = r);
    } catch (_) {}
  }

  @override
  void dispose() {
    _ocr.dispose();
    _plate.dispose();
    _seats.dispose();
    _photo.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final p = await _ocr.captureAndRecognizePlate();
    if (p != null && mounted) setState(() => _plate.text = p);
  }

  Future<void> _save() async {
    final seats = int.tryParse(_seats.text) ?? 0;
    if (_plate.text.trim().isEmpty || seats < 1 || seats > 80) {
      _snack('Enter a number plate and 1-80 seats.');
      return;
    }
    setState(() => _busy = true);
    try {
      if (_editing) {
        await _service.updateBus(widget.existing!.id, routeId: _routeId, totalSeats: seats, photoUrl: _photo.text.trim());
      } else {
        await _service.registerBus(plateNumber: _plate.text.trim(), totalSeats: seats, routeId: _routeId, photoUrl: _photo.text.trim());
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: AppTheme.occupiedRed));

  Future<void> _newRoute() async {
    final created = await Navigator.of(context).push<RouteModel>(MaterialPageRoute(builder: (_) => const RouteEditorScreen()));
    if (created != null) {
      await _loadRoutes();
      setState(() => _routeId = created.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _busy,
      message: 'Saving bus profile...',
      child: Scaffold(
        appBar: AppBar(title: Text(_editing ? 'Edit bus profile' : 'Set up your bus'), backgroundColor: AppTheme.primaryDark),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: _plate,
              enabled: !_editing,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Number plate',
                hintText: 'e.g. NB-2451',
                prefixIcon: const Icon(Icons.directions_bus),
                suffixIcon: _editing ? null : IconButton(icon: const Icon(Icons.camera_alt), tooltip: 'Scan plate', onPressed: _scan),
              ),
            ),
            const SizedBox(height: 16),
            TextField(controller: _seats, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Number of seats', prefixIcon: Icon(Icons.event_seat))),
            const SizedBox(height: 16),
            TextField(controller: _photo, decoration: const InputDecoration(labelText: 'Bus photo URL (optional)', prefixIcon: Icon(Icons.photo))),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _routes.any((r) => r.id == _routeId) ? _routeId : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Route', prefixIcon: Icon(Icons.alt_route)),
              items: [for (final r in _routes) DropdownMenuItem(value: r.id, child: Text('${r.routeNumber} - ${r.name}', overflow: TextOverflow.ellipsis))],
              onChanged: (v) => setState(() => _routeId = v),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(onPressed: _newRoute, icon: const Icon(Icons.add), label: const Text('Define a new route')),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _save, child: Text(_editing ? 'SAVE CHANGES' : 'REGISTER BUS')),
          ],
        ),
      ),
    );
  }
}

/// Minimal route editor: number, origin/destination, fare and ordered stops with coordinates.
class RouteEditorScreen extends StatefulWidget {
  const RouteEditorScreen({super.key});

  @override
  State<RouteEditorScreen> createState() => _RouteEditorScreenState();
}

class _RouteEditorScreenState extends State<RouteEditorScreen> {
  final _number = TextEditingController();
  final _origin = TextEditingController();
  final _dest = TextEditingController();
  final _fare = TextEditingController(text: '500');
  final _mins = TextEditingController(text: '60');
  final List<(TextEditingController, TextEditingController, TextEditingController)> _stops = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _addStop();
    _addStop();
  }

  void _addStop() => setState(() => _stops.add((TextEditingController(), TextEditingController(), TextEditingController())));

  Future<void> _save() async {
    final stops = <StopModel>[];
    for (final (n, la, lo) in _stops) {
      final lat = double.tryParse(la.text), lng = double.tryParse(lo.text);
      if (n.text.trim().isEmpty || lat == null || lng == null) continue;
      stops.add(StopModel(id: '', name: n.text.trim(), sequence: stops.length + 1, latitude: lat, longitude: lng));
    }
    if (_number.text.trim().isEmpty || _origin.text.trim().isEmpty || _dest.text.trim().isEmpty || stops.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill route number, origin, destination and at least 2 stops with coordinates.')));
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await BusService().createRoute(
        routeNumber: _number.text.trim(),
        origin: _origin.text.trim(),
        destination: _dest.text.trim(),
        fare: double.tryParse(_fare.text) ?? 500,
        durationMins: int.tryParse(_mins.text) ?? 60,
        stops: stops,
      );
      if (mounted) Navigator.of(context).pop(r);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _busy,
      message: 'Creating route...',
      child: Scaffold(
        appBar: AppBar(title: const Text('New route'), backgroundColor: AppTheme.primaryDark),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(controller: _number, decoration: const InputDecoration(labelText: 'Route number')),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _origin, decoration: const InputDecoration(labelText: 'Origin'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _dest, decoration: const InputDecoration(labelText: 'Destination'))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _fare, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Full fare (Rs.)'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _mins, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duration (min)'))),
            ]),
            const SizedBox(height: 16),
            const Text('Stops in order', style: TextStyle(fontWeight: FontWeight.bold)),
            for (var i = 0; i < _stops.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  Text('${i + 1}.'),
                  const SizedBox(width: 6),
                  Expanded(flex: 3, child: TextField(controller: _stops[i].$1, decoration: const InputDecoration(labelText: 'Stop name', isDense: true))),
                  const SizedBox(width: 4),
                  Expanded(flex: 2, child: TextField(controller: _stops[i].$2, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Lat', isDense: true))),
                  const SizedBox(width: 4),
                  Expanded(flex: 2, child: TextField(controller: _stops[i].$3, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Lng', isDense: true))),
                ]),
              ),
            TextButton.icon(onPressed: _addStop, icon: const Icon(Icons.add_location_alt), label: const Text('Add stop')),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _save, child: const Text('CREATE ROUTE')),
          ],
        ),
      ),
    );
  }
}
