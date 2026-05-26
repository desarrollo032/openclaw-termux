import 'dart:convert';
import 'dart:io';
import '../../models/node_frame.dart';
import 'capability_handler.dart';

class FileCapability extends CapabilityHandler {
  @override
  String get name => 'file';

  @override
  List<String> get commands => ['list', 'info', 'read', 'write', 'delete'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    switch (command) {
      case 'file.list':
        return _list(params);
      case 'file.info':
        return _info(params);
      case 'file.read':
        return _read(params);
      case 'file.write':
        return _write(params);
      case 'file.delete':
        return _delete(params);
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown file command: $command',
        });
    }
  }

  static final String _sandboxPath = Directory.systemTemp.path;

  /// Resolve path within the app's sandbox directory.
  /// Manually resolves `..` segments to prevent traversal
  /// without filesystem I/O (works for non-existent paths too).
  String _resolvePath(String path) {
    final clean = path.replaceAll('~', '');
    final relative = clean.startsWith('/') ? clean.substring(1) : clean;

    // Split on / or \ and resolve .. segments manually
    final parts = '$_sandboxPath/$relative'.split(RegExp(r'[/\\]'));
    final resolved = <String>[];
    for (final part in parts) {
      if (part == '.' || part.isEmpty) continue;
      if (part == '..') {
        if (resolved.isNotEmpty) resolved.removeLast();
      } else {
        resolved.add(part);
      }
    }

    final result = resolved.join('/');
    return result.startsWith(_sandboxPath) ? result : _sandboxPath;
  }

  Future<NodeFrame> _list(Map<String, dynamic> params) async {
    final path = params['path'] as String? ?? '.';
    try {
      final dir = Directory(_resolvePath(path));
      if (!await dir.exists()) {
        return NodeFrame.response('', error: {
          'code': 'NOT_FOUND',
          'message': 'Directory not found: $path',
        });
      }

      final entities = await dir.list().toList();
      final items = <Map<String, dynamic>>[];
      for (final entity in entities) {
        final stat = await entity.stat();
        items.add({
          'name': entity.uri.pathSegments.isNotEmpty
              ? entity.uri.pathSegments.last
              : entity.path,
          'path': entity.path,
          'type': entity is File ? 'file' : 'directory',
          'size': stat.size,
          'modified': stat.modified.millisecondsSinceEpoch,
          'permissions': stat.modeString(),
        });
      }

      // Sort: directories first, then by name
      items.sort((a, b) {
        if (a['type'] != b['type']) {
          return a['type'] == 'directory' ? -1 : 1;
        }
        return (a['name'] as String).compareTo(b['name'] as String);
      });

      return NodeFrame.response('', payload: {
        'path': path,
        'totalItems': items.length,
        'items': items,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'LIST_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _info(Map<String, dynamic> params) async {
    final path = params['path'] as String?;
    if (path == null) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_PARAM',
        'message': 'path is required',
      });
    }

    try {
      final file = File(_resolvePath(path));
      if (!await file.exists()) {
        return NodeFrame.response('', error: {
          'code': 'NOT_FOUND',
          'message': 'File not found: $path',
        });
      }

      final stat = await file.stat();
      return NodeFrame.response('', payload: {
        'name': file.uri.pathSegments.isNotEmpty
            ? file.uri.pathSegments.last
            : file.path,
        'path': file.path,
        'type': 'file',
        'size': stat.size,
        'modified': stat.modified.millisecondsSinceEpoch,
        'accessed': stat.accessed.millisecondsSinceEpoch,
        'permissions': stat.modeString(),
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'INFO_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _read(Map<String, dynamic> params) async {
    final path = params['path'] as String?;
    if (path == null) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_PARAM',
        'message': 'path is required',
      });
    }

    final encoding = params['encoding'] as String? ?? 'utf8';
    final maxSize = params['maxSizeKb'] as int? ?? 1024; // 1MB default max

    try {
      final file = File(_resolvePath(path));
      if (!await file.exists()) {
        return NodeFrame.response('', error: {
          'code': 'NOT_FOUND',
          'message': 'File not found: $path',
        });
      }

      final stat = await file.stat();
      if (stat.size > maxSize * 1024) {
        return NodeFrame.response('', error: {
          'code': 'FILE_TOO_LARGE',
          'message': 'File size (${stat.size} bytes) exceeds max allowed (${maxSize}KB)',
        });
      }

      if (encoding == 'base64') {
        final bytes = await file.readAsBytes();
        return NodeFrame.response('', payload: {
          'path': file.path,
          'size': bytes.length,
          'content': base64Encode(bytes),
          'encoding': 'base64',
        });
      } else {
        final content = await file.readAsString();
        return NodeFrame.response('', payload: {
          'path': file.path,
          'size': content.length,
          'content': content,
          'encoding': 'utf8',
        });
      }
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'READ_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _write(Map<String, dynamic> params) async {
    final path = params['path'] as String?;
    final content = params['content'] as String?;
    final encoding = params['encoding'] as String? ?? 'utf8';

    if (path == null || content == null) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_PARAM',
        'message': 'path and content are required',
      });
    }

    try {
      final file = File(_resolvePath(path));
      // Create parent directories if they don't exist
      await file.parent.create(recursive: true);

      if (encoding == 'base64') {
        final bytes = base64Decode(content);
        await file.writeAsBytes(bytes);
      } else {
        await file.writeAsString(content);
      }

      final stat = await file.stat();
      return NodeFrame.response('', payload: {
        'path': file.path,
        'size': stat.size,
        'written': true,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'WRITE_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _delete(Map<String, dynamic> params) async {
    final path = params['path'] as String?;
    if (path == null) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_PARAM',
        'message': 'path is required',
      });
    }

    try {
      final resolvedPath = _resolvePath(path);
      final entityType = FileSystemEntity.typeSync(resolvedPath);
      if (entityType == FileSystemEntityType.notFound) {
        return NodeFrame.response('', error: {
          'code': 'NOT_FOUND',
          'message': 'Not found: $path',
        });
      }

      if (entityType == FileSystemEntityType.directory) {
        await Directory(resolvedPath).delete(recursive: true);
      } else {
        await File(resolvedPath).delete();
      }
      return NodeFrame.response('', payload: {
        'path': path,
        'deleted': true,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'DELETE_ERROR',
        'message': '$e',
      });
    }
  }
}
