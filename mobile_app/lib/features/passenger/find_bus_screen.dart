import 'package:flutter/material.dart';
import '../../models/bus_model.dart';
import '../buses/bus_service.dart';
import '../buses/number_plate_ocr_service.dart';
import '../../shared/widgets/loading_overlay.dart';
import '../../core/theme/app_theme.dart';
import 'bus_tracking_screen.dart';

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
  final TextEditingController _plateController = TextEditingController();
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

  void _searchBus([String? plateToSearch]) async {
    final plate = (plateToSearch ?? _plateController.text).trim();
    if (plate.isEmpty) {
      setState(() => _errorMessage = 'Please enter a bus registration plate.');
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
          _errorMessage = 'No approved bus with plate "$plate" was found.';
          _isLoading = false;
        });
        return;
      }

      setState(() => _isLoading = false);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BusTrackingScreen(bus: bus),
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
      _searchBus(recognizedPlate);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not read a valid number plate from image. Please enter manually.';
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
                'Search Active Fleet',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                'Type the number plate (e.g. NB-2451) or scan it with the camera.',
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 20),

              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.occupiedRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_errorMessage!, style: const TextStyle(color: AppTheme.occupiedRed)),
                ),

              TextField(
                controller: _plateController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Bus Plate Number',
                  hintText: 'e.g. NB-2451',
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
                onPressed: () => _searchBus(),
                icon: const Icon(Icons.search),
                label: const Text('SEARCH BUS'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _scanPlateWithCamera,
                icon: const Icon(Icons.photo_camera),
                label: const Text('SCAN NUMBER PLATE PHOTO (OCR)'),
              ),

              const SizedBox(height: 30),
              const Text(
                'Buses in service (live):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 10),

              StreamBuilder<List<BusModel>>(
                stream: _busService.streamActiveBuses(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text(snapshot.error.toString(), style: const TextStyle(color: AppTheme.occupiedRed));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ));
                  }

                  final buses = snapshot.data ?? [];
                  if (buses.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'No buses in service yet.',
                        style: TextStyle(color: Colors.black54, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: buses.length,
                    itemBuilder: (context, index) {
                      final bus = buses[index];
                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.airport_shuttle, color: AppTheme.primaryBlue),
                          title: Text(bus.plateNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Route ${bus.routeNumber} - ${bus.onTrip ? '${bus.availableSeats} seats free' : 'not on a trip'}'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => BusTrackingScreen(bus: bus)),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
