import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../design/components.dart';
import '../design/tokens.dart';
import '../providers/node_provider.dart';
import '../services/capabilities/privacy_filter.dart';
import '../services/preferences_service.dart';
import '../widgets/node_controls.dart';

class NodeScreen extends StatefulWidget {
  const NodeScreen({super.key});

  @override
  State<NodeScreen> createState() => _NodeScreenState();
}

class _NodeScreenState extends State<NodeScreen> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _isLocal = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = PreferencesService();
    await prefs.init();
    final host = prefs.nodeGatewayHost ?? '127.0.0.1';
    final port = prefs.nodeGatewayPort ?? 18789;
    final token = prefs.nodeGatewayToken ?? '';
    setState(() {
      _isLocal = host == '127.0.0.1' || host == 'localhost';
      _hostController.text = _isLocal ? '' : host;
      _portController.text = _isLocal ? '' : '$port';
      _tokenController.text = _isLocal ? '' : token;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración del Nodo')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<NodeProvider>(
              builder: (context, provider, _) {
                final state = provider.state;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    const NodeControls(showConfigButton: false),
                    const SizedBox(height: 24),

                    // Gateway Connection
                    _sectionHeader(
                        theme, Icons.link_outlined, 'CONEXIÓN DEL GATEWAY'),
                    const SizedBox(height: 4),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RadioGroup<bool>(
                              groupValue: _isLocal,
                              onChanged: (value) =>
                                  setState(() => _isLocal = value ?? true),
                              child: Column(
                                children: [
                                  ListTile(
                                    leading: const Radio<bool>(value: true),
                                    title: const Text('Gateway Local',
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500)),
                                    subtitle: const Text(
                                        'Emparejar automáticamente con el gateway en este dispositivo'),
                                    contentPadding: EdgeInsets.zero,
                                    onTap: () =>
                                        setState(() => _isLocal = true),
                                    dense: true,
                                  ),
                                  ListTile(
                                    leading: const Radio<bool>(value: false),
                                    title: const Text('Gateway Remoto',
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500)),
                                    subtitle: const Text(
                                        'Conectar a un gateway en otro dispositivo'),
                                    contentPadding: EdgeInsets.zero,
                                    onTap: () =>
                                        setState(() => _isLocal = false),
                                    dense: true,
                                  ),
                                ],
                              ),
                            ),
                            if (!_isLocal) ...[
                              const SizedBox(height: 12),
                              TextField(
                                controller: _hostController,
                                decoration: const InputDecoration(
                                  labelText: 'Host del Gateway',
                                  hintText: '192.168.1.100',
                                  prefixIcon: Icon(Icons.computer),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _portController,
                                decoration: const InputDecoration(
                                  labelText: 'Puerto del Gateway',
                                  hintText: '18789',
                                  prefixIcon: Icon(Icons.numbers),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _tokenController,
                                decoration: const InputDecoration(
                                  labelText: 'Token del Gateway',
                                  hintText: 'Pega el token de la URL del panel',
                                  helperText:
                                      'Se encuentra después de #token= en la URL del panel',
                                  prefixIcon: Icon(Icons.key),
                                ),
                                obscureText: true,
                              ),
                              const SizedBox(height: 16),
                              AnimatedBuilder(
                                animation: Listenable.merge(
                                    [_hostController, _portController]),
                                builder: (context, _) {
                                  final hostFilled =
                                      _hostController.text.trim().isNotEmpty;
                                  return SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: hostFilled
                                          ? () {
                                              final host =
                                                  _hostController.text.trim();
                                              final port = int.tryParse(
                                                      _portController.text
                                                          .trim()) ??
                                                  18789;
                                              final token =
                                                  _tokenController.text.trim();
                                              provider.connectRemote(host, port,
                                                  token: token.isNotEmpty
                                                      ? token
                                                      : null);
                                            }
                                          : null,
                                      icon: const Icon(Icons.link, size: 18),
                                      label: const Text('Conectar'),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Privacy Mode
                    _sectionHeader(
                        theme, Icons.security_outlined, 'PRIVACIDAD'),
                    const SizedBox(height: 4),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.shield_outlined,
                                    size: 20, color: theme.colorScheme.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'Modo de privacidad: ${provider.privacyFilter.modeLabel}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              provider.privacyFilter.modeDescription,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SegmentedButton<PrivacyMode>(
                              segments: const [
                                ButtonSegment(
                                  value: PrivacyMode.high,
                                  label: Text('Alta',
                                      style: TextStyle(fontSize: 12)),
                                  icon: Icon(Icons.shield, size: 16),
                                ),
                                ButtonSegment(
                                  value: PrivacyMode.medium,
                                  label: Text('Media',
                                      style: TextStyle(fontSize: 12)),
                                  icon: Icon(Icons.shield_outlined, size: 16),
                                ),
                                ButtonSegment(
                                  value: PrivacyMode.low,
                                  label: Text('Baja',
                                      style: TextStyle(fontSize: 12)),
                                  icon: Icon(Icons.lock_open, size: 16),
                                ),
                              ],
                              selected: {provider.privacyFilter.mode},
                              onSelectionChanged: (modes) {
                                if (modes.isNotEmpty) {
                                  provider.setPrivacyMode(modes.first);
                                }
                              },
                              showSelectedIcon: false,
                              style: const ButtonStyle(
                                visualDensity: VisualDensity.compact,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    _privacyColor(provider.privacyFilter.mode)
                                        .withAlpha(10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _privacyIcon(provider.privacyFilter.mode),
                                    size: 18,
                                    color: _privacyColor(
                                        provider.privacyFilter.mode),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _privacyInfo(provider.privacyFilter.mode),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Pairing Status
                    if (state.pairingCode != null) ...[
                      _sectionHeader(theme, Icons.qr_code, 'EMPAREJAMIENTO'),
                      const SizedBox(height: 4),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.statusAmber.withAlpha(15),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.qr_code,
                                    size: 48, color: AppColors.statusAmber),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Aprueba este código en el gateway:',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.primary.withAlpha(10),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        theme.colorScheme.primary.withAlpha(30),
                                  ),
                                ),
                                child: SelectableText(
                                  state.pairingCode!,
                                  style:
                                      theme.textTheme.headlineMedium?.copyWith(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                    letterSpacing: 4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Capabilities
                    _sectionHeader(
                        theme, Icons.devices_outlined, 'CAPACIDADES'),
                    const SizedBox(height: 4),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _capabilityTile(
                              theme,
                              'Audio',
                              'Grabar audio, controlar volumen y altavoz',
                              Icons.mic),
                          const Divider(height: 1),
                          _capabilityTile(
                              theme,
                              'Bluetooth',
                              'Estado, emparejados, escaneo, encender/apagar',
                              Icons.bluetooth),
                          const Divider(height: 1),
                          _capabilityTile(theme, 'Cámara',
                              'Capturar fotos y videos', Icons.camera_alt),
                          const Divider(height: 1),
                          _capabilityTile(theme, 'Canvas',
                              'No disponible en móvil', Icons.web,
                              available: false),
                          const Divider(height: 1),
                          _capabilityTile(
                              theme,
                              'Clipboard',
                              'Leer y escribir en el portapapeles',
                              Icons.content_paste),
                          const Divider(height: 1),
                          _capabilityTile(
                              theme,
                              'Display',
                              'Brillo, tiempo de pantalla, orientación',
                              Icons.brightness_medium),
                          const Divider(height: 1),
                          _capabilityTile(
                              theme,
                              'Dispositivo',
                              'Modelo, RAM, almacenamiento, versión Android',
                              Icons.phone_android),
                          const Divider(height: 1),
                          _capabilityTile(
                              theme,
                              'Archivos',
                              'Listar, leer, escribir y eliminar archivos',
                              Icons.folder_open),
                          const Divider(height: 1),
                          _capabilityTile(theme, 'Linterna',
                              'Encender/apagar el flash', Icons.flashlight_on),
                          const Divider(height: 1),
                          _capabilityTile(
                              theme,
                              'Hotspot',
                              'Activar/desactivar punto de acceso WiFi',
                              Icons.wifi_tethering),
                          const Divider(height: 1),
                          _capabilityTile(theme, 'Ubicación',
                              'Obtener coordenadas GPS', Icons.location_on),
                          const Divider(height: 1),
                          _capabilityTile(
                              theme,
                              'Macros',
                              'Automatización: tap, swipe, apps, búsqueda, settings',
                              Icons.auto_fix_high),
                          const Divider(height: 1),
                          _capabilityTile(
                              theme,
                              'Red',
                              'WiFi, datos móviles, IPs y estado de red',
                              Icons.wifi),
                          const Divider(height: 1),
                          _capabilityTile(theme, 'NFC',
                              'Estado, habilitar/deshabilitar NFC', Icons.nfc),
                          const Divider(height: 1),
                          _capabilityTile(
                              theme,
                              'Tono',
                              'Modo normal/silencio/vibración y volumen',
                              Icons.volume_up),
                          const Divider(height: 1),
                          _capabilityTile(
                              theme,
                              'Grabación de Pantalla',
                              'Grabar pantalla (requiere consentimiento)',
                              Icons.screen_share),
                          const Divider(height: 1),
                          _capabilityTile(
                              theme,
                              'Sensores',
                              'Acelerómetro, giroscopio, magnetómetro, luz, proximidad',
                              Icons.sensors),
                          const Divider(height: 1),
                          _capabilityTile(theme, 'Serial',
                              'Bluetooth y USB serie', Icons.usb),
                          const Divider(height: 1),
                          _capabilityTile(
                              theme,
                              'Telefonía',
                              'Llamadas, SMS, contactos y tipo de red',
                              Icons.phone),
                          const Divider(height: 1),
                          _capabilityTile(
                              theme,
                              'TTS',
                              'Síntesis de voz (text-to-speech)',
                              Icons.record_voice_over),
                          const Divider(height: 1),
                          _capabilityTile(theme, 'Vibración',
                              'Activar respuesta háptica', Icons.vibration),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Device Info
                    if (state.deviceId != null) ...[
                      _sectionHeader(theme, Icons.fingerprint,
                          'INFORMACIÓN DEL DISPOSITIVO'),
                      const SizedBox(height: 4),
                      Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withAlpha(15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.fingerprint,
                                size: 20, color: theme.colorScheme.primary),
                          ),
                          title: const Text('ID del Dispositivo',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w500)),
                          subtitle: SelectableText(
                            state.deviceId!,
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Logs
                    _sectionHeader(
                        theme, Icons.article_outlined, 'REGISTROS DEL NODO'),
                    const SizedBox(height: 4),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Container(
                        height: 200,
                        padding: const EdgeInsets.all(12),
                        child: state.logs.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.article_outlined,
                                        size: 32,
                                        color: theme
                                            .colorScheme.onSurfaceVariant
                                            .withAlpha(80)),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Sin registros aún',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                reverse: true,
                                itemCount: state.logs.length,
                                itemBuilder: (context, index) {
                                  final log =
                                      state.logs[state.logs.length - 1 - index];
                                  return Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 1),
                                    child: Text(
                                      log,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Color _privacyColor(PrivacyMode mode) {
    switch (mode) {
      case PrivacyMode.high:
        return AppColors.statusGreen;
      case PrivacyMode.medium:
        return AppColors.statusAmber;
      case PrivacyMode.low:
        return Colors.redAccent;
    }
  }

  IconData _privacyIcon(PrivacyMode mode) {
    switch (mode) {
      case PrivacyMode.high:
        return Icons.check_circle;
      case PrivacyMode.medium:
        return Icons.info_outline;
      case PrivacyMode.low:
        return Icons.warning_amber_rounded;
    }
  }

  String _privacyInfo(PrivacyMode mode) {
    switch (mode) {
      case PrivacyMode.high:
        return 'La IA solo puede ver datos del sistema (batería, sensores básicos). Sin cámara ni ubicación.';
      case PrivacyMode.medium:
        return 'La IA puede ver datos del sistema y del dispositivo. La ubicación tiene precisión reducida. La cámara requiere aprobación manual.';
      case PrivacyMode.low:
        return 'La IA tiene acceso casi completo. Datos personales (IMEI, contactos) nunca se comparten.';
    }
  }

  Widget _sectionHeader(ThemeData theme, IconData icon, String title) {
    return SectionHeader(icon: icon, title: title);
  }

  Widget _capabilityTile(
      ThemeData theme, String title, String subtitle, IconData icon,
      {bool available = true}) {
    final color = available ? AppColors.statusGreen : AppColors.statusAmber;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
      title: Text(title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      trailing: Icon(
        available ? Icons.check_circle : Icons.block,
        color: color,
        size: 20,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}
