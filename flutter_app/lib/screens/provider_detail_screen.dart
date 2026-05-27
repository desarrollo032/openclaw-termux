import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_animate/flutter_animate.dart';
import '../design/components.dart';
import '../models/ai_provider.dart';
import '../services/provider_config_service.dart';

class ProviderDetailScreen extends StatefulWidget {
  final AiProvider provider;
  final String? existingApiKey;
  final String? existingModel;

  const ProviderDetailScreen({
    super.key,
    required this.provider,
    this.existingApiKey,
    this.existingModel,
  });

  @override
  State<ProviderDetailScreen> createState() => _ProviderDetailScreenState();
}

class _ProviderDetailScreenState extends State<ProviderDetailScreen> {
  static const _customModelSentinel = '__custom__';

  late final TextEditingController _apiKeyController;
  late final TextEditingController _customModelController;
  late String _selectedModel;
  bool _isCustomModel = false;
  bool _obscureKey = true;
  bool _saving = false;
  bool _removing = false;
  bool _browsingModels = false;

  bool get _isConfigured {
    final key = widget.existingApiKey;
    return key != null && key.isNotEmpty;
  }
  String get _effectiveModel =>
      _isCustomModel ? _customModelController.text.trim() : _selectedModel;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: widget.existingApiKey ?? '');
    _customModelController = TextEditingController();

    final existing = widget.existingModel ?? widget.provider.defaultModels.first;
    if (widget.provider.defaultModels.contains(existing)) {
      _selectedModel = existing;
    } else {
      _selectedModel = _customModelSentinel;
      _isCustomModel = true;
      _customModelController.text = existing;
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _customModelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La clave API no puede estar vacía')),
      );
      return;
    }
    final model = _effectiveModel;
    if (model.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre del modelo no puede estar vacío')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ProviderConfigService.saveProviderConfig(
        provider: widget.provider,
        apiKey: apiKey,
        model: model,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.provider.name} configurado y activado')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _browseModels() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa una clave API primero')),
      );
      return;
    }

    final url = widget.provider.fetchModelsUrl;
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Navegación de modelos no disponible')),
      );
      return;
    }

    setState(() => _browsingModels = true);
    try {
      final uri = Uri.parse(url);
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

      if (widget.provider.apiKeyHeader == 'query') {
        // API key goes as query param for Google
      } else if (widget.provider.apiKeyHeader != null) {
        headers[widget.provider.apiKeyHeader!] = widget.provider.id == 'anthropic'
            ? apiKey
            : 'Bearer $apiKey';
      }

      final requestUri = widget.provider.apiKeyHeader == 'query'
          ? uri.replace(queryParameters: {'key': apiKey})
          : uri;

      final response = await http
          .get(requestUri, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error API: ${response.statusCode}')),
          );
        }
        return;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      List<String> modelIds = [];

      if (widget.provider.id == 'google') {
        final models = body['models'] as List<dynamic>?;
        if (models != null) {
          for (final m in models) {
            if (m is Map<String, dynamic>) {
              final name = m['name'] as String?;
              if (name != null) {
                modelIds.add(name.startsWith('models/') ? name.substring(7) : name);
              }
            }
          }
        }
      } else {
        final data = body['data'] as List<dynamic>?;
        if (data != null) {
          for (final item in data) {
            if (item is Map<String, dynamic>) {
              final id = item['id'] as String?;
              if (id != null) modelIds.add(id);
            }
          }
        }
      }

      if (modelIds.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se encontraron modelos')),
          );
        }
        return;
      }

      if (mounted) {
        _showModelPickerDialog(modelIds);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al obtener modelos: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _browsingModels = false);
    }
  }

  void _showModelPickerDialog(List<String> modelIds) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _ModelPickerSheet(
          models: modelIds,
          onSelected: (model) {
            Navigator.pop(ctx);
            setState(() {
              _selectedModel = model;
              _isCustomModel = false;
            });
          },
        );
      },
    );
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Eliminar ${widget.provider.name}?'),
        content: const Text('Esto eliminará la clave API y desactivará el modelo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _removing = true);
    try {
      await ProviderConfigService.removeProviderConfig(provider: widget.provider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.provider.name} eliminado')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.provider.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Provider header
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: widget.provider.color.withAlpha(15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(widget.provider.icon, color: widget.provider.color, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.provider.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.provider.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isConfigured)
                    StatusBadge.active('Activo'),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 300.ms, curve: Curves.easeOut),
          const SizedBox(height: 28),

          // API Key section
          const SectionHeader(icon: Icons.key, title: 'CLAVE API'),
          const SizedBox(height: 8),
          Text(
            'Ingresa tu clave de API de ${widget.provider.name}.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKeyController,
            obscureText: _obscureKey,
            decoration: InputDecoration(
              hintText: widget.provider.apiKeyHint,
              prefixIcon: const Icon(Icons.key),
              suffixIcon: IconButton(
                icon: Icon(_obscureKey ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Model section
          const SectionHeader(icon: Icons.model_training, title: 'MODELO'),
          const SizedBox(height: 8),
          Text(
            'Selecciona qué modelo usar con este proveedor.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedModel,
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.model_training),
            ),
            items: [
              ...widget.provider.defaultModels
                  .map((m) => DropdownMenuItem(value: m, child: Text(m))),
              const DropdownMenuItem(
                value: _customModelSentinel,
                child: Text('Personalizado...'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedModel = value;
                  _isCustomModel = value == _customModelSentinel;
                });
              }
            },
          ),
          if (_isCustomModel) ...{
            const SizedBox(height: 12),
            TextField(
              controller: _customModelController,
              decoration: const InputDecoration(
                hintText: 'ej. meta/llama-3.3-70b-instruct',
                labelText: 'Nombre del modelo personalizado',
                prefixIcon: Icon(Icons.edit_outlined),
              ),
            ),
          },
          const SizedBox(height: 8),
          if (widget.provider.fetchModelsUrl != null) ...{
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _browsingModels ? null : _browseModels,
                icon: _browsingModels
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_download_outlined, size: 18),
                label: Text(_browsingModels ? 'Cargando...' : 'Explorar modelos disponibles'),
              ),
            ),
          },
          const SizedBox(height: 28),

          // Actions
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(_saving ? 'Guardando...' : 'Guardar y Activar'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          if (_isConfigured) ...{
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _removing ? null : _remove,
                icon: _removing
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline, size: 18),
                label: Text(_removing ? 'Eliminando...' : 'Eliminar Configuración'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          },
        ],
      ),
    );
  }
}

