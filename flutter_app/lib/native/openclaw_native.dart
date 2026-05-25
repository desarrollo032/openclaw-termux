import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';

/// Native bridge to Android Kotlin code via MethodChannel.
///
/// Replaces the need for several Flutter plugins (shared_preferences,
/// url_launcher, permission_handler, etc.) by calling native Android APIs directly.
class OpenClawNative {
  OpenClawNative._();

  static const _channel = MethodChannel('com.nxg.openclawproot/native');

  // ──────────────────────────────────────────────
  // App Info
  // ──────────────────────────────────────────────

  /// Returns {packageName, versionName, versionCode}.
  static Future<Map<String, dynamic>> getAppInfo() async {
    final result = await _channel.invokeMethod('getAppInfo');
    return Map<String, dynamic>.from(result as Map);
  }

  // ──────────────────────────────────────────────
  // URL Launcher
  // ──────────────────────────────────────────────

  /// Opens a URL in the default browser via Intent.ACTION_VIEW.
  static Future<bool> openUrl(String url) async {
    final result = await _channel.invokeMethod('openUrl', {'url': url});
    return result as bool? ?? false;
  }

  // ──────────────────────────────────────────────
  // SharedPreferences (native Android)
  // ──────────────────────────────────────────────

  // ──────────────────────────────────────────────
  // SharedPreferences (native Android)
  // ──────────────────────────────────────────────

  static Future<String?> getString(String key) async {
    final result = await _channel
        .invokeMethod('getString', {'key': key});
    return result as String?;
  }

  static Future<bool> saveString(String key, String value) async {
    final result = await _channel
        .invokeMethod('saveString', {'key': key, 'value': value});
    return result as bool? ?? false;
  }

  static Future<bool> getBool(String key) async {
    final result = await _channel
        .invokeMethod('getBool', {'key': key});
    return result as bool? ?? false;
  }

  static Future<bool> saveBool(String key, bool value) async {
    final result = await _channel
        .invokeMethod('saveBool', {'key': key, 'value': value});
    return result as bool? ?? false;
  }

  static Future<int?> getInt(String key) async {
    final result = await _channel
        .invokeMethod('getInt', {'key': key});
    return result as int?;
  }

  static Future<bool> saveInt(String key, int value) async {
    final result = await _channel
        .invokeMethod('saveInt', {'key': key, 'value': value});
    return result as bool? ?? false;
  }

  static Future<bool> removeKey(String key) async {
    final result = await _channel
        .invokeMethod('removeKey', {'key': key});
    return result as bool? ?? false;
  }

  static Future<bool> clearPrefs() async {
    final result = await _channel.invokeMethod('clearPrefs');
    return result as bool? ?? false;
  }

  // ──────────────────────────────────────────────
  // Permissions
  // ──────────────────────────────────────────────

  /// Permission strings match the ones in Android's Manifest.permission
  /// (e.g. "android.permission.CAMERA", "android.permission.ACCESS_FINE_LOCATION").
  static Future<bool> checkPermission(String permission) async {
    final result = await _channel
        .invokeMethod('checkPermission', {'permission': permission});
    return result as bool? ?? false;
  }

  static Future<bool> requestPermission(String permission) async {
    final result = await _channel
        .invokeMethod('requestPermission', {'permission': permission});
    return result as bool? ?? false;
  }

  /// Returns true if the permission was denied and the user checked "Don't ask again"
  /// (or denied twice). On Android, this is determined by
  /// shouldShowRequestPermissionRationale returning false when permission is denied.
  static Future<bool> isPermissionPermanentlyDenied(String permission) async {
    final result = await _channel
        .invokeMethod('isPermissionPermanentlyDenied', {'permission': permission});
    return result as bool? ?? false;
  }

  // ──────────────────────────────────────────────
  // WebView (native Activity)
  // ──────────────────────────────────────────────

  /// Opens a URL in the native WebViewActivity.
  static Future<bool> openWebDashboard(String url) async {
    final result = await _channel.invokeMethod('openWebDashboard', {'url': url});
    return result as bool? ?? false;
  }

  // ──────────────────────────────────────────────
  // Camera — torch/flash
  // ──────────────────────────────────────────────

