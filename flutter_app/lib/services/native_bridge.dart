import 'dart:async';
import 'package:flutter/services.dart';
import '../constants.dart';

class NativeBridge {
  static const _channel = MethodChannel(AppConstants.channelName);
  static const _eventChannel = EventChannel(AppConstants.eventChannelName);
  static const _defaultTimeout = Duration(seconds: 10);

  // Cache for immutable OS-level values (never change during app lifetime).
  // Avoids redundant MethodChannel IPC (~5-15ms per call).
  static String? _cachedFilesDir;
  static String? _cachedNativeLibDir;
  static String? _cachedArch;
  static String? _cachedProotPath;
  static bool _envReady = false;

  static Future<T?> _invokeNullable<T>(
    String method, [
    Map<String, dynamic>? args,
    Duration timeout = _defaultTimeout,
  ]) {
    return _channel.invokeMethod<T>(method, args).timeout(
          timeout,
          onTimeout: () => throw TimeoutException(
            'MethodChannel $method timed out after $timeout',
          ),
        );
  }

  static Future<T> _invokeRequired<T>(
    String method, [
    Map<String, dynamic>? args,
    Duration timeout = _defaultTimeout,
  ]) async {
    final result = await _invokeNullable<T>(method, args, timeout);
    if (result == null) {
      throw PlatformException(
        code: 'NULL_RESULT',
        message: 'MethodChannel $method returned null',
      );
    }
    return result;
  }

  /// Ensure environment directories and resolv.conf exist.
  /// Cached: only performs real work once (one-shot). Android may clear
  /// filesDir during APK updates but that is handled by the Kotlin services
  /// on each gateway/terminal start anyway.
  static Future<void> ensureReady() async {
    if (_envReady) return;
    try {
      await _invokeRequired<bool>(
        'setupDirs',
        null,
        const Duration(seconds: 30),
      );
      await _invokeRequired<bool>('writeResolv');
      _envReady = true;
    } catch (_) {
      // Non-fatal: Kotlin services also call setupDirectories on start
    }
  }

  static Future<String> getProotPath() async {
    if (_cachedProotPath != null) return _cachedProotPath!;
    _cachedProotPath = await _invokeRequired<String>('getProotPath');
    return _cachedProotPath!;
  }

  static Future<String> getArch() async {
    if (_cachedArch != null) return _cachedArch!;
    _cachedArch = await _invokeRequired<String>('getArch');
    return _cachedArch!;
  }

  static Future<String> getFilesDir() async {
    if (_cachedFilesDir != null) return _cachedFilesDir!;
    _cachedFilesDir = await _invokeRequired<String>('getFilesDir');
    return _cachedFilesDir!;
  }

  static Future<String> getNativeLibDir() async {
    if (_cachedNativeLibDir != null) return _cachedNativeLibDir!;
    _cachedNativeLibDir = await _invokeRequired<String>('getNativeLibDir');
    return _cachedNativeLibDir!;
  }

  /// Clear all caches (useful for testing or after reconfiguration).
  static void clearCache() {
    _cachedFilesDir = null;
    _cachedNativeLibDir = null;
    _cachedArch = null;
    _cachedProotPath = null;
    _envReady = false;
  }

  static Future<bool> isBootstrapComplete() async {
    return _invokeRequired<bool>('isBootstrapComplete');
  }

  static Future<Map<String, dynamic>> getBootstrapStatus() async {
    final result = await _invokeRequired<Map>('getBootstrapStatus');
    return Map<String, dynamic>.from(result);
  }

  static Future<bool> extractRootfs(String tarPath, {String? sha256}) async {
    return _invokeRequired<bool>('extractRootfs', {
      'tarPath': tarPath,
      'sha256': sha256,
    }, const Duration(minutes: 15));
  }

  static Future<String> runInProot(String command, {int timeout = 900}) async {
    return _invokeRequired<String>(
      'runInProot',
      {'command': command, 'timeout': timeout},
      Duration(seconds: timeout + 10),
    );
  }

  static Future<bool> startGateway() async {
    return _invokeRequired<bool>('startGateway', null, const Duration(seconds: 5));
  }

  static Future<bool> stopGateway() async {
    return _invokeRequired<bool>('stopGateway', null, const Duration(seconds: 5));
  }

  static Future<bool> isGatewayRunning() async {
    return _invokeRequired<bool>('isGatewayRunning', null, const Duration(seconds: 3));
  }

  static Future<bool> setupDirs() async {
    return _invokeRequired<bool>('setupDirs', null, const Duration(seconds: 30));
  }

  static Future<bool> installBionicBypass() async {
    return _invokeRequired<bool>(
      'installBionicBypass',
      null,
      const Duration(seconds: 30),
    );
  }

  static Future<bool> writeResolv() async {
    return _invokeRequired<bool>('writeResolv');
  }

  static Future<int> extractDebPackages() async {
    return _invokeRequired<int>(
      'extractDebPackages',
      null,
      const Duration(minutes: 10),
    );
  }

  static Future<bool> extractNodeTarball(String tarPath) async {
    return _invokeRequired<bool>(
      'extractNodeTarball',
      {'tarPath': tarPath},
      const Duration(minutes: 5),
    );
  }

  static Future<bool> createBinWrappers(String packageName) async {
    return _invokeRequired<bool>(
      'createBinWrappers',
      {'packageName': packageName},
      const Duration(seconds: 30),
    );
  }

