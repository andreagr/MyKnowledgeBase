/// Built-in provider list used when the backend omits `available_providers`.
const List<LlmProviderInfo> kFallbackLlmProviders = [
  LlmProviderInfo(
    id: 'deepseek',
    name: 'DeepSeek',
    models: ['deepseek-chat', 'deepseek-reasoner'],
    defaultModel: 'deepseek-chat',
  ),
  LlmProviderInfo(
    id: 'openai',
    name: 'OpenAI',
    models: ['gpt-4o', 'gpt-4o-mini', 'gpt-4.1', 'gpt-4.1-mini'],
    defaultModel: 'gpt-4o-mini',
  ),
  LlmProviderInfo(
    id: 'anthropic',
    name: 'Anthropic',
    models: [
      'claude-sonnet-4-20250514',
      'claude-3-5-haiku-latest',
      'claude-3-5-sonnet-latest',
    ],
    defaultModel: 'claude-sonnet-4-20250514',
  ),
  LlmProviderInfo(
    id: 'google',
    name: 'Google Gemini',
    models: [
      'gemini-2.0-flash',
      'gemini-2.0-flash-lite',
      'gemini-2.5-pro-preview-05-06',
    ],
    defaultModel: 'gemini-2.0-flash',
  ),
];

/// Metadata for a supported LLM provider.
class LlmProviderInfo {
  final String id;
  final String name;
  final List<String> models;
  final String defaultModel;
  final bool hasCustomKey;
  final String apiKeyPreview;

  const LlmProviderInfo({
    required this.id,
    required this.name,
    required this.models,
    required this.defaultModel,
    this.hasCustomKey = false,
    this.apiKeyPreview = '',
  });

  factory LlmProviderInfo.fromJson(Map<String, dynamic> json) {
    return LlmProviderInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      models: (json['models'] as List<dynamic>).map((e) => e as String).toList(),
      defaultModel: json['default_model'] as String,
      hasCustomKey: json['has_custom_key'] as bool? ?? false,
      apiKeyPreview: json['api_key_preview'] as String? ?? '',
    );
  }
}

/// LLM / intelligence configuration returned by the backend.
class IntelligenceConfig {
  final String provider;
  final String providerName;
  final String model;
  final bool hasCustomKey;
  final String apiKeyPreview;
  final List<String> availableModels;
  final List<LlmProviderInfo> availableProviders;
  final String? updatedAt;

  const IntelligenceConfig({
    required this.provider,
    required this.providerName,
    required this.model,
    required this.hasCustomKey,
    required this.apiKeyPreview,
    required this.availableModels,
    required this.availableProviders,
    this.updatedAt,
  });

  bool get isKeyConfigured => hasCustomKey;

  LlmProviderInfo? get currentProviderInfo {
    for (final info in availableProviders) {
      if (info.id == provider) return info;
    }
    return availableProviders.isNotEmpty ? availableProviders.first : null;
  }

  factory IntelligenceConfig.fromJson(Map<String, dynamic> json) {
    return IntelligenceConfig(
      provider: json['provider'] as String? ?? 'deepseek',
      providerName: json['provider_name'] as String? ?? 'DeepSeek',
      model: json['model'] as String? ?? 'deepseek-chat',
      hasCustomKey: json['has_custom_key'] as bool? ?? false,
      apiKeyPreview: json['api_key_preview'] as String? ?? '',
      availableModels: (json['available_models'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const ['deepseek-chat', 'deepseek-reasoner'],
      availableProviders: _parseAvailableProviders(json['available_providers']),
      updatedAt: json['updated_at'] as String?,
    );
  }
}

List<LlmProviderInfo> _parseAvailableProviders(dynamic raw) {
  if (raw is! List || raw.isEmpty) {
    return kFallbackLlmProviders;
  }
  return raw
      .map((e) => LlmProviderInfo.fromJson(e as Map<String, dynamic>))
      .toList();
}

class IntelligenceConfigUpdate {
  final String provider;
  final String model;
  final String? apiKey;

  const IntelligenceConfigUpdate({
    required this.provider,
    required this.model,
    this.apiKey,
  });

  Map<String, dynamic> toJson() {
    return {
      'provider': provider,
      'model': model,
      if (apiKey != null && apiKey!.isNotEmpty) 'api_key': apiKey,
    };
  }
}
