import 'dart:convert';
import 'dart:ui' as ui;
import '../../models/node_frame.dart';
import '../../native/openclaw_native.dart';
import 'capability_handler.dart';

class CameraCapability extends CapabilityHandler {
  @override
  String get name => 'camera';

  @override
  List<String> get commands => ['snap', 'clip', 'list'];

  @override
  List<String> get requiredPermissionNames => ['android.permission.CAMERA'];

  @override
  Future<bool> checkPermission() async {
    return await OpenClawNative.checkPermission('android.permission.CAMERA');
  }

  @override
  Future<bool> requestPermission() async {
    return await OpenClawNative.requestPermission('android.permission.CAMERA');
  }

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    switch (command) {
      case 'camera.snap':
        return _snap(params);
      case 'camera.clip':
        return _clip(params);
      case 'camera.list':
        return _list();
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown camera command: $command',
        });
    }
  }

  Future<NodeFrame> _list() async {
    try {
      final cameraList = await OpenClawNative.getCameraList();
      return NodeFrame.response('', payload: {
        'cameras': cameraList,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'CAMERA_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _snap(Map<String, dynamic> params) async {
    try {
      final facing = params['facing'] as String?;
      final filePath = await OpenClawNative.cameraSnap(facing: facing);

      if (filePath == null) {
        return NodeFrame.response('', error: {
          'code': 'CAMERA_CANCELLED',
          'message': 'Photo capture was cancelled',
        });
      }

      final bytes = await OpenClawNative.readFile(filePath);
      if (bytes == null) {
        return NodeFrame.response('', error: {
          'code': 'CAMERA_ERROR',
          'message': 'Failed to read photo file',
        });
      }

      // Clean up the temp file
      await OpenClawNative.deleteFile(filePath);

      final b64 = base64Encode(bytes);

      // Get image dimensions from raw bytes
      int width = 0;
      int height = 0;
      try {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        width = frame.image.width;
        height = frame.image.height;
        frame.image.dispose();
      } catch (_) {}

      return NodeFrame.response('', payload: {
        'base64': b64,
        'format': 'jpg',
        'width': width,
        'height': height,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'CAMERA_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _clip(Map<String, dynamic> params) async {
    try {
      final durationMs = params['durationMs'] as int? ?? 5000;
      final filePath = await OpenClawNative.cameraClip(durationMs: durationMs);

      if (filePath == null) {
        return NodeFrame.response('', error: {
          'code': 'CAMERA_CANCELLED',
          'message': 'Video capture was cancelled',
        });
      }

      final bytes = await OpenClawNative.readFile(filePath);
      if (bytes == null) {
        return NodeFrame.response('', error: {
          'code': 'CAMERA_ERROR',
          'message': 'Failed to read video file',
        });
      }

      // Clean up the temp file (keep for large files that would fail in memory)
      await OpenClawNative.deleteFile(filePath);

      final b64 = base64Encode(bytes);
      return NodeFrame.response('', payload: {
        'base64': b64,
        'format': 'mp4',
        'durationMs': durationMs,
        'hasAudio': false,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'CAMERA_ERROR',
        'message': '$e',
      });
    }
  }

  @override
  void dispose() {}
}
