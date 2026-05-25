import 'dart:convert';
import '../models/ai_provider.dart';
import 'native_bridge.dart';
import 'openclaw_config_normalizer.dart';

/// Reads and writes AI provider configuration in openclaw.json.
class ProviderConfigService {
  static const _configPath = '/root/.openclaw/openclaw.json';

  /// Escape a string for use as a single-quoted shell argument.
  static String _shellEscape(String s) {
    return "'${s.replaceAll("'", "'\\''")}'";
  }

  /// Read the current config and return a map with:
  /// - `activeModel`: the current primary model string (or null)
  /// - `providers`: Map of provider ID to its config (apiKey, model)
  static Future<Map<String, dynamic>> readConfig() async {
    try {
      final content = await NativeBridge.readRootfsFile(_configPath);
      if (content == null || content.isEmpty) {
        return {'activeModel': null, 'providers': <String, dynamic>{}};
      }
      final config = jsonDecode(content) as Map<String, dynamic>;

      // Extract active model
      String? activeModel;
      final agents = config['agents'] as Map<String, dynamic>?;
      if (agents != null) {
        final defaults = agents['defaults'] as Map<String, dynamic>?;
        if (defaults != null) {
          final model = defaults['model'] as Map<String, dynamic>?;
          if (model != null) {
            activeModel = model['primary'] as String?;
          }
        }
      }

      // Extract configured providers
      final providers = <String, dynamic>{};
      final modelsSection = config['models'] as Map<String, dynamic>?;
      if (modelsSection != null) {
        final providerEntries = modelsSection['providers'] as Map<String, dynamic>?;
        if (providerEntries != null) {
          for (final entry in providerEntries.entries) {
            providers[entry.key] = entry.value;
          }
        }
      }

      return {'activeModel': activeModel, 'providers': providers};
    } catch (_) {
      return {'activeModel': null, 'providers': <String, dynamic>{}};
    }
  }

  /// Save a provider's API key and set its model as the active model.
  /// Tries a Node.js one-liner in proot first, then falls back to a direct
  /// file write via NativeBridge.writeRootfsFile if proot/DNS is unavailable.
  static Future<void> saveProviderConfig({
    required AiProvider provider,
    required String apiKey,
    required String model,
  }) async {
    final providerIdJson = jsonEncode(provider.id);
    final apiKeyJson = jsonEncode(apiKey);
    final baseUrlJson = jsonEncode(provider.baseUrl);
    final modelJson = jsonEncode(model);
    final fullModelJson = jsonEncode('${provider.id}/$model');

    // OpenClaw 2026.5 validates model entries with both `id` and `name`.
    // Older app versions wrote only `id`, which makes every CLI command fail.
    final script = '''
const fs = require("fs");
const p = "$_configPath";
let c = {};
try { c = JSON.parse(fs.readFileSync(p, "utf8")); } catch {}
if (!c.models) c.models = {};
if (!c.models.mode) c.models.mode = "merge";
if (!c.models.providers) c.models.providers = {};
c.models.providers[$providerIdJson] = {
  apiKey: $apiKeyJson,
  baseUrl: $baseUrlJson,
  models: [{ id: $modelJson, name: $modelJson }]
};
if (!c.agents) c.agents = {};
if (!c.agents.defaults) c.agents.defaults = {};
if (!c.agents.defaults.model) c.agents.defaults.model = {};
c.agents.defaults.model.primary = $fullModelJson;
if (!c.gateway) c.gateway = {};
if (!c.gateway.mode) c.gateway.mode = "local";
if (c.models && c.models.providers) {
  for (const prov of Object.values(c.models.providers)) {
    if (!prov || !Array.isArray(prov.models)) continue;
    prov.models = prov.models
      .map((m) => typeof m === "string" ? { id: m, name: m } : m)
      .filter((m) => m && typeof m.id === "string" && m.id.length > 0)
      .map((m) => ({ ...m, name: (typeof m.name === "string" && m.name.length > 0) ? m.name : m.id }));
  }
}
fs.mkdirSync(require("path").dirname(p), { recursive: true });
fs.writeFileSync(p, JSON.stringify(c, null, 2));
''';
    try {
      await NativeBridge.runInProot(
        'node -e ${_shellEscape(script)}',
        timeout: 15,
      );
    } catch (_) {
      // Fallback: write config directly via NativeBridge file I/O
      await _saveConfigDirect(
        providerId: provider.id,
        apiKey: apiKey,
        baseUrl: provider.baseUrl,
        model: model,
      );
    }
  }

