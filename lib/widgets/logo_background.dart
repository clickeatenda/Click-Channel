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
                center: Alignment(0.0, -0.3),
                radius: 0.8,
                colors: [
                  Color(0xFF1a1a2e),
                  Color(0xFF0f0f1e),
                ],
              ),
            ),
            child: Center(
              child: Opacity(
                opacity: opacity,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 300,
                    height: 300,
                    fit: BoxFit.contain,
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
