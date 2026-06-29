import 'package:flutter/material.dart';

/// Apple-inspired color palette — restrained neutrals with a single confident accent.
abstract final class AppColors {
  // Brand & accent
  static const Color accent = Color(0xFF0071E3);
  static const Color accentHover = Color(0xFF0077ED);
  static const Color accentMuted = Color(0x1A0071E3);

  // Backgrounds
  static const Color background = Color(0xFFF5F5F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFAFAFC);
  static const Color surfaceMuted = Color(0xFFF2F2F7);

  // Text
  static const Color textPrimary = Color(0xFF1D1D1F);
  static const Color textSecondary = Color(0xFF6E6E73);
  static const Color textTertiary = Color(0xFFAEAEB2);
  static const Color textOnAccent = Color(0xFFFFFFFF);

  // Borders & separators
  static const Color separator = Color(0xFFD2D2D7);
  static const Color separatorLight = Color(0xFFE8E8ED);
  static const Color border = Color(0x1A000000);

  // Semantic
  static const Color success = Color(0xFF34C759);
  static const Color successMuted = Color(0x1A34C759);
  static const Color warning = Color(0xFFFF9500);
  static const Color error = Color(0xFFFF3B30);
  static const Color errorMuted = Color(0x1AFF3B30);

  // Chat bubbles
  static const Color userBubble = Color(0xFF0071E3);
  static const Color assistantBubble = Color(0xFFF2F2F7);
  static const Color sourceHighlight = Color(0x140071E3);
}
