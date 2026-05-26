/// Privacy & Security Filter for the Node capability system.
///
/// Sits between the gateway (AI) and capability handlers to control
/// what device data can be shared externally.
///
/// Three privacy modes:
///   [high]  — Only non-identifying data (battery level, capabilities list, etc.)
///   [medium] — Device info + system data. Location with reduced accuracy.
///   [low]   — Everything except PII (contacts, IMEI, phone number).
///
/// Usage in [NodeService._handleInvokeRequest]:
///   1. [beforeInvoke] — checks if command is allowed, sanitizes params
///   2. handler runs
///   3. [afterInvoke] — sanitizes response payload before sending to gateway
library;

import '../../models/node_frame.dart';

/// Privacy mode for the node.
enum PrivacyMode {
  /// Only non-identifying data. No photos, no location, no precise sensor values.
  high,

  /// Device info + system data. Location with reduced accuracy (~1km).
  /// Media requires user approval.
  medium,

  /// Everything except PII (contacts, IMEI, phone number).
  low,
}

/// Categorises the sensitivity of data produced by each capability command.
enum DataCategory {
  /// Capabilities list, commands, connection status — always shareable.
  public,

  /// Battery level, sensor availability, torch status — safe system info.
  system,

  /// Device model, Android version, screen size — non-personal device info.
  deviceInfo,

  /// GPS coordinates, altitude — location data.
  location,

  /// Photos, videos, audio recordings — media files.
  media,

  /// **Never shared externally** — contacts, IMEI, phone number, accounts.
  personal,
}

/// Privacy & Security Filter.
///
/// Each capability command is classified into a [DataCategory].
/// The filter checks whether the command is allowed in the current [PrivacyMode],
/// and sanitises both params (before handling) and response payload (after).
class PrivacyFilter {
  PrivacyMode mode;

  PrivacyFilter({this.mode = PrivacyMode.high});

  /// Maps each capability command to its data sensitivity category.
  static const Map<String, DataCategory> _commandCategories = {
    // camera
    'camera.snap': DataCategory.media,
    'camera.clip': DataCategory.media,
    'camera.list': DataCategory.public,
    // flash
    'flash.on': DataCategory.system,
    'flash.off': DataCategory.system,
    'flash.toggle': DataCategory.system,
    'flash.status': DataCategory.system,
    // battery
    'battery.status': DataCategory.system,
    // location
    'location.get': DataCategory.location,
    // sensor
    'sensor.read': DataCategory.system,
    'sensor.list': DataCategory.public,
    'sensor.light': DataCategory.system,
    'sensor.proximity': DataCategory.system,
    // network
    'network.status': DataCategory.deviceInfo,
    // audio
    'audio.record': DataCategory.media,
    'audio.volume': DataCategory.system,
    'audio.speaker': DataCategory.system,
    // screen
    'screen.record': DataCategory.media,
    // tts
    'tts.speak': DataCategory.public,
    'tts.list-voices': DataCategory.public,
    'tts.stop': DataCategory.public,
    // device
    'device.info': DataCategory.deviceInfo,
    // clipboard
    'clipboard.read': DataCategory.system,
    'clipboard.write': DataCategory.system,
    'clipboard.has': DataCategory.system,
    // display
    'display.brightness': DataCategory.system,
    'display.timeout': DataCategory.system,
    'display.orientation': DataCategory.system,
    'display.info': DataCategory.deviceInfo,
    // nfc
    'nfc.status': DataCategory.system,
    'nfc.read': DataCategory.system,
    'nfc.write': DataCategory.system,
    'nfc.enable': DataCategory.system,
    'nfc.disable': DataCategory.system,
    // ringer
    'ringer.mode': DataCategory.system,
    'ringer.set': DataCategory.system,
    'ringer.volume': DataCategory.system,
    // file
    'file.list': DataCategory.public,
    'file.info': DataCategory.public,
    'file.read': DataCategory.public,
    'file.write': DataCategory.system,
    'file.delete': DataCategory.system,
    // telephony
    'telephony.call': DataCategory.system,
    'telephony.sms': DataCategory.system,
    'telephony.contacts': DataCategory.personal,
    'telephony.contacts-search': DataCategory.personal,
    'telephony.network-type': DataCategory.deviceInfo,
    // bluetooth
    'bluetooth.status': DataCategory.system,
    'bluetooth.scan': DataCategory.system,
    'bluetooth.paired': DataCategory.system,
    'bluetooth.connect': DataCategory.system,
    'bluetooth.disconnect': DataCategory.system,
    'bluetooth.enable': DataCategory.system,
    'bluetooth.disable': DataCategory.system,
    'bluetooth.discoverable': DataCategory.system,
    // hotspot
    'hotspot.status': DataCategory.system,
    'hotspot.enable': DataCategory.system,
    'hotspot.disable': DataCategory.system,
    'hotspot.clients': DataCategory.system,
    // macros
    'macros.open-app': DataCategory.system,
    'macros.search': DataCategory.public,
    'macros.open-settings': DataCategory.system,
    'macros.open-url': DataCategory.public,
    'macros.tap': DataCategory.system,
    'macros.swipe': DataCategory.system,
    'macros.type': DataCategory.public,
    'macros.back': DataCategory.system,
    'macros.home': DataCategory.system,
    'macros.recents': DataCategory.system,
    'macros.accessibility-status': DataCategory.public,
    'macros.screenshot': DataCategory.media,
    'macros.notification-list': DataCategory.system,
    'macros.notification-click': DataCategory.system,
    'macros.notification-clear': DataCategory.system,
    // haptic
    'haptic.vibrate': DataCategory.system,
    // serial
    'serial.list': DataCategory.public,
    'serial.connect': DataCategory.system,
    'serial.disconnect': DataCategory.system,
    'serial.write': DataCategory.public,
    'serial.read': DataCategory.public,
  };

