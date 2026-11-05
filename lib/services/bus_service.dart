import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bus_model.dart';
import '../models/seat_model.dart';
import '../utils/app_constants.dart';

class BusService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Search bus by plate number (RTBT-17)
  Future<BusModel?> findBusByPlate(String plateNumber) async {
    final cleanPlate = plateNumber.trim().toUpperCase().replaceAll(' ', '-');
    final query = await _firestore
        .collection(AppConstants.colBuses)
        .where('plateNumber', isEqualTo: cleanPlate)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return null;
    }
    return BusModel.fromFirestore(query.docs.first);
  }

  // Stream seats for real-time map (RTBT-18 & RTBT-21)
  Stream<List<SeatModel>> streamSeatsForBus(String busId) {
    return _firestore
        .collection(AppConstants.colBuses)
        .doc(busId)
        .collection(AppConstants.colSeats)
        .orderBy('seatNumber')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SeatModel.fromMap(doc.data(), doc.id))
            .toList());
  }
}

