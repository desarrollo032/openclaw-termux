import 'dart:async';
import 'package:flutter/services.dart';
import '../../models/node_frame.dart';
import '../../native/openclaw_native.dart';
import 'capability_handler.dart';

class SensorCapability extends CapabilityHandler {
  static const _channel = MethodChannel('com.nxg.openclawproot/native');

  @override
  String get name => 'sensor';

  @override
  List<String> get commands => [
        'read',
        'list',
        'light',
        'proximity',
      ];

  @override
  List<String> get requiredPermissionNames => [
        'android.permission.BODY_SENSORS',
      ];

  @override
  Future<bool> checkPermission() async {
    return await OpenClawNative.checkPermission('android.permission.BODY_SENSORS');
  }

  @override
  Future<bool> requestPermission() async {
    return await OpenClawNative.requestPermission('android.permission.BODY_SENSORS');
  }

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    switch (command) {
      case 'sensor.read':
        return _read(params);
      case 'sensor.list':
        return _list();
      case 'sensor.light':
        return _read({'sensor': 'light'});
      case 'sensor.proximity':
        return _read({'sensor': 'proximity'});
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown sensor command: $command',
        });
    }
  }

  /// Available sensor types on Android.
  static const _allSensors = [
    'accelerometer',
    'gyroscope',
    'magnetometer',
    'barometer',
    'light',
    'proximity',
    'gravity',
    'linear_acceleration',
    'rotation_vector',
    'humidity',
    'ambient_temperature',
    'step_counter',
    'heart_rate',
  ];

  Future<NodeFrame> _list() async {
    // Read all available sensors to check which ones are present
    final available = <Map<String, dynamic>>[];
    for (final sensor in _allSensors) {
      try {
        final data = await _channel.invokeMethod('readSensor', {'sensor': sensor});
        if (data != null) {
          final info = Map<String, dynamic>.from(data as Map);
          available.add({
            'type': sensor,
            'available': true,
            if (info['accuracy'] != null) 'accuracy': info['accuracy'],
          });
        }
      } catch (_) {
        // Sensor not available
        available.add({'type': sensor, 'available': false});
      }
    }

    return NodeFrame.response('', payload: {'sensors': available});
  }

  Future<NodeFrame> _read(Map<String, dynamic> params) async {
    final sensor = params['sensor'] as String? ?? 'accelerometer';

    try {
      final data = await _channel.invokeMethod('readSensor', {'sensor': sensor});
      if (data != null) {
        return NodeFrame.response('', payload: Map<String, dynamic>.from(data as Map));
      }
      return NodeFrame.response('', error: {
        'code': 'SENSOR_UNAVAILABLE',
        'message': 'Sensor "$sensor" not available on this device',
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'SENSOR_ERROR',
        'message': '$e',
      });
    }
  }
}
