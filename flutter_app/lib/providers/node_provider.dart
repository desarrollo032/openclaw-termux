import 'dart:async';
import 'package:flutter/widgets.dart';
import '../models/gateway_state.dart';
import '../native/openclaw_native.dart';
import '../models/node_state.dart';
import '../services/capabilities/camera_capability.dart';
import '../services/capabilities/canvas_capability.dart';
import '../services/capabilities/battery_capability.dart';
import '../services/capabilities/flash_capability.dart';
import '../services/capabilities/location_capability.dart';
import '../models/node_frame.dart';
import '../services/capabilities/audio_capability.dart';
import '../services/capabilities/bluetooth_capability.dart';
import '../services/capabilities/clipboard_capability.dart';
import '../services/capabilities/device_capability.dart';
import '../services/capabilities/display_capability.dart';
import '../services/capabilities/file_capability.dart';
import '../services/capabilities/hotspot_capability.dart';
import '../services/capabilities/macros_capability.dart';
import '../services/capabilities/network_capability.dart';
import '../services/capabilities/nfc_capability.dart';
import '../services/capabilities/privacy_filter.dart';
import '../services/capabilities/ringer_capability.dart';
import '../services/capabilities/tts_capability.dart';
import '../services/capabilities/screen_capability.dart';
import '../services/capabilities/sensor_capability.dart';
import '../services/capabilities/serial_capability.dart';
import '../services/capabilities/telephony_capability.dart';
import '../services/capabilities/vibration_capability.dart';
import '../services/native_bridge.dart';
import '../services/node_service.dart';
import '../services/preferences_service.dart';


class NodeProvider extends ChangeNotifier with WidgetsBindingObserver {
  final NodeService _nodeService = NodeService();
  StreamSubscription? _subscription;
  NodeState _state = const NodeState();
  GatewayState? _lastGatewayState;
  Timer? _watchdog;

  // Privacy Filter — wraps capability execution to protect user data
  final PrivacyFilter privacyFilter = PrivacyFilter();

  // Capabilities — lazily initialized only when node is enabled
  AudioCapability? _audioCapability;
  BluetoothCapability? _bluetoothCapability;
  CameraCapability? _cameraCapability;
  CanvasCapability? _canvasCapability;
  ClipboardCapability? _clipboardCapability;
  DeviceCapability? _deviceCapability;
  DisplayCapability? _displayCapability;
  FileCapability? _fileCapability;
  TtsCapability? _ttsCapability;
  HotspotCapability? _hotspotCapability;
  BatteryCapability? _batteryCapability;
  MacrosCapability? _macrosCapability;
  FlashCapability? _flashCapability;
  LocationCapability? _locationCapability;
  NetworkCapability? _networkCapability;
  NfcCapability? _nfcCapability;
  RingerCapability? _ringerCapability;
  ScreenCapability? _screenCapability;
  SensorCapability? _sensorCapability;
  SerialCapability? _serialCapability;
  TelephonyCapability? _telephonyCapability;
  VibrationCapability? _vibrationCapability;
  bool _capabilitiesReady = false;

  NodeState get state => _state;

  NodeProvider() {
    WidgetsBinding.instance.addObserver(this);
    _subscription = _nodeService.stateStream.listen((state) {
      _state = state;
      _updateServiceNotification(state);
      notifyListeners();
    });
    // Capabilities are created lazily inside _init() if node is enabled
    _init();
  }

  void _ensureCapabilities() {
    if (_capabilitiesReady) return;
    _capabilitiesReady = true;
    _audioCapability = AudioCapability();
    _bluetoothCapability = BluetoothCapability();
    _cameraCapability = CameraCapability();
    _canvasCapability = CanvasCapability();
    _clipboardCapability = ClipboardCapability();
    _deviceCapability = DeviceCapability();
    _displayCapability = DisplayCapability();
    _fileCapability = FileCapability();
    _ttsCapability = TtsCapability();
    _hotspotCapability = HotspotCapability();
    _batteryCapability = BatteryCapability();
    _macrosCapability = MacrosCapability();
    _flashCapability = FlashCapability();
    _locationCapability = LocationCapability();
    _networkCapability = NetworkCapability();
    _nfcCapability = NfcCapability();
    _ringerCapability = RingerCapability();
    _screenCapability = ScreenCapability();
    _sensorCapability = SensorCapability();
    _serialCapability = SerialCapability();
    _telephonyCapability = TelephonyCapability();
    _vibrationCapability = VibrationCapability();
    _registerCapabilities();
  }

