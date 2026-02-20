import 'package:flutter/material.dart';
import 'dart:ui';

/// Background com logo desfocada que pode ser usado em qualquer tela
class LogoBackground extends StatelessWidget {
  final Widget child;
  final double opacity;
  final double blur;

  const LogoBackground({
    super.key,
    required this.child,
    this.opacity = 0.15,
    this.blur = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background com logo
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.2),
                radius: 1.0,
                colors: [
                  Color(0xFF161e2b), // Brilho central mais neutro/navy
                  Color(0xFF0b0f16), // Bordas mais escuras
                ],
              ),
            ),
            child: Opacity(
              opacity: opacity,
              child: RepaintBoundary(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        ),
        // Conteúdo
        child,
      ],
    );
  }
}
