import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

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
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final active = _isHovering || _isFocused;
    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKey: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onTap?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(active ? 0.12 : 0.07),
                      Colors.white.withOpacity(active ? 0.08 : 0.03),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(active ? 0.2 : 0.05),
                    width: 1,
                  ),
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 30,
                            spreadRadius: -5,
                            offset: const Offset(0, 10),
                          ),
                        ]
                      : null,
                ),
                transform: active
                    ? (Matrix4.identity()
                      ..translate(0, -4)
                      ..scale(1.02))
                    : Matrix4.identity(),
                padding: widget.padding,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
