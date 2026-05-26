import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../widgets/orb/ai_orb_controller.dart';

/// WebSocket service that connects to the Ktor orb backend at
/// ws://[host]:[port]/orb-events and updates an [AiOrbController].
class OrbWebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  final AiOrbController _controller;
  String? _host;
  int? _port;
  bool _shouldReconnect = true;
  int _reconnectAttempt = 0;
  bool _isConnected = false;

  /// Fired when connection state changes.
  final _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;
  bool get isConnected => _isConnected;

  OrbWebSocketService(this._controller);

  /// Connect to the orb server at [host]:[port].
  /// Defaults to 127.0.0.1:18790.
  Future<void> connect({
    String host = '127.0.0.1',
    int port = 18790,
  }) async {
    _host = host;
    _port = port;
    _shouldReconnect = true;
    _reconnectAttempt = 0;
    await _doConnect();
  }

  Future<void> _doConnect() async {
    if (_host == null || _port == null) return;

    final url = 'ws://$_host:$_port/orb-events';
    try {
      final channel = WebSocketChannel.connect(Uri.parse(url));
      _channel = channel;
      await channel.ready;
      _isConnected = true;
      _connectionController.add(true);
      _reconnectAttempt = 0;

      _subscription = channel.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            if (json['type'] == 'orb_state') {
              final emotion = json['emotion'] as String? ?? 'idle';
              final audioLevel = (json['audioLevel'] as num?)?.toDouble() ?? 0.0;
              final message = json['message'] as String?;

              _controller.setEmotionFromString(emotion);
              _controller.setAudioLevel(audioLevel);

              // Log message if present (for debugging)
              if (message != null && message.isNotEmpty) {
                // ignore: avoid_print
                print('[ORB] $message');
              }
            }
          } catch (_) {
            // Ignore malformed frames
          }
        },
        onError: (_) => _handleDisconnect(),
        onDone: _handleDisconnect,
      );
    } catch (_) {
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _isConnected = false;
    _connectionController.add(false);
    _subscription?.cancel();
    _channel = null;

    if (_shouldReconnect) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final delayMs = [
      500, 1000, 2000, 4000, 8000,
    ][_reconnectAttempt.clamp(0, 4)];
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () {
      if (_shouldReconnect) {
        _doConnect();
      }
    });
  }

  /// Send a POST request to the REST endpoint to update emotion.
  Future<bool> sendEmotion(String emotion, {String? message, double audioLevel = 0.0}) async {
    if (_host == null || _port == null) return false;
    try {
      final client = HttpClient();
      final request = await client.postUrl(
        Uri.parse('http://$_host:$_port/orb/emotion'),
      );
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'emotion': emotion,
        'audioLevel': audioLevel,
        'message': message,
      }));
      final response = await request.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Send audio level to the REST endpoint.
  Future<bool> sendAudioLevel(double level) async {
    if (_host == null || _port == null) return false;
    try {
      final client = HttpClient();
      final request = await client.postUrl(
        Uri.parse('http://$_host:$_port/orb/audio'),
      );
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'level': level.clamp(0.0, 1.0)}));
      final response = await request.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Send text for sentiment analysis to the REST endpoint.
  Future<bool> analyzeSentiment(String text, {String? message}) async {
    if (_host == null || _port == null) return false;
    try {
      final client = HttpClient();
      final request = await client.postUrl(
        Uri.parse('http://$_host:$_port/orb/sentiment'),
      );
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'text': text,
        if (message != null) 'message': message,
      }));
      final response = await request.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Disconnect and stop reconnecting.
  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _isConnected = false;
    _connectionController.add(false);
    await _channel?.sink.close();
    _channel = null;
  }

  /// Clean up resources.
  void dispose() {
    disconnect();
    _connectionController.close();
  }
}
