import 'dart:async';

import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/api/live_socket.dart';
import '../../models/ticket_model.dart';

class PaymentStart {
  final String mode; // simulated | sandbox | live
  final String? checkoutUrl;
  PaymentStart(this.mode, this.checkoutUrl);
  bool get isSimulated => mode == 'simulated';
}

/// Ticketing and PayHere payments. Seat locking is done atomically by the server
/// (SELECT ... FOR UPDATE), so a lost race surfaces as ApiException.isConflict.
class TicketService {
  final ApiClient _api = ApiClient.instance;

  /// Passenger books in-app (pending until paid) or conductor issues a cash ticket.
  Future<TicketModel> bookSeat({
    required String busId,
    required String seatNumber,
    String? fromStopId,
    String? toStopId,
    String? passengerName,
    String? passengerPhone,
  }) async =>
      TicketModel.fromJson(await _api.post('/tickets', {
        'bus_id': busId,
        'seat_number': seatNumber,
        if (fromStopId != null) 'from_stop_id': fromStopId,
        if (toStopId != null) 'to_stop_id': toStopId,
        if (passengerName != null) 'passenger_name': passengerName,
        if (passengerPhone != null) 'passenger_phone': passengerPhone,
      }) as Map<String, dynamic>);

  Future<TicketModel> getTicket(String id) async => TicketModel.fromJson(await _api.get('/tickets/$id') as Map<String, dynamic>);

  Future<List<TicketModel>> myTickets() async =>
      ((await _api.get('/tickets/mine')) as List).map((t) => TicketModel.fromJson(t as Map<String, dynamic>)).toList();

  Future<List<TicketModel>> busTickets(String busId, {String? status}) async =>
      ((await _api.get('/tickets', query: {'bus_id': busId, if (status != null) 'status': status})) as List)
          .map((t) => TicketModel.fromJson(t as Map<String, dynamic>))
          .toList();

  Future<TicketModel> cancel(String ticketId) async => TicketModel.fromJson(await _api.post('/tickets/$ticketId/cancel') as Map<String, dynamic>);

  /// Conductor verifies a passenger's QR / ticket number. Returns (valid, ticket).
  Future<(bool, TicketModel)> verify(String ticketNumber) async {
    final res = await _api.get('/tickets/verify/${Uri.encodeComponent(ticketNumber.trim().toUpperCase())}') as Map<String, dynamic>;
    return (res['valid'] == true, TicketModel.fromJson(res['ticket'] as Map<String, dynamic>));
  }

  /// Conductor frees the seat when the passenger alights.
  Future<void> releaseSeat({required String busId, required String seatNumber}) =>
      _api.post('/seats/release', {'bus_id': busId, 'seat_number': seatNumber});

  Future<void> overrideSeat({required String busId, required String seatNumber, required bool taken}) =>
      _api.post('/seats/override', {'bus_id': busId, 'seat_number': seatNumber, 'status': taken ? 'taken' : 'available'});

  // ----- PayHere -----

  Future<PaymentStart> startPayment(String ticketId) async {
    final res = await _api.post('/payments/start', {'ticket_id': ticketId}) as Map<String, dynamic>;
    return PaymentStart(res['mode'] as String, res['checkout_url'] as String?);
  }

  /// Opens PayHere's hosted checkout in the browser (sandbox or live).
  Future<bool> openCheckout(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  /// Demo mode only (server has no PayHere merchant configured).
  Future<TicketModel> simulatePayment(String ticketId) async =>
      TicketModel.fromJson(await _api.post('/payments/simulate', {'ticket_id': ticketId}) as Map<String, dynamic>);

  /// Waits for PayHere's server callback to mark the ticket paid (or failed).
  Stream<TicketModel> watchTicket(TicketModel ticket) {
    late StreamController<TicketModel> ctrl;
    LiveSocket? socket;
    StreamSubscription? sub;
    Timer? poll;
    Future<void> reload() async {
      try {
        final t = await getTicket(ticket.id);
        if (!ctrl.isClosed) ctrl.add(t);
      } catch (_) {}
    }

    ctrl = StreamController<TicketModel>(
      onListen: () {
        reload();
        socket = LiveSocket(busId: ticket.busId);
        sub = socket!.events.listen((e) {
          if (e['ticket_id'] == ticket.id || e['type'] == 'resync') reload();
        });
        poll = Timer.periodic(const Duration(seconds: 5), (_) => reload());
      },
      onCancel: () {
        poll?.cancel();
        sub?.cancel();
        socket?.close();
      },
    );
    return ctrl.stream;
  }

  /// Passenger's tickets, refreshed on payment / seat events for buses they ride.
  Stream<List<TicketModel>> streamPassengerTickets(String passengerId) {
    late StreamController<List<TicketModel>> ctrl;
    LiveSocket? socket;
    StreamSubscription? sub;
    Timer? debounce;
    Future<void> reload() async {
      try {
        final t = await myTickets();
        if (!ctrl.isClosed) ctrl.add(t);
      } catch (e) {
        if (!ctrl.isClosed) ctrl.addError(e);
      }
    }

    ctrl = StreamController<List<TicketModel>>(
      onListen: () {
        reload();
        socket = LiveSocket();
        sub = socket!.events.listen((e) {
          final t = e['type'];
          if (t == 'ticket_paid' || t == 'seat_released' || t == 'trip_end' || t == 'resync') {
            debounce?.cancel();
            debounce = Timer(const Duration(milliseconds: 500), reload);
          }
        });
      },
      onCancel: () {
        debounce?.cancel();
        sub?.cancel();
        socket?.close();
      },
    );
    return ctrl.stream;
  }

  /// Conductor's trip manifest (active tickets), refreshed on seat events.
  Stream<List<TicketModel>> streamBusTickets(String busId) {
    late StreamController<List<TicketModel>> ctrl;
    LiveSocket? socket;
    StreamSubscription? sub;
    Future<void> reload() async {
      try {
        final t = await busTickets(busId, status: 'active');
        if (!ctrl.isClosed) ctrl.add(t);
      } catch (e) {
        if (!ctrl.isClosed) ctrl.addError(e);
      }
    }

    ctrl = StreamController<List<TicketModel>>(
      onListen: () {
        reload();
        socket = LiveSocket(busId: busId);
        sub = socket!.events.listen((e) {
          final t = e['type'];
          if (t == 'seat_booked' || t == 'seat_released' || t == 'ticket_paid' || t == 'trip_end' || t == 'resync') reload();
        });
      },
      onCancel: () {
        sub?.cancel();
        socket?.close();
      },
    );
    return ctrl.stream;
  }
}
