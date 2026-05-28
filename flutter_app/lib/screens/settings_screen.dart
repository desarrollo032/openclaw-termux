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

    final results = await Future.wait([
      _safeCall(NativeBridge.getArch),
      _safeCall(NativeBridge.getProotPath),
      _safeCall(NativeBridge.getBootstrapStatus),
      _safeCall(NativeBridge.isBatteryOptimized),
      _safeCall(NativeBridge.hasStoragePermission),
      _safeCall(NativeBridge.getFilesDir),
    ]);
    final arch = (results[0] as String?) ?? '';
    final prootPath = (results[1] as String?) ?? '';
    final status = (results[2] as Map<String, dynamic>?) ??
        <String, dynamic>{};
    final batteryOptimized = (results[3] as bool?) ?? false;
    final storageGranted = (results[4] as bool?) ?? false;
    final filesDir = results[5] as String?;

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

                // Advanced
                SettingsCard(
                  title: 'Avanzado',
                  icon: Icons.tune_outlined,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.code_rounded, size: 22),
                      title: const Text('openclaw.json', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      subtitle: Text(
                        'Ver contenido completo del archivo de configuración',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => _showFullConfigViewer(context),
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

  void _showFullConfigViewer(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _FullConfigViewerDialog(),
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

/// Full-screen dialog that reads, displays and allows inline editing of openclaw.json.
class _FullConfigViewerDialog extends StatefulWidget {
  const _FullConfigViewerDialog();

  @override
  State<_FullConfigViewerDialog> createState() => _FullConfigViewerDialogState();
}

class _FullConfigViewerDialogState extends State<_FullConfigViewerDialog> {
  bool _loading = true;
  String? _error;
  _JsonNode? _root;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final raw = await NativeBridge.readRootfsFile('root/.openclaw/openclaw.json');
      if (raw == null || raw.isEmpty) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'No se encontró openclaw.json o está vacío';
          });
        }
        return;
      }
      final parsed = jsonDecode(raw);
      if (mounted) {
        setState(() {
          _root = _JsonNode.build('config', parsed);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al leer openclaw.json: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveConfig() async {
    if (_root == null) return;
    try {
      final json = _nodeToJson(_root!);
      final pretty = const JsonEncoder.withIndent('  ').convert(json);
      await NativeBridge.writeRootfsFile('root/.openclaw/openclaw.json', pretty);
      if (!mounted) return;
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('openclaw.json guardado'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e'), duration: const Duration(seconds: 3)),
      );
    }
  }

  dynamic _nodeToJson(_JsonNode node) {
    switch (node.type) {
      case _JsonValueType.object:
        final map = <String, dynamic>{};
        for (final child in node.children) {
          map[child.key] = _nodeToJson(child);
        }
        return map;
      case _JsonValueType.array:
        return node.children.map((child) => _nodeToJson(child)).toList();
      case _JsonValueType.string:
        return node.value as String;
      case _JsonValueType.number:
        return node.value;
      case _JsonValueType.boolean:
        return node.value as bool;
      case _JsonValueType.null_:
        return null;
    }
  }

  void _editValue(_JsonNode node) {
    switch (node.type) {
      case _JsonValueType.string:
        _showStringEditDialog(node);
      case _JsonValueType.number:
        _showNumberEditDialog(node);
      case _JsonValueType.boolean:
        _showBooleanEditDialog(node);
      case _JsonValueType.null_:
        _showNullEditDialog(node);
      case _JsonValueType.object:
      case _JsonValueType.array:
        break;
    }
  }

  void _showStringEditDialog(_JsonNode node) {
    final controller = TextEditingController(text: node.value as String? ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar "${node.key}"'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          minLines: 1,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final newValue = controller.text;
              Navigator.pop(ctx);
              setState(() {
                node.value = newValue;
                _dirty = true;
              });
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showNumberEditDialog(_JsonNode node) {
    final isInt = node.value is int;
    final controller = TextEditingController(text: node.value.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar "${node.key}"'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.numberWithOptions(decimal: !isInt, signed: true),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              Navigator.pop(ctx);
              if (text.isEmpty) return;
              setState(() {
                if (isInt && !text.contains('.') && !text.contains(',')) {
                  node.value = int.tryParse(text) ?? node.value;
                } else {
                  node.value = double.tryParse(text.replaceAll(',', '.')) ?? node.value;
                }
                _dirty = true;
              });
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showBooleanEditDialog(_JsonNode node) {
    final current = node.value as bool;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar "${node.key}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<bool>(
              title: const Text('true'),
              value: true,
              groupValue: current,
              onChanged: (v) {
                Navigator.pop(ctx);
                setState(() {
                  node.value = v;
                  _dirty = true;
                });
              },
            ),
            RadioListTile<bool>(
              title: const Text('false'),
              value: false,
              groupValue: current,
              onChanged: (v) {
                Navigator.pop(ctx);
                setState(() {
                  node.value = v;
                  _dirty = true;
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        ],
      ),
    );
  }

  void _showNullEditDialog(_JsonNode node) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Establecer "${node.key}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Valor actual: null', style: TextStyle(fontStyle: FontStyle.italic)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Nuevo valor (string)',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              Navigator.pop(ctx);
              setState(() {
                if (text.isEmpty) {
                  // Keep as null
                } else if (text == 'true') {
                  node.type = _JsonValueType.boolean;
                  node.value = true;
                } else if (text == 'false') {
                  node.type = _JsonValueType.boolean;
                  node.value = false;
                } else {
                  final intVal = int.tryParse(text);
                  if (intVal != null) {
                    node.type = _JsonValueType.number;
                    node.value = intVal;
                  } else {
                    final doubleVal = double.tryParse(text.replaceAll(',', '.'));
                    if (doubleVal != null) {
                      node.type = _JsonValueType.number;
                      node.value = doubleVal;
                    } else {
                      node.type = _JsonValueType.string;
                      node.value = text;
                    }
                  }
                }
                _dirty = true;
              });
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('openclaw.json'),
              if (_dirty)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.error.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Sin guardar',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.error,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            if (_root != null)
              IconButton(
                icon: Icon(Icons.save_rounded, color: _dirty ? cs.primary : cs.onSurface.withAlpha(80)),
                tooltip: 'Guardar cambios',
                onPressed: _dirty ? _saveConfig : null,
              ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Cerrar',
              onPressed: () {
                if (_dirty) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('¿Descartar cambios?'),
                      content: const Text('Hay cambios sin guardar. ¿Estás seguro de que quieres cerrar?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                        FilledButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.of(context).pop();
                          },
                          child: const Text('Descartar'),
                        ),
                      ],
                    ),
                  );
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        ),
        body: _buildBody(theme, cs),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme cs) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: cs.error)),
            ],
          ),
        ),
      );
    }

    if (_root == null) {
      return Center(
        child: Text('No se encontró openclaw.json', style: theme.textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
      );
    }

    // Build the flat list of tree rows
    final rows = <Widget>[];
    _buildTreeRows(_root!, 0, rows, theme, cs);

    return Column(
      children: [
        // Status bar
        if (rows.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withAlpha(80),
              border: Border(bottom: BorderSide(color: cs.outlineVariant.withAlpha(60))),
            ),
            child: Row(
              children: [
                Icon(Icons.data_object_rounded, size: 14, color: cs.onSurfaceVariant.withAlpha(160)),
                const SizedBox(width: 6),
                Text(
                  '${_countLeaves(_root!)} valores',
                  style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant.withAlpha(160)),
                ),
                const SizedBox(width: 12),
                Icon(Icons.list_alt_rounded, size: 14, color: cs.onSurfaceVariant.withAlpha(160)),
                const SizedBox(width: 6),
                Text(
                  '${_countNodes(_root!)} nodos',
                  style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant.withAlpha(160)),
                ),
              ],
            ),
          ),
        // Tree content
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: rows,
          ),
        ),
      ],
    );
  }

  void _buildTreeRows(_JsonNode node, int depth, List<Widget> rows, ThemeData theme, ColorScheme cs) {
    final indent = depth * 16.0;

    if (node.type == _JsonValueType.object || node.type == _JsonValueType.array) {
      // Expandable row
      final isObject = node.type == _JsonValueType.object;
      final icon = isObject ? Icons.code_rounded : Icons.view_list_rounded;
      final count = node.children.length;

      rows.add(
        InkWell(
          onTap: () => setState(() => node.isExpanded = !node.isExpanded),
          child: Padding(
            padding: EdgeInsets.only(left: indent, right: 8, top: 4, bottom: 4),
            child: Row(
              children: [
                Icon(
                  node.isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Icon(icon, size: 16, color: cs.primary.withAlpha(180)),
                const SizedBox(width: 6),
                Text(
                  node.key,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withAlpha(80),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count ${isObject ? 'claves' : 'items'}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant.withAlpha(160),
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      if (node.isExpanded) {
        for (final child in node.children) {
          _buildTreeRows(child, depth + 1, rows, theme, cs);
        }
      }
    } else {
      // Leaf value row
      rows.add(_buildLeafRow(node, depth, theme, cs));
    }
  }

  Widget _buildLeafRow(_JsonNode node, int depth, ThemeData theme, ColorScheme cs) {
    final indent = depth * 16.0;

    Color valueColor;
    String valueText;
    IconData? valueIcon;

    switch (node.type) {
      case _JsonValueType.string:
        valueColor = const Color(0xFF2E7D32);
        valueText = '"${node.value}"';
        valueIcon = Icons.text_fields_rounded;
      case _JsonValueType.number:
        valueColor = const Color(0xFF1565C0);
        valueText = '${node.value}';
        valueIcon = Icons.tag_rounded;
      case _JsonValueType.boolean:
        valueColor = (node.value as bool) ? const Color(0xFF6A1B9A) : const Color(0xFF9E9E9E);
        valueText = '${node.value}';
        valueIcon = Icons.toggle_on_outlined;
      case _JsonValueType.null_:
        valueColor = const Color(0xFF9E9E9E);
        valueText = 'null';
        valueIcon = Icons.block_rounded;
      default:
        valueColor = cs.onSurface;
        valueText = '?';
    }

    return Padding(
      padding: EdgeInsets.only(left: indent + 22, right: 8, top: 2, bottom: 2),
      child: InkWell(
        onTap: () => _editValue(node),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              // Key
              Flexible(
                flex: 3,
                child: Text(
                  node.key,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: cs.onSurface.withAlpha(200),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Separator
              Text(
                ':',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: cs.onSurface.withAlpha(80),
                ),
              ),
              const SizedBox(width: 6),
              // Value
              Expanded(
                flex: 5,
                child: Row(
                  children: [
                    if (valueIcon != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(valueIcon, size: 12, color: valueColor.withAlpha(160)),
                      ),
                    Flexible(
                      child: Text(
                        valueText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: valueColor,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Edit indicator
              Icon(
                Icons.edit_rounded,
                size: 14,
                color: cs.onSurface.withAlpha(40),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _countLeaves(_JsonNode node) {
    if (node.type == _JsonValueType.object || node.type == _JsonValueType.array) {
      return node.children.fold(0, (sum, c) => sum + _countLeaves(c));
    }
    return 1;
  }

  int _countNodes(_JsonNode node) {
    int count = 1;
    for (final child in node.children) {
      count += _countNodes(child);
    }
    return count;
  }
}

// ─── Editable JSON tree model ─────────────────────────────────────────────

enum _JsonValueType { object, array, string, number, boolean, null_ }

class _JsonNode {
  final String key;
  _JsonValueType type;
  dynamic value;
  final List<_JsonNode> children;
  bool isExpanded;

  _JsonNode._({
    required this.key,
    required this.type,
    this.value,
    List<_JsonNode>? children,
    this.isExpanded = true,
  }) : children = children ?? [];

  factory _JsonNode.build(String key, dynamic json) {
    if (json is Map) {
      final node = _JsonNode._(key: key, type: _JsonValueType.object);
      for (final entry in json.entries) {
        node.children.add(_JsonNode.build(entry.key as String, entry.value));
      }
      return node;
    } else if (json is List) {
      final node = _JsonNode._(key: key, type: _JsonValueType.array);
      for (int i = 0; i < json.length; i++) {
        node.children.add(_JsonNode.build('[$i]', json[i]));
      }
      return node;
    } else if (json is String) {
      return _JsonNode._(key: key, type: _JsonValueType.string, value: json);
    } else if (json is num) {
      return _JsonNode._(key: key, type: _JsonValueType.number, value: json);
    } else if (json is bool) {
      return _JsonNode._(key: key, type: _JsonValueType.boolean, value: json);
    } else {
      return _JsonNode._(key: key, type: _JsonValueType.null_, value: null);
    }
  }
}