  /// Keep the foreground notification text in sync with the node status.
  void _updateServiceNotification(NodeState state) {
    if (state.isDisabled) return;
    String text;
    switch (state.status) {
      case NodeStatus.paired:
        text = 'Node connected';
        break;
      case NodeStatus.connecting:
      case NodeStatus.challenging:
      case NodeStatus.pairing:
        text = 'Node connecting...';
        break;
      case NodeStatus.disconnected:
        text = 'Node reconnecting...';
        break;
      case NodeStatus.error:
        text = 'Node error — retrying';
        break;
      default:
        return;
    }
    try {
      NativeBridge.updateNodeNotification(text);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _nodeService.setAppInForeground(true);
      _onAppResumed();
    } else if (state == AppLifecycleState.paused) {
      _nodeService.setAppInForeground(false);
      _onAppPaused();
    }
  }

  /// App returned to foreground — force connection health check.
  /// Dart timers freeze while backgrounded, so the watchdog and ping
  /// timers won't have fired.  We must check and reconnect manually.
  Future<void> _onAppResumed() async {
    if (_state.isDisabled) return;

    // Ensure the foreground service is still alive
    try {
      final running = await NativeBridge.isNodeServiceRunning();
      if (!running) {
        await NativeBridge.startNodeService();
      }
    } catch (_) {}

    if (_state.isPaired && _nodeService.isConnectionStale) {
      // WebSocket went stale while in background — force reconnect
      await _nodeService.disconnect();
      await _nodeService.connect();
    } else if (!_state.isPaired && !_state.isConnecting) {
      // Connection dropped while in background
      await _nodeService.connect();
    }

    // Restart watchdog (may have been frozen)
    _startWatchdog();
  }

  /// App going to background — ensure the foreground service is running
  /// so Android keeps our process alive.
  Future<void> _onAppPaused() async {
    if (_state.isDisabled) return;

    try {
      final running = await NativeBridge.isNodeServiceRunning();
      if (!running) {
        await NativeBridge.startNodeService();
      }
    } catch (_) {}
  }

  /// Wrap a capability handler with the PrivacyFilter.
  ///
  /// 1. [beforeInvoke] checks if the command is allowed and sanitises params.
  /// 2. The real handler runs.
  /// 3. [afterInvoke] sanitises the response payload before sending to gateway.
  Future<NodeFrame> Function(String, Map<String, dynamic>) _wrapWithPrivacy(
    Future<NodeFrame> Function(String, Map<String, dynamic>) handler,
  ) {
    return (String command, Map<String, dynamic> params) async {
      // 1. Pre-filter — check if command is allowed, sanitise params
      final sanitizedParams = privacyFilter.beforeInvoke(command, params);
      if (sanitizedParams == null) {
        return privacyFilter.blockedFrame(command);
      }

      // 2. Run the real capability handler
      final result = await handler(command, sanitizedParams);

      // 3. Post-filter — sanitise the response payload
      if (result.payload != null) {
        final sanitized = privacyFilter.afterInvoke(command, result.payload);
        if (sanitized == null) {
          return privacyFilter.blockedFrame(command);
        }
        return NodeFrame.response(
          result.id ?? '',
          payload: sanitized,
        );
      }

      return result;
    };
  }

