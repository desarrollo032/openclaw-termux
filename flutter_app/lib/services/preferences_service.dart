import '../native/openclaw_native.dart';

class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  static const _keyAutoStart = 'auto_start_gateway';
  static const _keySetupComplete = 'setup_complete';
  static const _keyFirstRun = 'first_run';
  static const _keyDashboardUrl = 'dashboard_url';
  static const _keyNodeEnabled = 'node_enabled';
  static const _keyNodeDeviceToken = 'node_device_token';
  static const _keyNodeGatewayHost = 'node_gateway_host';
  static const _keyNodeGatewayPort = 'node_gateway_port';
  static const _keyNodePublicKey = 'node_ed25519_public';
  static const _keyNodeGatewayToken = 'node_gateway_token';
  static const _keyLastAppVersion = 'last_app_version';
  static const _keyPrivacyMode = 'privacy_mode';

  // Cached values for zero-latency access
  bool _autoStartGateway = false;
  bool _setupComplete = false;
  bool _isFirstRun = true;
  String? _dashboardUrl;
  bool _nodeEnabled = false;
  String? _nodeDeviceToken;
  String? _nodeGatewayHost;
  int? _nodeGatewayPort;
  String? _nodePublicKey;
  String? _nodeGatewayToken;
  String? _lastAppVersion;
  String _privacyMode = 'high';
  
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    
    _autoStartGateway = await OpenClawNative.getBool(_keyAutoStart);
    _setupComplete = await OpenClawNative.getBool(_keySetupComplete);
    _isFirstRun = await OpenClawNative.getBool(_keyFirstRun);
    _dashboardUrl = await OpenClawNative.getString(_keyDashboardUrl);
    _nodeEnabled = await OpenClawNative.getBool(_keyNodeEnabled);
    _nodeDeviceToken = await OpenClawNative.getString(_keyNodeDeviceToken);
    _nodeGatewayHost = await OpenClawNative.getString(_keyNodeGatewayHost);
    _nodeGatewayPort = await OpenClawNative.getInt(_keyNodeGatewayPort);
    _nodePublicKey = await OpenClawNative.getString(_keyNodePublicKey);
    _nodeGatewayToken = await OpenClawNative.getString(_keyNodeGatewayToken);
    _lastAppVersion = await OpenClawNative.getString(_keyLastAppVersion);
    _privacyMode = (await OpenClawNative.getString(_keyPrivacyMode)) ?? 'high';
    
    _initialized = true;
  }

  bool get autoStartGateway => _autoStartGateway;
  set autoStartGateway(bool value) {
    if (_autoStartGateway == value) return;
    _autoStartGateway = value;
    OpenClawNative.saveBool(_keyAutoStart, value);
  }

  bool get setupComplete => _setupComplete;
  set setupComplete(bool value) {
    if (_setupComplete == value) return;
    _setupComplete = value;
    OpenClawNative.saveBool(_keySetupComplete, value);
  }

  bool get isFirstRun => _isFirstRun;
  set isFirstRun(bool value) {
    if (_isFirstRun == value) return;
    _isFirstRun = value;
    OpenClawNative.saveBool(_keyFirstRun, value);
  }

  String? get dashboardUrl => _dashboardUrl;
  set dashboardUrl(String? value) {
    if (_dashboardUrl == value) return;
    _dashboardUrl = value;
    if (value != null) {
      OpenClawNative.saveString(_keyDashboardUrl, value);
    } else {
      OpenClawNative.removeKey(_keyDashboardUrl);
    }
  }

  bool get nodeEnabled => _nodeEnabled;
  set nodeEnabled(bool value) {
    if (_nodeEnabled == value) return;
    _nodeEnabled = value;
    OpenClawNative.saveBool(_keyNodeEnabled, value);
  }

  String? get nodeDeviceToken => _nodeDeviceToken;
  set nodeDeviceToken(String? value) {
    if (_nodeDeviceToken == value) return;
    _nodeDeviceToken = value;
    if (value != null) {
      OpenClawNative.saveString(_keyNodeDeviceToken, value);
    } else {
      OpenClawNative.removeKey(_keyNodeDeviceToken);
    }
  }

  String? get nodeGatewayHost => _nodeGatewayHost;
  set nodeGatewayHost(String? value) {
    if (_nodeGatewayHost == value) return;
    _nodeGatewayHost = value;
    if (value != null) {
      OpenClawNative.saveString(_keyNodeGatewayHost, value);
    } else {
      OpenClawNative.removeKey(_keyNodeGatewayHost);
    }
  }

  String? get nodePublicKey => _nodePublicKey;

  String? get nodeGatewayToken => _nodeGatewayToken;
  set nodeGatewayToken(String? value) {
    if (_nodeGatewayToken == value) return;
    _nodeGatewayToken = value;
    if (value != null && value.isNotEmpty) {
      OpenClawNative.saveString(_keyNodeGatewayToken, value);
    } else {
      OpenClawNative.removeKey(_keyNodeGatewayToken);
    }
  }

  String? get lastAppVersion => _lastAppVersion;
  set lastAppVersion(String? value) {
    if (_lastAppVersion == value) return;
    _lastAppVersion = value;
    if (value != null) {
      OpenClawNative.saveString(_keyLastAppVersion, value);
    } else {
      OpenClawNative.removeKey(_keyLastAppVersion);
    }
  }

  String get privacyMode => _privacyMode;
  set privacyMode(String value) {
    if (_privacyMode == value) return;
    _privacyMode = value;
    OpenClawNative.saveString(_keyPrivacyMode, value);
  }

  int? get nodeGatewayPort => _nodeGatewayPort;
  set nodeGatewayPort(int? value) {
    if (_nodeGatewayPort == value) return;
    _nodeGatewayPort = value;
    if (value != null) {
      OpenClawNative.saveInt(_keyNodeGatewayPort, value);
    } else {
      OpenClawNative.removeKey(_keyNodeGatewayPort);
    }
  }
}
