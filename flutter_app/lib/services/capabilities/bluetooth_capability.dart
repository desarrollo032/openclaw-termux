import 'package:flutter/services.dart';
import '../../models/node_frame.dart';
import '../../native/openclaw_native.dart';
import 'capability_handler.dart';

class BluetoothCapability extends CapabilityHandler {
  static const _channel = MethodChannel('com.nxg.openclawproot/native');

  @override
  String get name => 'bluetooth';

  @override
  List<String> get commands => [
        'status',
        'scan',
        'paired',
        'connect',
        'disconnect',
        'enable',
        'disable',
        'discoverable',
      ];

  @override
  List<String> get requiredPermissionNames => [
        'android.permission.BLUETOOTH_CONNECT',
        'android.permission.BLUETOOTH_SCAN',
        'android.permission.ACCESS_FINE_LOCATION',
      ];

  @override
  Future<bool> checkPermission() async {
    final connect = await OpenClawNative.checkPermission(
        'android.permission.BLUETOOTH_CONNECT');
    final scan = await OpenClawNative.checkPermission(
        'android.permission.BLUETOOTH_SCAN');
    return connect && scan;
  }

  @override
  Future<bool> requestPermission() async {
    await OpenClawNative.requestPermission('android.permission.BLUETOOTH_CONNECT');
    await OpenClawNative.requestPermission('android.permission.BLUETOOTH_SCAN');
    return true;
  }

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    switch (command) {
      case 'bluetooth.status':
        return _status();
      case 'bluetooth.scan':
        return _scan(params);
      case 'bluetooth.paired':
        return _paired();
      case 'bluetooth.connect':
        return _connect(params);
      case 'bluetooth.disconnect':
        return _disconnect(params);
      case 'bluetooth.enable':
        return _enable();
      case 'bluetooth.disable':
        return _disable();
      case 'bluetooth.discoverable':
        return _discoverable(params);
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown bluetooth command: $command',
        });
    }
  }

  Future<NodeFrame> _status() async {
    try {
      final result = await _channel.invokeMethod('getBluetoothStatus') as Map? ?? {};
      return NodeFrame.response('', payload: result.cast<String, dynamic>());
    } catch (e) {
      return NodeFrame.response('', payload: {
        'enabled': false,
        'available': false,
        'error': '$e',
      });
    }
  }

  Future<NodeFrame> _scan(Map<String, dynamic> params) async {
    final timeoutMs = params['timeoutMs'] as int? ?? 5000;
    try {
      final devices = await _channel.invokeMethod('bluetoothScan', {
        'timeoutMs': timeoutMs,
      }) as List? ?? [];
      return NodeFrame.response('', payload: {
        'devices': devices,
        'count': devices.length,
        'timeoutMs': timeoutMs,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'BT_SCAN_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _paired() async {
    try {
      final devices = await _channel.invokeMethod('getPairedBluetoothDevices') as List? ?? [];
      return NodeFrame.response('', payload: {
        'devices': devices,
        'count': devices.length,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'BT_PAIRED_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _connect(Map<String, dynamic> params) async {
    final address = params['address'] as String?;
    if (address == null) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_PARAM',
        'message': 'address is required',
      });
    }

    try {
      final result = await _channel.invokeMethod('bluetoothConnect', {
        'address': address,
      });
      return NodeFrame.response('', payload: {
        'connected': result == true,
        'address': address,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'BT_CONNECT_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _disconnect(Map<String, dynamic> params) async {
    final address = params['address'] as String?;
    try {
      final map = <String, dynamic>{};
      if (address != null) map['address'] = address;
      await _channel.invokeMethod('bluetoothDisconnect', map);
      return NodeFrame.response('', payload: {
        'disconnected': true,
        if (address != null) 'address': address,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'BT_DISCONNECT_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _enable() async {
    try {
      await _channel.invokeMethod('enableBluetooth');
      return NodeFrame.response('', payload: {'enabled': true});
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'BT_ENABLE_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _disable() async {
    try {
      await _channel.invokeMethod('disableBluetooth');
      return NodeFrame.response('', payload: {'enabled': false});
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'BT_DISABLE_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _discoverable(Map<String, dynamic> params) async {
    final duration = params['duration'] as int? ?? 120;
    try {
      await _channel.invokeMethod('makeBluetoothDiscoverable', {
        'duration': duration,
      });
      return NodeFrame.response('', payload: {
        'discoverable': true,
        'durationSeconds': duration,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'BT_DISCOVERABLE_ERROR',
        'message': '$e',
      });
    }
  }
}
