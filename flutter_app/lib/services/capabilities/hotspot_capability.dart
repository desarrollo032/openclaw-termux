import 'package:flutter/services.dart';
import '../../models/node_frame.dart';
import 'capability_handler.dart';

class HotspotCapability extends CapabilityHandler {
  static const _channel = MethodChannel('com.nxg.openclawproot/native');

  @override
  String get name => 'hotspot';

  @override
  List<String> get commands => [
        'status',
        'enable',
        'disable',
        'clients',
      ];

  /// Hotspot control requires CHANGE_WIFI_STATE (normal, auto-granted)
  /// On Android 10+ (Q) the system UI shows a confirmation dialog.
  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    switch (command) {
      case 'hotspot.status':
        return _status();
      case 'hotspot.enable':
        return _enable(params);
      case 'hotspot.disable':
        return _disable();
      case 'hotspot.clients':
        return _clients();
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown hotspot command: $command',
        });
    }
  }

  Future<NodeFrame> _status() async {
    try {
      final result = await _channel.invokeMethod('getHotspotStatus') as Map? ?? {};
      return NodeFrame.response('', payload: result.cast<String, dynamic>());
    } catch (e) {
      return NodeFrame.response('', payload: {
        'enabled': false,
        'error': '$e',
      });
    }
  }

  Future<NodeFrame> _enable(Map<String, dynamic> params) async {
    final ssid = params['ssid'] as String?;
    final password = params['password'] as String?;
    try {
      final map = <String, dynamic>{};
      if (ssid != null) map['ssid'] = ssid;
      if (password != null) map['password'] = password;
      await _channel.invokeMethod('enableHotspot', map);
      return NodeFrame.response('', payload: {
        'enabled': true,
        if (ssid != null) 'ssid': ssid,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'HOTSPOT_ENABLE_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _disable() async {
    try {
      await _channel.invokeMethod('disableHotspot');
      return NodeFrame.response('', payload: {'enabled': false});
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'HOTSPOT_DISABLE_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _clients() async {
    try {
      final clients = await _channel.invokeMethod('getHotspotClients') as List? ?? [];
      return NodeFrame.response('', payload: {
        'clients': clients,
        'count': clients.length,
      });
    } catch (e) {
      return NodeFrame.response('', payload: {
        'clients': [],
        'count': 0,
        'error': '$e',
      });
    }
  }
}
