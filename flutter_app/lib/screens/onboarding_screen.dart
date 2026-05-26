import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/native_bridge.dart';
import '../services/terminal_service.dart';
import '../services/preferences_service.dart';
import '../widgets/terminal_view_module.dart';
import 'dashboard_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final bool isFirstRun;
  const OnboardingScreen({super.key, this.isFirstRun = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _terminalModuleKey = GlobalKey<TerminalViewModuleState>();
  bool _initialized = false;
  bool _finished = false;
  String _shell = '';
  List<String> _args = [];
  Map<String, String> _env = {};

  final _tokenUrlRegex = RegExp(r'https?://(?:localhost|127\.0\.0\.1):18789/#token=[0-9a-f]+');

  @override
  void initState() {
    super.initState();
    NativeBridge.startTerminalService();
    _prepareConfig();
  }

  Future<void> _prepareConfig() async {
    try {
      final config = await TerminalService.getProotShellConfig();
      final args = TerminalService.buildProotArgs(config, columns: 80, rows: 24);

      final onboardingArgs = List<String>.from(args);
      onboardingArgs.removeLast(); // remove '-l'
      onboardingArgs.removeLast(); // remove '/bin/bash'
      onboardingArgs.addAll([
        '/bin/bash',
        '-lc',
        'echo "=== OpenClaw Onboarding ===" && openclaw onboard && echo "Onboarding complete!"',
      ]);

      setState(() {
        _shell = config['executable'] as String;
        _args = onboardingArgs;
        _env = TerminalService.buildHostEnv(config);
        _initialized = true;
      });
    } catch (e) {
      debugPrint('Error preparing onboarding: $e');
    }
  }

  @override
  void dispose() {
    NativeBridge.stopTerminalService();
    super.dispose();
  }

  void _handleOutput(String text) {
    final tokenMatch = _tokenUrlRegex.firstMatch(text.replaceAll(RegExp(r'\s+'), ''));
    if (tokenMatch != null) {
      _saveTokenUrl(tokenMatch.group(0) ?? '');
    }

    if (!_finished && (text.contains('Onboarding complete') || text.contains('setup complete'))) {
      setState(() => _finished = true);
    }
  }

  Future<void> _saveTokenUrl(String url) async {
    final prefs = PreferencesService();
    await prefs.init();
    prefs.dashboardUrl = url;
  }

  Future<void> _goToDashboard() async {
    final prefs = PreferencesService();
    await prefs.init();
    prefs.setupComplete = true;
    prefs.isFirstRun = false;
    if (mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const DashboardScreen()));
    }
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
                Icons.rocket_launch_outlined,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Configuración Inicial'),
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
                      onOutput: _handleOutput,
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
                    onPressed: widget.isFirstRun ? _goToDashboard : () => Navigator.pop(context),
                    icon: Icon(widget.isFirstRun ? Icons.arrow_forward : Icons.check),
                    label: Text(widget.isFirstRun ? 'Ir al Panel' : 'Listo'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
