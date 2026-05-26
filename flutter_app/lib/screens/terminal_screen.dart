import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/native_bridge.dart';
import '../services/screenshot_service.dart';
import '../services/terminal_service.dart';
import '../widgets/terminal_view_module.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final _screenshotKey = GlobalKey();
  final _terminalModuleKey = GlobalKey<TerminalViewModuleState>();

  bool _initialized = false;
  String _shell = '/bin/sh';
  List<String> _args = [];
  Map<String, String> _env = {};

  @override
  void initState() {
    super.initState();
    NativeBridge.startTerminalService();
    _prepareConfig();
  }

  Future<void> _prepareConfig() async {
    try {
      final config = await TerminalService.getProotShellConfig();
      final args = TerminalService.buildProotArgs(
        config,
        columns: 80,
        rows: 24,
      );

      setState(() {
        _shell = config['executable'] as String;
        _args = args;
        _env = TerminalService.buildHostEnv(config);
        _initialized = true;
      });
    } catch (e) {
      debugPrint('Error preparing terminal config: $e');
    }
  }

  @override
  void dispose() {
    NativeBridge.stopTerminalService();
    super.dispose();
  }

  void _copySelection() {
    _terminalModuleKey.currentState?.copySelection();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.terminal_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Terminal'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            tooltip: 'Captura de pantalla',
            onPressed: () => ScreenshotService.capture(_screenshotKey),
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copiar selección',
            onPressed: _copySelection,
          ),
          IconButton(
            icon: const Icon(Icons.paste),
            tooltip: 'Pegar',
            onPressed: () => _terminalModuleKey.currentState?.paste(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reiniciar terminal',
            onPressed: () => _terminalModuleKey.currentState?.startPty(),
          ),
        ],
      ),
      body: !_initialized
          ? const Center(child: CircularProgressIndicator())
          : RepaintBoundary(
              key: _screenshotKey,
              child: TerminalViewModule(
                key: _terminalModuleKey,
                shell: _shell,
                arguments: _args,
                environment: _env,
              ),
            ).animate().fadeIn(duration: 300.ms, curve: Curves.easeOut),
    );
  }
}
