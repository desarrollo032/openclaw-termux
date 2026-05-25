import 'package:flutter_test/flutter_test.dart';
import 'package:openclaw/models/ai_provider.dart';
import 'package:openclaw/services/openclaw_config_normalizer.dart';

void main() {
  test('provider entry writes model id and name required by OpenClaw', () {
    final entry = OpenClawConfigNormalizer.providerEntry(
      provider: AiProvider.google,
      apiKey: 'AIza-test',
      model: 'gemini-2.5-pro',
    );

    expect(entry['apiKey'], 'AIza-test');
    expect(entry['baseUrl'], AiProvider.google.baseUrl);
    expect(entry['models'], [
      {'id': 'gemini-2.5-pro', 'name': 'gemini-2.5-pro'},
    ]);
  });

  test('repairConfig converts old provider models to named model objects', () {
    final config = <String, dynamic>{
      'agents': {
        'defaults': {
          'model': {'primary': 'gemini-2.5-pro'},
        },
      },
      'models': {
        'providers': {
          'google': {
            'models': [
              {'id': 'gemini-2.5-pro'},
              {'id': 'gemini-2.0-flash', 'name': 'Gemini Flash'},
            ],
          },
          'openai': {
            'models': ['gpt-4o'],
          },
        },
      },
    };

    final changed = OpenClawConfigNormalizer.repairConfig(config);
    final providers =
        (config['models'] as Map<String, dynamic>)['providers'] as Map;

    expect(changed, isTrue);
    expect((config['models'] as Map<String, dynamic>)['mode'], 'merge');
    expect(
      (providers['google'] as Map)['models'],
      [
        {'id': 'gemini-2.5-pro', 'name': 'gemini-2.5-pro'},
        {'id': 'gemini-2.0-flash', 'name': 'Gemini Flash'},
      ],
    );
    expect(
      (providers['openai'] as Map)['models'],
      [
        {'id': 'gpt-4o', 'name': 'gpt-4o'},
      ],
    );
    expect(
      (((config['agents'] as Map)['defaults'] as Map)['model'] as Map)['primary'],
      'google/gemini-2.5-pro',
    );
  });
}
