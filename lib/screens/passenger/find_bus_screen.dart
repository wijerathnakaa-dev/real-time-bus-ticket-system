import 'package:flutter/material.dart';
import '../../models/bus_model.dart';
import '../../services/bus_service.dart';
import '../../services/number_plate_ocr_service.dart';
import '../../widgets/loading_overlay.dart';
import '../../utils/app_theme.dart';
import 'seat_map_screen.dart';

class FindBusScreen extends StatefulWidget {
  final String passengerId;
  final String passengerName;

  const FindBusScreen({
    super.key,
    required this.passengerId,
    required this.passengerName,
  });

  @override
  State<FindBusScreen> createState() => _FindBusScreenState();
}

class _FindBusScreenState extends State<FindBusScreen> {
  final TextEditingController _plateController = TextEditingController(text: 'WP-ND-1024');
  final BusService _busService = BusService();
  final NumberPlateOcrService _ocrService = NumberPlateOcrService();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _plateController.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  void _searchBus() async {
    final plate = _plateController.text.trim();
    if (plate.isEmpty) {
      setState(() => _errorMessage = 'Please enter a bus number plate.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bus = await _busService.findBusByPlate(plate);
      if (!mounted) return;

      if (bus == null) {
        setState(() {
          _errorMessage = 'Bus "$plate" not found in active fleet.';
          _isLoading = false;
        });
        return;
      }

      setState(() => _isLoading = false);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SeatMapScreen(
            bus: bus,
            passengerId: widget.passengerId,
            passengerName: widget.passengerName,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading bus: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _scanPlateWithCamera() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final recognizedPlate = await _ocrService.captureAndRecognizePlate();
    if (!mounted) return;

    if (recognizedPlate != null) {
      _plateController.text = recognizedPlate;
      setState(() => _isLoading = false);
      _searchBus();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not read number plate from photo. Please enter manually.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Searching bus database...',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Identify Bus'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter Bus Registration Number',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter plate number or scan the vehicle plate photo (RTBT-17).',
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 20),

              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.occupiedRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_errorMessage!, style: const TextStyle(color: AppTheme.occupiedRed)),
                ),

              TextField(
                controller: _plateController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Bus Plate Number',
                  hintText: 'e.g. WP-ND-1024',
                  prefixIcon: const Icon(Icons.directions_bus),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.camera_alt, color: AppTheme.primaryBlue),
                    tooltip: 'Scan Number Plate with Camera',
                    onPressed: _scanPlateWithCamera,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _searchBus,
                icon: const Icon(Icons.search),
                label: const Text('VIEW SEATS ON THIS BUS'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _scanPlateWithCamera,
                icon: const Icon(Icons.photo_camera),
                label: const Text('SCAN NUMBER PLATE PHOTO (OCR)'),
              ),

              const SizedBox(height: 30),
              const Text(
                'Quick Route Selection (Demo Fleet):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              _buildDemoBusCard('WP-ND-1024', 'Route 138 (Colombo Fort - Kottawa)', '18 Seats Available'),
              _buildDemoBusCard('WP-NA-9081', 'Route 120 (Pettah - Horana)', '25 Seats Available'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDemoBusCard(String plate, String route, String seats) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.airport_shuttle, color: AppTheme.primaryBlue),
        title: Text(plate, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(route),
        trailing: Text(seats, style: const TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.bold, fontSize: 12)),
        onTap: () {
          _plateController.text = plate;
          _searchBus();
        },
      ),
    );
  }
}
