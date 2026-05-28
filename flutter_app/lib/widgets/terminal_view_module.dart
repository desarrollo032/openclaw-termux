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

/// Terminal emulator widget built on xterm.dart.
///
/// Architecture for selection & scroll:
///   - TerminalView is rendered WITHOUT any GestureDetector wrapper so
///     the xterm widget's own scroll gesture recognizer wins the arena.
///   - A transparent long‑press overlay with `HitTestBehavior.translucent`
///     sits *above* the terminal to detect long‑press → activate selection.
///   - In selection mode the terminal is ignored and a Listener overlay
///     handles drag‑to‑select.
///   - A floating toolbar (Copy / Select‑All / Cancel) appears when text
///     is selected.
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
  double _cellWidth = 0;
  double _cellHeight = 0;

  // ── Public accessors ────────────────────────────────────────────────────

  Terminal get terminal => _terminal;
  TerminalController get controller => _controller;
  int? get sessionId => _sessionId;
  bool get selectionMode => _selectionMode;

  /// Whether there is an active (non-collapsed) selection.
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

  // ── Lifecycle ───────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 2000);
    _controller = TerminalController();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => startPty());
    }
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

  // ── PTY session ─────────────────────────────────────────────────────────

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
            final text = event['text'] as String;  // Pre-decodeado en Kotlin
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
          OpenClawPty.write(
              sid, Uint8List.fromList(utf8.encode('\x1b$data')));
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
          _error = 'Error al iniciar terminal: $e';
        });
      }
    }
  }

  // ── Paste ────────────────────────────────────────────────────────────────

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

  // ── Selection mode ───────────────────────────────────────────────────────

  /// Toggle selection mode on/off.
  void setSelectionMode(bool enabled) {
    if (!enabled) {
      _controller.clearSelection();
      _selStartX = null;
      _selStartY = null;
    }
    if (mounted) setState(() => _selectionMode = enabled);
  }

  // ── Long-press activation (separate overlay, does NOT wrap TerminalView) ─

  void _onLongPressStart(LongPressStartDetails details) {
    if (_selectionMode) return;
    final col = (details.localPosition.dx / _cellWidth)
        .floor()
        .clamp(0, _terminal.viewWidth - 1);
    final row = (details.localPosition.dy / _cellHeight)
        .floor()
        .clamp(0, _terminal.viewHeight - 1);
    _selStartX = col;
    _selStartY = row;
    setSelectionMode(true);
    // Place initial single-character anchor
    final anchor = _terminal.buffer.createAnchor(col, row);
    _controller.setSelection(anchor, anchor);
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!_selectionMode || _selStartX == null) return;
    final col = (details.localPosition.dx / _cellWidth)
        .floor()
        .clamp(0, _terminal.viewWidth - 1);
    final row = (details.localPosition.dy / _cellHeight)
        .floor()
        .clamp(0, _terminal.viewHeight - 1);
    final base = _terminal.buffer.createAnchor(_selStartX!, _selStartY!);
    final extent = _terminal.buffer.createAnchor(col, row);
    _controller.setSelection(base, extent);
    setState(() {});
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    setState(() {});
  }

  // ── Drag-to-select in selection mode ────────────────────────────────────

  void _onSelectionPointerDown(PointerDownEvent event) {
    if (!_selectionMode) return;
    final col = (event.localPosition.dx / _cellWidth)
        .floor()
        .clamp(0, _terminal.viewWidth - 1);
    final row = (event.localPosition.dy / _cellHeight)
        .floor()
        .clamp(0, _terminal.viewHeight - 1);
    _selStartX = col;
    _selStartY = row;
    final anchor = _terminal.buffer.createAnchor(col, row);
    _controller.setSelection(anchor, anchor);
    setState(() {});
  }

  void _onSelectionPointerMove(PointerMoveEvent event) {
    if (!_selectionMode || _selStartX == null) return;
    final col = (event.localPosition.dx / _cellWidth)
        .floor()
        .clamp(0, _terminal.viewWidth - 1);
    final row = (event.localPosition.dy / _cellHeight)
        .floor()
        .clamp(0, _terminal.viewHeight - 1);
    final base = _terminal.buffer.createAnchor(_selStartX!, _selStartY!);
    final extent = _terminal.buffer.createAnchor(col, row);
    _controller.setSelection(base, extent);
    setState(() {});
  }

  void _onSelectionPointerUp(PointerUpEvent event) {
    setState(() {});
  }

  // ── Selection actions ───────────────────────────────────────────────────

  void selectAll() {
    final maxY = _terminal.buffer.lines.length - 1;
    if (maxY < 0) return;
    final base = _terminal.buffer.createAnchor(0, 0);
    final extent =
        _terminal.buffer.createAnchor(_terminal.viewWidth, maxY);
    _controller.setSelection(base, extent);
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
    final text = sb.toString();
    if (text.trim().isEmpty) return;

    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Text('Copiado (${text.length} caracteres)'),
            ],
          ),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    setSelectionMode(false);
  }

  // ── Build ────────────────────────────────────────────────────────────────

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
              // Cache cell dimensions for pointer → coordinate conversion
              _cellWidth =
                  constraints.maxWidth / math.max(_terminal.viewWidth, 1);
              _cellHeight =
                  constraints.maxHeight / math.max(_terminal.viewHeight, 1);

              return Stack(
                children: [
                  // ── Terminal (NO GestureDetector wrapper) ─────────────
                  // TerminalView receives pointer events directly so its
                  // built-in scroll gesture recogniser wins the arena.
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

                  // ── Long-press overlay (always present) ───────────────
                  // Translucent → terminal still receives events for scroll.
                  // If the user holds still for 500ms the long-press
                  // recogniser wins and activates selection mode.
                  // IMPORTANT: This overlay stays mounted even when
                  // _selectionMode is true so the gesture isn't cancelled
                  // mid-drag. The Listener overlay below coexists because
                  // Listener is passive (it doesn't compete in the arena).
                  Positioned.fill(
                    child: GestureDetector(
                      onLongPressStart: _onLongPressStart,
                      onLongPressMoveUpdate: _onLongPressMoveUpdate,
                      onLongPressEnd: _onLongPressEnd,
                      // translucent = overlay participates in hit-test
                      // but does NOT block events from reaching the
                      // TerminalView below.
                      behavior: HitTestBehavior.translucent,
                    ),
                  ),

                  // ── Selection overlay (drag-to-select) ───────────────
                  if (_selectionMode)
                    Positioned.fill(
                      child: Listener(
                        onPointerDown: _onSelectionPointerDown,
                        onPointerMove: _onSelectionPointerMove,
                        onPointerUp: _onSelectionPointerUp,
                        onPointerCancel: (_) {
                          _selStartX = null;
                          _selStartY = null;
                          setState(() {});
                        },
                        behavior: HitTestBehavior.translucent,
                      ),
                    ),

                  // ── Hint banner ───────────────────────────────────────
                  if (_selectionMode && !hasSelection)
                    Positioned(
                      top: Spacing.sm,
                      left: Spacing.md,
                      right: Spacing.md,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.md,
                            vertical: Spacing.xs + 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer
                                .withAlpha(220),
                            borderRadius:
                                BorderRadius.circular(RadiusTokens.pill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.touch_app_rounded,
                                size: 14,
                                color: theme
                                    .colorScheme.onPrimaryContainer,
                              ),
                              const SizedBox(width: Spacing.xs + 2),
                              Text(
                                'Arrastra para seleccionar',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme
                                      .colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // ── Floating toolbar (text selected) ────────────────
                  if (_selectionMode && hasSelection)
                    Positioned(
                      bottom: Spacing.sm + 4,
                      left: Spacing.md,
                      right: Spacing.md,
                      child: Center(
                        child: Material(
                          elevation: 8,
                          shadowColor: Colors.black.withAlpha(60),
                          borderRadius:
                              BorderRadius.circular(RadiusTokens.md + 4),
                          color: theme.brightness == Brightness.dark
                              ? theme.colorScheme.surfaceContainerHigh
                              : Colors.white,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Spacing.xs,
                              vertical: Spacing.xs,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Close
                                IconButton(
                                  icon: const Icon(
                                      Icons.close_rounded, size: 18),
                                  tooltip: 'Cancelar selección',
                                  onPressed: () =>
                                      setSelectionMode(false),
                                  style: IconButton.styleFrom(
                                    foregroundColor: theme
                                        .colorScheme.onSurfaceVariant,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                const SizedBox(width: Spacing.xs),
                                _divider(theme),
                                const SizedBox(width: Spacing.xs),

                                // Select All
                                TextButton.icon(
                                  onPressed: selectAll,
                                  icon: const Icon(
                                      Icons.select_all_rounded,
                                      size: 16),
                                  label: const Text('Todo',
                                      style:
                                          TextStyle(fontSize: 12)),
                                  style: TextButton.styleFrom(
                                    foregroundColor: theme
                                        .colorScheme.onSurfaceVariant,
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                  ),
                                ),
                                const SizedBox(width: Spacing.xs),
                                _divider(theme),
                                const SizedBox(width: Spacing.xs),

                                // Copy (primary)
                                FilledButton.icon(
                                  onPressed: copySelection,
                                  icon: const Icon(Icons.copy_rounded,
                                      size: 16),
                                  label: const Text('Copiar',
                                      style:
                                          TextStyle(fontSize: 12)),
                                  style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                  ),
                                ),
                              ],
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

        // ── Bottom toolbar (ESC, SEL, CTRL, ALT, arrows…) ────────────
        TerminalToolbar(
          sessionId: _sessionId,
          ctrlNotifier: _ctrlNotifier,
          altNotifier: _altNotifier,
          selectionMode: _selectionMode,
          onToggleSelection: () => setSelectionMode(!_selectionMode),
        ),
      ],
    );
  }

  Widget _divider(ThemeData theme) {
    return Container(
      width: 1,
      height: 24,
      color: theme.colorScheme.outlineVariant.withAlpha(80),
    );
  }
}
