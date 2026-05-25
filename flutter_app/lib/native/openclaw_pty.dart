import 'dart:async';
import 'package:flutter/services.dart';

/// Native PTY bridge that replaces flutter_pty.
///
/// Uses MethodChannel for commands and EventChannel per session
/// for streaming output events.
class OpenClawPty {
  OpenClawPty._();

  static const _methodChannel = MethodChannel('com.nxg.openclawproot/pty');

  static final Map<int, StreamSubscription<dynamic>> _eventSubscriptions = {};
  static final Map<int, StreamController<Map<String, dynamic>>> _eventControllers = {};

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
  /// This also cancels the event stream subscription.
  static Future<bool> close(int sessionId) async {
    // Cancel event subscription
    await _eventSubscriptions.remove(sessionId)?.cancel();
    await _eventControllers.remove(sessionId)?.close();

    final result = await _methodChannel.invokeMethod<bool>('closePty', {
      'sessionId': sessionId,
    });
    return result ?? false;
  }

  /// Get the event stream for a PTY session.
  ///
  /// Events:
  /// ```json
  /// { "type": "output", "data": Uint8List }
  /// { "type": "exit", "exitCode": int }
  /// { "type": "error", "message": String }
  /// ```
  ///
  /// The stream closes when the session ends or is closed.
  /// Only one listener per session is supported.
  static Stream<Map<String, dynamic>> events(int sessionId) {
    // Return existing stream if already created
    if (_eventControllers.containsKey(sessionId)) {
      return _eventControllers[sessionId]!.stream;
    }

    final controller = StreamController<Map<String, dynamic>>.broadcast(
      onCancel: () {
        // Auto-cleanup when no more listeners
        _eventControllers.remove(sessionId)?.close();
        _eventSubscriptions.remove(sessionId)?.cancel();
      },
    );
    _eventControllers[sessionId] = controller;

    final eventChannel = EventChannel('com.nxg.openclawproot/pty/events/$sessionId');
    final subscription = eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          final typed = Map<String, dynamic>.from(event);
          controller.add(typed);

          // Auto-close stream on exit or error
          if (typed['type'] == 'exit' || typed['type'] == 'error') {
            _eventSubscriptions.remove(sessionId)?.cancel();
            unawaited(controller.close());
            _eventControllers.remove(sessionId);
          }
        }
      },
      onError: (error) {
        controller.addError(error);
        _eventSubscriptions.remove(sessionId)?.cancel();
        unawaited(controller.close());
        _eventControllers.remove(sessionId);
      },
      onDone: () {
        if (!controller.isClosed) {
          unawaited(controller.close());
        }
        _eventControllers.remove(sessionId);
      },
      cancelOnError: false,
    );
    _eventSubscriptions[sessionId] = subscription;

    return controller.stream;
  }
}
