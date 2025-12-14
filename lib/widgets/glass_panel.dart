import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final BorderRadius borderRadius;
  final Color? backgroundColor;
  final Border? border;
  final BoxShadow? shadow;
  final double blurSigma;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.backgroundColor,
    this.border,
    this.shadow,
    this.blurSigma = 40,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor ?? const Color.fromARGB(217, 5, 5, 5),
            border: border ?? Border.all(
              color: Colors.white.withOpacity(0.05),
              width: 1,
            ),
            borderRadius: borderRadius,
            boxShadow: shadow != null ? [shadow!] : [
              BoxShadow(
                color: Colors.black.withOpacity(0.8),
                blurRadius: 40,
                spreadRadius: -12,
                offset: const Offset(0, 40),
              ),
            ],
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class SmallGlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double blurSigma;
  final VoidCallback? onTap;

  const SmallGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(8),
    this.blurSigma = 12,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              border: Border.all(
                color: Colors.white.withOpacity(0.04),
                width: 1,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

class GlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final double elevation;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.elevation = 0,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(_isHovering ? 0.1 : 0.07),
                    Colors.white.withOpacity(_isHovering ? 0.05 : 0.03),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(_isHovering ? 0.15 : 0.05),
                  width: 1,
                ),
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                boxShadow: _isHovering ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 30,
                    spreadRadius: -5,
                    offset: const Offset(0, 10),
                  ),
                ] : null,
              ),
              transform: _isHovering ? Matrix4.identity()..translate(0, -5) : Matrix4.identity(),
              padding: widget.padding,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
