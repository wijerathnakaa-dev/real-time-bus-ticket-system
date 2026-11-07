import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_config.dart';

/// Live event feed for one bus (or every bus when [busId] is null).
///
/// Reconnects with backoff after network loss and emits a synthetic
/// `{"type": "resync"}` event on every (re)connect so listeners re-fetch
/// authoritative state instead of trusting a gap in the event stream.
class LiveSocket {
  final String? busId;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _retry;
  int _attempt = 0;
  bool _closed = false;
  bool connected = false;

  LiveSocket({this.busId}) {
    _connect();
  }

  Stream<Map<String, dynamic>> get events => _controller.stream;

  void _connect() {
    if (_closed) return;
    final url = '${ApiConfig.wsUrl}/ws${busId != null ? '?bus_id=$busId' : ''}';
    try {
      final ch = WebSocketChannel.connect(Uri.parse(url));
      _channel = ch;
      ch.ready.then((_) {
        connected = true;
        _attempt = 0;
        _controller.add({'type': 'resync'});
      }).catchError((_) => _scheduleRetry());
      _sub = ch.stream.listen(
        (raw) {
          try {
            final m = jsonDecode(raw as String);
            if (m is Map<String, dynamic>) _controller.add(m);
          } catch (_) {}
        },
        onDone: _scheduleRetry,
        onError: (_) => _scheduleRetry(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    connected = false;
    _sub?.cancel();
    if (_closed || (_retry?.isActive ?? false)) return;
    final secs = [1, 2, 4, 8, 15][_attempt.clamp(0, 4)];
    _attempt++;
    _controller.add({'type': 'disconnected', 'retry_in': secs});
    _retry = Timer(Duration(seconds: secs), _connect);
  }

  void close() {
    _closed = true;
    _retry?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _controller.close();
  }
}
