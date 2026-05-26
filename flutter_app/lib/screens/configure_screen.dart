import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/native_bridge.dart';
import '../services/terminal_service.dart';
import '../widgets/terminal_view_module.dart';

/// Runs `openclaw configure` in a terminal so the user can manage
/// gateway settings. Uses the unified [TerminalViewModule].
class ConfigureScreen extends StatefulWidget {
  const ConfigureScreen({super.key});

  @override
  State<ConfigureScreen> createState() => _ConfigureScreenState();
}

class _ConfigureScreenState extends State<ConfigureScreen> {
  final _terminalModuleKey = GlobalKey<TerminalViewModuleState>();
  bool _initialized = false;
  bool _finished = false;
  String _shell = '';
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

      final configureArgs = List<String>.from(args);
      configureArgs.removeLast(); // remove '-l'
      configureArgs.removeLast(); // remove '/bin/bash'
      configureArgs.addAll([
        '/bin/bash', '-lc',
        'echo "=== OpenClaw Configure ===" && openclaw configure; echo "Configuration complete!"',
      ]);

      setState(() {
        _shell = config['executable'] as String;
        _args = configureArgs;
        _env = TerminalService.buildHostEnv(config);
        _initialized = true;
      });
    } catch (e) {
      debugPrint('Error preparing configure screen: $e');
    }
  }

  @override
  void dispose() {
    NativeBridge.stopTerminalService();
    super.dispose();
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
                Icons.tune_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Configurar Gateway'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: !_initialized
                  ? const Center(child: CircularProgressIndicator())
                  : TerminalViewModule(
                      key: _terminalModuleKey,
                      shell: _shell,
                      arguments: _args,
                      environment: _env,
                      onExit: (_) => setState(() => _finished = true),
                    ).animate().fadeIn(
                      duration: 300.ms,
                      curve: Curves.easeOut,
                    ),
            ),
            if (_finished)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: theme.dividerTheme.color ?? theme.colorScheme.outline.withAlpha(40),
                    ),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.check),
                    label: const Text('Listo'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