  static Future<bool> startTerminalService() async {
    return _invokeRequired<bool>(
      'startTerminalService',
      null,
      const Duration(seconds: 5),
    );
  }

  static Future<bool> stopTerminalService() async {
    return _invokeRequired<bool>(
      'stopTerminalService',
      null,
      const Duration(seconds: 5),
    );
  }

  static Future<bool> isTerminalServiceRunning() async {
    return _invokeRequired<bool>(
      'isTerminalServiceRunning',
      null,
      const Duration(seconds: 3),
    );
  }

  /// Renew the terminal wake lock with a fresh 30-second timeout.
  /// Called on PTY output to keep CPU awake while user is actively typing.
  static Future<bool> renewTerminalWakeLock() async {
    return _invokeRequired<bool>(
      'renewTerminalWakeLock',
      null,
      const Duration(seconds: 3),
    );
  }

  static Future<bool> startNodeService() async {
    return _invokeRequired<bool>('startNodeService', null, const Duration(seconds: 5));
  }

  static Future<bool> stopNodeService() async {
    return _invokeRequired<bool>('stopNodeService', null, const Duration(seconds: 5));
  }

  static Future<bool> isNodeServiceRunning() async {
    return _invokeRequired<bool>('isNodeServiceRunning', null, const Duration(seconds: 3));
  }

  static Future<Map<String, dynamic>> getBatteryStatus() async {
    final result = await _invokeRequired<Map>(
      'getBatteryStatus',
      null,
      const Duration(seconds: 5),
    );
    return Map<String, dynamic>.from(result);
  }

  static Future<bool> updateNodeNotification(String text) async {
    return _invokeRequired<bool>(
      'updateNodeNotification',
      {'text': text},
      const Duration(seconds: 3),
    );
  }

  static Future<bool> requestBatteryOptimization() async {
    return _invokeRequired<bool>(
      'requestBatteryOptimization',
      null,
      const Duration(seconds: 10),
    );
  }

  static Future<bool> isBatteryOptimized() async {
    return _invokeRequired<bool>(
      'isBatteryOptimized',
      null,
      const Duration(seconds: 5),
    );
  }

  static Future<bool> startSetupService() async {
    return _invokeRequired<bool>('startSetupService', null, const Duration(seconds: 5));
  }

  static Future<bool> updateSetupNotification(String text, {int progress = -1}) async {
    return _invokeRequired<bool>(
      'updateSetupNotification',
      {'text': text, 'progress': progress},
      const Duration(seconds: 3),
    );
  }

  static Future<bool> stopSetupService() async {
    return _invokeRequired<bool>('stopSetupService', null, const Duration(seconds: 5));
  }

  static Future<bool> showUrlNotification(String url, {String title = 'URL Detected'}) async {
    return _invokeRequired<bool>(
      'showUrlNotification',
      {'url': url, 'title': title},
      const Duration(seconds: 3),
    );
  }

  static Stream<String> get gatewayLogStream {
    return _eventChannel.receiveBroadcastStream().map((event) => event.toString());
  }

  static Future<String?> requestScreenCapture(int durationMs) async {
    return _invokeNullable<String>(
      'requestScreenCapture',
      {'durationMs': durationMs},
      const Duration(minutes: 5),
    );
  }

  static Future<bool> stopScreenCapture() async {
    return _invokeRequired<bool>('stopScreenCapture', null, const Duration(seconds: 5));
  }

  static Future<bool> requestStoragePermission() async {
    return _invokeRequired<bool>(
      'requestStoragePermission',
      null,
      const Duration(seconds: 10),
    );
  }

  static Future<bool> hasStoragePermission() async {
    return _invokeRequired<bool>('hasStoragePermission', null, const Duration(seconds: 3));
  }

  static Future<String> getExternalStoragePath() async {
    return _invokeRequired<String>(
      'getExternalStoragePath',
      null,
      const Duration(seconds: 5),
    );
  }

  static Future<String?> readRootfsFile(String path) async {
    return _invokeNullable<String>(
      'readRootfsFile',
      {'path': path},
      const Duration(seconds: 10),
    );
  }

  static Future<bool> writeRootfsFile(String path, String content) async {
    return _invokeRequired<bool>(
      'writeRootfsFile',
      {'path': path, 'content': content},
      const Duration(seconds: 10),
    );
  }

  // SSH Service
  static Future<bool> startSshd({int port = 8022}) async {
    return _invokeRequired<bool>(
      'startSshd',
      {'port': port},
      const Duration(seconds: 5),
    );
  }

  static Future<bool> stopSshd() async {
    return _invokeRequired<bool>('stopSshd', null, const Duration(seconds: 5));
  }

  static Future<bool> isSshdRunning() async {
    return _invokeRequired<bool>('isSshdRunning', null, const Duration(seconds: 3));
  }

  static Future<int> getSshdPort() async {
    return _invokeRequired<int>('getSshdPort', null, const Duration(seconds: 3));
  }

  static Future<List<String>> getDeviceIps() async {
    final result = await _invokeRequired<List>(
      'getDeviceIps',
      null,
      const Duration(seconds: 5),
    );
    return List<String>.from(result);
  }

  static Future<bool> bringToForeground() async {
    return _invokeRequired<bool>('bringToForeground', null, const Duration(seconds: 3));
  }

  static Future<bool> setRootPassword(String password) async {
    return _invokeRequired<bool>(
      'setRootPassword',
      {'password': password},
      const Duration(seconds: 15),
    );
  }
}
