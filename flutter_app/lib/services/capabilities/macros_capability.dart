import 'package:flutter/services.dart';
import '../../models/node_frame.dart';
import '../../native/openclaw_native.dart';
import 'capability_handler.dart';

/// Macros — high-level device automation.
///
/// Two tiers of actions:
///   1. **Intent-based** — open app, search phone, go to settings.
///      Work without AccessibilityService. No special setup required.
///   2. **Screen interaction** — tap, swipe, type, back, home, recents.
///      Require the OpenClaw AccessibilityService to be enabled
///      in System Settings > Accessibility > OpenClaw.
///
/// The AI should check `accessibility.enabled` first before issuing
/// screen-interaction commands, and guide the user to enable it if needed.
class MacrosCapability extends CapabilityHandler {
  static const _channel = MethodChannel('com.nxg.openclawproot/native');

  @override
  String get name => 'macros';

  @override
  List<String> get commands => [
        // Intent-based (no accessibility required)
        'open-app',
        'search',
        'open-settings',
        'open-url',
        // Screen interaction (accessibility required)
        'tap',
        'swipe',
        'type',
        'back',
        'home',
        'recents',
        'accessibility-status',
        'screenshot',
        'notification-list',
        'notification-click',
        'notification-clear',
      ];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    switch (command) {
      // Intent-based
      case 'macros.open-app':
        return _openApp(params);
      case 'macros.search':
        return _search(params);
      case 'macros.open-settings':
        return _openSettings(params);
      case 'macros.open-url':
        return _openUrl(params);
      // Accessibility-dependent
      case 'macros.tap':
        return _requireAccessibility(() => _tap(params));
      case 'macros.swipe':
        return _requireAccessibility(() => _swipe(params));
      case 'macros.type':
        return _requireAccessibility(() => _type(params));
      case 'macros.back':
        return _requireAccessibility(() => _back());
      case 'macros.home':
        return _requireAccessibility(() => _home());
      case 'macros.recents':
        return _requireAccessibility(() => _recents());
      case 'macros.accessibility-status':
        return _accessibilityStatus();
      case 'macros.screenshot':
        return _screenshot();
      case 'macros.notification-list':
        return _notificationList();
      case 'macros.notification-click':
        return _notificationClick(params);
      case 'macros.notification-clear':
        return _notificationClear(params);
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown macros command: $command',
        });
    }
  }

  /// Wrap an accessibility-dependent action with a check.
  Future<NodeFrame> _requireAccessibility(
      Future<NodeFrame> Function() action) async {
    final a11yEnabled = await _isAccessibilityServiceEnabled();
    if (!a11yEnabled) {
      return NodeFrame.response('', error: {
        'code': 'ACCESSIBILITY_REQUIRED',
        'message':
            'Screen interaction requires the OpenClaw Accessibility Service. '
            'Enable it in Settings > Accessibility > OpenClaw.',
        'actionRequired': 'enable_accessibility',
      });
    }
    return action();
  }

  Future<bool> _isAccessibilityServiceEnabled() async {
    try {
      final result =
          await _channel.invokeMethod('isAccessibilityServiceEnabled');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  // ─── Intent-based actions ──────────────────────

  /// Open an app by package name.
  Future<NodeFrame> _openApp(Map<String, dynamic> params) async {
    final package = params['package'] as String?;
    final activity = params['activity'] as String?;

    if (package == null) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_PARAM',
        'message': 'package is required (e.g. "com.whatsapp")',
      });
    }

    try {
      await _channel
          .invokeMethod('openApp', {'package': package, 'activity': activity ?? ''});
      return NodeFrame.response('', payload: {
        'opened': true,
        'package': package,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'OPEN_APP_ERROR',
        'message': '$e',
      });
    }
  }

  /// Search the phone (opens browser with web search).
  Future<NodeFrame> _search(Map<String, dynamic> params) async {
    final query = params['query'] as String?;
    if (query == null || query.isEmpty) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_PARAM',
        'message': 'query is required',
      });
    }

    try {
      await _channel.invokeMethod('webSearch', {'query': query});
      return NodeFrame.response('', payload: {
        'searched': true,
        'query': query,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'SEARCH_ERROR',
        'message': '$e',
      });
    }
  }

  /// Open a specific system settings panel.
  Future<NodeFrame> _openSettings(Map<String, dynamic> params) async {
    final panel = params['panel'] as String? ?? 'main'; // main, wifi, bluetooth, accessibility, etc.

    try {
      await _channel.invokeMethod('openSettingsPanel', {'panel': panel});
      return NodeFrame.response('', payload: {
        'opened': true,
        'panel': panel,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'SETTINGS_ERROR',
        'message': '$e',
      });
    }
  }

  /// Open a URL in the browser.
  Future<NodeFrame> _openUrl(Map<String, dynamic> params) async {
    final url = params['url'] as String?;
    if (url == null) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_PARAM',
        'message': 'url is required',
      });
    }

    try {
      await OpenClawNative.openUrl(url);
      return NodeFrame.response('', payload: {
        'opened': true,
        'url': url,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'URL_ERROR',
        'message': '$e',
      });
    }
  }

  // ─── Screen interaction (requires AccessibilityService) ──────

  /// Tap at screen coordinates.
  Future<NodeFrame> _tap(Map<String, dynamic> params) async {
    final x = params['x'] as num?;
    final y = params['y'] as num?;
    if (x == null || y == null) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_PARAM',
        'message': 'x and y coordinates are required',
      });
    }

    try {
      await _channel.invokeMethod('macroTap', {'x': x.toInt(), 'y': y.toInt()});
      return NodeFrame.response('', payload: {
        'action': 'tap',
        'x': x.toInt(),
        'y': y.toInt(),
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'MACRO_ERROR',
        'message': '$e',
      });
    }
  }

  /// Swipe from (x1,y1) to (x2,y2).
  Future<NodeFrame> _swipe(Map<String, dynamic> params) async {
    final x1 = params['x1'] as num?;
    final y1 = params['y1'] as num?;
    final x2 = params['x2'] as num?;
    final y2 = params['y2'] as num?;
    final durationMs = params['durationMs'] as int? ?? 300;

    if (x1 == null || y1 == null || x2 == null || y2 == null) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_PARAM',
        'message': 'x1, y1, x2, y2 are required',
      });
    }

    try {
      await _channel.invokeMethod('macroSwipe', {
        'x1': x1.toInt(),
        'y1': y1.toInt(),
        'x2': x2.toInt(),
        'y2': y2.toInt(),
        'durationMs': durationMs,
      });
      return NodeFrame.response('', payload: {
        'action': 'swipe',
        'from': {'x': x1.toInt(), 'y': y1.toInt()},
        'to': {'x': x2.toInt(), 'y': y2.toInt()},
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'MACRO_ERROR',
        'message': '$e',
      });
    }
  }

  /// Type text (like keyboard input).
  Future<NodeFrame> _type(Map<String, dynamic> params) async {
    final text = params['text'] as String?;
    if (text == null || text.isEmpty) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_PARAM',
        'message': 'text is required',
      });
    }

    try {
      await _channel.invokeMethod('macroType', {'text': text});
      return NodeFrame.response('', payload: {
        'action': 'type',
        'length': text.length,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'MACRO_ERROR',
        'message': '$e',
      });
    }
  }

  /// Navigate back.
  Future<NodeFrame> _back() async {
    try {
      await _channel.invokeMethod('macroBack');
      return NodeFrame.response('', payload: {'action': 'back'});
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'MACRO_ERROR',
        'message': '$e',
      });
    }
  }

  /// Go to home screen.
  Future<NodeFrame> _home() async {
    try {
      await _channel.invokeMethod('macroHome');
      return NodeFrame.response('', payload: {'action': 'home'});
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'MACRO_ERROR',
        'message': '$e',
      });
    }
  }

  /// Open recents/overview.
  Future<NodeFrame> _recents() async {
    try {
      await _channel.invokeMethod('macroRecents');
      return NodeFrame.response('', payload: {'action': 'recents'});
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'MACRO_ERROR',
        'message': '$e',
      });
    }
  }

  /// Check if the AccessibilityService is currently enabled and connected.
  Future<NodeFrame> _accessibilityStatus() async {
    try {
      final enabled = await _isAccessibilityServiceEnabled();
      return NodeFrame.response('', payload: {
        'enabled': enabled,
        'setupRequired': !enabled,
        'setupGuide':
            'Settings > Accessibility > Installed Apps > OpenClaw > Toggle on',
        'capabilities': [
          'tap',
          'swipe',
          'type',
          'back',
          'home',
          'recents',
          'screenshot',
          'notifications',
        ],
      });
    } catch (e) {
      return NodeFrame.response('', payload: {
        'enabled': false,
        'error': '$e',
      });
    }
  }

  /// Take a screenshot (if a11y is enabled, use it; otherwise try media projection).
  Future<NodeFrame> _screenshot() async {
    try {
      final result = await _channel.invokeMethod('takeScreenshot') as Map?;
      if (result == null) {
        return NodeFrame.response('', error: {
          'code': 'SCREENSHOT_FAILED',
          'message': 'Screenshot not available. Grant screen capture permission.',
        });
      }
      return NodeFrame.response('', payload: result.cast<String, dynamic>());
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'SCREENSHOT_ERROR',
        'message': '$e',
      });
    }
  }

  /// List current notifications.
  Future<NodeFrame> _notificationList() async {
    try {
      final notifications =
          await _channel.invokeMethod('listNotifications') as List? ?? [];
      return NodeFrame.response('', payload: {
        'notifications': notifications,
        'count': notifications.length,
      });
    } catch (e) {
      return NodeFrame.response('', payload: {
        'notifications': [],
        'count': 0,
        'error': '$e',
      });
    }
  }

  /// Click on a notification by key.
  Future<NodeFrame> _notificationClick(Map<String, dynamic> params) async {
    final key = params['key'] as String?;
    if (key == null) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_PARAM',
        'message': 'notification key is required',
      });
    }

    try {
      await _channel.invokeMethod('clickNotification', {'key': key});
      return NodeFrame.response('', payload: {'clicked': true, 'key': key});
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'NOTIFICATION_ERROR',
        'message': '$e',
      });
    }
  }

  /// Clear/dismiss a notification by key (or all if no key).
  Future<NodeFrame> _notificationClear(Map<String, dynamic> params) async {
    final key = params['key'] as String?;
    try {
      final map = <String, dynamic>{};
      if (key != null) map['key'] = key;
      await _channel.invokeMethod('clearNotification', map);
      return NodeFrame.response('', payload: {
        'cleared': true,
        if (key != null) 'key': key,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'NOTIFICATION_ERROR',
        'message': '$e',
      });
    }
  }
}
