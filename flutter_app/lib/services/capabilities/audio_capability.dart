import 'dart:convert';
import 'package:flutter/services.dart';
import '../../models/node_frame.dart';
import '../../native/openclaw_native.dart';
import 'capability_handler.dart';

class AudioCapability extends CapabilityHandler {
  static const _channel = MethodChannel('com.nxg.openclawproot/native');

  @override
  String get name => 'audio';

  @override
  List<String> get commands => ['record', 'volume', 'speaker'];

  @override
  List<String> get requiredPermissionNames => [
        'android.permission.RECORD_AUDIO',
      ];

  @override
  Future<bool> checkPermission() async {
    return await OpenClawNative.checkPermission(
        'android.permission.RECORD_AUDIO');
  }

  @override
  Future<bool> requestPermission() async {
    return await OpenClawNative.requestPermission(
        'android.permission.RECORD_AUDIO');
  }

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    switch (command) {
      case 'audio.record':
        return _record(params);
      case 'audio.volume':
        return _volume(params);
      case 'audio.speaker':
        return _speaker(params);
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown audio command: $command',
        });
    }
  }

  Future<NodeFrame> _record(Map<String, dynamic> params) async {
    final durationMs = params['durationMs'] as int? ?? 5000;

    try {
      final result =
          await _channel.invokeMethod('recordAudio', {'durationMs': durationMs});

      if (result == null) {
        return NodeFrame.response('', error: {
          'code': 'RECORDING_FAILED',
          'message': 'Audio recording returned no data',
        });
      }

      final filePath = result as String;

      // Read the recorded file — always clean up even on error
      Uint8List? bytes;
      try {
        bytes = await OpenClawNative.readFile(filePath);
      } finally {
        OpenClawNative.deleteFile(filePath);
      }

      if (bytes == null || bytes.isEmpty) {
        return NodeFrame.response('', error: {
          'code': 'READ_ERROR',
          'message': 'Could not read recorded audio file',
        });
      }

      return NodeFrame.response('', payload: {
        'mimeType': 'audio/aac',
        'data': base64Encode(bytes),
        'durationMs': durationMs,
        'sizeBytes': bytes.length,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'RECORDING_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _volume(Map<String, dynamic> params) async {
    final setVolume = params['set'] as num?;

    try {
      if (setVolume != null) {
        // Set volume (0.0 — 1.0)
        await _channel
            .invokeMethod('setAudioVolume', {'level': setVolume.toDouble()});
      }

      final current = await _channel.invokeMethod('getAudioVolume');
      return NodeFrame.response('', payload: {
        'volume': current ?? 0.5,
        'min': 0.0,
        'max': 1.0,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'VOLUME_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _speaker(Map<String, dynamic> params) async {
    final on = params['on'] as bool?;

    try {
      if (on != null) {
        await _channel
            .invokeMethod('setSpeakerphone', {'on': on});
      }

      final currentStatus =
          await _channel.invokeMethod('isSpeakerphoneOn');
      return NodeFrame.response('', payload: {
        'speakerphoneOn': currentStatus == true,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'SPEAKER_ERROR',
        'message': '$e',
      });
    }
  }
}
