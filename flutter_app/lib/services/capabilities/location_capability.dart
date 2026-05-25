import '../../models/node_frame.dart';
import '../../native/openclaw_native.dart';
import 'capability_handler.dart';

class LocationCapability extends CapabilityHandler {
  @override
  String get name => 'location';

  @override
  List<String> get commands => ['get'];

  @override
  List<String> get requiredPermissionNames => ['android.permission.ACCESS_FINE_LOCATION'];

  @override
  Future<bool> checkPermission() async {
    return await OpenClawNative.checkPermission('android.permission.ACCESS_FINE_LOCATION');
  }

  @override
  Future<bool> requestPermission() async {
    return await OpenClawNative.requestPermission('android.permission.ACCESS_FINE_LOCATION');
  }

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    switch (command) {
      case 'location.get':
        return _getLocation(params);
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown location command: $command',
        });
    }
  }

  Future<NodeFrame> _getLocation(Map<String, dynamic> params) async {
    try {
      final enabled = await OpenClawNative.isLocationServiceEnabled();
      if (!enabled) {
        return NodeFrame.response('', error: {
          'code': 'LOCATION_DISABLED',
          'message': 'Location services are disabled',
        });
      }

      final location = await OpenClawNative.getCurrentLocation();
      if (location == null) {
        return NodeFrame.response('', error: {
          'code': 'LOCATION_TIMEOUT',
          'message': 'Could not get location within 10 seconds and no cached position available',
        });
      }

      return NodeFrame.response('', payload: {
        'lat': location['latitude'],
        'lng': location['longitude'],
        'accuracy': location['accuracy'],
        'altitude': location['altitude'],
        'timestamp': DateTime.fromMillisecondsSinceEpoch(
          (location['timestamp'] as int? ?? 0) ~/ 1,
          isUtc: true,
        ).toIso8601String(),
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'LOCATION_ERROR',
        'message': '$e',
      });
    }
  }
}