/// A searchable bottom sheet that displays a list of model IDs.
class _ModelPickerSheet extends StatefulWidget {
  final List<String> models;
  final ValueChanged<String> onSelected;

  const _ModelPickerSheet({
    required this.models,
    required this.onSelected,
  });

  @override
  State<_ModelPickerSheet> createState() => _ModelPickerSheetState();
}

class _ModelPickerSheetState extends State<_ModelPickerSheet> {
  final _searchController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _filtered {
    if (_filter.isEmpty) return widget.models;
    final q = _filter.toLowerCase();
    return widget.models.where((m) => m.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filtered;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: true,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withAlpha(60),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_filter.isEmpty ? widget.models.length : _filtered.length} de ${widget.models.length} modelos',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Buscar modelos...',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _filter = v),
              ),
            ),
            const SizedBox(height: 8),
            // Model list
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: EmptyState(
                          icon: Icons.search_off,
                          title: _filter.isEmpty
                              ? 'Sin modelos'
                              : 'Sin resultados',
                          subtitle: _filter.isEmpty
                              ? 'No hay modelos disponibles'
                              : 'No se encontraron modelos para "$_filter"',
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final model = filtered[i];
                        return ListTile(
                          title: Text(
                            model,
                            style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withAlpha(10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.arrow_forward_ios,
                              size: 12,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          dense: true,
                          onTap: () => widget.onSelected(model),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
