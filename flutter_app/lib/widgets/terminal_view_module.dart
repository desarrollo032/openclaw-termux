import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import '../native/openclaw_pty.dart';
import '../services/native_bridge.dart';
import '../widgets/terminal_toolbar.dart';

class TerminalViewModule extends StatefulWidget {
  final String shell;
  final List<String> arguments;
  final Map<String, String>? environment;
  final String? workingDirectory;
  final bool autoStart;
  final Function(int sessionId)? onSessionStarted;
  final Function(String output)? onOutput;
  final Function(int exitCode)? onExit;
  final String? completionSentinel;
  final Function()? onSentinelMatched;

  const TerminalViewModule({
    super.key,
    required this.shell,
    this.arguments = const [],
    this.environment,
    this.workingDirectory,
    this.autoStart = true,
    this.onSessionStarted,
    this.onOutput,
    this.onExit,
    this.completionSentinel,
    this.onSentinelMatched,
  });

  @override
  State<TerminalViewModule> createState() => TerminalViewModuleState();
}

class TerminalViewModuleState extends State<TerminalViewModule> {
  late final Terminal _terminal;
  late final TerminalController _controller;
  int? _sessionId;
  StreamSubscription<Map<String, dynamic>>? _ptySubscription;
  bool _loading = true;
  String? _error;
  final _ctrlNotifier = ValueNotifier<bool>(false);
  final _altNotifier = ValueNotifier<bool>(false);
  final _outputBuffer = StringBuffer();
  Timer? _batchTimer;

  Terminal get terminal => _terminal;
  TerminalController get controller => _controller;
  int? get sessionId => _sessionId;

  static const _fontFallback = [
    'monospace',
    'Noto Sans Mono',
    'Noto Color Emoji',
    'Noto Sans Symbols',
    'sans-serif',
  ];

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 2000);
    _controller = TerminalController();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        startPty();
      });
    }
  }

  Future<void> startPty() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    await _ptySubscription?.cancel();
    _ptySubscription = null;
    final prevSession = _sessionId;
    _sessionId = null;
    if (prevSession != null) {
      await OpenClawPty.close(prevSession);
    }

    try {
      final sessionId = await OpenClawPty.start(
        shell: widget.shell,
        arguments: widget.arguments,
        environment: widget.environment ?? {},
        workingDirectory: widget.workingDirectory,
        rows: _terminal.viewHeight,
        columns: _terminal.viewWidth,
      );
      _sessionId = sessionId;
      widget.onSessionStarted?.call(sessionId);

      _ptySubscription = OpenClawPty.events(sessionId).listen((event) {
        switch (event['type']) {
          case 'output':
            final raw = (event['data'] as Uint8List);
            final text = utf8.decode(raw, allowMalformed: true);
            
            _outputBuffer.write(text);
            _batchTimer ??= Timer(const Duration(milliseconds: 4), () {
              if (!mounted) return;
              final flushed = _outputBuffer.toString();
              _outputBuffer.clear();
              if (flushed.isNotEmpty) {
                _terminal.write(flushed);
                widget.onOutput?.call(flushed);
                
                if (widget.completionSentinel != null && flushed.contains(widget.completionSentinel!)) {
                  widget.onSentinelMatched?.call();
                }
              }
              _batchTimer = null;
            });
            break;
          case 'exit':
            final code = event['exitCode'] as int;
            _terminal.write('\r\n[Process exited with code $code]\r\n');
            widget.onExit?.call(code);
            break;
          case 'error':
            _terminal.write('\r\n[Error: ${event['message']}]\r\n');
            break;
        }
      });

      _terminal.onOutput = (data) {
        final sid = _sessionId;
        if (sid == null) return;
        if (_ctrlNotifier.value && data.length == 1) {
          final code = data.toLowerCase().codeUnitAt(0);
          if (code >= 97 && code <= 122) {
            OpenClawPty.write(sid, Uint8List.fromList([code - 96]));
            _ctrlNotifier.value = false;
            return;
          }
        }
        if (_altNotifier.value && data.isNotEmpty) {
          OpenClawPty.write(sid, Uint8List.fromList(utf8.encode('\x1b$data')));
          _altNotifier.value = false;
          return;
        }
        OpenClawPty.write(sid, Uint8List.fromList(utf8.encode(data)));
      };

      _terminal.onResize = (w, h, pw, ph) {
        final sid = _sessionId;
        if (sid != null) {
          OpenClawPty.resize(sid, h, w);
        }
      };

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to start terminal: $e';
        });
      }
    }
  }

  Future<void> paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.isNotEmpty) {
      if (_sessionId != null) {
        OpenClawPty.write(_sessionId!, Uint8List.fromList(utf8.encode(text)));
      }
    }
  }

  @override
  void dispose() {
    _ctrlNotifier.dispose();
    _altNotifier.dispose();
    _controller.dispose();
    _batchTimer?.cancel();
    _ptySubscription?.cancel();
    _ptySubscription = null;
    final sid = _sessionId;
    _sessionId = null;
    if (sid != null) {
      OpenClawPty.close(sid);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.error),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: startPty, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: TerminalView(
            _terminal,
            controller: _controller,
            textStyle: const TerminalStyle(
              fontSize: 11,
              height: 1.0,
              fontFamily: 'DejaVuSansMono',
              fontFamilyFallback: _fontFallback,
            ),
          ),
        ),
        TerminalToolbar(
          sessionId: _sessionId,
          ctrlNotifier: _ctrlNotifier,
          altNotifier: _altNotifier,
        ),
      ],
    );
  }
}