  void _registerCapabilities() {
    _nodeService.registerCapability(
      _audioCapability!.name,
      _audioCapability!.commands.map((c) => '${_audioCapability!.name}.$c').toList(),
      _wrapWithPrivacy((cmd, params) => _audioCapability!.handleWithPermission(cmd, params)),
    );
    _nodeService.registerCapability(
      _cameraCapability!.name,
      _cameraCapability!.commands.map((c) => '${_cameraCapability!.name}.$c').toList(),
      _wrapWithPrivacy((cmd, params) => _cameraCapability!.handleWithPermission(cmd, params)),
    );
    _nodeService.registerCapability(
      _canvasCapability!.name,
      _canvasCapability!.commands.map((c) => '${_canvasCapability!.name}.$c').toList(),
      _wrapWithPrivacy((cmd, params) => _canvasCapability!.handle(cmd, params)),
    );
    _nodeService.registerCapability(
      _ttsCapability!.name,
      _ttsCapability!.commands.map((c) => '${_ttsCapability!.name}.$c').toList(),
      _wrapWithPrivacy((cmd, params) => _ttsCapability!.handle(cmd, params)),
    );
    _nodeService.registerCapability(
      _deviceCapability!.name,
      _deviceCapability!.commands.map((c) => '${_deviceCapability!.name}.$c').toList(),
      _wrapWithPrivacy((cmd, params) => _deviceCapability!.handle(cmd, params)),
    );
    _nodeService.registerCapability(
      _batteryCapability!.name,
      _batteryCapability!.commands.map((c) => '${_batteryCapability!.name}.$c').toList(),
      _wrapWithPrivacy((cmd, params) => _batteryCapability!.handle(cmd, params)),
    );
    _nodeService.registerCapability(
      _locationCapability!.name,
      _locationCapability!.commands.map((c) => '${_locationCapability!.name}.$c').toList(),
      _wrapWithPrivacy((cmd, params) => _locationCapability!.handleWithPermission(cmd, params)),
    );
    _nodeService.registerCapability(
      _networkCapability!.name,
      _networkCapability!.commands.map((c) => '${_networkCapability!.name}.$c').toList(),
      _wrapWithPrivacy((cmd, params) => _networkCapability!.handleWithPermission(cmd, params)),
    );
    _nodeService.registerCapability(
      _screenCapability!.name,
      _screenCapability!.commands.map((c) => '${_screenCapability!.name}.$c').toList(),
      _wrapWithPrivacy((cmd, params) => _screenCapability!.handle(cmd, params)),
    );
    _nodeService.registerCapability(
      _bluetoothCapability!.name,
      _bluetoothCapability!.commands.map((c) => '${_bluetoothCapability!.name}.$c').toList(),
      _wrapWithPrivacy((cmd, params) => _bluetoothCapability!.handleWithPermission(cmd, params)),
    );
    _nodeService.registerCapability(
      _clipboardCapability!.name,
      _clipboardCapability!.commands.map((c) => '${_clipboardCapability!.name}.$c').toList(),
      _wrapWithPrivacy((cmd, params) => _clipboardCapability!.handle(cmd, params)),
    );
    _nodeService.registerCapability(
      _displayCapability!.name,
      _displayCapability!.commands.map((c) => '${_displayCapability!.name}.$c').toList(),
      _wrapWithPrivacy((cmd, params) => _displayCapability!.handle(cmd, params)),
    );
    _nodeService.registerCapability(
      _fileCapability!.name,
      _fileCapability!.commands.map((c) => '${_fileCapability!.name}.$c').toList(),
      _wrapWithPrivacy((cmd, params) => _fileCapability!.handle(cmd, params)),
    );
    _nodeService.registerCapability(
      _hotspotCapability!.name,
      _hotspotCapability!.commands.map((c) => '${_hotspotCapability!.name}.$c').toList(),
      _wrapWithPrivacy((cmd, params) => _hotspotCapability!.handle(cmd, params)),
    );
    _nodeService.registerCapability(
      _macrosCapability!.name,
      _macrosCapability!.commands.map((c) => '${_macrosCapability!.name}.$c').toList(),
      _wrapWithPrivacy((cmd, params) => _macrosCapability!.handle(cmd, params)),
    );
    _nodeService.registerCapability(
      _nfcCapability!.name,
      _nfcCapability!.commands.map((c) => '${_nfcCapability!.name}.$c').toList(),
      _wrapWithPrivacy((cmd, params) => _nfcCapability!.handleWithPermission(cmd, params)),
    );
    _nodeService.registerCapability(
      _ringerCapability!.name,
      _ringerCapability!.commands.map((c) => '${_ringerCapability!.name}.$c').toList(),
      _wrapWithPrivacy((cmd, params) => _ringerCapability!.handle(cmd, params)),
    );
    _nodeService.registerCapability(
      _telephonyCapability!.name,
      _telephonyCapability!.commands.map((c) => '${_telephonyCapability!.name}.$c').toList(),
      _wrapWithPrivacy((cmd, params) => _telephonyCapability!.handleWithPermission(cmd, params)),
    );
    _nodeService.registerCapability(
      _flashCapability!.name,
      _flashCapability!.commands.map((c) => '${_flashCapability!.name}.$c').toList(),
      _wrapWithPrivacy((cmd, params) => _flashCapability!.handleWithPermission(cmd, params)),
    );
    _nodeService.registerCapability(
      _vibrationCapability!.name,
      _vibrationCapability!.commands.map((c) => '${_vibrationCapability!.name}.$c').toList(),
      _wrapWithPrivacy((cmd, params) => _vibrationCapability!.handle(cmd, params)),
    );
    _nodeService.registerCapability(
      _sensorCapability!.name,
      _sensorCapability!.commands.map((c) => '${_sensorCapability!.name}.$c').toList(),
      _wrapWithPrivacy((cmd, params) => _sensorCapability!.handleWithPermission(cmd, params)),
    );
    _nodeService.registerCapability(
      _serialCapability!.name,
      _serialCapability!.commands.map((c) => '${_serialCapability!.name}.$c').toList(),
      _wrapWithPrivacy((cmd, params) => _serialCapability!.handleWithPermission(cmd, params)),
    );
  }

