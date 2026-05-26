import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import '../native/openclaw_pty.dart';
import '../services/native_bridge.dart';
import '../design/tokens.dart';
import '../design/components.dart';
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
  DateTime _lastWakeLockRenewal = DateTime(2000);

  // Selection state
  bool _selectionMode = false;
  int? _selStartX;
  int? _selStartY;

  Terminal get terminal => _terminal;
  TerminalController get controller => _controller;
  int? get sessionId => _sessionId;
  bool get selectionMode => _selectionMode;
  bool get hasSelection =>
      _controller.selection != null && !_controller.selection!.isCollapsed;

  static const _fontFallback = [
    'monospace',
    'Noto Sans Mono',
    'Noto Color Emoji',
    'Noto Sans Symbols',
    'sans-serif',
  ];

  static double _fontSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return (width / 360 * 11).clamp(9.0, 14.0);
  }

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
            if (text.isNotEmpty) {
              if (DateTime.now().difference(_lastWakeLockRenewal).inSeconds >=
                  15) {
                _lastWakeLockRenewal = DateTime.now();
                NativeBridge.renewTerminalWakeLock();
              }
              _terminal.write(text);
              widget.onOutput?.call(text);
              if (widget.completionSentinel != null &&
                  text.contains(widget.completionSentinel!)) {
                widget.onSentinelMatched?.call();
              }
            }
            break;
          case 'exit':
            final code = event['exitCode'] as int;
            _terminal.write('\r\n[Proceso terminado con código $code]\r\n');
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
          OpenClawPty.write(sid,
              Uint8List.fromList(utf8.encode('\x1b$data')));
          _altNotifier.value = false;
          return;
        }
        OpenClawPty.write(
            sid, Uint8List.fromList(utf8.encode(data)));
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
          _error = 'Error al iniciar terminal: $e';
        });
      }
    }
  }

  Future<void> paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.isNotEmpty) {
      if (_sessionId != null) {
        OpenClawPty.write(
            _sessionId!, Uint8List.fromList(utf8.encode(text)));
      }
    }
  }

  void setSelectionMode(bool enabled) {
    if (!enabled) {
      _controller.clearSelection();
      _selStartX = null;
      _selStartY = null;
    }
    setState(() => _selectionMode = enabled);
  }

  void _onSelectionTap(int col, int row) {
    if (_selStartX == null) {
      _selStartX = col;
      _selStartY = row;
      final anchor = _terminal.buffer.createAnchor(col, row);
      _controller.setSelection(anchor, anchor);
    } else {
      final base =
          _terminal.buffer.createAnchor(_selStartX!, _selStartY!);
      final extent = _terminal.buffer.createAnchor(col, row);
      _controller.setSelection(base, extent);
      _selStartX = null;
      _selStartY = null;
    }
    setState(() {});
  }

  Future<void> copySelection() async {
    final selection = _controller.selection;
    if (selection == null || selection.isCollapsed) return;

    final range = selection.normalized;
    final sb = StringBuffer();
    for (int y = range.begin.y; y <= range.end.y; y++) {
      if (y >= _terminal.buffer.lines.length) break;
      final line = _terminal.buffer.lines[y];
      final from = (y == range.begin.y) ? range.begin.x : 0;
      final to = (y == range.end.y) ? range.end.x : null;
      sb.write(line.getText(from, to));
      if (y < range.end.y) sb.writeln();
    }
    final text = sb.toString().trim();
    if (text.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copiado al portapapeles'),
          duration: Duration(seconds: 1),
        ),
      );
    }
    setSelectionMode(false);
  }

  @override
  void dispose() {
    _ctrlNotifier.dispose();
    _altNotifier.dispose();
    _controller.dispose();
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
    final theme = Theme.of(context);

    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.accent),
            const SizedBox(height: Spacing.lg),
            Text(
              'Iniciando terminal...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const EmptyState(
                icon: Icons.terminal_rounded,
                title: 'Error de terminal',
                subtitle: 'No se pudo iniciar la sesión PTY',
              ),
              const SizedBox(height: Spacing.lg),
              FilledButton.icon(
                onPressed: startPty,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cellWidth =
                  constraints.maxWidth / math.max(_terminal.viewWidth, 1);
              final cellHeight =
                  constraints.maxHeight / math.max(_terminal.viewHeight, 1);

              return Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: _selectionMode,
                      child: TerminalView(
                        _terminal,
                        controller: _controller,
                        textStyle: TerminalStyle(
                          fontSize: _fontSize(context),
                          height: 1.0,
                          fontFamily: 'DejaVuSansMono',
                          fontFamilyFallback: _fontFallback,
                        ),
                      ),
                    ),
                  ),
                  if (_selectionMode)
                    Positioned.fill(
                      child: GestureDetector(
                        onTapDown: (details) {
                          final col = (details.localPosition.dx / cellWidth)
                              .floor()
                              .clamp(0, _terminal.viewWidth - 1);
                          final row = (details.localPosition.dy / cellHeight)
                              .floor()
                              .clamp(0, _terminal.viewHeight - 1);
                          _onSelectionTap(col, row);
                        },
                        behavior: HitTestBehavior.translucent,
                      ),
                    ),
                  if (_selectionMode && _selStartX == null)
                    Positioned(
                      top: Spacing.sm,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.md,
                            vertical: Spacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer
                                .withAlpha(220),
                            borderRadius:
                                BorderRadius.circular(RadiusTokens.pill),
                          ),
                          child: Text(
                            'Toca el primer carácter para iniciar selección',
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_selectionMode && hasSelection)
                    Positioned(
                      bottom: Spacing.sm,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Material(
                          elevation: 6,
                          borderRadius:
                              BorderRadius.circular(RadiusTokens.pill),
                          color: AppColors.accent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(
                                RadiusTokens.pill),
                            onTap: copySelection,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Spacing.xl,
                                vertical: Spacing.sm + 2,
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.copy_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: Spacing.sm - 1),
                                  Text(
                                    'Copiar',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        TerminalToolbar(
          sessionId: _sessionId,
          ctrlNotifier: _ctrlNotifier,
          altNotifier: _altNotifier,
          selectionMode: _selectionMode,
          onToggleSelection: () =>
              setSelectionMode(!_selectionMode),
        ),
      ],
    );
  }
}
