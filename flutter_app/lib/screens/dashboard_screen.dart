import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../design/components.dart';
import '../design/tokens.dart';
import '../native/openclaw_native.dart';
import '../models/gateway_state.dart';
import '../constants.dart';
import '../providers/gateway_provider.dart';
import '../providers/node_provider.dart';
import 'node_screen.dart';
import 'configure_screen.dart';
import 'onboarding_screen.dart';
import 'setup_wizard_screen.dart';
import 'terminal_screen.dart';
import 'web_dashboard_screen.dart';
import 'logs_screen.dart';
import 'packages_screen.dart';
import 'providers_screen.dart';
import 'settings_screen.dart';
import 'ssh_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bolt, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('OpenClaw'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar estado',
            onPressed: () {
              context.read<GatewayProvider>().checkHealth();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Ajustes',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Gateway section
          const _GatewaySection().animate().fadeIn(
                duration: 300.ms,
                curve: Curves.easeOut,
              ),
          const SizedBox(height: 24),

          // Tools section
          const SectionHeader(icon: Icons.code_rounded, title: 'Herramientas'),
          const SizedBox(height: 8),
          _DashboardTile(
            icon: Icons.code_rounded,
            title: 'Terminal',
            subtitle: 'Shell Ubuntu con entorno OpenClaw',
            iconBgColor: theme.colorScheme.primary.withAlpha(15),
            iconColor: theme.colorScheme.primary,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TerminalScreen()),
            ),
          ).animate().fadeIn(
                duration: 250.ms,
                delay: 50.ms,
                curve: Curves.easeOut,
              ),
          const SizedBox(height: 8),
          Consumer<GatewayProvider>(
            builder: (context, provider, _) {
              final url = provider.state.dashboardUrl;
              final token = url != null
                  ? RegExp(r'#token=([0-9a-f]+)').firstMatch(url)?.group(1)
                  : null;
              final subtitle = provider.state.isRunning
                  ? (token != null
                      ? 'Token: ${token.substring(0, token.length > 8 ? 8 : token.length)}...'
                      : 'Open dashboard in browser')
                  : 'Start gateway first';

              return _DashboardTile(
                icon: Icons.travel_explore_rounded,
                title: 'Panel Web',
                subtitle: subtitle,
                iconBgColor: theme.colorScheme.secondary.withAlpha(15),
                iconColor: theme.colorScheme.secondary,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (token != null)
                      IconActionButton(
                        icon: Icons.copy,
                        tooltip: 'Copy URL',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: url!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('URL del panel copiada')),
                          );
                        },
                      ),
                    const Icon(Icons.chevron_right, size: 20),
                  ],
                ),
                onTap: provider.state.isRunning
                    ? () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => WebDashboardScreen(url: url),
                          ),
                        )
                    : null,
              ).animate().fadeIn(
                    duration: 250.ms,
                    delay: 100.ms,
                    curve: Curves.easeOut,
                  );
            },
          ),
          const SizedBox(height: 8),
          _DashboardTile(
            icon: Icons.vpn_lock_rounded,
            title: 'Entorno Proot',
            subtitle: 'Instalar rootfs Ubuntu, Node.js y OpenClaw',
            iconBgColor: const Color(0xFFE55E2B).withAlpha(15),
            iconColor: const Color(0xFFE55E2B),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SetupWizardScreen()),
            ),
          ).animate().fadeIn(
                duration: 250.ms,
                delay: 150.ms,
                curve: Curves.easeOut,
              ),
          const SizedBox(height: 8),
          _DashboardTile(
            icon: Icons.key_rounded,
            title: 'Claves API',
            subtitle: 'Configurar proveedores despues del runtime',
            iconBgColor: const Color(0xFF3B82F6).withAlpha(15),
            iconColor: const Color(0xFF3B82F6),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const OnboardingScreen()),
            ),
          ).animate().fadeIn(
                duration: 250.ms,
                delay: 175.ms,
                curve: Curves.easeOut,
              ),

          const SizedBox(height: 28),

          // Configuration section
          const SectionHeader(icon: Icons.tune_rounded, title: 'Configuración'),
          const SizedBox(height: 8),
          _ConfigTile(
            icon: Icons.hub_rounded,
            title: 'Ajustes del Gateway',
            subtitle: 'Administrar configuración del gateway',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ConfigureScreen()),
            ),
          ).animate().fadeIn(
                duration: 250.ms,
                delay: 200.ms,
                curve: Curves.easeOut,
              ),
          const SizedBox(height: 8),
          _ConfigTile(
            icon: Icons.psychology_alt_rounded,
            title: 'Proveedores IA',
            subtitle: 'Configurar modelos y claves API',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProvidersScreen()),
            ),
          ).animate().fadeIn(
                duration: 250.ms,
                delay: 250.ms,
                curve: Curves.easeOut,
              ),
          const SizedBox(height: 8),
          _ConfigTile(
            icon: Icons.inventory_2_rounded,
            title: 'Paquetes',
            subtitle: 'Instalar Go, Homebrew, SSH y más',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PackagesScreen()),
            ),
          ).animate().fadeIn(
                duration: 250.ms,
                delay: 300.ms,
                curve: Curves.easeOut,
              ),
          const SizedBox(height: 8),
          _ConfigTile(
            icon: Icons.lan_rounded,
            title: 'Acceso SSH',
            subtitle: 'Acceso remoto por terminal SSH',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SshScreen()),
            ),
          ).animate().fadeIn(
                duration: 250.ms,
                delay: 350.ms,
                curve: Curves.easeOut,
              ),

          const SizedBox(height: 28),

          // System section
          const SectionHeader(icon: Icons.memory_rounded, title: 'Sistema'),
          const SizedBox(height: 8),
          _ConfigTile(
            icon: Icons.receipt_long_rounded,
            title: 'Registros',
            subtitle: 'Ver salida y errores del gateway',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LogsScreen()),
            ),
          ).animate().fadeIn(
                duration: 250.ms,
                delay: 400.ms,
                curve: Curves.easeOut,
              ),
          const SizedBox(height: 8),
          _ConfigTile(
            icon: Icons.restore_page_rounded,
            title: 'Respaldo y Restauración',
            subtitle: 'Exportar o importar configuración',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ).animate().fadeIn(
                duration: 250.ms,
                delay: 450.ms,
                curve: Curves.easeOut,
              ),
          const SizedBox(height: 8),
          Consumer<NodeProvider>(
            builder: (context, nodeProvider, _) {
              final nodeState = nodeProvider.state;
              return _ConfigTile(
                icon: Icons.developer_board_rounded,
                title: 'Nodo del Dispositivo',
                subtitle: nodeState.isPaired
                    ? 'Conectado al gateway'
                    : nodeState.isDisabled
                        ? 'Capacidades del dispositivo para IA'
                        : nodeState.statusText,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NodeScreen()),
                ),
              );
            },
          ).animate().fadeIn(
                duration: 250.ms,
                delay: 500.ms,
                curve: Curves.easeOut,
              ),

          const SizedBox(height: 32),

          // Footer
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Versión ${AppConstants.version}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${AppConstants.orgName}/openclaw-termux',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Gateway section card
class _GatewaySection extends StatelessWidget {
  const _GatewaySection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<GatewayProvider>(
      builder: (context, provider, _) {
        final state = provider.state;

        return PressableCard(
          onTap: null,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withAlpha(15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.dns_outlined,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gateway',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Servidor Gateway IA',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(
                      color: state.isRunning
                          ? AppColors.statusGreen
                          : state.status == GatewayStatus.starting
                              ? AppColors.statusAmber
                              : state.status == GatewayStatus.error
                                  ? AppColors.statusRed
                                  : AppColors.statusGrey,
                      label: state.isRunning
                          ? 'Activo'
                          : state.status == GatewayStatus.starting
                              ? 'Iniciando'
                              : state.status == GatewayStatus.error
                                  ? 'Error'
                                  : 'Detenido',
                      icon: state.isRunning
                          ? Icons.check_circle
                          : state.status == GatewayStatus.starting
                              ? Icons.hourglass_top
                              : state.status == GatewayStatus.error
                                  ? Icons.error_outline
                                  : Icons.circle_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (state.isRunning) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withAlpha(8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: theme.colorScheme.primary.withAlpha(25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              final url = state.dashboardUrl ?? AppConstants.gatewayUrl;
                              OpenClawNative.openUrl(url);
                            },
                            child: Text(
                              state.dashboardUrl ?? AppConstants.gatewayUrl,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontFamily: 'monospace',
                                fontSize: 13,
                                decoration: TextDecoration.underline,
                                decorationColor: theme.colorScheme.primary.withAlpha(100),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconActionButton(
                          icon: Icons.copy,
                          tooltip: 'Copiar URL',
                          onPressed: () {
                            final url = state.dashboardUrl ?? AppConstants.gatewayUrl;
                            Clipboard.setData(ClipboardData(text: url));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('URL copiada'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        IconActionButton(
                          icon: Icons.open_in_browser,
                          tooltip: 'Abrir en navegador',
                          onPressed: () {
                            final url = state.dashboardUrl ?? AppConstants.gatewayUrl;
                            OpenClawNative.openUrl(url);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (state.errorMessage != null) ...[
                  ErrorBox(message: state.errorMessage!),
                  const SizedBox(height: 12),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (state.isStopped || state.status == GatewayStatus.error)
                      FilledButton.icon(
                        onPressed: () => provider.start(),
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('Iniciar'),
                      ),
                    if (state.isRunning || state.status == GatewayStatus.starting)
                      OutlinedButton.icon(
                        onPressed: () => provider.stop(),
                        icon: const Icon(Icons.stop, size: 18),
                        label: const Text('Detener'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LogsScreen()),
                      ),
                      icon: const Icon(Icons.article_outlined, size: 18),
                      label: const Text('Registros'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Tile for tools section — prominent with icon background
class _DashboardTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconBgColor;
  final Color iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _DashboardTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconBgColor,
    required this.iconColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PressableCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ] else ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 20, color: theme.colorScheme.onSurfaceVariant),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tile for config/system sections — compact with icon-only
class _ConfigTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ConfigTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PressableCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