  Future<void> _init() async {
    await _nodeService.init();
    final prefs = PreferencesService();
    await prefs.init();

    // Restore privacy mode from preferences
    _applyPrivacyMode(prefs.privacyMode);

    if (prefs.nodeEnabled) {
      _ensureCapabilities();
      await _requestNodePermissions();
      await _requestBatteryOptimization();
      await NativeBridge.startNodeService();
      await _nodeService.connect();
      _startWatchdog();
    }
  }

  void onGatewayStateChanged(GatewayState gatewayState) {
    final wasRunning = _lastGatewayState?.isRunning ?? false;
    final isRunning = gatewayState.isRunning;
    _lastGatewayState = gatewayState;

    if (!wasRunning && isRunning && _state.isDisabled) {
      // Gateway just started - auto-enable node if previously enabled
      _checkAutoConnect();
    } else if (wasRunning && !isRunning && !_state.isDisabled) {
      // Gateway stopped - disconnect node and stop foreground service
      _stopWatchdog();
      _nodeService.disconnect();
      NativeBridge.stopNodeService();
    }
  }

  Future<void> _checkAutoConnect() async {
    final prefs = PreferencesService();
    await prefs.init();
    if (prefs.nodeEnabled) {
      await _requestNodePermissions();
      // Ensure foreground service is running before connecting
      try {
        final running = await NativeBridge.isNodeServiceRunning();
        if (!running) {
          await NativeBridge.startNodeService();
        }
      } catch (_) {}
      await _nodeService.connect();
      _startWatchdog();
    }
  }

  /// Request runtime permissions proactively so they are granted before
  /// the gateway sends invoke requests (which would otherwise be blocked).
  Future<void> _requestNodePermissions() async {
    await Future.wait([
      OpenClawNative.requestPermission('android.permission.CAMERA'),
      OpenClawNative.requestPermission('android.permission.ACCESS_FINE_LOCATION'),
      OpenClawNative.requestPermission('android.permission.BODY_SENSORS'),
      OpenClawNative.requestPermission('android.permission.BLUETOOTH_CONNECT'),
      OpenClawNative.requestPermission('android.permission.BLUETOOTH_SCAN'),
    ]);
  }

