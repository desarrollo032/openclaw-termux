import 'package:flutter/services.dart';
import '../../models/node_frame.dart';
import '../../native/openclaw_native.dart';
import 'capability_handler.dart';

class TelephonyCapability extends CapabilityHandler {
  static const _channel = MethodChannel('com.nxg.openclawproot/native');

  @override
  String get name => 'telephony';

  @override
  List<String> get commands => [
        'call',
        'sms',
        'contacts',
        'contacts-search',
        'network-type',
      ];

  @override
  List<String> get requiredPermissionNames => [
        'android.permission.READ_CONTACTS',
        'android.permission.READ_PHONE_STATE',
      ];

  @override
  Future<bool> checkPermission() async {
    final contacts = await OpenClawNative.checkPermission(
        'android.permission.READ_CONTACTS');
    final phoneState = await OpenClawNative.checkPermission(
        'android.permission.READ_PHONE_STATE');
    return contacts && phoneState;
  }

  @override
  Future<bool> requestPermission() async {
    await OpenClawNative.requestPermission('android.permission.READ_CONTACTS');
    await OpenClawNative.requestPermission('android.permission.READ_PHONE_STATE');
    return true;
  }

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    switch (command) {
      case 'telephony.call':
        return _call(params);
      case 'telephony.sms':
        return _sms(params);
      case 'telephony.contacts':
        return _contacts();
      case 'telephony.contacts-search':
        return _contactsSearch(params);
      case 'telephony.network-type':
        return _networkType();
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown telephony command: $command',
        });
    }
  }

  /// Open dialer with a phone number (no CALL_PHONE permission needed).
  Future<NodeFrame> _call(Map<String, dynamic> params) async {
    final number = params['number'] as String?;
    if (number == null) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_PARAM',
        'message': 'number is required',
      });
    }

    try {
      await _channel.invokeMethod('dialNumber', {'number': number});
      return NodeFrame.response('', payload: {
        'action': 'dial',
        'number': number,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'CALL_ERROR',
        'message': '$e',
      });
    }
  }

  /// Open SMS app with a phone number and optional body.
  Future<NodeFrame> _sms(Map<String, dynamic> params) async {
    final number = params['number'] as String?;
    final body = params['body'] as String? ?? '';

    if (number == null) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_PARAM',
        'message': 'number is required',
      });
    }

    try {
      await _channel.invokeMethod('sendSmsIntent', {
        'number': number,
        'body': body,
      });
      return NodeFrame.response('', payload: {
        'action': 'sms',
        'number': number,
        'body': body,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'SMS_ERROR',
        'message': '$e',
      });
    }
  }

  /// List contacts (requires READ_CONTACTS).
  Future<NodeFrame> _contacts() async {
    try {
      final result = await _channel.invokeMethod('getContacts') as List? ?? [];
      return NodeFrame.response('', payload: {
        'total': result.length,
        'contacts': result,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'CONTACTS_ERROR',
        'message': '$e',
      });
    }
  }

  /// Search contacts by query.
  Future<NodeFrame> _contactsSearch(Map<String, dynamic> params) async {
    final query = params['query'] as String? ?? '';
    if (query.isEmpty) return _contacts();

    try {
      final result = await _channel.invokeMethod('searchContacts', {
        'query': query,
      }) as List? ?? [];
      return NodeFrame.response('', payload: {
        'total': result.length,
        'query': query,
        'contacts': result,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'CONTACTS_ERROR',
        'message': '$e',
      });
    }
  }

  /// Get current cellular network type (4G, 5G, etc.).
  Future<NodeFrame> _networkType() async {
    try {
      final result = await _channel.invokeMethod('getCellularNetworkType') as String? ?? 'unknown';
      return NodeFrame.response('', payload: {
        'networkType': result,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'NETWORK_TYPE_ERROR',
        'message': '$e',
      });
    }
  }
}