  /// Lists available cameras with their facing direction.
  static Future<List<Map<String, dynamic>>> getCameraList() async {
    final result = await _channel.invokeMethod('getCameraList');
    return (result as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  /// Toggle torch mode on/off.
  static Future<bool> toggleTorch(bool on) async {
    final result = await _channel.invokeMethod('toggleTorch', {'on': on});
    return result as bool? ?? false;
  }

  /// Check if torch is available.
  static Future<bool> isTorchAvailable() async {
    final result = await _channel.invokeMethod('isTorchAvailable');
    return result as bool? ?? false;
  }

  /// Take a photo via the system camera. Returns the file path or null if cancelled.
  /// The file is in the app cache directory and should be read with [readFile]
  /// and cleaned up with [deleteFile].
  static Future<String?> cameraSnap({String? facing}) async {
    final params = <String, dynamic>{};
    if (facing != null) params['facing'] = facing;
    final result = await _channel.invokeMethod('cameraSnap', params);
    return result as String?;
  }

  /// Record a video clip via the system camera. Returns the file path or null if cancelled.
  /// The file is in the app cache directory and should be read with [readFile]
  /// and cleaned up with [deleteFile].
  static Future<String?> cameraClip({int durationMs = 5000, String? facing}) async {
    final params = <String, dynamic>{'durationMs': durationMs};
    if (facing != null) params['facing'] = facing;
    final result = await _channel.invokeMethod('cameraClip', params);
    return result as String?;
  }

  /// Read a file from the given path and return raw bytes.
  static Future<Uint8List?> readFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  /// Delete a file at the given path.
  static Future<bool> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ──────────────────────────────────────────────
  // Location (via LocationManager)
  // ──────────────────────────────────────────────

  /// Check if location services are enabled.
  static Future<bool> isLocationServiceEnabled() async {
    final result = await _channel.invokeMethod('isLocationServiceEnabled');
    return result as bool? ?? false;
  }

  /// Get current location. Returns {latitude, longitude, accuracy, altitude, timestamp}.
  static Future<Map<String, dynamic>?> getCurrentLocation() async {
    try {
      final result = await _channel.invokeMethod('getCurrentLocation');
      return result as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  // ──────────────────────────────────────────────
  // BLE
  // ──────────────────────────────────────────────

  /// Scan for BLE devices. Returns list of {id, name, rssi}.
  static Future<List<Map<String, dynamic>>> bleScan({int timeoutMs = 3000}) async {
    final result = await _channel.invokeMethod('bleScan', {'timeoutMs': timeoutMs});
    return (result as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  /// Connect to a BLE device by MAC address.
  static Future<bool> bleConnect(String deviceId) async {
    final result = await _channel.invokeMethod('bleConnect', {'deviceId': deviceId});
    return result as bool? ?? false;
  }

  /// Disconnect from a BLE device. If deviceId is null, disconnect all.
  static Future<bool> bleDisconnect({String? deviceId}) async {
    final params = <String, dynamic>{};
    if (deviceId != null) params['deviceId'] = deviceId;
    final result = await _channel.invokeMethod('bleDisconnect', params);
    return result as bool? ?? false;
  }

  /// Write data to a BLE device. Accepts Uint8List for proper MethodChannel serialization.
  static Future<bool> bleWrite(String deviceId, Uint8List data) async {
    final result = await _channel.invokeMethod('bleWrite', {
      'deviceId': deviceId,
      'data': data,
    });
    return result as bool? ?? false;
  }

  /// Read data from a BLE device. Returns null on timeout.
  static Future<Uint8List?> bleRead(String deviceId, {int timeoutMs = 2000}) async {
    final result = await _channel.invokeMethod('bleRead', {
      'deviceId': deviceId,
      'timeoutMs': timeoutMs,
    });
    if (result == null) return null;
    return Uint8List.fromList((result as List<int>).cast<int>());
  }

  /// Discover services on a connected BLE device.
  static Future<List<Map<String, dynamic>>> bleListServices(String deviceId) async {
    final result = await _channel.invokeMethod('bleListServices', {'deviceId': deviceId});
    return (result as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  // ──────────────────────────────────────────────
  // USB Serial
  // ──────────────────────────────────────────────

  /// List USB serial devices. Returns list of {deviceId, name, vendorId, productId}.
  static Future<List<Map<String, dynamic>>> usbList() async {
    final result = await _channel.invokeMethod('usbList');
    return (result as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  /// Connect to a USB serial device.
  static Future<bool> usbConnect(int deviceId, {int baudRate = 115200}) async {
    final result = await _channel.invokeMethod('usbConnect', {
      'deviceId': deviceId,
      'baudRate': baudRate,
    });
    return result as bool? ?? false;
  }

  /// Disconnect from a USB device.
  static Future<bool> usbDisconnect({int? deviceId}) async {
    final params = <String, dynamic>{};
    if (deviceId != null) params['deviceId'] = deviceId;
    final result = await _channel.invokeMethod('usbDisconnect', params);
    return result as bool? ?? false;
  }

  /// Write data to a USB device. Accepts Uint8List for proper MethodChannel serialization.
  static Future<bool> usbWrite(int deviceId, Uint8List data) async {
    final result = await _channel.invokeMethod('usbWrite', {
      'deviceId': deviceId,
      'data': data,
    });
    return result as bool? ?? false;
  }

  /// Read data from a USB device. Returns null on timeout.
  static Future<Uint8List?> usbRead(int deviceId, {int timeoutMs = 2000}) async {
    final result = await _channel.invokeMethod('usbRead', {
      'deviceId': deviceId,
      'timeoutMs': timeoutMs,
    });
    if (result == null) return null;
    return Uint8List.fromList((result as List<int>).cast<int>());
  }
}
