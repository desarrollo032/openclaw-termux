import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/native_bridge.dart';
import '../services/terminal_service.dart';
import '../models/optional_package.dart';
import '../design/components.dart';
import '../design/tokens.dart';
import '../widgets/terminal_view_module.dart';

/// Runs an install or uninstall command for an [OptionalPackage] inside proot.
/// Uses the unified [TerminalViewModule].
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
  final _terminalModuleKey = GlobalKey<TerminalViewModuleState>();
  bool _initialized = false;
  bool _finished = false;
  String? _error;
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
      // Try native terminal first (Termux + glibc runtime, no proot)
      final nativeConfig = await TerminalService.getNativeShellConfig();
      if (nativeConfig != null) {
        final command = widget.isUninstall ? widget.package.uninstallCommand : widget.package.installCommand;
        if (!mounted) return;
        setState(() {
          _shell = nativeConfig['shell'] as String;
          _args = ['-lc', command];
          _env = TerminalService.buildNativeHostEnv(nativeConfig);
          _initialized = true;
          _error = null;
        });
        return;
      }

      // Fallback to proot-based terminal
      final config = await TerminalService.getProotShellConfig();
      final args = TerminalService.buildProotArgs(config, columns: 80, rows: 24);
      final command = widget.isUninstall ? widget.package.uninstallCommand : widget.package.installCommand;

      final cmdArgs = List<String>.from(args);
      cmdArgs.removeLast(); // remove '-l'
      cmdArgs.removeLast(); // remove '/bin/bash'
      cmdArgs.addAll(['/bin/bash', '-lc', command]);

      if (!mounted) return;
      setState(() {
        _shell = config['executable'] as String;
        _args = cmdArgs;
        _env = TerminalService.buildHostEnv(config);
        _initialized = true;
        _error = null;
      });
    } catch (e, st) {
      debugPrint('Error preparing package install: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo preparar la instalación: $e';
      });
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
    final action = widget.isUninstall ? 'Desinstalar' : 'Instalar';
    final pkgColor = widget.isUninstall ? AppColors.statusAmber : widget.package.color;
    final sentinel = widget.isUninstall ? widget.package.uninstallSentinel : widget.package.completionSentinel;

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
            const SizedBox(width: 8),
            StatusBadge(
              color: pkgColor,
              label: widget.isUninstall ? 'Eliminar' : action,
              icon: widget.isUninstall ? Icons.delete_outline : Icons.download,
            ),
          ],
        ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ErrorBox(message: _error!),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              children: [
                                FilledButton.icon(
                                  onPressed: () {
                                    setState(() => _error = null);
                                    _prepareConfig();
                                  },
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('Reintentar'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  icon: const Icon(Icons.close, size: 18),
                                  label: const Text('Cancelar'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                  : !_initialized
                      ? const Center(child: CircularProgressIndicator())
                      : TerminalViewModule(
                          key: _terminalModuleKey,
                          shell: _shell,
                          arguments: _args,
                          environment: _env,
                          completionSentinel: sentinel,
                          onSentinelMatched: () => setState(() => _finished = true),
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
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(Icons.check),
                    label: Text(widget.isUninstall ? 'Eliminado' : 'Instalado'),
                    style: FilledButton.styleFrom(
                      backgroundColor: pkgColor,
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