  /// Prompt user to disable battery optimization so Android doesn't kill
  /// the app process while the node is connected in the background.
  Future<void> _requestBatteryOptimization() async {
    try {
      final optimized = await NativeBridge.isBatteryOptimized();
      if (optimized) {
        await NativeBridge.requestBatteryOptimization();
      }
    } catch (_) {}
  }

  /// Periodic watchdog that detects stale/dropped connections and forces
  /// reconnect. Runs every 45s only while node is enabled. Handles two cases:
  /// 1. Node should be connected but isn't (dropped in background)
  /// 2. Node appears paired but WebSocket is stale (no data for 90s+)
  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(seconds: 45), (_) async {
      // If node was disabled after this timer was created, cancel it entirely
      if (_state.isDisabled) {
        _watchdog?.cancel();
        _watchdog = null;
        return;
      }

      // Also verify foreground service is still alive
      try {
        final running = await NativeBridge.isNodeServiceRunning();
        if (!running) {
          await NativeBridge.startNodeService();
        }
      } catch (_) {}

      if (!_state.isPaired && !_state.isConnecting) {
        // Connection dropped — reconnect
        _nodeService.connect();
      } else if (_state.isPaired && _nodeService.isConnectionStale) {
        // Connection appears alive but no data received — force reconnect
        _nodeService.disconnect().then((_) => _nodeService.connect());
      }
    });
  }

  void _stopWatchdog() {
    _watchdog?.cancel();
    _watchdog = null;
  }

  /// Set the privacy mode and persist it.
  Future<void> setPrivacyMode(PrivacyMode mode) async {
    privacyFilter.mode = mode;
    final prefs = PreferencesService();
    await prefs.init();
    prefs.privacyMode = mode.name;
    notifyListeners();
  }

  void _applyPrivacyMode(String name) {
    privacyFilter.mode = PrivacyMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => PrivacyMode.high,
    );
  }

  Future<void> enable() async {
    final prefs = PreferencesService();
    await prefs.init();
    prefs.nodeEnabled = true;
    _ensureCapabilities();
    await _requestNodePermissions();
    await _requestBatteryOptimization();
    await NativeBridge.startNodeService();
    await _nodeService.connect();
    _startWatchdog();
  }

  Future<void> disable() async {
    final prefs = PreferencesService();
    await prefs.init();
    prefs.nodeEnabled = false;
    _stopWatchdog();
    await _nodeService.disable();
    await NativeBridge.stopNodeService();
  }

  Future<void> connectRemote(String host, int port, {String? token}) async {
    final prefs = PreferencesService();
    await prefs.init();
    prefs.nodeGatewayHost = host;
    prefs.nodeGatewayPort = port;
    prefs.nodeGatewayToken = token;
    prefs.nodeEnabled = true;
    _ensureCapabilities();
    // Clear cached token so it re-reads on next connect
    _nodeService.clearCachedToken();
    await _requestNodePermissions();
    await _requestBatteryOptimization();
    await NativeBridge.startNodeService();
    await _nodeService.connect(host: host, port: port);
    _startWatchdog();
  }

  Future<void> reconnect() async {
    await _nodeService.disconnect();
    await _nodeService.connect();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopWatchdog();
    _subscription?.cancel();
    _nodeService.dispose();
    // Only dispose capabilities that were actually created
    _audioCapability?.dispose();
    _bluetoothCapability?.dispose();
    _cameraCapability?.dispose();
    _clipboardCapability?.dispose();
    _ttsCapability?.dispose();
    _deviceCapability?.dispose();
    _displayCapability?.dispose();
    _fileCapability?.dispose();
    _flashCapability?.dispose();
    _hotspotCapability?.dispose();
    _macrosCapability?.dispose();
    _nfcCapability?.dispose();
    _ringerCapability?.dispose();
    _serialCapability?.dispose();
    _telephonyCapability?.dispose();
    NativeBridge.stopNodeService();
    super.dispose();
  }
}
