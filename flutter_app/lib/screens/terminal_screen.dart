import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/native_bridge.dart';
import '../services/screenshot_service.dart';
import '../services/terminal_service.dart';
import '../widgets/terminal_toolbar.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  late final Terminal _terminal;
  late final TerminalController _controller;
  Pty? _pty;
  bool _loading = true;
  String? _error;
  final _ctrlNotifier = ValueNotifier<bool>(false);
  final _altNotifier = ValueNotifier<bool>(false);
  final _screenshotKey = GlobalKey();
  final _outputBuffer = StringBuffer();
  Timer? _batchTimer;
  static final _anyUrlRegex = RegExp(r'https?://[^\s<>\[\]"' "'" r'\)]+');
  /// Box-drawing and other TUI characters that break URLs when copied
  static final _boxDrawing = RegExp(r'[│┤├┬┴┼╮╯╰╭─╌╴╶┌┐└┘◇◆]+');

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
    NativeBridge.startTerminalService();
    // Defer PTY start until after the first frame so TerminalView has been
    // laid out and _terminal.viewWidth/viewHeight reflect real screen
    // dimensions instead of the 80×24 default.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPty();
    });
  }

  Future<void> _startPty() async {
    _pty?.kill();
    _pty = null;
    try {
      // Ensure dirs + resolv.conf exist before proot starts (#40).
      await _ensureEnvFiles();
      final config = await TerminalService.getProotShellConfig();
      final args = TerminalService.buildProotArgs(
        config,
        columns: _terminal.viewWidth,
        rows: _terminal.viewHeight,
      );

      final executable = config['executable'] as String;
      final pty = Pty.start(
        executable,
        arguments: args,
        environment: TerminalService.buildHostEnv(config),
        columns: _terminal.viewWidth,
        rows: _terminal.viewHeight,
      );
      _pty = pty;

      pty.output.cast<List<int>>().listen((data) {
        final text = utf8.decode(data, allowMalformed: true);
        _outputBuffer.write(text);
        // Batch writes to avoid triggering a repaint per chunk.
        // Flush at most once per ~16ms (60fps) instead of per-chunk.
        _batchTimer ??= Timer(const Duration(milliseconds: 16), () {
          if (!mounted) return;
          final flushed = _outputBuffer.toString();
          _outputBuffer.clear();
          if (flushed.isNotEmpty) {
            _terminal.write(flushed);
          }
          _batchTimer = null;
        });
      });

      pty.exitCode.then((code) {
        _terminal.write('\r\n[Process exited with code $code]\r\n');
      });

      _terminal.onOutput = (data) {
        // Intercept keyboard input when CTRL/ALT toolbar modifiers are active
        if (_ctrlNotifier.value && data.length == 1) {
          final code = data.toLowerCase().codeUnitAt(0);
          if (code >= 97 && code <= 122) {
            // Ctrl+a-z → bytes 1-26
            _pty?.write(Uint8List.fromList([code - 96]));
            _ctrlNotifier.value = false;
            return;
          }
        }
        if (_altNotifier.value && data.isNotEmpty) {
          // Alt+key → ESC + key
          _pty?.write(utf8.encode('\x1b$data'));
          _altNotifier.value = false;
          return;
        }
        _pty?.write(utf8.encode(data));
      };

      _terminal.onResize = (w, h, pw, ph) {
        _pty?.resize(h, w);
      };

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to start terminal: $e';
      });
    }
  }


  Future<void> _ensureEnvFiles() async {
    try { await NativeBridge.ensureReady(); } catch (_) {}
    try {
      final filesDir = await NativeBridge.getFilesDir();
      const resolvContent = 'nameserver 8.8.8.8\nnameserver 8.8.4.4\n';
      final resolvFile = File('$filesDir/config/resolv.conf');
      if (!resolvFile.existsSync()) {
        Directory('$filesDir/config').createSync(recursive: true);
        resolvFile.writeAsStringSync(resolvContent);
      }
      final rootfsResolv = File('$filesDir/rootfs/ubuntu/etc/resolv.conf');
      if (!rootfsResolv.existsSync()) {
        rootfsResolv.parent.createSync(recursive: true);
        rootfsResolv.writeAsStringSync(resolvContent);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _ctrlNotifier.dispose();
    _altNotifier.dispose();
    _controller.dispose();
    _batchTimer?.cancel();
    _pty?.kill();
    NativeBridge.stopTerminalService();
    super.dispose();
  }

  String? _getSelectedText() {
    final selection = _controller.selection;
    if (selection == null || selection.isCollapsed) return null;

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
    return text.isEmpty ? null : text;
  }

  /// Extract a clean URL from selected text by stripping box-drawing
  /// chars and rejoining lines, but splitting on `http` boundaries
  /// so concatenated URLs don't merge into one.
  String? _extractUrl(String text) {
    final clean = text.replaceAll(_boxDrawing, '').replaceAll(RegExp(r'\s+'), '');
    // Split before each http(s):// so concatenated URLs become separate
    final parts = clean.split(RegExp(r'(?=https?://)'));
    // Return the longest URL match (token URLs are longest)
    String? best;
    for (final part in parts) {
      final match = _anyUrlRegex.firstMatch(part);
      if (match != null) {
        final url = match.group(0) ?? '';
        if (best == null || url.length > best.length) {
          best = url;
        }
      }
    }
    return best;
  }

  void _copySelection() {
    final text = _getSelectedText();
    if (text == null) return;

    Clipboard.setData(ClipboardData(text: text));

    // If the copied text contains a URL, offer "Open" action
    final url = _extractUrl(text);
    if (url != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Copiado al portapapeles'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Abrir',
            onPressed: () {
              final uri = Uri.tryParse(url);
              if (uri != null) {
                launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copiado al portapapeles'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _openSelection() {
    final text = _getSelectedText();
    if (text == null) return;

    final url = _extractUrl(text);
    if (url != null) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No se encontró URL en la selección'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.isNotEmpty) {
      _pty?.write(utf8.encode(text));
    }
  }



  String _getTerminalBufferText({int maxLines = 400}) {
    final total = _terminal.buffer.lines.length;
    final start = (total - maxLines).clamp(0, total);
    final sb = StringBuffer();
    for (int row = start; row < total; row++) {
      final line = _getLineText(row).trimRight();
      if (line.isNotEmpty) sb.writeln(line);
    }
    return sb.toString().trim();
  }

  Future<void> _searchSelectedTextWeb() async {
    final text = _getSelectedText();
    if (text == null) return;
    final q = Uri.encodeQueryComponent(text);
    final uri = Uri.parse('https://www.google.com/search?q=$q');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _showAdvancedSelectionTools() async {
    final selected = _getSelectedText();
    final hasSelection = selected != null && selected.isNotEmpty;
    final url = hasSelection ? _extractUrl(selected!) : null;

    await HapticFeedback.mediumImpact();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.touch_app_outlined),
                title: const Text('Selección avanzada'),
                subtitle: Text(hasSelection
                    ? 'Texto seleccionado: ${selected!.length} caracteres'
                    : 'Mantén presionado en la terminal para seleccionar texto'),
              ),
              ListTile(
                leading: const Icon(Icons.copy_all_outlined),
                title: const Text('Copiar selección'),
                enabled: hasSelection,
                onTap: hasSelection ? () { Navigator.pop(ctx); _copySelection(); } : null,
              ),
              ListTile(
                leading: const Icon(Icons.open_in_browser_outlined),
                title: const Text('Abrir URL seleccionada'),
                enabled: hasSelection && url != null,
                onTap: hasSelection && url != null ? () { Navigator.pop(ctx); _openSelection(); } : null,
              ),
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Buscar selección en web'),
                enabled: hasSelection,
                onTap: hasSelection ? () { Navigator.pop(ctx); _searchSelectedTextWeb(); } : null,
              ),
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Copiar últimas 400 líneas'),
                onTap: () {
                  final allText = _getTerminalBufferText();
                  Navigator.pop(ctx);
                  if (allText.isEmpty) return;
                  Clipboard.setData(ClipboardData(text: allText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Historial reciente copiado')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _takeScreenshot() async {
    final path = await ScreenshotService.capture(_screenshotKey);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(path != null
            ? 'Screenshot saved: ${path.split('/').last}'
            : 'Failed to capture screenshot'),
      ),
    );
  }

  /// Detect URLs in terminal at tap position. Joins adjacent lines
  /// and strips box-drawing chars to handle wrapped URLs.
  void _handleTap(TapUpDetails details, CellOffset offset) {
    final totalLines = _terminal.buffer.lines.length;
    final startRow = (offset.y - 2).clamp(0, totalLines - 1);
    final endRow = (offset.y + 2).clamp(0, totalLines - 1);

    final sb = StringBuffer();
    for (int row = startRow; row <= endRow; row++) {
      sb.write(_getLineText(row).trimRight());
    }
    final url = _extractUrl(sb.toString());
    if (url != null) {
      _openUrl(url);
    }
  }

  String _getLineText(int row) {
    try {
      final line = _terminal.buffer.lines[row];
      final sb = StringBuffer();
      for (int i = 0; i < line.length; i++) {
        final char = line.getCodePoint(i);
        if (char != 0) {
          sb.writeCharCode(char);
        }
      }
      return sb.toString();
    } catch (_) {
      return '';
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Abrir Enlace'),
        content: Text(url),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Enlace copiado'),
                  duration: Duration(seconds: 1),
                ),
              );
              Navigator.pop(ctx, false);
            },
            child: const Text('Copiar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abrir'),
          ),
        ],
      ),
    );

    if (shouldOpen == true) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terminal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            tooltip: 'Captura',
            onPressed: _takeScreenshot,
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copiar',
            onPressed: _copySelection,
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            tooltip: 'Abrir URL',
            onPressed: _openSelection,
          ),
          IconButton(
            icon: const Icon(Icons.select_all),
            tooltip: 'Selección avanzada',
            onPressed: _showAdvancedSelectionTools,
          ),
          IconButton(
            icon: const Icon(Icons.paste),
            tooltip: 'Pegar',
            onPressed: _paste,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reiniciar',
            onPressed: () {
              _batchTimer?.cancel();
              _batchTimer = null;
              _outputBuffer.clear();
              _pty?.kill();
              setState(() {
                _loading = true;
                _error = null;
              });
              _startPty();
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final theme = Theme.of(context);
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Iniciando terminal...',
              style: theme.textTheme.bodyMedium?.copyWith(
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
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withAlpha(15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Error al iniciar',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),                      Text(
                        _error ?? '',
                        textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _startPty();
                },
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
          child: RepaintBoundary(
            key: _screenshotKey,
            child: TerminalView(
              _terminal,
              controller: _controller,
              textStyle: const TerminalStyle(
                fontSize: 11,
                height: 1.0,
                fontFamily: 'DejaVuSansMono',
                fontFamilyFallback: _fontFallback,
              ),
              onTapUp: _handleTap,
            ),
          ),
        ),
        TerminalToolbar(
          pty: _pty,
          ctrlNotifier: _ctrlNotifier,
          altNotifier: _altNotifier,
        ),
      ],
    );
  }

}
