import '../../models/node_frame.dart';
import '../../native/openclaw_native.dart';
import 'capability_handler.dart';

class FlashCapability extends CapabilityHandler {
  bool _torchOn = false;

  @override
  String get name => 'flash';

  @override
  List<String> get commands => ['on', 'off', 'toggle', 'status'];

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
      case 'flash.on':
        return _setTorch(true);
      case 'flash.off':
        return _setTorch(false);
      case 'flash.toggle':
        return _setTorch(!_torchOn);
      case 'flash.status':
        return NodeFrame.response('', payload: {'on': _torchOn});
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown flash command: $command',
        });
    }
  }

  Future<NodeFrame> _setTorch(bool on) async {
    try {
      final success = await OpenClawNative.toggleTorch(on);
      if (!success) {
        return NodeFrame.response('', error: {
          'code': 'FLASH_ERROR',
          'message': 'Torch not available or failed to toggle',
        });
      }
      _torchOn = on;
      return NodeFrame.response('', payload: {'on': _torchOn});
    } catch (e) {
      _torchOn = false;
      return NodeFrame.response('', error: {
        'code': 'FLASH_ERROR',
        'message': '$e',
      });
    }
  }

  void dispose() {}
}
