import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import '../native/openclaw_pty.dart';
import '../models/optional_package.dart';
import '../services/native_bridge.dart';
import '../services/screenshot_service.dart';
import '../services/terminal_service.dart';
import '../app.dart';
import '../widgets/terminal_toolbar.dart';

/// Runs an install or uninstall command for an [OptionalPackage] inside proot.
/// Follows the same terminal pattern as [OnboardingScreen].
class PackageInstallScreen extends StatefulWidget {
  final OptionalPackage package;
  final bool isUninstall;

  const PackageInstallScreen({
    super.key,
    required this.package,
    this.isUninstall = false,
  });

  @override
  State<PackageInstallScreen> createState() => _PackageInstallScreenState();
}

class _PackageInstallScreenState extends State<PackageInstallScreen> {
  late final Terminal _terminal;
  late final TerminalController _controller;
  int? _sessionId;
  StreamSubscription<Map<String, dynamic>>? _ptySubscription;
  bool _loading = true;
  bool _finished = false;
  String? _error;
  final _ctrlNotifier = ValueNotifier<bool>(false);
  final _altNotifier = ValueNotifier<bool>(false);
  final _screenshotKey = GlobalKey();

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startProcess();
    });
  }

  Future<void> _startProcess() async {
    await _ptySubscription?.cancel();
    _ptySubscription = null;
    final prevSession = _sessionId;
    _sessionId = null;
    if (prevSession != null) {
      await OpenClawPty.close(prevSession);
    }
    try {
      // Ensure dirs + resolv.conf exist before proot starts (#40).
      try { await NativeBridge.setupDirs(); } catch (_) {}
      try { await NativeBridge.writeResolv(); } catch (_) {}
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
      final config = await TerminalService.getProotShellConfig();
      final args = TerminalService.buildProotArgs(
        config,
        columns: _terminal.viewWidth,
        rows: _terminal.viewHeight,
      );

      final command = widget.isUninstall
          ? widget.package.uninstallCommand
          : widget.package.installCommand;

      // Replace login shell with the install/uninstall command
      final cmdArgs = List<String>.from(args);
      cmdArgs.removeLast(); // remove '-l'
      cmdArgs.removeLast(); // remove '/bin/bash'
      cmdArgs.addAll(['/bin/bash', '-lc', command]);

      final executable = config['executable'] as String;
      final sessionId = await OpenClawPty.start(
        shell: executable,
        arguments: cmdArgs,
        environment: TerminalService.buildHostEnv(config),
        rows: _terminal.viewHeight,
        columns: _terminal.viewWidth,
      );
      _sessionId = sessionId;

      final sentinel = widget.isUninstall
          ? widget.package.uninstallSentinel
          : widget.package.completionSentinel;

      _ptySubscription = OpenClawPty.events(sessionId).listen((event) {
        switch (event['type']) {
          case 'output':
            final raw = event['data'] as Uint8List;
            final text = utf8.decode(raw, allowMalformed: true);
            _terminal.write(text);

            if (!_finished && text.contains(sentinel)) {
              if (mounted) setState(() => _finished = true);
            }
            break;
          case 'exit':
            final code = event['exitCode'] as int;
            _terminal.write('\r\n[Process exited with code $code]\r\n');
            if (mounted && !_finished) {
              setState(() => _finished = true);
            }
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

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to start: $e';
      });
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.isNotEmpty) {
      if (_sessionId != null) {
        OpenClawPty.write(_sessionId!, Uint8List.fromList(utf8.encode(text)));
      }
    }
  }

  Future<void> _takeScreenshot() async {
    final path = await ScreenshotService.capture(_screenshotKey, prefix: 'package');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(path != null
            ? 'Screenshot saved: ${path.split('/').last}'
            : 'Failed to capture screenshot'),
      ),
    );
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
    NativeBridge.stopTerminalService();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final action = widget.isUninstall ? 'Desinstalar' : 'Instalar';
    final pkgColor = widget.isUninstall ? AppColors.statusAmber : widget.package.color;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: pkgColor.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(widget.package.icon, size: 16, color: pkgColor),
            ),
            const SizedBox(width: 10),
            Text('$action ${widget.package.name}'),
          ],
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            tooltip: 'Captura',
            onPressed: _takeScreenshot,
          ),
          IconButton(
            icon: const Icon(Icons.paste),
            tooltip: 'Pegar',
            onPressed: _paste,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
        children: [
          if (_loading)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _AnimatedPulseIcon(
                      icon: widget.package.icon,
                      color: pkgColor,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Iniciando $action…',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Preparando el entorno Ubuntu',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: pkgColor,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_error != null)
            Expanded(
              child: Center(
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
                      const SizedBox(height: 8),
                      Text(
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
                            _finished = false;
                          });
                          _startProcess();
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
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
                ),
              ),
            ),
            TerminalToolbar(
              sessionId: _sessionId,
              ctrlNotifier: _ctrlNotifier,
              altNotifier: _altNotifier,
            ),
          ],
          if (_finished)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: theme.dividerTheme.color ?? theme.colorScheme.outline.withAlpha(40)),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Icon(
                    widget.isUninstall ? Icons.delete_outline : Icons.check_circle_outline,
                    color: widget.isUninstall ? AppColors.statusAmber : AppColors.statusGreen,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${widget.isUninstall ? 'Desinstalación' : 'Instalación'} completada',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Listo'),
                  ),
                ],
              ),
            ),
        ],
        ),
      ),
    );
  }
}

/// Animated icon that pulses during loading.
class _AnimatedPulseIcon extends StatefulWidget {
  final IconData icon;
  final Color color;

  const _AnimatedPulseIcon({
    required this.icon,
    required this.color,
  });

  @override
  State<_AnimatedPulseIcon> createState() => _AnimatedPulseIconState();
}

class _AnimatedPulseIconState extends State<_AnimatedPulseIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _opacityAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: widget.color.withAlpha(15),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withAlpha(25),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(widget.icon, size: 34, color: widget.color),
            ),
          ),
        );
      },
    );
  }
}
