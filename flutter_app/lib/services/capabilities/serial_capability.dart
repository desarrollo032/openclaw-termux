import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../../models/node_frame.dart';
import '../../native/openclaw_native.dart';
import 'capability_handler.dart';

class SerialCapability extends CapabilityHandler {
  // Track connected devices
  final Set<String> _connectedDevices = {};

  @override
  String get name => 'serial';

  @override
  List<String> get commands => ['list', 'connect', 'disconnect', 'write', 'read'];

  @override
  List<String> get requiredPermissionNames => [
    'android.permission.BLUETOOTH_CONNECT',
    'android.permission.BLUETOOTH_SCAN',
  ];

  @override
  Future<bool> checkPermission() async {
    return await OpenClawNative.checkPermission('android.permission.BLUETOOTH_CONNECT') &&
        await OpenClawNative.checkPermission('android.permission.BLUETOOTH_SCAN');
  }

  @override
  Future<bool> requestPermission() async {
    final granted1 = await OpenClawNative.requestPermission('android.permission.BLUETOOTH_CONNECT');
    final granted2 = await OpenClawNative.requestPermission('android.permission.BLUETOOTH_SCAN');
    return granted1 && granted2;
  }

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    switch (command) {
      case 'serial.list':
        return _list();
      case 'serial.connect':
        return _connect(params);
      case 'serial.disconnect':
        return _disconnect(params);
      case 'serial.write':
        return _write(params);
      case 'serial.read':
        return _read(params);
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown serial command: $command',
        });
    }
  }

  Future<NodeFrame> _list() async {
    final devices = <Map<String, dynamic>>[];

    // List USB devices via native
    try {
      final usbDevices = await OpenClawNative.usbList();
      for (final d in usbDevices) {
        devices.add({
          'id': 'usb:${d['deviceId']}',
          'type': 'usb',
          'name': d['name'] ?? 'USB Device',
          'vendorId': d['vendorId'],
          'productId': d['productId'],
        });
      }
    } catch (_) {}

    // List BLE devices via native (quick scan)
    try {
      final bleDevices = await OpenClawNative.bleScan(timeoutMs: 3000);
      for (final d in bleDevices) {
        if (!devices.any((dev) => dev['id'] == 'ble:${d['id']}')) {
          devices.add({
            'id': 'ble:${d['id']}',
            'type': 'ble',
            'name': (d['name'] as String?)?.isNotEmpty == true
                ? d['name']
                : 'BLE Device',
          });
        }
      }
    } catch (_) {}

    return NodeFrame.response('', payload: {'devices': devices});
  }

  Future<NodeFrame> _connect(Map<String, dynamic> params) async {
    final deviceId = params['deviceId'] as String?;
    if (deviceId == null) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_PARAM',
        'message': 'deviceId is required',
      });
    }

    if (_connectedDevices.contains(deviceId)) {
      return NodeFrame.response('', payload: {
        'status': 'already_connected',
        'deviceId': deviceId,
      });
    }

    try {
      if (deviceId.startsWith('usb:')) {
        final usbId = int.tryParse(deviceId.substring(4));
        if (usbId == null) {
          return NodeFrame.response('', error: {
            'code': 'INVALID_DEVICE_ID',
            'message': 'Invalid USB device ID',
          });
        }

        final baudRate = params['baudRate'] as int? ?? 115200;
        final connected = await OpenClawNative.usbConnect(usbId, baudRate: baudRate);

        if (!connected) {
          return NodeFrame.response('', error: {
            'code': 'CONNECT_ERROR',
            'message': 'Failed to connect to USB device',
          });
        }

        _connectedDevices.add(deviceId);
        return NodeFrame.response('', payload: {
          'status': 'connected',
          'deviceId': deviceId,
          'type': 'usb',
          'baudRate': baudRate,
        });
      } else if (deviceId.startsWith('ble:')) {
        final bleId = deviceId.substring(4);
        final connected = await OpenClawNative.bleConnect(bleId);

        if (!connected) {
          return NodeFrame.response('', error: {
            'code': 'CONNECT_ERROR',
            'message': 'Failed to connect to BLE device',
          });
        }

        _connectedDevices.add(deviceId);
        return NodeFrame.response('', payload: {
          'status': 'connected',
          'deviceId': deviceId,
          'type': 'ble',
        });
      }

      return NodeFrame.response('', error: {
        'code': 'INVALID_DEVICE_ID',
        'message': 'deviceId must start with usb: or ble:',
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'CONNECT_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _disconnect(Map<String, dynamic> params) async {
    final deviceId = params['deviceId'] as String?;
    if (deviceId == null) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_PARAM',
        'message': 'deviceId is required',
      });
    }

    if (!_connectedDevices.remove(deviceId)) {
      return NodeFrame.response('', payload: {
        'status': 'not_connected',
        'deviceId': deviceId,
      });
    }

    try {
      if (deviceId.startsWith('usb:')) {
        final usbId = int.tryParse(deviceId.substring(4));
        if (usbId != null) {
          await OpenClawNative.usbDisconnect(deviceId: usbId);
        }
      } else if (deviceId.startsWith('ble:')) {
        final bleId = deviceId.substring(4);
        await OpenClawNative.bleDisconnect(deviceId: bleId);
      }
    } catch (_) {}

    return NodeFrame.response('', payload: {
      'status': 'disconnected',
      'deviceId': deviceId,
    });
  }

  Future<NodeFrame> _write(Map<String, dynamic> params) async {
    final deviceId = params['deviceId'] as String?;
    final data = params['data'] as String?;
    if (deviceId == null || data == null) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_PARAM',
        'message': 'deviceId and data are required',
      });
    }

    if (!_connectedDevices.contains(deviceId)) {
      return NodeFrame.response('', error: {
        'code': 'NOT_CONNECTED',
        'message': 'Device not connected: $deviceId',
      });
    }

    try {
      final bytes = utf8.encode(data);
      bool success;

      if (deviceId.startsWith('usb:')) {
        final usbId = int.parse(deviceId.substring(4));
        success = await OpenClawNative.usbWrite(usbId, Uint8List.fromList(bytes));
      } else if (deviceId.startsWith('ble:')) {
        final bleId = deviceId.substring(4);
        success = await OpenClawNative.bleWrite(bleId, Uint8List.fromList(bytes));
      } else {
        return NodeFrame.response('', error: {
          'code': 'INVALID_DEVICE_ID',
          'message': 'Unknown device type',
        });
      }

      return NodeFrame.response('', payload: {
        'status': success ? 'written' : 'write_failed',
        'deviceId': deviceId,
        'bytesWritten': bytes.length,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'WRITE_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _read(Map<String, dynamic> params) async {
    final deviceId = params['deviceId'] as String?;
    if (deviceId == null) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_PARAM',
        'message': 'deviceId is required',
      });
    }

    if (!_connectedDevices.contains(deviceId)) {
      return NodeFrame.response('', error: {
        'code': 'NOT_CONNECTED',
        'message': 'Device not connected: $deviceId',
      });
    }

    try {
      final timeoutMs = params['timeoutMs'] as int? ?? 2000;
      Uint8List? data;

      if (deviceId.startsWith('usb:')) {
        final usbId = int.parse(deviceId.substring(4));
        final result = await OpenClawNative.usbRead(usbId, timeoutMs: timeoutMs);
        data = result;
      } else if (deviceId.startsWith('ble:')) {
        final bleId = deviceId.substring(4);
        final result = await OpenClawNative.bleRead(bleId, timeoutMs: timeoutMs);
        data = result;
      } else {
        return NodeFrame.response('', error: {
          'code': 'INVALID_DEVICE_ID',
          'message': 'Unknown device type',
        });
      }

      return NodeFrame.response('', payload: {
        'deviceId': deviceId,
        'data': data != null ? utf8.decode(data, allowMalformed: true) : null,
        'bytesRead': data?.length ?? 0,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'READ_ERROR',
        'message': '$e',
      });
    }
  }

  void dispose() {
    // Disconnect all on dispose
    for (final deviceId in _connectedDevices.toList()) {
      try {
        if (deviceId.startsWith('usb:')) {
          final usbId = int.parse(deviceId.substring(4));
          OpenClawNative.usbDisconnect(deviceId: usbId);
        } else if (deviceId.startsWith('ble:')) {
          final bleId = deviceId.substring(4);
          OpenClawNative.bleDisconnect(deviceId: bleId);
        }
      } catch (_) {}
    }
    _connectedDevices.clear();
  }
}
