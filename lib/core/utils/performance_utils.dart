import 'package:flutter/material.dart';

/// Utilidades para otimização de performance
class PerformanceUtils {
  /// Evita rebuilds desnecessários usando const quando possível
  static const emptyBox = SizedBox.shrink();
  
  static const smallSpacing = SizedBox(height: 8);
  static const mediumSpacing = SizedBox(height: 16);
  static const largeSpacing = SizedBox(height: 24);
  
  /// Recomendações para otimização
  static const bestPractices = [
    'Use const widgets quando o construtor permitir',
    'Use RepaintBoundary para widgets com renderização complexa',
    'Implemente lazy loading em listas grandes',
    'Cache imagens com CachedNetworkImage',
    'Use itemExtent em listas para melhor performance',
    'Minimize o número de widgets no build',
  ];
}

/// Extensão para cache de cores comuns
extension ColorExtension on Color {
  static const transparent10 = Color.fromRGBO(0, 0, 0, 0.1);
  static const transparent20 = Color.fromRGBO(0, 0, 0, 0.2);
  static const transparent30 = Color.fromRGBO(0, 0, 0, 0.3);
  static const transparent50 = Color.fromRGBO(0, 0, 0, 0.5);
}
