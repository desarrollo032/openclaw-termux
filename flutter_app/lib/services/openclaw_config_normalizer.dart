import '../models/ai_provider.dart';

class OpenClawConfigNormalizer {
  OpenClawConfigNormalizer._();

  static Map<String, dynamic> providerEntry({
    required AiProvider provider,
    required String apiKey,
    required String model,
  }) {
    return {
      'apiKey': apiKey,
      'baseUrl': provider.baseUrl,
      'models': [
        {'id': model, 'name': model},
      ],
    };
  }

  static bool repairConfig(Map<String, dynamic> config) {
    var modified = false;

    final gateway = _ensureMap(config, 'gateway');
    if (gateway['mode'] == null) {
      gateway['mode'] = 'local';
      modified = true;
    }
    if (gateway.containsKey('plugins')) {
      gateway.remove('plugins');
      modified = true;
    }

    final models = _ensureMap(config, 'models');
    if (models['mode'] != 'merge') {
      models['mode'] = 'merge';
      modified = true;
    }

    final providersRaw = models['providers'];
    if (providersRaw is Map) {
      // Convert to Map<String, dynamic> to avoid runtime type errors when
      // mutating nested maps that were created with more specific value types.
      final providers = Map<String, dynamic>.from(providersRaw);
      models['providers'] = providers;

      for (final providerEntry in providers.entries) {
        final providerId = providerEntry.key.toString();
        var provider = providerEntry.value;
        if (provider is! Map) continue;

        provider = Map<String, dynamic>.from(provider);
        providers[providerId] = provider;

        final modelEntries = provider['models'];
        if (modelEntries is! List) continue;

        final repairedModels = <Map<String, dynamic>>[];
        var modelListModified = false;

        for (final item in modelEntries) {
          final repaired = _repairModelEntry(item);
          if (repaired == null) {
            modelListModified = true;
            continue;
          }
          if (!_modelEntryEquals(item, repaired)) {
            modelListModified = true;
          }
          repairedModels.add(repaired);
        }

        if (modelListModified) {
          provider['models'] = repairedModels;
          modified = true;
        }

        modified = _normalizePrimary(config, providerId, repairedModels) || modified;
      }
    }

    return modified;
  }

  static Map<String, dynamic> _ensureMap(
    Map<String, dynamic> parent,
    String key,
  ) {
    final existing = parent[key];
    if (existing is Map) {
      // Always create a new Map<String, dynamic> to avoid runtime type
      // errors when the existing map has a more specific value type
      // (e.g., Map<String, Map<String, dynamic>>).
      final converted = Map<String, dynamic>.from(existing);
      parent[key] = converted;
      return converted;
    }
    final created = <String, dynamic>{};
    parent[key] = created;
    return created;
  }

  static Map<String, dynamic>? _repairModelEntry(Object? item) {
    if (item is String) {
      final id = item.trim();
      if (id.isEmpty) return null;
      return {'id': id, 'name': id};
    }

    if (item is Map) {
      final repaired = Map<String, dynamic>.from(item);
      final id = repaired['id'];
      final name = repaired['name'];
      if (id is! String || id.trim().isEmpty) return null;
      if (name is! String || name.trim().isEmpty) {
        repaired['name'] = id;
      }
      return repaired;
    }

    return null;
  }

  static bool _modelEntryEquals(Object? original, Map<String, dynamic> repaired) {
    if (original is! Map) return false;
    if (original.length != repaired.length) return false;
    for (final entry in repaired.entries) {
      if (original[entry.key] != entry.value) return false;
    }
    return true;
  }

  static bool _normalizePrimary(
    Map<String, dynamic> config,
    String providerId,
    List<Map<String, dynamic>> providerModels,
  ) {
    final agents = config['agents'];
    if (agents is! Map) return false;
    final defaults = agents['defaults'];
    if (defaults is! Map) return false;
    final model = defaults['model'];
    if (model is! Map) return false;
    final primary = model['primary'];
    if (primary is! String || primary.contains('/')) return false;

    final hasMatchingModel = providerModels.any((entry) => entry['id'] == primary);
    if (!hasMatchingModel) return false;

    model['primary'] = '$providerId/$primary';
    return true;
  }
}
