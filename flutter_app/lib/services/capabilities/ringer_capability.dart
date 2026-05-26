import 'package:flutter/services.dart';
import '../../models/node_frame.dart';
import 'capability_handler.dart';

class RingerCapability extends CapabilityHandler {
  static const _channel = MethodChannel('com.nxg.openclawproot/native');

  @override
  String get name => 'ringer';

  @override
  List<String> get commands => ['mode', 'set', 'volume'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    switch (command) {
      case 'ringer.mode':
        return _mode();
      case 'ringer.set':
        return _set(params);
      case 'ringer.volume':
        return _volume(params);
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown ringer command: $command',
        });
    }
  }

  Future<NodeFrame> _mode() async {
    try {
      final mode = await _channel.invokeMethod('getRingerMode') as String? ?? 'normal';
      return NodeFrame.response('', payload: {
        'mode': mode,
        'supported': ['normal', 'silent', 'vibrate'],
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'RINGER_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _set(Map<String, dynamic> params) async {
    final mode = params['mode'] as String?;
    if (mode == null || !['normal', 'silent', 'vibrate'].contains(mode)) {
      return NodeFrame.response('', error: {
        'code': 'INVALID_PARAM',
        'message': "mode must be one of: normal, silent, vibrate",
      });
    }

    try {
      await _channel.invokeMethod('setRingerMode', {'mode': mode});
      return NodeFrame.response('', payload: {'mode': mode});
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'RINGER_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _volume(Map<String, dynamic> params) async {
    final stream = params['stream'] as String? ?? 'ring'; // ring, notification, alarm, music
    final set = params['set'] as num?;

    try {
      if (set != null) {
        final level = (set.toDouble() * 7).toInt().clamp(0, 7);
        await _channel.invokeMethod('setStreamVolume', {
          'stream': stream,
          'level': level,
        });
      }

      final current = await _channel.invokeMethod('getStreamVolume', {'stream': stream}) as num? ?? 0;
      return NodeFrame.response('', payload: {
        'stream': stream,
        'volume': (current / 7.0).toStringAsFixed(2),
        'level': current,
        'max': 7,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'VOLUME_ERROR',
        'message': '$e',
      });
    }
  }
}
