import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design/components.dart';
import '../design/tokens.dart';
import '../services/ssh_service.dart';
import 'packages_screen.dart';

class SshScreen extends StatefulWidget {
  const SshScreen({super.key});

  @override
  State<SshScreen> createState() => _SshScreenState();
}

class _SshScreenState extends State<SshScreen> {
  bool _loading = true;
  bool _installed = false;
  bool _running = false;
  bool _toggling = false;
  bool _settingPassword = false;

  final _portController = TextEditingController(text: '8022');
  final _passwordController = TextEditingController();
  List<String> _ips = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _portController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final installed = await SshService.isInstalled();
    bool running = false;
    List<String> ips = [];
    if (installed) {
      running = await SshService.isSshdRunning();
      ips = await SshService.getIpAddresses();
      if (running) {
        final port = await SshService.getPort();
        if (mounted) _portController.text = port.toString();
      }
    }
    if (mounted) {
      setState(() {
        _installed = installed;
        _running = running;
        _ips = ips;
        _loading = false;
      });
    }
  }

  Future<void> _toggleSshd() async {
    setState(() => _toggling = true);
    try {
      if (_running) {
        await SshService.stopSshd();
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        final port = int.tryParse(_portController.text.trim()) ?? 8022;
        await SshService.startSshd(port: port);
        await Future.delayed(const Duration(seconds: 2));
      }
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _setPassword() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La contraseña no puede estar vacía')),
      );
      return;
    }
    setState(() => _settingPassword = true);
    try {
      await SshService.setPassword(password);
      if (mounted) {
        _passwordController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contraseña root actualizada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _settingPassword = false);
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copiado al portapapeles')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Acceso SSH')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _installed
              ? _buildInstalledView(theme, isDark)
              : _buildNotInstalledView(theme),
    );
  }

  Widget _buildNotInstalledView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withAlpha(15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.vpn_key, size: 48, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Text(
              'OpenSSH no instalado',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Instala el paquete OpenSSH desde la pantalla de Paquetes.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PackagesScreen()),
                );
                _refresh();
              },
              icon: const Icon(Icons.extension_outlined, size: 18),
              label: const Text('Abrir Paquetes'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstalledView(ThemeData theme, bool isDark) {
    final port = _portController.text.trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _card(theme, [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (_running ? AppColors.statusGreen : AppColors.statusGrey).withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _running ? Icons.check_circle : Icons.cancel,
                        color: _running ? AppColors.statusGreen : AppColors.statusGrey,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _running ? 'Servidor SSH Activo' : 'Servidor SSH Detenido',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _running ? 'Aceptando conexiones' : 'Presiona Iniciar para habilitar',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (!_running)
                  TextField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Puerto',
                      hintText: '8022',
                      prefixIcon: Icon(Icons.numbers),
                    ),
                  ),
                if (!_running) const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: _running
                      ? OutlinedButton.icon(
                          onPressed: _toggling ? null : _toggleSshd,
                          icon: _toggling
                              ? const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.stop, size: 18),
                          label: const Text('Detener Servidor'),
                        )
                      : FilledButton.icon(
                          onPressed: _toggling ? null : _toggleSshd,
                          icon: _toggling
                              ? const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.play_arrow, size: 18),
                          label: const Text('Iniciar Servidor'),
                        ),
                ),
              ],
            ),
          ),
        ], title: 'Control del Servicio', icon: Icons.power_outlined),

        const SizedBox(height: 16),
        _card(theme, [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Establece la contraseña root para el acceso SSH.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nueva contraseña',
                    hintText: 'Ingresa contraseña',
                    prefixIcon: Icon(Icons.lock_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _settingPassword ? null : _setPassword,
                    icon: _settingPassword
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.lock_outline, size: 18),
                    label: const Text('Establecer Contraseña'),
                  ),
                ),
              ],
            ),
          ),
        ], title: 'Contraseña Root', icon: Icons.lock_outlined),

        if (_running) ...[
          const SizedBox(height: 16),
          _card(theme, [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow(theme, 'Usuario', 'root'),
                  const Divider(height: 24),
                  _infoRow(theme, 'Puerto', port),
                  if (_ips.isNotEmpty) ...[
                    const Divider(height: 24),
                    _infoRow(theme, 'Direcciones IP', _ips.join(', ')),
                  ],
                  const Divider(height: 24),
                  Text(
                    'Conéctate desde otro dispositivo:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final ip in _ips) ...[
                    _commandRow(theme, isDark, 'ssh root@$ip -p $port'),
                    const SizedBox(height: 8),
                  ],
                  if (_ips.isEmpty)
                    _commandRow(theme, isDark, 'ssh root@<device-ip> -p $port'),
                ],
              ),
            ),
          ], title: 'Información de Conexión', icon: Icons.info_outline),
        ],
      ],
    );
  }

  Widget _card(ThemeData theme, List<Widget> children, {required String title, required IconData icon}) {
    return SettingsCard(title: title, icon: icon, children: children);
  }

  Widget _infoRow(ThemeData theme, String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              SelectableText(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _commandRow(ThemeData theme, bool isDark, String command) {
    final bg = isDark ? AppColors.darkSurfaceAlt : const Color(0xFFF3F4F6);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.terminal, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              command,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 16),
            onPressed: () => _copyToClipboard(command),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
