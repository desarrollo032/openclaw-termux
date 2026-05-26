import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../design/components.dart';
import '../design/tokens.dart';
import '../models/node_state.dart';
import '../providers/node_provider.dart';
import '../screens/node_screen.dart';

class NodeControls extends StatelessWidget {
  const NodeControls({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<NodeProvider>(
      builder: (context, provider, _) {
        final state = provider.state;

        return Card(
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
                        color: AppColors.statusGreen.withAlpha(15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.devices_outlined,
                        color: AppColors.statusGreen,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Node',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Capacidades del dispositivo',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _statusBadge(state.status),
                  ],
                ),
                const SizedBox(height: 12),
                if (state.isPaired) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.statusGreen.withAlpha(10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.statusGreen.withAlpha(30),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.link, size: 16, color: AppColors.statusGreen),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Conectado a ${state.gatewayHost}:${state.gatewayPort}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.statusGreen,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (state.pairingCode != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.statusAmber.withAlpha(10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.statusAmber.withAlpha(30),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.qr_code, size: 16, color: AppColors.statusAmber),
                        const SizedBox(width: 8),
                        Text(
                          'Código de vinculación: ',
                          style: theme.textTheme.bodySmall,
                        ),
                        SelectableText(
                          state.pairingCode!,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: AppColors.statusAmber,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (state.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withAlpha(15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            size: 16, color: theme.colorScheme.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.errorMessage!,
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (state.isDisabled)
                      FilledButton.icon(
                        onPressed: () => provider.enable(),
                        icon: const Icon(Icons.power_settings_new, size: 18),
                        label: const Text('Habilitar'),
                      ),
                    if (!state.isDisabled) ...[
                      OutlinedButton.icon(
                        onPressed: () => provider.disable(),
                        icon: const Icon(Icons.stop, size: 18),
                        label: const Text('Deshabilitar'),
                      ),
                      if (state.status == NodeStatus.error ||
                          state.status == NodeStatus.disconnected)
                        OutlinedButton.icon(
                          onPressed: () => provider.reconnect(),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Reconectar'),
                        ),
                    ],
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const NodeScreen()),
                      ),
                      icon: const Icon(Icons.settings, size: 18),
                      label: const Text('Configurar'),
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

  Widget _statusBadge(NodeStatus status) {
    switch (status) {
      case NodeStatus.paired:
        return StatusBadge.active('Vinculado');
      case NodeStatus.connecting:
      case NodeStatus.challenging:
      case NodeStatus.pairing:
        return StatusBadge.loading('Conectando');
      case NodeStatus.error:
        return StatusBadge.error('Error');
      case NodeStatus.disabled:
        return StatusBadge.inactive('Deshabilitado');
      case NodeStatus.disconnected:
        return const StatusBadge(
          color: AppColors.statusGrey,
          label: 'Sin conexión',
          icon: Icons.link_off,
        );
    }
  }
}
