import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../native/openclaw_native.dart';
import '../app.dart';
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

  Future<void> _loadSettings() async {
    await _prefs.init();
    _autoStart = _prefs.autoStartGateway;
    _nodeEnabled = _prefs.nodeEnabled;

    try {
      final arch = await NativeBridge.getArch();
      final prootPath = await NativeBridge.getProotPath();
      final status = await NativeBridge.getBootstrapStatus();
      final batteryOptimized = await NativeBridge.isBatteryOptimized();
      final storageGranted = await NativeBridge.hasStoragePermission();

      final filesDir = await NativeBridge.getFilesDir();
      final rootfs = '$filesDir/rootfs/ubuntu';
      final goInstalled = File('$rootfs/usr/bin/go').existsSync();
      final brewInstalled =
          File('$rootfs/home/linuxbrew/.linuxbrew/bin/brew').existsSync();
      final sshInstalled = File('$rootfs/usr/bin/ssh').existsSync();

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
    } catch (e) {
      setState(() => _loading = false);
    }
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
                _settingsCard(theme, [
                  _switchTile(
                    theme,
                    Icons.power_outlined,
                    'Inicio automático',
                    'Iniciar el gateway al abrir la app',
                    _autoStart,
                    AppColors.statusGreen,
                    (value) {
                      setState(() => _autoStart = value);
                      _prefs.autoStartGateway = value;
                    },
                  ),
                  _listTile(
                    theme,
                    Icons.battery_alert_outlined,
                    'Optimización de Batería',
                    _batteryOptimized
                        ? 'Optimizado — puede cerrar sesiones en segundo plano'
                        : 'Sin restricciones — recomendado',
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (_batteryOptimized ? AppColors.statusAmber : AppColors.statusGreen)
                            .withAlpha(20),
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
                  ),
                  _listTile(
                    theme,
                    Icons.sd_storage_outlined,
                    'Acceso a Almacenamiento',
                    _storageGranted
                        ? 'Concedido — proot puede acceder a /sdcard'
                        : 'No concedido — recomendado por seguridad',
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (_storageGranted ? AppColors.statusAmber : AppColors.statusGreen)
                            .withAlpha(20),
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
                  ),
                ], title: 'General', icon: Icons.tune_outlined),

                const SizedBox(height: 16),
                _settingsCard(theme, [
                  _switchTile(
                    theme,
                    Icons.devices_outlined,
                    'Activar Nodo',
                    'Proporcionar capacidades del dispositivo al gateway',
                    _nodeEnabled,
                    AppColors.statusGreen,
                    (value) {
                      setState(() => _nodeEnabled = value);
                      _prefs.nodeEnabled = value;
                      final nodeProvider = context.read<NodeProvider>();
                      if (value) {
                        nodeProvider.enable();
                      } else {
                        nodeProvider.disable();
                      }
                    },
                  ),
                  _listTile(
                    theme,
                    Icons.tune_outlined,
                    'Configuración del Nodo',
                    'Conexión, emparejamiento y capacidades',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const NodeScreen()),
                    ),
                  ),
                ], title: 'Nodo', icon: Icons.devices_outlined),

                const SizedBox(height: 16),
                _settingsCard(theme, [
                  _infoRow(theme, 'Arquitectura', _arch, Icons.memory_outlined),
                  _infoRow(theme, 'Ruta PRoot', _prootPath, Icons.folder_outlined),
                  _infoRow(theme, 'Rootfs', _status['rootfsExists'] == true ? 'Instalado' : 'No instalado', Icons.storage_outlined),
                  _infoRow(theme, 'Node.js', _status['nodeInstalled'] == true ? 'Instalado' : 'No instalado', Icons.code_outlined),
                  _infoRow(theme, 'OpenClaw', _status['openclawInstalled'] == true ? 'Instalado' : 'No instalado', Icons.cloud_outlined),
                  _infoRow(theme, 'Go (Golang)', _goInstalled ? 'Instalado' : 'No instalado', Icons.integration_instructions_outlined),
                  _infoRow(theme, 'Homebrew', _brewInstalled ? 'Instalado' : 'No instalado', Icons.science_outlined),
                  _infoRow(theme, 'OpenSSH', _sshInstalled ? 'Instalado' : 'No instalado', Icons.vpn_key_outlined),
                ], title: 'Info del Sistema', icon: Icons.monitor_outlined),

                const SizedBox(height: 16),
                _settingsCard(theme, [
                  _listTile(
                    theme,
                    Icons.upload_file_outlined,
                    'Exportar Respaldo',
                    'Respaldar configuración en Descargas',
                    onTap: _exportSnapshot,
                  ),
                  _listTile(
                    theme,
                    Icons.download_outlined,
                    'Importar Respaldo',
                    'Restaurar configuración desde respaldo',
                    onTap: _importSnapshot,
                  ),
                  _listTile(
                    theme,
                    Icons.build_outlined,
                    'Re-ejecutar Instalación',
                    'Reinstalar o reparar el entorno',
                    onTap: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const SetupWizardScreen()),
                    ),
                  ),
                ], title: 'Mantenimiento', icon: Icons.build_outlined),

                const SizedBox(height: 16),
                _settingsCard(theme, [
                  const _AboutTile(),
                  _listTile(
                    theme,
                    Icons.system_update_outlined,
                    'Buscar Actualizaciones',
                    'Verificar GitHub para nueva versión',
                    trailing: _checkingUpdate
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap: _checkingUpdate ? null : _checkForUpdates,
                  ),
                  _listTile(
                    theme,
                    Icons.person_outlined,
                    'Desarrollador',
                    AppConstants.orgName,
                  ),
                  _listTile(
                    theme,
                    Icons.code_outlined,
                    'GitHub',
                    'desarrollo032/openclaw-termux',
                    onTap: () => OpenClawNative.openUrl(AppConstants.githubUrl),
                  ),
                  _listTile(
                    theme,
                    Icons.email_outlined,
                    'Contacto',
                    AppConstants.orgEmail,
                    onTap: () => OpenClawNative.openUrl('mailto:${AppConstants.orgEmail}'),
                  ),
                  _listTile(
                    theme,
                    Icons.description_outlined,
                    'Licencia',
                    AppConstants.license,
                    onTap: () => OpenClawNative.openUrl(AppConstants.licenseUrl),
                  ),
                ], title: 'Acerca de', icon: Icons.info_outline),
              ],
            ),
    );
  }

  Widget _settingsCard(ThemeData theme, List<Widget> children, {required String title, required IconData icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: List.generate(children.length, (i) {
              return Column(
                children: [
                  if (i > 0)
                    const Divider(height: 1),
                  children[i],
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _switchTile(ThemeData theme, IconData icon, String title, String subtitle, bool value, Color toggleColor, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      secondary: Icon(icon, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  Widget _listTile(ThemeData theme, IconData icon, String title, String subtitle, {VoidCallback? onTap, Widget? trailing}) {
    return ListTile(
      leading: Icon(icon, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right, size: 20) : null),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  Widget _infoRow(ThemeData theme, String label, String value, IconData icon) {
    return ListTile(
      leading: Icon(icon, size: 22, color: theme.colorScheme.onSurfaceVariant),
      title: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: Text(
        value,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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
            content: Text(
              'Current: ${AppConstants.version}\nLatest: ${result.latest}',
            ),
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

class _AboutTile extends StatelessWidget {
  const _AboutTile();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
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
        'AI Gateway for Android\nVersion ${AppConstants.version}',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      isThreeLine: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}
