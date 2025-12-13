import 'package:flutter/material.dart';

class AppColors {
  // Background - Stitch Design
  static const Color backgroundDark = Color(0xFF101622);
  static const Color backgroundDarker = Color(0xFF0f172a);
  static const Color background = Color(0xFF111318);
  static const Color foreground = Color(0xFFFFFFFF);

  // Primary - Azul Stitch
  static const Color primary = Color(0xFF135bec);
  static const Color primaryLight = Color(0xFF38bdf8);
  static const Color primaryForeground = Color(0xFFFFFFFF);

  // Surface
  static const Color surface = Color(0xFF1e293b);
  static const Color surfaceDark = Color(0xFF1a202c);
  static const Color surfaceLight = Color(0xFFffffff);

  // Secondary
  static const Color secondary = Color(0xFF1F1F1F);
  static const Color secondaryForeground = Color(0xFFFAFAFA);

  // Muted
  static const Color muted = Color(0xFF262626);
  static const Color mutedForeground = Color(0xFF999999);

  // Accent Colors
  static const Color accent = Color(0xFF38bdf8);
  static const Color success = Color(0xFF10b981);
  static const Color warning = Color(0xFFf59e0b);
  static const Color error = Color(0xFFef4444);

  // Overlay
  static const Color overlayDark = Color(0xCC000000); // 80% opacity
  static const Color glassLight = Color(0x0dffffff); // 5% white for glass effect
  static const Color glassMedium = Color(0x1affffff); // 10% white for glass effect
}

// Gradientes
final LinearGradient heroGradient = LinearGradient(
  begin: Alignment.bottomCenter,
  end: Alignment.topCenter,
  colors: [
    AppColors.background,
    AppColors.background.withOpacity(0.6),
    Colors.transparent,
  ],
);

final LinearGradient cardGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Colors.transparent,
    Colors.black.withOpacity(0.8),
  ],
);

// Glass Panel Gradient
final LinearGradient glassPanelGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Colors.white.withOpacity(0.06),
    Colors.white.withOpacity(0.02),
  ],
);