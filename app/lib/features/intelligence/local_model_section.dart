import 'package:flutter/material.dart';

import '../../core/models/local_llm_compatibility.dart';
import '../../design_system/design_system.dart';

/// Scans the PC and shows a managed local model recommendation.
class LocalModelSection extends StatelessWidget {
  final LocalLlmCompatibility? compatibility;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRescan;
  final bool showTitle;

  const LocalModelSection({
    super.key,
    required this.compatibility,
    required this.isLoading,
    required this.errorMessage,
    required this.onRescan,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: showTitle
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Local model (this PC)',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'We scan your computer and pick a model that fits. '
                          'Download and setup are handled by the app — no manual steps.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'We scan your computer and pick a model that fits. '
                      'Download and setup are handled by the app — no manual steps.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              onPressed: isLoading ? null : onRescan,
              tooltip: 'Scan again',
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 20),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _buildBody(context),
      ],
    );
  }

  List<LocalModelInfo> _alternativeModels(LocalLlmCompatibility result) {
    final recommendedId = result.recommendedModel?.id;
    return result.fittingModels
        .where((model) => model.id != recommendedId)
        .toList();
  }

  Widget _buildBody(BuildContext context) {
    if (isLoading && compatibility == null) {
      return const _ScanningCard();
    }

    if (errorMessage != null && compatibility == null) {
      return _MessageCard(
        icon: Icons.error_outline,
        color: AppColors.error,
        title: 'Could not scan this PC',
        subtitle: errorMessage!,
        action: TextButton.icon(
          onPressed: onRescan,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Try again'),
        ),
      );
    }

    final result = compatibility;
    if (result == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SpecsRow(specs: result.specs),
        const SizedBox(height: AppSpacing.md),
        if (!result.compatible) ...[
          _MessageCard(
            icon: Icons.block_outlined,
            color: AppColors.warning,
            title: 'Local model not available on this PC',
            subtitle: result.blockers.join('\n'),
          ),
        ] else ...[
          if (result.recommendedModel != null)
            _RecommendedModelCard(
              model: result.recommendedModel!,
              reason: result.recommendationReason,
            ),
          if (result.warnings.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ...result.warnings.map(
              (warning) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: _InlineNote(
                  icon: Icons.info_outline,
                  color: AppColors.warning,
                  text: warning,
                ),
              ),
            ),
          ],
          if (_alternativeModels(result).isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _AlternativesList(models: _alternativeModels(result)),
          ],
          const SizedBox(height: AppSpacing.md),
          _ManagedSetupNote(),
        ],
      ],
    );
  }
}

class _ScanningCard extends StatelessWidget {
  const _ScanningCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: AppColors.separatorLight),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Checking memory, disk space, and GPU…',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecsRow extends StatelessWidget {
  final LocalLlmSpecs specs;

  const _SpecsRow({required this.specs});

  @override
  Widget build(BuildContext context) {
    final chips = <String>[
      '${specs.totalRamGb.toStringAsFixed(0)} GB RAM',
      '${specs.freeDiskGb.toStringAsFixed(0)} GB free disk',
      '${specs.cpuCores} CPU cores',
      if (specs.hasGpu && specs.vramGb != null)
        '${specs.vramGb!.toStringAsFixed(0)} GB GPU',
    ];

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: chips
          .map(
            (label) => Chip(
              label: Text(label),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          )
          .toList(),
    );
  }
}

class _RecommendedModelCard extends StatelessWidget {
  final LocalModelInfo model;
  final String reason;

  const _RecommendedModelCard({
    required this.model,
    required this.reason,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accentMuted,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.memory_outlined, size: 20, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Recommended for you',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.accent,
                  ),
                ),
              ),
              Text(
                '~${model.downloadSizeGb.toStringAsFixed(1)} GB download',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(model.name, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            reason.isNotEmpty ? reason : model.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlternativesList extends StatelessWidget {
  final List<LocalModelInfo> models;

  const _AlternativesList({required this.models});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Other models your PC can run', style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        ...models.map(
          (model) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              '• ${model.name} (~${model.downloadSizeGb.toStringAsFixed(1)} GB)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ManagedSetupNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.successMuted,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user_outlined, size: 20, color: AppColors.success),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fully managed by the app', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'When you enable local chat, the app will download the model, '
                  'start the on-device engine, and keep everything updated. '
                  'Your questions and document excerpts stay on this computer.',
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

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget? action;

  const _MessageCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(alignment: Alignment.centerRight, child: action),
          ],
        ],
      ),
    );
  }
}

class _InlineNote extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _InlineNote({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
