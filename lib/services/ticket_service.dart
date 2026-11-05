import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ticket_model.dart';
import '../utils/app_constants.dart';

class TicketService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Atomic transactional booking for Passenger (RTBT-19) and Conductor (RTBT-20)
  Future<TicketModel> bookSeat({
    required String busId,
    required String busPlateNumber,
    required String routeNumber,
    required String seatNumber,
    required String passengerId,
    required String passengerName,
    required String issuedByRole,
    String? conductorId,
    required double fare,
    String paymentMethod = 'cash',
  }) async {
    final busRef = _firestore.collection(AppConstants.colBuses).doc(busId);
    final seatRef = busRef.collection(AppConstants.colSeats).doc(seatNumber);
    final ticketRef = _firestore.collection(AppConstants.colTickets).doc();

    final ticketNumber = 'TKT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    return await _firestore.runTransaction((transaction) async {
      final seatSnapshot = await transaction.get(seatRef);

      if (!seatSnapshot.exists) {
        throw Exception('Seat $seatNumber does not exist on bus $busPlateNumber.');
      }

      final currentStatus = seatSnapshot.get('status') as String? ?? 'available';
      if (currentStatus == AppConstants.seatTaken) {
        throw Exception('Seat $seatNumber is already occupied! Please choose another seat.');
      }

      // Mark seat taken
      transaction.update(seatRef, {
        'status': AppConstants.seatTaken,
        'bookedBy': passengerId,
        'bookedAt': FieldValue.serverTimestamp(),
        'ticketId': ticketRef.id,
      });

      // Decrement available seats counter
      transaction.update(busRef, {
        'availableSeats': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final newTicket = TicketModel(
        id: ticketRef.id,
        ticketId: ticketNumber,
        busId: busId,
        busPlateNumber: busPlateNumber,
        routeNumber: routeNumber,
        seatNumber: seatNumber,
        passengerId: passengerId,
        passengerName: passengerName,
        issuedByRole: issuedByRole,
        conductorId: conductorId,
        fare: fare,
        paymentStatus: 'paid',
        paymentMethod: paymentMethod,
        issuedAt: DateTime.now(),
      );

      transaction.set(ticketRef, newTicket.toMap());
      return newTicket;
    });
  }

  // Stream tickets for Passenger (My Tickets)
  Stream<List<TicketModel>> streamPassengerTickets(String passengerId) {
    return _firestore
        .collection(AppConstants.colTickets)
        .where('passengerId', isEqualTo: passengerId)
        .orderBy('issuedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TicketModel.fromFirestore(doc))
            .toList());
  }

  // Stream tickets for Conductor (Trip Manifest)
  Stream<List<TicketModel>> streamBusTickets(String busId) {
    return _firestore
        .collection(AppConstants.colTickets)
        .where('busId', isEqualTo: busId)
        .orderBy('issuedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TicketModel.fromFirestore(doc))
            .toList());
  }
}

