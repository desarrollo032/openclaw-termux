import 'package:flutter/services.dart';
import '../../models/node_frame.dart';
import '../native_bridge.dart';
import 'capability_handler.dart';

class NetworkCapability extends CapabilityHandler {
  static const _channel = MethodChannel('com.nxg.openclawproot/native');

  @override
  String get name => 'network';

  @override
  List<String> get commands => ['status'];

  @override
  List<String> get requiredPermissionNames => [
        'android.permission.ACCESS_NETWORK_STATE',
        'android.permission.ACCESS_WIFI_STATE',
      ];

  /// Network info does not require runtime permission on most API levels
  /// (ACCESS_NETWORK_STATE and ACCESS_WIFI_STATE are normal permissions).
  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    switch (command) {
      case 'network.status':
        return _status();
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown network command: $command',
        });
    }
  }

  Future<NodeFrame> _status() async {
    try {
      // Get IPs from native bridge (already available)
      final ips = await NativeBridge.getDeviceIps();

      // Get detailed network info from native
      final networkInfo =
          await _channel.invokeMethod('getNetworkInfo') as Map? ?? {};

      return NodeFrame.response('', payload: {
        'ips': ips,
        'wifi': {
          if (networkInfo['wifiSSID'] != null)
            'ssid': networkInfo['wifiSSID'],
          if (networkInfo['wifiSignalStrength'] != null)
            'signalStrength': networkInfo['wifiSignalStrength'],
          if (networkInfo['wifiFrequency'] != null)
            'frequencyMHz': networkInfo['wifiFrequency'],
          if (networkInfo['wifiSpeedMbps'] != null)
            'linkSpeedMbps': networkInfo['wifiSpeedMbps'],
          'connected': networkInfo['wifiConnected'] == true,
        },
        'cellular': {
          if (networkInfo['cellularCarrier'] != null)
            'carrier': networkInfo['cellularCarrier'],
          if (networkInfo['cellularNetworkType'] != null)
            'networkType': networkInfo['cellularNetworkType'],
          if (networkInfo['cellularSignalDbm'] != null)
            'signalDbm': networkInfo['cellularSignalDbm'],
          'available': networkInfo['cellularAvailable'] == true,
        },
        'activeNetwork': networkInfo['activeNetwork'] ?? 'unknown',
        'isMetered': networkInfo['isMetered'] == true,
        'hasInternet': networkInfo['hasInternet'] == true,
      });
    } catch (e) {
      // Fallback: return at least IPs
      return NodeFrame.response('', payload: {
        'ips': await NativeBridge.getDeviceIps(),
        'error': '$e',
      });
    }
  }
}