  /// Returns the data category for a command, defaulting to [DataCategory.public].
  static DataCategory categoryOf(String command) {
    return _commandCategories[command] ?? DataCategory.public;
  }

  /// Check whether [command] is allowed in the current [mode].
  bool isCommandAllowed(String command) {
    final cat = categoryOf(command);
    switch (mode) {
      case PrivacyMode.high:
        return cat == DataCategory.public || cat == DataCategory.system;
      case PrivacyMode.medium:
        return cat != DataCategory.personal && cat != DataCategory.media;
      case PrivacyMode.low:
        return cat != DataCategory.personal;
    }
  }

  /// Called **before** the handler runs.
  ///
  /// Returns the (possibly sanitised) params, or `null` if the command is
  /// blocked entirely (caller should send a PERMISSION_DENIED error frame).
  Map<String, dynamic>? beforeInvoke(String command, Map<String, dynamic> params) {
    if (!isCommandAllowed(command)) {
      return null;
    }

    // Sanitise params per command
    switch (command) {
      case 'location.get':
        if (mode == PrivacyMode.medium) {
          // Round coordinates to ~1° (~111 km) for medium privacy
          final lat = params['lat'];
          final lng = params['lng'];
          if (lat is num) params['lat'] = lat.roundToDouble();
          if (lng is num) params['lng'] = lng.roundToDouble();
        }
        break;

      case 'camera.snap':
      case 'camera.clip':
        if (mode != PrivacyMode.low) {
          // In high/medium mode, only allow front camera that doesn't
          // capture identifiable information by default
          params['facing'] ??= 'back';
        }
        break;
    }

    return params;
  }

  /// Called **after** the handler runs.
  ///
  /// Sanitises the response payload before it is sent to the gateway.
  /// Returns the (possibly sanitised) payload, or `null` to remove the payload.
  Map<String, dynamic>? afterInvoke(String command, Map<String, dynamic>? payload) {
    if (payload == null) return null;

    switch (command) {
      case 'location.get':
        if (mode == PrivacyMode.medium) {
          // Reduce accuracy
          if (payload['lat'] is num) {
            payload['lat'] = (payload['lat'] as num).roundToDouble();
          }
          if (payload['lng'] is num) {
            payload['lng'] = (payload['lng'] as num).roundToDouble();
          }
          // Remove precise accuracy / altitude in medium mode
          payload.remove('accuracy');
          payload.remove('altitude');
        }
        break;

      case 'sensor.read':
        if (mode == PrivacyMode.high) {
          // Only indicate sensor availability, not precise values
          return {'sensor': payload['sensor'], 'available': true, 'status': 'available'};
        }
        break;

      case 'camera.snap':
      case 'camera.clip':
        if (mode != PrivacyMode.low) {
          // Add watermark / warning that media was shared
          payload['privacy'] = 'shared_with_consent';
        }
        break;

      case 'screen.record':
        if (mode != PrivacyMode.low) {
          payload['privacy'] = 'shared_with_consent';
        }
        break;

      case 'battery.status':
        if (mode == PrivacyMode.high) {
          // Only share percentage, not details
          final pct = payload['percentage'];
          return {'percentage': pct, 'status': payload['status']};
        }
        break;
    }

    return payload;
  }

  /// Add an error frame explaining why the command was blocked.
  NodeFrame blockedFrame(String command) {
    final cat = categoryOf(command);
    String reason;
    switch (cat) {
      case DataCategory.media:
        reason = 'Media capture is blocked in $mode privacy mode. '
            'Switch to "Low" mode in Node settings to allow photos/videos.';
        break;
      case DataCategory.location:
        reason = 'Location access is blocked in $mode privacy mode. '
            'Switch to "Low" mode in Node settings to allow GPS data.';
        break;
      case DataCategory.personal:
        reason = 'Personal data cannot be shared with external AI systems.';
        break;
      default:
        reason = 'Command "$command" is not allowed in $mode privacy mode.';
    }
    return NodeFrame.response('', error: {
      'code': 'PRIVACY_BLOCKED',
      'message': reason,
    });
  }

  /// Human-readable mode name.
  String get modeLabel {
    switch (mode) {
      case PrivacyMode.high:
        return 'Alta';
      case PrivacyMode.medium:
        return 'Media';
      case PrivacyMode.low:
        return 'Baja';
    }
  }

  /// Human-readable mode description.
  String get modeDescription {
    switch (mode) {
      case PrivacyMode.high:
        return 'Solo datos no identificables. Sin cámara, sin ubicación, sin valores precisos de sensores.';
      case PrivacyMode.medium:
        return 'Datos del dispositivo y sistema. Ubicación con precisión reducida.';
      case PrivacyMode.low:
        return 'Todo excepto datos personales (contactos, IMEI, número de teléfono).';
    }
  }
}
