import 'package:flutter/material.dart';
import 'dart:ui';
import '../core/theme/app_colors.dart';

class GlassButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? width;
  final double height;
  final EdgeInsets padding;
  final FocusNode? focusNode;

  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.backgroundColor,
    this.foregroundColor,
    this.width,
    this.height = 48,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    this.focusNode,
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _isHovering = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final bool isActive = _isHovering || _isFocused;
    return FocusableActionDetector(
      focusNode: widget.focusNode,
      onShowFocusHighlight: (hasFocus) => setState(() => _isFocused = hasFocus),
      onShowHoverHighlight: (isHovering) => setState(() => _isHovering = isHovering),
      actions: {
        ActivateIntent: CallbackAction<Intent>(
          onInvoke: (_) {
            if (!widget.isLoading) widget.onPressed();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTap: widget.isLoading ? null : widget.onPressed,
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                color: widget.backgroundColor ?? Colors.white.withOpacity(isActive ? 0.08 : 0.03),
                border: Border.all(
                  color: isActive ? AppColors.primary : Colors.white.withOpacity(0.04),
                  width: isActive ? 3 : 1,
                ),
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                boxShadow: isActive ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.5),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ] : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.isLoading ? null : widget.onPressed,
                  child: Padding(
                    padding: widget.padding,
                    child: widget.isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                widget.foregroundColor ?? Colors.white,
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.icon != null) ...[
                                Icon(
                                  widget.icon,
                                  color: widget.foregroundColor ?? Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                widget.label,
                                style: TextStyle(
                                  color: widget.foregroundColor ?? Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SolidButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? width;
  final double height;
  final FocusNode? focusNode;

  const SolidButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.backgroundColor,
    this.foregroundColor,
    this.width,
    this.height = 48,
    this.focusNode,
  });

  @override
  State<SolidButton> createState() => _SolidButtonState();
}

class _SolidButtonState extends State<SolidButton> {
  bool _isHovering = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final bool isActive = _isHovering || _isFocused;
    return FocusableActionDetector(
      focusNode: widget.focusNode,
      onShowFocusHighlight: (hasFocus) => setState(() => _isFocused = hasFocus),
      onShowHoverHighlight: (isHovering) => setState(() => _isHovering = isHovering),
      actions: {
        ActivateIntent: CallbackAction<Intent>(
          onInvoke: (_) {
            if (!widget.isLoading) widget.onPressed();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTap: widget.isLoading ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.backgroundColor ?? AppColors.primary,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            border: isActive ? Border.all(color: Colors.white, width: 3) : null,
            boxShadow: isActive ? [
              BoxShadow(
                color: Colors.white.withOpacity(0.6),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ] : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.isLoading ? null : widget.onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: widget.isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            widget.foregroundColor ?? Colors.white,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(
                              widget.icon,
                              color: widget.foregroundColor ?? Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            widget.label,
                            style: TextStyle(
                              color: widget.foregroundColor ?? Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
