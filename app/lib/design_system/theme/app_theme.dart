import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

ThemeData buildAppTheme() {
  const colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.accent,
    onPrimary: AppColors.textOnAccent,
    primaryContainer: AppColors.accentMuted,
    onPrimaryContainer: AppColors.accent,
    secondary: AppColors.textSecondary,
    onSecondary: AppColors.textOnAccent,
    secondaryContainer: AppColors.surfaceMuted,
    onSecondaryContainer: AppColors.textPrimary,
    tertiary: AppColors.textTertiary,
    onTertiary: AppColors.textOnAccent,
    error: AppColors.error,
    onError: AppColors.textOnAccent,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.separator,
    outlineVariant: AppColors.separatorLight,
    shadow: Colors.black26,
    scrim: Colors.black54,
    inverseSurface: AppColors.textPrimary,
    onInverseSurface: AppColors.surface,
    inversePrimary: AppColors.accentHover,
    surfaceTint: Colors.transparent,
  );

  final textTheme = AppTypography.textTheme();

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    textTheme: textTheme,
    iconTheme: const IconThemeData(
      color: AppColors.textSecondary,
      size: 20,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.separatorLight,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      backgroundColor: AppColors.surface.withValues(alpha: 0.85),
      foregroundColor: AppColors.textPrimary,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      toolbarHeight: 52,
      actionsIconTheme: const IconThemeData(
        color: AppColors.textSecondary,
        size: 20,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.xlAll,
        side: const BorderSide(color: AppColors.separatorLight),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.textOnAccent,
        disabledBackgroundColor: AppColors.separatorLight,
        disabledForegroundColor: AppColors.textTertiary,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
        textStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textOnAccent,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.textOnAccent,
        disabledBackgroundColor: AppColors.separatorLight,
        disabledForegroundColor: AppColors.textTertiary,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.accent,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
        side: const BorderSide(color: AppColors.separator),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.smAll),
        textStyle: textTheme.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceMuted,
      hoverColor: AppColors.surfaceElevated,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: AppRadii.mdAll,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadii.mdAll,
        borderSide: const BorderSide(color: AppColors.separatorLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadii.mdAll,
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadii.mdAll,
        borderSide: const BorderSide(color: AppColors.error),
      ),
      hintStyle: textTheme.bodyLarge?.copyWith(color: AppColors.textTertiary),
      labelStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceMuted,
      selectedColor: AppColors.accentMuted,
      labelStyle: textTheme.labelMedium,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.smAll),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.surface;
          }
          return Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.textPrimary;
          }
          return AppColors.textSecondary;
        }),
        side: WidgetStateProperty.all(BorderSide.none),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: AppRadii.smAll),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
        ),
        textStyle: WidgetStateProperty.all(
          textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.xlAll),
      titleTextStyle: textTheme.headlineSmall,
      contentTextStyle: textTheme.bodyLarge,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.textPrimary,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.surface),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
      linearTrackColor: AppColors.separatorLight,
    ),
    splashColor: AppColors.accent.withValues(alpha: 0.08),
    highlightColor: AppColors.accent.withValues(alpha: 0.04),
  );
}
