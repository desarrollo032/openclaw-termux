import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../native/openclaw_native.dart';
import '../design/components.dart';
import '../design/tokens.dart';
import '../constants.dart';
import '../providers/node_provider.dart';
import '../services/native_bridge.dart';
import '../services/preferences_service.dart';
import '../services/update_service.dart';
import 'node_screen.dart';
import 'setup_wizard_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _prefs = PreferencesService();
  bool _autoStart = false;
  bool _nodeEnabled = false;
  bool _batteryOptimized = true;
  String _arch = '';
  String _prootPath = '';
  Map<String, dynamic> _status = {};
  bool _loading = true;
  bool _goInstalled = false;
  bool _brewInstalled = false;
  bool _sshInstalled = false;
  bool _storageGranted = false;
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<T?> _safeCall<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (_) {
      return null;
    }
  }

  bool _safeFileExists(String path) {
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadSettings() async {
    try {
      await _prefs.init();
      _autoStart = _prefs.autoStartGateway;
      _nodeEnabled = _prefs.nodeEnabled;
    } catch (_) {
      // Preferences may be unavailable; fall back to defaults so the
      // settings page still renders instead of getting stuck on the spinner.
    }

    final arch = await _safeCall(NativeBridge.getArch) ?? '';
    final prootPath = await _safeCall(NativeBridge.getProotPath) ?? '';
    final status = await _safeCall(NativeBridge.getBootstrapStatus) ??
        <String, dynamic>{};
    final batteryOptimized =
        await _safeCall(NativeBridge.isBatteryOptimized) ?? false;
    final storageGranted =
        await _safeCall(NativeBridge.hasStoragePermission) ?? false;
    final filesDir = await _safeCall(NativeBridge.getFilesDir);

    var goInstalled = false;
    var brewInstalled = false;
    var sshInstalled = false;
    if (filesDir != null && filesDir.isNotEmpty) {
      final rootfs = '$filesDir/rootfs/ubuntu';
      goInstalled = _safeFileExists('$rootfs/usr/bin/go');
      brewInstalled =
          _safeFileExists('$rootfs/home/linuxbrew/.linuxbrew/bin/brew');
      sshInstalled = _safeFileExists('$rootfs/usr/bin/ssh');
    }

    if (!mounted) return;
    setState(() {
      _batteryOptimized = batteryOptimized;
      _storageGranted = storageGranted;
      _arch = arch;
      _prootPath = prootPath;
      _status = status;
      _goInstalled = goInstalled;
      _brewInstalled = brewInstalled;
      _sshInstalled = sshInstalled;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                // General
                SettingsCard(
                  title: 'General',
                  icon: Icons.tune_outlined,
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.power_outlined, size: 22),
                      title: const Text('Inicio automático', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      subtitle: Text('Iniciar el gateway al abrir la app', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      value: _autoStart,
                      onChanged: (value) {
                        setState(() => _autoStart = value);
                        _prefs.autoStartGateway = value;
                      },
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    ListTile(
                      leading: const Icon(Icons.battery_alert_outlined, size: 22),
                      title: const Text('Optimización de Batería', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      subtitle: Text(
                        _batteryOptimized
                            ? 'Optimizado — puede cerrar sesiones en segundo plano'
                            : 'Sin restricciones — recomendado',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (_batteryOptimized ? AppColors.statusAmber : AppColors.statusGreen).withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _batteryOptimized ? 'Optimizado' : 'Sin restricciones',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: _batteryOptimized ? AppColors.statusAmber : AppColors.statusGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      onTap: () async {
                        await NativeBridge.requestBatteryOptimization();
                        final optimized = await NativeBridge.isBatteryOptimized();
                        setState(() => _batteryOptimized = optimized);
                      },
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    ListTile(
                      leading: const Icon(Icons.sd_storage_outlined, size: 22),
                      title: const Text('Acceso a Almacenamiento', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      subtitle: Text(
                        _storageGranted
                            ? 'Concedido — proot puede acceder a /sdcard'
                            : 'No concedido — recomendado por seguridad',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (_storageGranted ? AppColors.statusAmber : AppColors.statusGreen).withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _storageGranted ? 'Concedido' : 'Restringido',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: _storageGranted ? AppColors.statusAmber : AppColors.statusGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      onTap: () async {
                        await NativeBridge.requestStoragePermission();
                        final granted = await NativeBridge.hasStoragePermission();
                        setState(() => _storageGranted = granted);
                      },
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Node
                SettingsCard(
                  title: 'Nodo',
                  icon: Icons.devices_outlined,
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.devices_outlined, size: 22),
                      title: const Text('Activar Nodo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      subtitle: Text(
                        'Proporcionar capacidades del dispositivo al gateway',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      value: _nodeEnabled,
                      onChanged: (value) {
                        setState(() => _nodeEnabled = value);
                        _prefs.nodeEnabled = value;
                        final nodeProvider = context.read<NodeProvider>();
                        if (value) {
                          nodeProvider.enable();
                        } else {
                          nodeProvider.disable();
                        }
                      },
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    ListTile(
                      leading: const Icon(Icons.tune_outlined, size: 22),
                      title: const Text('Configuración del Nodo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      subtitle: Text(
                        'Conexión, emparejamiento y capacidades',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const NodeScreen()),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // System Info
                SettingsCard(
                  title: 'Info del Sistema',
                  icon: Icons.monitor_outlined,
                  children: [
                    InfoRow(icon: Icons.memory_outlined, label: 'Arquitectura', value: _arch),
                    InfoRow(icon: Icons.folder_outlined, label: 'Ruta PRoot', value: _prootPath),
                    InfoRow(icon: Icons.storage_outlined, label: 'Rootfs', value: _status['rootfsExists'] == true ? 'Instalado' : 'No instalado'),
                    InfoRow(icon: Icons.code_outlined, label: 'Node.js', value: _status['nodeInstalled'] == true ? 'Instalado' : 'No instalado'),
                    InfoRow(icon: Icons.cloud_outlined, label: 'OpenClaw', value: _status['openclawInstalled'] == true ? 'Instalado' : 'No instalado'),
                    InfoRow(icon: Icons.integration_instructions_outlined, label: 'Go (Golang)', value: _goInstalled ? 'Instalado' : 'No instalado'),
                    InfoRow(icon: Icons.science_outlined, label: 'Homebrew', value: _brewInstalled ? 'Instalado' : 'No instalado'),
                    InfoRow(icon: Icons.vpn_key_outlined, label: 'OpenSSH', value: _sshInstalled ? 'Instalado' : 'No instalado'),
                  ],
                ),

                const SizedBox(height: 16),

                // Maintenance
                SettingsCard(
                  title: 'Mantenimiento',
                  icon: Icons.build_outlined,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.upload_file_outlined, size: 22),
                      title: const Text('Exportar Respaldo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      subtitle: Text(
                        'Respaldar configuración en Descargas',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: _exportSnapshot,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    ListTile(
                      leading: const Icon(Icons.download_outlined, size: 22),
                      title: const Text('Importar Respaldo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      subtitle: Text(
                        'Restaurar configuración desde respaldo',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: _importSnapshot,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    ListTile(
                      leading: const Icon(Icons.build_outlined, size: 22),
                      title: const Text('Re-ejecutar Instalación', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      subtitle: Text(
                        'Reinstalar o reparar el entorno',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const SetupWizardScreen()),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // About
                SettingsCard(
                  title: 'Acerca de',
                  icon: Icons.info_outline,
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withAlpha(15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.bolt, size: 20, color: theme.colorScheme.primary),
                      ),
                      title: const Text('OpenClaw', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        'AI Gateway para Android\nVersión ${AppConstants.version}',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      isThreeLine: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    ListTile(
                      leading: const Icon(Icons.system_update_outlined, size: 22),
                      title: const Text('Buscar Actualizaciones', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      subtitle: Text(
                        'Verificar GitHub para nueva versión',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      trailing: _checkingUpdate
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.chevron_right, size: 20),
                      onTap: _checkingUpdate ? null : _checkForUpdates,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    ListTile(
                      leading: const Icon(Icons.person_outlined, size: 22),
                      title: const Text('Desarrollador', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      subtitle: Text(AppConstants.orgName, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    ListTile(
                      leading: const Icon(Icons.code_outlined, size: 22),
                      title: const Text('GitHub', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      subtitle: Text(
                        'desarrollo032/openclaw-termux',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => OpenClawNative.openUrl(AppConstants.githubUrl),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    ListTile(
                      leading: const Icon(Icons.email_outlined, size: 22),
                      title: const Text('Contacto', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      subtitle: Text(
                        AppConstants.orgEmail,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => OpenClawNative.openUrl('mailto:${AppConstants.orgEmail}'),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    ListTile(
                      leading: const Icon(Icons.description_outlined, size: 22),
                      title: const Text('Licencia', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      subtitle: Text(
                        AppConstants.license,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => _showLicenseDialog(context),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  void _showLicenseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.description_outlined, size: 22),
            SizedBox(width: 8),
            Text('Licencia MIT'),
          ],
        ),
        content: SingleChildScrollView(
          child: SelectableText(
            AppConstants.licenseText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              OpenClawNative.openUrl(AppConstants.licenseUrl);
            },
            child: const Text('Ver en GitHub'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<String> _getSnapshotPath() async {
    final hasPermission = await NativeBridge.hasStoragePermission();
    if (hasPermission) {
      final sdcard = await NativeBridge.getExternalStoragePath();
      final downloadDir = Directory('$sdcard/Download');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      return '$sdcard/Download/openclaw-snapshot.json';
    }
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/openclaw-snapshot.json';
  }

  Future<void> _exportSnapshot() async {
    try {
      final openclawJson = await NativeBridge.readRootfsFile('root/.openclaw/openclaw.json');
      final snapshot = {
        'version': AppConstants.version,
        'timestamp': DateTime.now().toIso8601String(),
        'openclawConfig': openclawJson,
        'dashboardUrl': _prefs.dashboardUrl,
        'autoStart': _prefs.autoStartGateway,
        'nodeEnabled': _prefs.nodeEnabled,
        'nodeDeviceToken': _prefs.nodeDeviceToken,
        'nodeGatewayHost': _prefs.nodeGatewayHost,
        'nodeGatewayPort': _prefs.nodeGatewayPort,
        'nodeGatewayToken': _prefs.nodeGatewayToken,
      };
      final path = await _getSnapshotPath();
      await File(path).writeAsString(const JsonEncoder.withIndent('  ').convert(snapshot));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Snapshot saved to $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _importSnapshot() async {
    try {
      final path = await _getSnapshotPath();
      final file = File(path);
      if (!await file.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No snapshot found at $path')),
        );
        return;
      }
      final content = await file.readAsString();
      final snapshot = jsonDecode(content) as Map<String, dynamic>;
      final openclawConfig = snapshot['openclawConfig'] as String?;
      if (openclawConfig != null) {
        await NativeBridge.writeRootfsFile('root/.openclaw/openclaw.json', openclawConfig);
      }
      if (snapshot['dashboardUrl'] != null) {
        _prefs.dashboardUrl = snapshot['dashboardUrl'] as String;
      }
      if (snapshot['autoStart'] != null) {
        _prefs.autoStartGateway = snapshot['autoStart'] as bool;
      }
      if (snapshot['nodeEnabled'] != null) {
        _prefs.nodeEnabled = snapshot['nodeEnabled'] as bool;
      }
      if (snapshot['nodeDeviceToken'] != null) {
        _prefs.nodeDeviceToken = snapshot['nodeDeviceToken'] as String;
      }
      if (snapshot['nodeGatewayHost'] != null) {
        _prefs.nodeGatewayHost = snapshot['nodeGatewayHost'] as String;
      }
      if (snapshot['nodeGatewayPort'] != null) {
        _prefs.nodeGatewayPort = snapshot['nodeGatewayPort'] as int;
      }
      if (snapshot['nodeGatewayToken'] != null) {
        _prefs.nodeGatewayToken = snapshot['nodeGatewayToken'] as String;
      }
      await _loadSettings();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Snapshot restored. Restart gateway to apply.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() => _checkingUpdate = true);
    try {
      final result = await UpdateService.check();
      if (!mounted) return;
      if (result.available) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Update Available'),
            content: Text('Current: ${AppConstants.version}\nLatest: ${result.latest}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Later'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  OpenClawNative.openUrl(result.url);
                },
                child: const Text('Download'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You're on the latest version")),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not check for updates')),
      );
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }
}
