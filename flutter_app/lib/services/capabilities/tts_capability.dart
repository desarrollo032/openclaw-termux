import 'package:flutter/services.dart';
import '../../models/node_frame.dart';
import 'capability_handler.dart';

class TtsCapability extends CapabilityHandler {
  static const _channel = MethodChannel('com.nxg.openclawproot/native');

  @override
  String get name => 'tts';

  @override
  List<String> get commands => ['speak', 'list-voices', 'stop'];

  /// Android TTS does not require runtime permissions.
  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    switch (command) {
      case 'tts.speak':
        return _speak(params);
      case 'tts.list-voices':
        return _listVoices();
      case 'tts.stop':
        return _stop();
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown TTS command: $command',
        });
    }
  }

  Future<NodeFrame> _speak(Map<String, dynamic> params) async {
    final text = params['text'] as String?;
    if (text == null || text.isEmpty) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_PARAM',
        'message': 'text is required',
      });
    }

    try {
      await _channel.invokeMethod('ttsSpeak', {
        'text': text,
        if (params['language'] != null) 'language': params['language'],
        if (params['pitch'] != null) 'pitch': (params['pitch'] as num).toDouble(),
        if (params['speechRate'] != null) 'speechRate': (params['speechRate'] as num).toDouble(),
      });

      return NodeFrame.response('', payload: {
        'status': 'speaking',
        'text': text,
        'language': params['language'] ?? 'default',
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'TTS_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _listVoices() async {
    try {
      final result = await _channel.invokeMethod('ttsListVoices');
      final voices = (result as List?)?.cast<Map<String, dynamic>>() ?? [];
      return NodeFrame.response('', payload: {
        'voices': voices,
        'count': voices.length,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'TTS_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _stop() async {
    try {
      await _channel.invokeMethod('ttsStop');
      return NodeFrame.response('', payload: {
        'status': 'stopped',
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'TTS_ERROR',
        'message': '$e',
      });
    }
  }
}
