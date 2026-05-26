import 'package:flutter/services.dart';
import '../../models/node_frame.dart';
import 'capability_handler.dart';

class ClipboardCapability extends CapabilityHandler {
  static const _channel = MethodChannel('com.nxg.openclawproot/native');

  @override
  String get name => 'clipboard';

  @override
  List<String> get commands => ['read', 'write', 'has'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    switch (command) {
      case 'clipboard.read':
        return _read();
      case 'clipboard.write':
        return _write(params);
      case 'clipboard.has':
        return _has();
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown clipboard command: $command',
        });
    }
  }

  Future<NodeFrame> _read() async {
    try {
      final result = await _channel.invokeMethod('getClipboard');
      return NodeFrame.response('', payload: {
        'text': result ?? '',
        'hasContent': result != null && (result as String).isNotEmpty,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'CLIPBOARD_ERROR',
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
      await _channel.invokeMethod('copyToClipboard', {'text': text});
      return NodeFrame.response('', payload: {'written': true, 'length': text.length});
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'CLIPBOARD_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _has() async {
    try {
      final result = await _channel.invokeMethod('getClipboard');
      return NodeFrame.response('', payload: {
        'hasContent': result != null && (result as String).isNotEmpty,
      });
    } catch (e) {
      return NodeFrame.response('', payload: {'hasContent': false});
    }
  }
}
