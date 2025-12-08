import 'package:flutter/material.dart';

class AppColors {
  // Background
  static const Color background = Color(0xFF0A0A0A);
  static const Color foreground = Color(0xFFFAFAFA);

  // Cards
  static const Color card = Color(0xFF121212);
  
  // Primary - Vermelho vibrante
  static const Color primary = Color(0xFFE11D48);
  static const Color primaryForeground = Color(0xFFFFFFFF);

  // Secondary
  static const Color secondary = Color(0xFF1F1F1F);
  static const Color secondaryForeground = Color(0xFFFAFAFA);

  // Muted
  static const Color muted = Color(0xFF262626);
  static const Color mutedForeground = Color(0xFF999999);

  // Overlay
  static const Color overlayDark = Color(0xCC000000); // 80% opacity
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