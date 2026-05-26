import '../../models/node_frame.dart';
import '../../native/openclaw_native.dart';

abstract class CapabilityHandler {
  String get name;
  List<String> get commands;

  Future<NodeFrame> handle(String command, Map<String, dynamic> params);
  Future<bool> checkPermission();
  Future<bool> requestPermission();

  /// Override to return the Android permission string(s) this capability needs
  /// (e.g. "android.permission.CAMERA", "android.permission.ACCESS_FINE_LOCATION").
  /// Used by [handleWithPermission] to detect permanently denied state.
  List<String> get requiredPermissionNames => [];

  /// Optional cleanup. Override if the capability holds native resources.
  void dispose() {}

  /// Ensures permission is granted before handling. Returns error frame if denied.
  Future<NodeFrame> handleWithPermission(
      String command, Map<String, dynamic> params) async {
    if (!await checkPermission()) {
      // Check if any permission is permanently denied
      for (final permission in requiredPermissionNames) {
        if (await OpenClawNative.isPermissionPermanentlyDenied(permission)) {
          return NodeFrame.response('', error: {
            'code': 'PERMISSION_PERMANENTLY_DENIED',
            'message':
                '$name permission permanently denied. Enable it in Android Settings > Apps > OpenClaw > Permissions.',
          });
        }
      }

      final granted = await requestPermission();
      if (!granted) {
        return NodeFrame.response('', error: {
          'code': 'PERMISSION_DENIED',
          'message': '$name permission not granted',
        });
      }
    }
    return handle(command, params);
  }
}
