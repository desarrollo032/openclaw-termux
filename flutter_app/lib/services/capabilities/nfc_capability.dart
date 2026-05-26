import 'package:flutter/services.dart';
import '../../models/node_frame.dart';
import '../../native/openclaw_native.dart';
import 'capability_handler.dart';

class NfcCapability extends CapabilityHandler {
  static const _channel = MethodChannel('com.nxg.openclawproot/native');

  @override
  String get name => 'nfc';

  @override
  List<String> get commands => ['status', 'read', 'write', 'enable', 'disable'];

  @override
  List<String> get requiredPermissionNames => [
        'android.permission.NFC',
      ];

  @override
  Future<bool> checkPermission() async {
    return await OpenClawNative.checkPermission('android.permission.NFC');
  }

  @override
  Future<bool> requestPermission() async {
    return await OpenClawNative.requestPermission('android.permission.NFC');
  }

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    switch (command) {
      case 'nfc.status':
        return _status();
      case 'nfc.read':
        return _read();
      case 'nfc.write':
        return _write(params);
      case 'nfc.enable':
        return _enable(params);
      case 'nfc.disable':
        return _disable();
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown NFC command: $command',
        });
    }
  }

  Future<NodeFrame> _status() async {
    try {
      final result = await _channel.invokeMethod('getNfcStatus') as Map? ?? {};
      return NodeFrame.response('', payload: {
        'available': result['available'] ?? false,
        'enabled': result['enabled'] ?? false,
        'tagPresent': result['tagPresent'] ?? false,
      });
    } catch (e) {
      return NodeFrame.response('', payload: {
        'available': false,
        'enabled': false,
        'error': '$e',
      });
    }
  }

  Future<NodeFrame> _read() async {
    try {
      final result = await _channel.invokeMethod('nfcReadTag') as Map?;
      if (result == null) {
        return NodeFrame.response('', error: {
          'code': 'NO_TAG',
          'message': 'No NFC tag detected. Place the device near a tag.',
        });
      }
      return NodeFrame.response('', payload: result.cast<String, dynamic>());
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'NFC_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _write(Map<String, dynamic> params) async {
    final text = params['text'] as String?;
    if (text == null || text.isEmpty) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_PARAM',
        'message': 'text is required',
      });
    }

    try {
      await _channel.invokeMethod('nfcWriteTag', {'text': text});
      return NodeFrame.response('', payload: {'written': true});
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'NFC_WRITE_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _enable(Map<String, dynamic> params) async {
    try {
      await _channel.invokeMethod('enableNfc');
      return NodeFrame.response('', payload: {'enabled': true});
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'NFC_ENABLE_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _disable() async {
    try {
      await _channel.invokeMethod('disableNfc');
      return NodeFrame.response('', payload: {'enabled': false});
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'NFC_DISABLE_ERROR',
        'message': '$e',
      });
    }
  }
}