  /// Direct file-write fallback that doesn't depend on proot or DNS.
  static Future<void> _saveConfigDirect({
    required String providerId,
    required String apiKey,
    required String baseUrl,
    required String model,
  }) async {
    Map<String, dynamic> config = {};
    try {
      final content = await NativeBridge.readRootfsFile(_configPath);
      if (content != null && content.isNotEmpty) {
        config = jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (_) {
      // Start fresh
    }

    // Merge provider entry — models must be objects with `id`, not bare strings (#83, #88).
    config['models'] ??= <String, dynamic>{};
    (config['models'] as Map<String, dynamic>)['mode'] = 'merge';
    (config['models'] as Map<String, dynamic>)['providers'] ??= <String, dynamic>{};
    ((config['models'] as Map<String, dynamic>)['providers'] as Map<String, dynamic>)[providerId] = {
      'apiKey': apiKey,
      'baseUrl': baseUrl,
      'models': [
        {'id': model, 'name': model},
      ],
    };

    // Set active model
    config['agents'] ??= <String, dynamic>{};
    (config['agents'] as Map<String, dynamic>)['defaults'] ??= <String, dynamic>{};
    ((config['agents'] as Map<String, dynamic>)['defaults'] as Map<String, dynamic>)['model'] ??= <String, dynamic>{};
    (((config['agents'] as Map<String, dynamic>)['defaults'] as Map<String, dynamic>)['model'] as Map<String, dynamic>)['primary'] = '$providerId/$model';

    // Ensure gateway.mode is set (#93, #90)
    config['gateway'] ??= <String, dynamic>{};
    (config['gateway'] as Map<String, dynamic>)['mode'] ??= 'local';
    OpenClawConfigNormalizer.repairConfig(config);

    const encoder = JsonEncoder.withIndent('  ');
    await NativeBridge.writeRootfsFile(_configPath, encoder.convert(config));
  }

  static Future<void> repairExistingConfig() async {
    try {
      final content = await NativeBridge.readRootfsFile(_configPath);
      if (content == null || content.isEmpty) return;
      final config = Map<String, dynamic>.from(jsonDecode(content) as Map);
      if (!OpenClawConfigNormalizer.repairConfig(config)) return;

      const encoder = JsonEncoder.withIndent('  ');
      await NativeBridge.writeRootfsFile(_configPath, encoder.convert(config));
    } catch (_) {
      // Best effort: malformed JSON can still be replaced by saving provider
      // settings again or by running openclaw doctor --fix.
    }
  }

  /// Remove a provider's config entry and clear the active model if it
  /// belonged to this provider.
  static Future<void> removeProviderConfig({
    required AiProvider provider,
  }) async {
    final providerIdJson = jsonEncode(provider.id);
    // Build a list of this provider's known model names so we can clear
    // the active model if it matches one of them.
    final modelsJson = jsonEncode(provider.defaultModels);

    final script = '''
const fs = require("fs");
const p = "$_configPath";
let c = {};
try { c = JSON.parse(fs.readFileSync(p, "utf8")); } catch {}
if (c.models && c.models.providers) {
  delete c.models.providers[$providerIdJson];
}
const known = $modelsJson;
if (c.agents && c.agents.defaults && c.agents.defaults.model) {
  const cur = c.agents.defaults.model.primary;
  if (cur && known.some(m => cur.includes(m))) {
    delete c.agents.defaults.model.primary;
  }
}
fs.writeFileSync(p, JSON.stringify(c, null, 2));
''';
    await NativeBridge.runInProot(
      'node -e ${_shellEscape(script)}',
      timeout: 15,
    );
  }
}
