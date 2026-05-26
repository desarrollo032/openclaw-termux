import 'package:flutter/services.dart';
import '../../models/node_frame.dart';
import 'capability_handler.dart';

class DisplayCapability extends CapabilityHandler {
  static const _channel = MethodChannel('com.nxg.openclawproot/native');

  @override
  String get name => 'display';

  @override
  List<String> get commands => ['brightness', 'timeout', 'orientation', 'info'];

  @override
  List<String> get requiredPermissionNames => [
        'android.permission.WRITE_SETTINGS',
      ];

  /// Read operations don't need runtime permission.
  @override
  Future<bool> checkPermission() async => true;

  /// WRITE_SETTINGS is a special permission (requires intent, not runtime dialog).
  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    switch (command) {
      case 'display.brightness':
        return _brightness(params);
      case 'display.timeout':
        return _timeout(params);
      case 'display.orientation':
        return _orientation(params);
      case 'display.info':
        return _info();
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown display command: $command',
        });
    }
  }

  Future<NodeFrame> _brightness(Map<String, dynamic> params) async {
    final set = params['set'] as num?;

    try {
      if (set != null) {
        final level = (set.toDouble() * 255).toInt().clamp(0, 255);
        await _channel.invokeMethod('setScreenBrightness', {'level': level});
      }

      final current = await _channel.invokeMethod('getScreenBrightness') as int? ?? 128;
      return NodeFrame.response('', payload: {
        'brightness': (current / 255.0).toStringAsFixed(2),
        'level': current,
        'min': 0,
        'max': 255,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'BRIGHTNESS_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _timeout(Map<String, dynamic> params) async {
    final setSeconds = params['set'] as int?;

    try {
      if (setSeconds != null) {
        await _channel.invokeMethod('setScreenTimeout', {'timeoutMs': setSeconds * 1000});
      }

      final current = await _channel.invokeMethod('getScreenTimeout') as int? ?? 30000;
      return NodeFrame.response('', payload: {
        'timeoutSeconds': current ~/ 1000,
        'timeoutMs': current,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'TIMEOUT_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _orientation(Map<String, dynamic> params) async {
    final set = params['set'] as String?; // "portrait", "landscape", "auto"

    try {
      if (set != null) {
        await _channel.invokeMethod('setScreenOrientation', {'mode': set});
      }

      final current = await _channel.invokeMethod('getScreenOrientation') as String? ?? 'auto';
      return NodeFrame.response('', payload: {
        'orientation': current,
        'supported': ['portrait', 'landscape', 'auto'],
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'ORIENTATION_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _info() async {
    try {
      final info = await _channel.invokeMethod('getDisplayInfo') as Map? ?? {};
      return NodeFrame.response('', payload: info.cast<String, dynamic>());
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'DISPLAY_ERROR',
        'message': '$e',
      });
    }
  }
}
