import 'dart:async';
import 'package:flutter/services.dart';

/// Native PTY bridge that replaces flutter_pty.
///
/// Uses MethodChannel for commands and BasicMessageChannel (thread-safe)
/// per session for streaming output events.
///
/// Optimisations:
///   - BasicMessageChannel with JSONMessageCodec is thread-safe in Kotlin
///   → eliminates mainHandler.post() overhead (~2-16ms savings per event)
///   - UTF-8 decode happens in Kotlin background thread, not Flutter UI thread
///   - Sub-millisecond flush threshold (500 μs) for faster small-output commands
class OpenClawPty {
  OpenClawPty._();

  static const _methodChannel = MethodChannel('com.nxg.openclawproot/pty');
  static const _outputPrefix = 'com.nxg.openclawproot/pty/output/';

  static final Map<int, BasicMessageChannel<dynamic>> _outputChannels = {};
  static final Map<int, StreamSubscription<dynamic>> _outputSubscriptions = {};
  static final Map<int, StreamController<Map<String, dynamic>>> _outputControllers = {};

  /// Start a new PTY session.
  ///
  /// Returns a session ID (positive int) on success.
  /// Throws [Exception] on failure.
  static Future<int> start({
    required String shell,
    List<String>? args,
    List<String> arguments = const [],
    Map<String, String>? env,
    Map<String, String> environment = const {},
    String? workingDirectory,
    int rows = 24,
    int columns = 80,
  }) async {
    final resolvedArgs = args ?? arguments;
    final resolvedEnvironment = env ?? environment;
    final envList = resolvedEnvironment.entries.map((e) => '${e.key}=${e.value}').toList();

    final result = await _methodChannel.invokeMethod<int>('startPty', {
      'shell': shell,
      'args': resolvedArgs,
      'envVars': envList,
      'cwd': workingDirectory,
      'rows': rows,
      'cols': columns,
    });

    if (result == null || result < 0) {
      throw Exception('Failed to start PTY session');
    }

    return result;
  }

  /// Write data to a PTY session.
  static Future<bool> write(int sessionId, Uint8List data) async {
    final result = await _methodChannel.invokeMethod<bool>('writePty', {
      'sessionId': sessionId,
      'data': data,
    });
    return result ?? false;
  }

  /// Resize a PTY session.
  static Future<bool> resize(int sessionId, int rows, int columns) async {
    final result = await _methodChannel.invokeMethod<bool>('resizePty', {
      'sessionId': sessionId,
      'rows': rows,
      'cols': columns,
    });
    return result ?? false;
  }

  /// Kill a PTY session (send SIGTERM/SIGKILL).
  static Future<bool> kill(int sessionId) async {
    final result = await _methodChannel.invokeMethod<bool>('killPty', {
      'sessionId': sessionId,
    });
    return result ?? false;
  }

  /// Close a PTY session and clean up resources.
  ///
  /// This also cancels the output stream subscription and unregisters
  /// the BasicMessageChannel handler.
  static Future<bool> close(int sessionId) async {
    // Unregister message handler + cancel subscription
    _outputChannels.remove(sessionId)?.setMessageHandler(null);
    await _outputSubscriptions.remove(sessionId)?.cancel();
    await _outputControllers.remove(sessionId)?.close();

    final result = await _methodChannel.invokeMethod<bool>('closePty', {
      'sessionId': sessionId,
    });
    return result ?? false;
  }

  /// Get the event stream for a PTY session.
  ///
  /// Events use BasicMessageChannel (thread-safe on Kotlin side):
  /// ```json
  /// { "type": "output", "text": String }    // pre-decoded UTF-8
  /// { "type": "exit", "exitCode": int }
  /// { "type": "error", "message": String }
  /// ```
  ///
  /// Optimisations vs old EventChannel approach:
  ///   - No utf8.decode() needed on Dart side (Kotlin decodes on background thread)
  ///   - No mainHandler.post() overhead (BasicMessageChannel.send() is thread-safe)
  ///   - Lower flush threshold (500 μs vs 1 ms) for more responsive output
  ///
  /// Uses setMessageHandler internally (bridged to a StreamController) because
  /// BasicMessageChannel.receiveBroadcastStream() has inconsistent availability
  /// across Flutter versions.
  ///
  /// The stream closes when the session ends or is closed.
  /// Only one listener per session is supported.
  static Stream<Map<String, dynamic>> events(int sessionId) {
    // Return existing stream if already created
    if (_outputControllers.containsKey(sessionId)) {
      return _outputControllers[sessionId]!.stream;
    }

    final controller = StreamController<Map<String, dynamic>>.broadcast(
      onCancel: () {
        _outputControllers.remove(sessionId)?.close();
        _outputSubscriptions.remove(sessionId)?.cancel();
        // Unregister the handler when no listeners remain
        final channel = _outputChannels.remove(sessionId);
        channel?.setMessageHandler(null);
      },
    );
    _outputControllers[sessionId] = controller;

    // BasicMessageChannel with JSONMessageCodec — thread-safe, no main thread dependency
    // ignore: prefer_const_constructors (string interpolation prevents const)
    final outputChannel = BasicMessageChannel<dynamic>(
      '$_outputPrefix$sessionId',
      const JSONMessageCodec(),
    );
    _outputChannels[sessionId] = outputChannel;

    outputChannel.setMessageHandler((message) async {
      if (message is Map) {
        final typed = Map<String, dynamic>.from(message);
        if (!controller.isClosed) {
          controller.add(typed);
        }

        // Auto-close stream on exit or error
        if (typed['type'] == 'exit' || typed['type'] == 'error') {
          _outputChannels.remove(sessionId)?.setMessageHandler(null);
          _outputSubscriptions.remove(sessionId)?.cancel();
          if (!controller.isClosed) {
            unawaited(controller.close());
          }
          _outputControllers.remove(sessionId);
        }
      }
      return null;
    });

    return controller.stream;
  }
}
