import 'package:flutter/material.dart';
import '../app.dart';
import '../models/ai_provider.dart';
import '../services/provider_config_service.dart';
import 'provider_detail_screen.dart';

class ProvidersScreen extends StatefulWidget {
  const ProvidersScreen({super.key});

  @override
  State<ProvidersScreen> createState() => _ProvidersScreenState();
}

class _ProvidersScreenState extends State<ProvidersScreen> {
  String? _activeModel;
  Map<String, dynamic> _providers = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final config = await ProviderConfigService.readConfig();
    if (mounted) {
      setState(() {
        _activeModel = config['activeModel'] as String?;
        _providers = config['providers'] as Map<String, dynamic>? ?? {};
        _loading = false;
      });
    }
  }

  Future<void> _openProvider(AiProvider provider) async {
    final providerConfig = _providers[provider.id] as Map<String, dynamic>?;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProviderDetailScreen(
          provider: provider,
          existingApiKey: providerConfig?['apiKey'] as String?,
          existingModel: _activeModel,
        ),
      ),
    );
    if (result == true) _refresh();
  }

  String _statusLabel(AiProvider provider) {
    final isConfigured = _providers.containsKey(provider.id);
    if (!isConfigured) return '';
    final activeModel = _activeModel;
    if (activeModel != null) {
      final isActive = provider.defaultModels.any((m) => activeModel.contains(m)) ||
          activeModel.contains(provider.id);
      if (isActive) return 'Activo';
    }
    return 'Configurado';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeModel = _activeModel;

    return Scaffold(
      appBar: AppBar(title: const Text('Proveedores IA')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
              if (activeModel != null && activeModel.isNotEmpty)
                ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.statusGreen.withAlpha(12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.statusGreen.withAlpha(30)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.statusGreen.withAlpha(25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.check_circle, color: AppColors.statusGreen, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Modelo Activo',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.statusGreen,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                            Text(
                              activeModel,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Selecciona un proveedor para configurar su clave API y modelo.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                for (final provider in AiProvider.all)
                  _buildProviderCard(theme, provider),
              ],
            ),
    );
  }

  Widget _buildProviderCard(ThemeData theme, AiProvider provider) {
    final isConfigured = _providers.containsKey(provider.id);
    final status = _statusLabel(provider);
    final statusColor = status == 'Activo' ? AppColors.statusGreen : AppColors.statusAmber;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openProvider(provider),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: provider.color.withAlpha(15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(provider.icon, color: provider.color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          provider.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (status.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withAlpha(20),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              status,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                        if (isConfigured && status.isEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.mutedText.withAlpha(20),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Configurado',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.mutedText,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      provider.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 22, color: AppColors.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}
