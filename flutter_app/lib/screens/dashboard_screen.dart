import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../providers/gateway_provider.dart';
import '../providers/node_provider.dart';
import '../widgets/gateway_controls.dart';
import '../widgets/status_card.dart';
import 'node_screen.dart';
import 'configure_screen.dart';
import 'onboarding_screen.dart';
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
              child: Icon(Icons.bolt, size: 18, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 10),
            const Text('OpenClaw'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Gateway controls
          const GatewayControls(),
          const SizedBox(height: 24),

          // Tools section
          _sectionHeader(theme, Icons.build_outlined, 'TOOLS'),
          const SizedBox(height: 4),
          StatusCard(
            title: 'Terminal',
            subtitle: 'Ubuntu shell with OpenClaw environment',
            icon: Icons.terminal,
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TerminalScreen()),
            ),
          ),
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

              return StatusCard(
                title: 'Web Dashboard',
                subtitle: subtitle,
                icon: Icons.dashboard,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (token != null)
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: 'Copy URL',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: url!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Dashboard URL copied')),
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
              );
            },
          ),
          StatusCard(
            title: 'Onboarding',
            subtitle: 'Configure API keys and binding',
            icon: Icons.vpn_key_outlined,
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const OnboardingScreen()),
            ),
          ),
          const SizedBox(height: 20),

          // Configuration section
          _sectionHeader(theme, Icons.tune_outlined, 'CONFIGURATION'),
          const SizedBox(height: 4),
          StatusCard(
            title: 'Gateway Settings',
            subtitle: 'Manage gateway configuration',
            icon: Icons.tune,
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ConfigureScreen()),
            ),
          ),
          StatusCard(
            title: 'AI Providers',
            subtitle: 'Configure models and API keys',
            icon: Icons.model_training,
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProvidersScreen()),
            ),
          ),
          StatusCard(
            title: 'Packages',
            subtitle: 'Install Go, Homebrew, SSH and more',
            icon: Icons.extension_outlined,
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PackagesScreen()),
            ),
          ),
          StatusCard(
            title: 'SSH Access',
            subtitle: 'Remote terminal access via SSH',
            icon: Icons.terminal,
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SshScreen()),
            ),
          ),
          const SizedBox(height: 20),

          // System section
          _sectionHeader(theme, Icons.monitor_outlined, 'SYSTEM'),
          const SizedBox(height: 4),
          StatusCard(
            title: 'Logs',
            subtitle: 'View gateway output and errors',
            icon: Icons.article_outlined,
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LogsScreen()),
            ),
          ),
          StatusCard(
            title: 'Backup & Restore',
            subtitle: 'Export or import configuration snapshots',
            icon: Icons.backup_outlined,
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          Consumer<NodeProvider>(
            builder: (context, nodeProvider, _) {
              final nodeState = nodeProvider.state;
              return StatusCard(
                title: 'Device Node',
                subtitle: nodeState.isPaired
                    ? 'Connected to gateway'
                    : nodeState.isDisabled
                        ? 'Device capabilities for AI'
                        : nodeState.statusText,
                icon: Icons.devices_outlined,
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NodeScreen()),
                ),
              );
            },
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
                    'v${AppConstants.version}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'by ${AppConstants.authorName} · ${AppConstants.orgName}',
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

  Widget _sectionHeader(ThemeData theme, IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
