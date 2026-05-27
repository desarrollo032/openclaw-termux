import 'package:flutter/material.dart';

/// Metadata for an AI model provider that can be configured
/// to power the OpenClaw gateway.
class AiProvider {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final String baseUrl;
  final String? fetchModelsUrl;
  final String? apiKeyHeader;
  final List<String> defaultModels;
  final String apiKeyHint;

  const AiProvider({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.baseUrl,
    this.fetchModelsUrl,
    this.apiKeyHeader,
    required this.defaultModels,
    required this.apiKeyHint,
  });

  static const anthropic = AiProvider(
    id: 'anthropic',
    name: 'Anthropic',
    description: 'Claude models — advanced reasoning and coding',
    icon: Icons.psychology,
    color: Color(0xFFD97706),
    baseUrl: 'https://api.anthropic.com/v1',
    fetchModelsUrl: 'https://api.anthropic.com/v1/models',
    apiKeyHeader: 'x-api-key',
    defaultModels: [
      'claude-sonnet-4-20250514',
      'claude-opus-4-20250514',
      'claude-haiku-4-20250506',
    ],
    apiKeyHint: 'sk-ant-...',
  );

  static const openai = AiProvider(
    id: 'openai',
    name: 'OpenAI',
    description: 'GPT and o-series models',
    icon: Icons.auto_awesome,
    color: Color(0xFF10A37F),
    baseUrl: 'https://api.openai.com/v1',
    fetchModelsUrl: 'https://api.openai.com/v1/models',
    apiKeyHeader: 'Authorization',
    defaultModels: [
      'gpt-4o',
      'gpt-4o-mini',
      'o1',
      'o1-mini',
      'gpt-4-turbo',
    ],
    apiKeyHint: 'sk-...',
  );

  static const google = AiProvider(
    id: 'google',
    name: 'Google Gemini',
    description: 'Gemini family of multimodal models',
    icon: Icons.diamond,
    color: Color(0xFF4285F4),
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
    fetchModelsUrl: 'https://generativelanguage.googleapis.com/v1beta/models',
    apiKeyHeader: 'query', // special: API key is ?key= query param
    defaultModels: [
      'gemini-2.5-pro',
      'gemini-2.5-flash',
      'gemini-2.0-flash',
      'gemini-1.5-pro',
    ],
    apiKeyHint: 'AIza...',
  );

  static const openrouter = AiProvider(
    id: 'openrouter',
    name: 'OpenRouter',
    description: 'Unified API for hundreds of models',
    icon: Icons.route,
    color: Color(0xFF6366F1),
    baseUrl: 'https://openrouter.ai/api/v1',
    fetchModelsUrl: 'https://openrouter.ai/api/v1/models',
    apiKeyHeader: 'Authorization',
    defaultModels: [
      'anthropic/claude-sonnet-4',
      'openai/gpt-4o',
      'google/gemini-2.5-pro',
      'meta-llama/llama-3.1-405b-instruct',
    ],
    apiKeyHint: 'sk-or-...',
  );

  static const nvidia = AiProvider(
    id: 'nvidia',
    name: 'NVIDIA NIM',
    description: 'GPU-optimized inference endpoints',
    icon: Icons.memory,
    color: Color(0xFF76B900),
    baseUrl: 'https://integrate.api.nvidia.com/v1',
    fetchModelsUrl: 'https://integrate.api.nvidia.com/v1/models',
    apiKeyHeader: 'Authorization',
    defaultModels: [
      'meta/llama-3.1-405b-instruct',
      'meta/llama-3.1-70b-instruct',
      'meta/llama-3.3-70b-instruct',
      'nvidia/nemotron-4-340b-instruct',
      'deepseek-ai/deepseek-r1',
    ],
    apiKeyHint: 'nvapi-...',
  );

  static const deepseek = AiProvider(
    id: 'deepseek',
    name: 'DeepSeek',
    description: 'High-performance open models',
    icon: Icons.explore,
    color: Color(0xFF0EA5E9),
    baseUrl: 'https://api.deepseek.com/v1',
    fetchModelsUrl: 'https://api.deepseek.com/v1/models',
    apiKeyHeader: 'Authorization',
    defaultModels: [
      'deepseek-chat',
      'deepseek-reasoner',
    ],
    apiKeyHint: 'sk-...',
  );

  static const xai = AiProvider(
    id: 'xai',
    name: 'xAI',
    description: 'Grok models from xAI',
    icon: Icons.bolt,
    color: Color(0xFFEF4444),
    baseUrl: 'https://api.x.ai/v1',
    fetchModelsUrl: 'https://api.x.ai/v1/models',
    apiKeyHeader: 'Authorization',
    defaultModels: [
      'grok-3',
      'grok-3-mini',
      'grok-2',
    ],
    apiKeyHint: 'xai-...',
  );

  static const ollama = AiProvider(
    id: 'ollama',
    name: 'Ollama',
    description: 'Local LLM runner — modelos open-source en tu dispositivo',
    icon: Icons.computer,
    color: Color(0xFF4338CA),
    baseUrl: 'http://localhost:11434/v1',
    defaultModels: [
      'llama3.3',
      'llama3.2',
      'mistral',
      'codellama',
      'phi-4',
      'deepseek-r1',
    ],
    apiKeyHint: 'No requiere clave (local)',
  );

