import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class BlinkingCursorPlaceholder extends StatefulWidget {
  final String text;
  final String hintText;
  final bool isFocused;
  final bool isAlphanumericTrigger;
  final VoidCallback onActivate;
  final IconData prefixIcon;
  final Color? focusedColor;

  const BlinkingCursorPlaceholder({
    super.key,
    required this.text,
    required this.hintText,
    required this.isFocused,
    required this.onActivate,
    this.prefixIcon = Icons.search,
    this.isAlphanumericTrigger = true,
    this.focusedColor,
  });

  @override
  State<BlinkingCursorPlaceholder> createState() => _BlinkingCursorPlaceholderState();
}

class _BlinkingCursorPlaceholderState extends State<BlinkingCursorPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _cursorController;
  bool _cursorVisible = true;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _cursorVisible = !_cursorVisible);
          _cursorController.reverse();
        } else if (status == AnimationStatus.dismissed) {
          setState(() => _cursorVisible = !_cursorVisible);
          _cursorController.forward();
        }
      });
    _cursorController.forward();
  }

  @override
  void dispose() {
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveFocusedColor = widget.focusedColor ?? AppColors.primary;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: widget.isFocused ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isFocused ? effectiveFocusedColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            widget.prefixIcon,
            color: widget.isFocused ? effectiveFocusedColor : Colors.white54,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Hint Text or Actual Text
                Text(
                  widget.text.isEmpty ? widget.hintText : widget.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.text.isEmpty ? Colors.white30 : Colors.white,
                    fontSize: 16,
                    fontWeight: widget.isFocused && widget.text.isEmpty ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                // Custom Blinking Cursor
                if (widget.isFocused && _cursorVisible)
                  Positioned(
                    left: _calculateCursorOffset(),
                    child: Container(
                      width: 2,
                      height: 20,
                      color: effectiveFocusedColor,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _calculateCursorOffset() {
    if (widget.text.isEmpty) return 0.0;
    
    // Simple estimation of cursor position based on text length
    // For a more accurate position, LayoutBuilder/TextPainter would be needed
    final textPainter = TextPainter(
      text: TextSpan(
        text: widget.text,
        style: const TextStyle(fontSize: 16),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    
    return textPainter.width;
  }
}
