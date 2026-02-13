import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

/// Gerenciamento de preferências de legendas
class SubtitlePreferences {
  static const String _keyColor = 'subtitle_color';
  static const String _keyBackgroundOpacity = 'subtitle_bg_opacity';
  static const String _keyFontSize = 'subtitle_font_size';

  // Valores padrão
  static const int _defaultColor = 0xFFFFFFFF; // Branco
  static const double _defaultBackgroundOpacity = 0.7;
  static const double _defaultFontSize = 18.0;

  /// Salva a cor da legenda
  static Future<void> setSubtitleColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyColor, color.value);
  }

  /// Obtém a cor da legenda
  static Future<Color> getSubtitleColor() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt(_keyColor) ?? _defaultColor;
    return Color(colorValue);
  }

  /// Salva a opacidade do fundo
  static Future<void> setBackgroundOpacity(double opacity) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyBackgroundOpacity, opacity);
  }

  /// Obtém a opacidade do fundo
  static Future<double> getBackgroundOpacity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyBackgroundOpacity) ?? _defaultBackgroundOpacity;
  }

  /// Salva o tamanho da fonte
  static Future<void> setFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyFontSize, size);
  }

  /// Obtém o tamanho da fonte
  static Future<double> getFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyFontSize) ?? _defaultFontSize;
  }

  /// Reseta todas as preferências para o padrão
  static Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyColor);
    await prefs.remove(_keyBackgroundOpacity);
    await prefs.remove(_keyFontSize);
  }
}
