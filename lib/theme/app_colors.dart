// lib/theme/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  final BuildContext context;
  AppColors(this.context);

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  Color get scaffoldBackground => isDark ? const Color(0xFF0D1B2A) : const Color(0xFFF8FAFC);
  Color get appBarBackground => isDark ? const Color(0xFF1A3A5C) : const Color(0xFFFFFFFF);
  Color get cardBackground => isDark ? const Color(0xFF162233) : const Color(0xFFFFFFFF);
  Color get secondaryCardBackground => isDark ? const Color(0xFF0F1A28) : const Color(0xFFF1F5F9);
  Color get primaryAccent => isDark ? const Color(0xFFD4AF37) : const Color(0xFFB8860B);
  Color get primaryAccentDark => isDark ? const Color(0xFFB8860B) : const Color(0xFF8B6508);
  
  Color get textPrimary => isDark ? Colors.white : const Color(0xFF1E293B);
  Color get textSecondary => isDark ? Colors.white54 : const Color(0xFF64748B);
  Color get divider => isDark ? Colors.white24 : const Color(0xFFE2E8F0);
  Color get iconMuted => isDark ? Colors.white38 : const Color(0xFF94A3B8);

  // Helper gradients
  List<Color> get primaryGradient => isDark
      ? [const Color(0xFF1A3A5C), const Color(0xFF0D1B2A)]
      : [const Color(0xFFFFFFFF), const Color(0xFFF8FAFC)];
}

extension AppColorsExtension on BuildContext {
  AppColors get colors => AppColors(this);
}
