import 'dart:async';
import 'package:flutter/services.dart';
import '../constants.dart';

class NativeBridge {
  static const _channel = MethodChannel(AppConstants.channelName);
  static const _eventChannel = EventChannel(AppConstants.eventChannelName);

  static const _defaultTimeout = Duration(seconds: 10);

  static String? _cachedFilesDir;
  static String? _cachedNativeLibDir;
  static String? _cachedArch;
  static String? _cachedProotPath;
  static bool _envReady = false;

  static Future<T> _invoke<T>(String method, [Map<String, dynamic>? args, Duration timeout = _defaultTimeout]) {
    return (_channel.invokeMethod<T>(method, args) as Future<T>).timeout(
      timeout,
      onTimeout: () => throw TimeoutException('MethodChannel $method timed out after $timeout'),
    );
  }

  static Future<void> ensureReady() async {
    if (_envReady) return;
    try {
      await _invoke('setupDirs');
      await _invoke('writeResolv');
      _envReady = true;
    } catch (_) {}
  }

  static Future<String> getProotPath() async {
    if (_cachedProotPath != null) return _cachedProotPath!;
    _cachedProotPath = await _invoke<String>('getProotPath');
    return _cachedProotPath!;
  }

  static Future<String> getArch() async {
    if (_cachedArch != null) return _cachedArch!;
    _cachedArch = await _invoke<String>('getArch');
    return _cachedArch!;
  }

  static Future<String> getFilesDir() async {
    if (_cachedFilesDir != null) return _cachedFilesDir!;
    _cachedFilesDir = await _invoke<String>('getFilesDir');
    return _cachedFilesDir!;
  }

  static Future<String> getNativeLibDir() async {
    if (_cachedNativeLibDir != null) return _cachedNativeLibDir!;
    _cachedNativeLibDir = await _invoke<String>('getNativeLibDir');
    return _cachedNativeLibDir!;
  }

  static void clearCache() {
    _cachedFilesDir = null;
    _cachedNativeLibDir = null;
    _cachedArch = null;
    _cachedProotPath = null;
    _envReady = false;
  }

  static Future<bool> isBootstrapComplete() async {
    return await _invoke<bool>('isBootstrapComplete');
  }

  static Future<Map<String, dynamic>> getBootstrapStatus() async {
    final result = await _invoke<Map>('getBootstrapStatus');
    return Map<String, dynamic>.from(result);
  }

  static Future<bool> extractRootfs(String tarPath, {String? sha256}) async {
    return await _invoke<bool>('extractRootfs', {
      'tarPath': tarPath,
      'sha256': sha256,
    }, const Duration(minutes: 15));
  }

  static Future<String> runInProot(String command, {int timeout = 900}) async {
    return await _invoke<String>('runInProot', {'command': command, 'timeout': timeout}, Duration(seconds: timeout + 10));
  }

  static Future<bool> startGateway() async {
    return await _invoke<bool>('startGateway', null, const Duration(seconds: 5));
  }

  static Future<bool> stopGateway() async {
    return await _invoke<bool>('stopGateway', null, const Duration(seconds: 5));
  }

  static Future<bool> isGatewayRunning() async {
    return await _invoke<bool>('isGatewayRunning', null, const Duration(seconds: 3));
  }

  static Future<bool> setupDirs() async {
    return await _invoke<bool>('setupDirs', null, const Duration(seconds: 30));
  }

  static Future<bool> installBionicBypass() async {
    return await _invoke<bool>('installBionicBypass', null, const Duration(seconds: 30));
  }

  static Future<bool> writeResolv() async {
    return await _invoke<bool>('writeResolv', null, const Duration(seconds: 10));
  }

  static Future<int> extractDebPackages() async {
    return await _invoke<int>('extractDebPackages', null, const Duration(minutes: 10));
  }

  static Future<bool> extractNodeTarball(String tarPath) async {
    return await _invoke<bool>('extractNodeTarball', {'tarPath': tarPath}, const Duration(minutes: 5));
  }

  static Future<bool> createBinWrappers(String packageName) async {
    return await _invoke<bool>('createBinWrappers', {'packageName': packageName}, const Duration(seconds: 30));
  }

  static Future<bool> startTerminalService() async {
    return await _invoke<bool>('startTerminalService', null, const Duration(seconds: 5));
  }

  static Future<bool> stopTerminalService() async {
    return await _invoke<bool>('stopTerminalService', null, const Duration(seconds: 5));
  }

