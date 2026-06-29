import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';

/// Compact metadata pill — used for tags, counts, and status labels.
class AppChip extends StatelessWidget {
  final String label;
  final bool highlighted;
  final Color? color;

  const AppChip({
    super.key,
    required this.label,
    this.highlighted = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? AppColors.accent;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: highlighted ? accent.withValues(alpha: 0.1) : AppColors.surfaceMuted,
        borderRadius: AppRadii.smAll,
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: highlighted ? accent : (color ?? AppColors.textSecondary),
          fontWeight: highlighted ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );
  }
}
