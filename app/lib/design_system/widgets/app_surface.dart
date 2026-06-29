import 'dart:ui';

import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_shadows.dart';
import '../tokens/app_spacing.dart';

/// Elevated panel surface with optional frosted-glass header treatment.
class AppSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool elevated;

  const AppSurface({
    super.key,
    required this.child,
    this.padding,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.xlAll,
        border: Border.all(color: AppColors.separatorLight),
        boxShadow: elevated ? AppShadows.subtle : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: padding != null
          ? Padding(padding: padding!, child: child)
          : child,
    );
  }
}

/// Frosted toolbar strip — mimics macOS vibrancy in the title bar area.
class AppFrostedBar extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AppFrostedBar({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.72),
            border: const Border(
              bottom: BorderSide(color: AppColors.separatorLight),
            ),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