  static Future<bool> isTerminalServiceRunning() async {
    return await _invoke<bool>('isTerminalServiceRunning', null, const Duration(seconds: 3));
  }

  static Future<bool> renewTerminalWakeLock() async {
    return await _invoke<bool>('renewTerminalWakeLock', null, const Duration(seconds: 3));
  }

  static Future<bool> startNodeService() async {
    return await _invoke<bool>('startNodeService', null, const Duration(seconds: 5));
  }

  static Future<bool> stopNodeService() async {
    return await _invoke<bool>('stopNodeService', null, const Duration(seconds: 5));
  }

  static Future<bool> isNodeServiceRunning() async {
    return await _invoke<bool>('isNodeServiceRunning', null, const Duration(seconds: 3));
  }

  static Future<Map<String, dynamic>> getBatteryStatus() async {
    final result = await _invoke<Map>('getBatteryStatus', null, const Duration(seconds: 5));
    return Map<String, dynamic>.from(result as Map? ?? {});
  }

  static Future<bool> updateNodeNotification(String text) async {
    return await _invoke<bool>('updateNodeNotification', {'text': text}, const Duration(seconds: 3));
  }

  static Future<bool> requestBatteryOptimization() async {
    return await _invoke<bool>('requestBatteryOptimization', null, const Duration(seconds: 10));
  }

  static Future<bool> isBatteryOptimized() async {
    return await _invoke<bool>('isBatteryOptimized', null, const Duration(seconds: 5));
  }

  static Future<bool> startSetupService() async {
    return await _invoke<bool>('startSetupService', null, const Duration(seconds: 5));
  }

  static Future<bool> updateSetupNotification(String text, {int progress = -1}) async {
    return await _invoke<bool>('updateSetupNotification', {'text': text, 'progress': progress}, const Duration(seconds: 3));
  }

  static Future<bool> stopSetupService() async {
    return await _invoke<bool>('stopSetupService', null, const Duration(seconds: 5));
  }

  static Future<bool> showUrlNotification(String url, {String title = 'URL Detected'}) async {
    return await _invoke<bool>('showUrlNotification', {'url': url, 'title': title}, const Duration(seconds: 3));
  }

  static Stream<String> get gatewayLogStream {
    return _eventChannel.receiveBroadcastStream().map((event) => event.toString());
  }

  static Future<String?> requestScreenCapture(int durationMs) async {
    return await _invoke<String?>('requestScreenCapture', {'durationMs': durationMs}, const Duration(minutes: 5));
  }

  static Future<bool> stopScreenCapture() async {
    return await _invoke<bool>('stopScreenCapture', null, const Duration(seconds: 5));
  }

  static Future<bool> requestStoragePermission() async {
    return await _invoke<bool>('requestStoragePermission', null, const Duration(seconds: 10));
  }

  static Future<bool> hasStoragePermission() async {
    return await _invoke<bool>('hasStoragePermission', null, const Duration(seconds: 3));
  }

  static Future<String> getExternalStoragePath() async {
    return await _invoke<String>('getExternalStoragePath', null, const Duration(seconds: 5));
  }

  static Future<String?> readRootfsFile(String path) async {
    return await _invoke<String?>('readRootfsFile', {'path': path}, const Duration(seconds: 10));
  }

  static Future<bool> writeRootfsFile(String path, String content) async {
    return await _invoke<bool>('writeRootfsFile', {'path': path, 'content': content}, const Duration(seconds: 10));
  }

  static Future<bool> startSshd({int port = 8022}) async {
    return await _invoke<bool>('startSshd', {'port': port}, const Duration(seconds: 5));
  }

  static Future<bool> stopSshd() async {
    return await _invoke<bool>('stopSshd', null, const Duration(seconds: 5));
  }

  static Future<bool> isSshdRunning() async {
    return await _invoke<bool>('isSshdRunning', null, const Duration(seconds: 3));
  }

  static Future<int> getSshdPort() async {
    return await _invoke<int>('getSshdPort', null, const Duration(seconds: 3));
  }

  static Future<List<String>> getDeviceIps() async {
    final result = await _invoke<List>('getDeviceIps', null, const Duration(seconds: 5));
    return List<String>.from(result);
  }

  static Future<bool> bringToForeground() async {
    return await _invoke<bool>('bringToForeground', null, const Duration(seconds: 3));
  }

  static Future<bool> setRootPassword(String password) async {
    return await _invoke<bool>('setRootPassword', {'password': password}, const Duration(seconds: 15));
  }
}