  static const groq = AiProvider(
    id: 'groq',
    name: 'Groq',
    description: 'Inferencia ultrarrápida con LPU',
    icon: Icons.bolt,
    color: Color(0xFFF97316),
    baseUrl: 'https://api.groq.com/openai/v1',
    fetchModelsUrl: 'https://api.groq.com/openai/v1/models',
    apiKeyHeader: 'Authorization',
    defaultModels: [
      'llama-3.3-70b-versatile',
      'llama-3.1-8b-instant',
      'mixtral-8x7b-32768',
      'gemma2-9b-it',
    ],
    apiKeyHint: 'gsk_...',
  );

  static const mistral = AiProvider(
    id: 'mistral',
    name: 'Mistral',
    description: 'Modelos eficientes y open-source de Mistral AI',
    icon: Icons.air,
    color: Color(0xFF7C3AED),
    baseUrl: 'https://api.mistral.ai/v1',
    fetchModelsUrl: 'https://api.mistral.ai/v1/models',
    apiKeyHeader: 'Authorization',
    defaultModels: [
      'mistral-large-latest',
      'mistral-small-latest',
      'codestral-latest',
      'open-mistral-nemo',
    ],
    apiKeyHint: 'R9P...',
  );

  static const together = AiProvider(
    id: 'together',
    name: 'Together AI',
    description: 'Cloud API para modelos open-source y propietarios',
    icon: Icons.cloud,
    color: Color(0xFF0F172A),
    baseUrl: 'https://api.together.xyz/v1',
    fetchModelsUrl: 'https://api.together.xyz/v1/models',
    apiKeyHeader: 'Authorization',
    defaultModels: [
      'meta-llama/Llama-3.3-70B-Instruct-Turbo',
      'meta-llama/Llama-3.2-90B-Vision-Instruct-Turbo',
      'mistralai/Mixtral-8x22B-Instruct-v0.1',
      'deepseek-ai/DeepSeek-R1',
    ],
    apiKeyHint: 'tgpv2_...',
  );

  static const perplexity = AiProvider(
    id: 'perplexity',
    name: 'Perplexity',
    description: 'Modelos Sonar con búsqueda en tiempo real',
    icon: Icons.travel_explore,
    color: Color(0xFF1F2937),
    baseUrl: 'https://api.perplexity.ai',
    apiKeyHeader: 'Authorization',
    defaultModels: [
      'sonar-pro',
      'sonar',
      'sonar-reasoning-pro',
      'sonar-reasoning',
    ],
    apiKeyHint: 'pplx-...',
  );

  static const azure = AiProvider(
    id: 'azure',
    name: 'Azure OpenAI',
    description: 'OpenAI models hosted on Microsoft Azure',
    icon: Icons.cloud_queue,
    color: Color(0xFF0078D4),
    baseUrl: 'https://{resource}.openai.azure.com',
    apiKeyHeader: 'api-key',
    defaultModels: [
      'gpt-4o',
      'gpt-4o-mini',
      'o1',
      'gpt-4-turbo',
    ],
    apiKeyHint: 'Clave del recurso Azure',
  );

  static const cohere = AiProvider(
    id: 'cohere',
    name: 'Cohere',
    description: 'Modelos empresariales RAG y generación',
    icon: Icons.business,
    color: Color(0xFF39594D),
    baseUrl: 'https://api.cohere.com/v1',
    apiKeyHeader: 'Authorization',
    defaultModels: [
      'command-r-plus',
      'command-r',
      'command-light',
    ],
    apiKeyHint: 'Clave de Cohere',
  );

  static const replicate = AiProvider(
    id: 'replicate',
    name: 'Replicate',
    description: 'Modelos open-source como API serverless',
    icon: Icons.loop,
    color: Color(0xFF0D1117),
    baseUrl: 'https://api.replicate.com/v1',
    apiKeyHeader: 'Authorization',
    defaultModels: [
      'meta/meta-llama-3.3-70b-instruct',
      'mistralai/mistral-7b-instruct-v0.3',
      'deepseek-ai/deepseek-r1',
    ],
    apiKeyHint: 'r8_...',
  );

  /// Create a generic provider from an ID (for providers in config but not in presets).
  factory AiProvider.generic(String id) {
    return AiProvider(
      id: id,
      name: id[0].toUpperCase() + id.substring(1),
      description: 'Proveedor personalizado',
      icon: Icons.cloud_outlined,
      color: Color(0xFF6B7280),
      baseUrl: '',
      defaultModels: [],
      apiKeyHint: 'Clave API',
    );
  }

  /// All available AI providers.
  static const all = [
    anthropic,
    openai,
    google,
    openrouter,
    nvidia,
    deepseek,
    xai,
    ollama,
    groq,
    mistral,
    together,
    perplexity,
    azure,
    cohere,
    replicate,
  ];
}
