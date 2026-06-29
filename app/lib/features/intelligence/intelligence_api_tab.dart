import 'package:flutter/material.dart';

import '../../core/models/intelligence_config.dart';
import '../../design_system/design_system.dart';

/// Cloud provider, API key, and model configuration.
class IntelligenceApiTab extends StatelessWidget {
  final IntelligenceConfig config;
  final String provider;
  final String model;
  final bool obscureApiKey;
  final TextEditingController apiKeyController;
  final ValueChanged<String?> onProviderChanged;
  final ValueChanged<String?> onModelChanged;
  final VoidCallback onToggleApiKeyVisibility;

  const IntelligenceApiTab({
    super.key,
    required this.config,
    required this.provider,
    required this.model,
    required this.obscureApiKey,
    required this.apiKeyController,
    required this.onProviderChanged,
    required this.onModelChanged,
    required this.onToggleApiKeyVisibility,
  });

  LlmProviderInfo? _providerInfo() {
    for (final info in config.availableProviders) {
      if (info.id == provider) return info;
    }
    return config.currentProviderInfo;
  }

  List<String> _modelsForProvider() {
    return _providerInfo()?.models ?? config.availableModels;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final providerInfo = _providerInfo();
    final providerName = providerInfo?.name ?? config.providerName;
    final models = _modelsForProvider();
    final hasCustomKey = providerInfo?.hasCustomKey ?? config.hasCustomKey;
    final apiKeyPreview = providerInfo?.apiKeyPreview ?? config.apiKeyPreview;
    final selectedModel = models.contains(model) ? model : models.first;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Use your own API key with an online model. Keys stay on this device.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Provider', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            key: ValueKey(provider),
            initialValue: config.availableProviders.any((p) => p.id == provider)
                ? provider
                : config.availableProviders.first.id,
            decoration: const InputDecoration(
              labelText: 'LLM provider',
            ),
            items: config.availableProviders
                .map(
                  (p) => DropdownMenuItem<String>(
                    value: p.id,
                    child: Text(p.name),
                  ),
                )
                .toList(),
            onChanged: config.availableProviders.length <= 1
                ? null
                : onProviderChanged,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('API key', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Use your own key from the provider\'s dashboard. It is stored locally and never shared.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: apiKeyController,
            obscureText: obscureApiKey,
            decoration: InputDecoration(
              labelText: '$providerName API key',
              hintText: hasCustomKey
                  ? 'Leave blank to keep $apiKeyPreview'
                  : 'Paste your API key',
              suffixIcon: IconButton(
                icon: Icon(
                  obscureApiKey
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: onToggleApiKeyVisibility,
              ),
            ),
          ),
          if (hasCustomKey) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Saved key: $apiKeyPreview',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Text('Model', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            key: ValueKey(selectedModel),
            initialValue: selectedModel,
            decoration: const InputDecoration(
              labelText: 'Chat model',
            ),
            items: models
                .map(
                  (m) => DropdownMenuItem<String>(
                    value: m,
                    child: Text(m),
                  ),
                )
                .toList(),
            onChanged: onModelChanged,
          ),
          const SizedBox(height: AppSpacing.xl),
          _ApiStatusTile(
            hasCustomKey: hasCustomKey,
            providerName: providerName,
            model: selectedModel,
          ),
        ],
      ),
    );
  }
}

class _ApiStatusTile extends StatelessWidget {
  final bool hasCustomKey;
  final String providerName;
  final String model;

  const _ApiStatusTile({
    required this.hasCustomKey,
    required this.providerName,
    required this.model,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = hasCustomKey ? AppColors.success : AppColors.error;
    final icon =
        hasCustomKey ? Icons.check_circle_outline : Icons.error_outline;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasCustomKey
                      ? 'Ready to answer questions'
                      : 'API key required',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  hasCustomKey
                      ? 'Chat will use $providerName · $model with your API key.'
                      : 'Enter and save your API key before asking questions.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
