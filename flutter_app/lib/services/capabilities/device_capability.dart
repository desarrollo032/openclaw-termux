import 'package:flutter/services.dart';
import '../../models/node_frame.dart';
import '../../native/openclaw_native.dart';
import 'capability_handler.dart';

class DeviceCapability extends CapabilityHandler {
  static const _channel = MethodChannel('com.nxg.openclawproot/native');

  @override
  String get name => 'device';

  @override
  List<String> get commands => ['info'];

  /// Device info is non-personal and does not require runtime permissions
  /// (no IMEI, no phone number, no contacts are exposed).
  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    switch (command) {
      case 'device.info':
        return _info();
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown device command: $command',
        });
    }
  }

  Future<NodeFrame> _info() async {
    try {
      // App info from existing method
      final appInfo = await OpenClawNative.getAppInfo();

      // Detailed device info from native
      final deviceInfo =
          await _channel.invokeMethod('getDeviceInfo') as Map? ?? {};

      return NodeFrame.response('', payload: {
        // Device hardware
        'model': deviceInfo['model'] ?? 'unknown',
        'manufacturer': deviceInfo['manufacturer'] ?? 'unknown',
        'brand': deviceInfo['brand'] ?? 'unknown',
        'deviceName': deviceInfo['deviceName'] ?? 'unknown',
        'hardware': deviceInfo['hardware'] ?? 'unknown',

        // OS
        'androidVersion': deviceInfo['androidVersion'] ?? 'unknown',
        'sdkInt': deviceInfo['sdkInt'] ?? 0,
        'buildId': deviceInfo['buildId'] ?? 'unknown',

        // Screen
        'screenWidthPx': deviceInfo['screenWidthPx'] ?? 0,
        'screenHeightPx': deviceInfo['screenHeightPx'] ?? 0,
        'screenDensity': deviceInfo['screenDensity'] ?? 1.0,
        'screenDensityDpi': deviceInfo['screenDensityDpi'] ?? 0,

        // Memory & Storage
        'totalRamMb': deviceInfo['totalRamMb'] ?? 0,
        'availableRamMb': deviceInfo['availableRamMb'] ?? 0,
        'internalStorageTotalMb': deviceInfo['internalStorageTotalMb'] ?? 0,
        'internalStorageFreeMb': deviceInfo['internalStorageFreeMb'] ?? 0,

        // App (from existing getAppInfo)
        'appPackageName': appInfo['packageName'] ?? '',
        'appVersionName': appInfo['versionName'] ?? '',
        'appVersionCode': appInfo['versionCode'] ?? 0,

        // Architecture
        'supportedAbis': (deviceInfo['supportedAbis'] as List?)
                ?.cast<String>() ??
            ['unknown'],
      });
    } catch (e) {
      // Fallback: return at least app info
      try {
        final appInfo = await OpenClawNative.getAppInfo();
        return NodeFrame.response('', payload: {
          'appPackageName': appInfo['packageName'] ?? '',
          'appVersionName': appInfo['versionName'] ?? '',
          'appVersionCode': appInfo['versionCode'] ?? 0,
          'error': '$e',
        });
      } catch (_) {
        return NodeFrame.response('', error: {
          'code': 'DEVICE_INFO_ERROR',
          'message': '$e',
        });
      }
    }
  }
}
