import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  static TextStyle get displayLarge => GoogleFonts.plusJakartaSans(
      fontSize: 48,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: AppColors.foreground);

  static TextStyle get displayMedium => GoogleFonts.plusJakartaSans(
      fontSize: 40,
      fontWeight: FontWeight.w700,
      color: AppColors.foreground);

  static TextStyle get headlineLarge => GoogleFonts.plusJakartaSans(
      fontSize: 32,
      fontWeight: FontWeight.w600,
      color: AppColors.foreground);

  // --- ADICIONADO ---
  static TextStyle get headlineMedium => GoogleFonts.plusJakartaSans(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: AppColors.foreground);

  static TextStyle get titleLarge => GoogleFonts.plusJakartaSans(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: AppColors.foreground);

  static TextStyle get bodyMedium => GoogleFonts.plusJakartaSans(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AppColors.mutedForeground);

  // --- ADICIONADO ---
  static TextStyle get bodySmall => GoogleFonts.plusJakartaSans(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: AppColors.mutedForeground);

  static TextStyle get labelMedium => GoogleFonts.plusJakartaSans(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppColors.foreground);
}