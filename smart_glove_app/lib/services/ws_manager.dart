import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/glove_data.dart';
import 'package:http/http.dart' as http;

class WsManager {
  static const String _wsUrl = 'ws://192.168.4.1:81';
  
  final _gloveDataController = StreamController<GloveData>.broadcast();
  WebSocketChannel? _channel;
  bool _isConnected = false;

  // ── Public streams ──────────────────────────────────────────────────────────

  /// Parsed GloveData from WiFi WebSocket notifications.
  Stream<GloveData> get gloveDataStream => _gloveDataController.stream;

  bool get isConnected => _isConnected;

  // ── Connection ──────────────────────────────────────────────────────────────

  Future<void> connect() async {
    if (_isConnected) return;
    
    // Quick ping to check if we are on the right network first
    try {
      await http.get(Uri.parse('http://192.168.4.1')).timeout(const Duration(seconds: 3));
      // Doesn't matter what it returns, just that it didn't timeout
    } catch (_) {
      // It will likely throw if the network isn't connected, but we still try WS
    }

    try {
      final uri = Uri.parse(_wsUrl);
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;
      _isConnected = true;

      _channel!.stream.listen(
        (message) {
          try {
            final String raw = message.toString();
            _gloveDataController.add(GloveData.fromRaw(raw));
          } catch (_) { }
        },
        onDone: () {
          _isConnected = false;
        },
        onError: (error) {
          _isConnected = false;
        },
      );

    } catch (e) {
      _isConnected = false;
      throw Exception('Could not connect to Glove Access Point: $e');
    }
  }

  Future<void> disconnect() async {
    await _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _gloveDataController.close();
  }
}
