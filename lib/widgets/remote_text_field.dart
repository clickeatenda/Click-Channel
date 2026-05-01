import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import 'blinking_cursor_placeholder.dart';

class RemoteTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onCancel;
  final VoidCallback? onActivated;
  final VoidCallback? onArrowUp;
  final VoidCallback? onArrowDown;
  final VoidCallback? onArrowLeft;
  final VoidCallback? onArrowRight;
  final FocusNode? placeholderFocusNode;
  final FocusNode? editFocusNode;
  final bool initiallyActive;
  final Color focusedColor;

  const RemoteTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.onChanged,
    this.onSubmitted,
    this.onCancel,
    this.onActivated,
    this.onArrowUp,
    this.onArrowDown,
    this.onArrowLeft,
    this.onArrowRight,
    this.placeholderFocusNode,
    this.editFocusNode,
    this.initiallyActive = false,
    this.focusedColor = AppColors.primary,
  });

  @override
  State<RemoteTextField> createState() => _RemoteTextFieldState();
}

class _RemoteTextFieldState extends State<RemoteTextField> {
  late FocusNode _placeholderFocusNode;
  late FocusNode _editFocusNode;
  late bool _ownsPlaceholderFocusNode;
  late bool _ownsEditFocusNode;
  late bool _active;

  @override
  void initState() {
    super.initState();
    _active = widget.initiallyActive;
    _placeholderFocusNode = widget.placeholderFocusNode ?? FocusNode();
    _editFocusNode = widget.editFocusNode ?? FocusNode();
    _ownsPlaceholderFocusNode = widget.placeholderFocusNode == null;
    _ownsEditFocusNode = widget.editFocusNode == null;
  }

  @override
  void didUpdateWidget(covariant RemoteTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placeholderFocusNode != widget.placeholderFocusNode) {
      if (_ownsPlaceholderFocusNode) _placeholderFocusNode.dispose();
      _placeholderFocusNode = widget.placeholderFocusNode ?? FocusNode();
      _ownsPlaceholderFocusNode = widget.placeholderFocusNode == null;
    }
    if (oldWidget.editFocusNode != widget.editFocusNode) {
      if (_ownsEditFocusNode) _editFocusNode.dispose();
      _editFocusNode = widget.editFocusNode ?? FocusNode();
      _ownsEditFocusNode = widget.editFocusNode == null;
    }
  }

  @override
  void dispose() {
    if (_ownsPlaceholderFocusNode) _placeholderFocusNode.dispose();
    if (_ownsEditFocusNode) _editFocusNode.dispose();
    super.dispose();
  }

  void _activate() {
    setState(() => _active = true);
    widget.onActivated?.call();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _editFocusNode.requestFocus();
      SystemChannels.textInput.invokeMethod('TextInput.show');
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && _editFocusNode.hasFocus) {
          SystemChannels.textInput.invokeMethod('TextInput.show');
        }
      });
    });
  }

  void _deactivate({bool refocusPlaceholder = true}) {
    setState(() => _active = false);
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    if (refocusPlaceholder) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _placeholderFocusNode.requestFocus();
      });
    }
  }

  KeyEventResult _handlePlaceholderKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.gameButtonA) {
      _activate();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp && widget.onArrowUp != null) {
      widget.onArrowUp!();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown && widget.onArrowDown != null) {
      widget.onArrowDown!();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft && widget.onArrowLeft != null) {
      widget.onArrowLeft!();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight && widget.onArrowRight != null) {
      widget.onArrowRight!();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleEditKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      _deactivate();
      widget.onCancel?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp && widget.onArrowUp != null) {
      _deactivate(refocusPlaceholder: false);
      widget.onArrowUp!();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown && widget.onArrowDown != null) {
      _deactivate(refocusPlaceholder: false);
      widget.onArrowDown!();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) {
      return Focus(
        focusNode: _placeholderFocusNode,
        onFocusChange: (_) {
          if (mounted) setState(() {});
          SystemChannels.textInput.invokeMethod('TextInput.hide');
        },
        onKeyEvent: (_, event) => _handlePlaceholderKey(event),
        child: GestureDetector(
          onTap: _activate,
          child: BlinkingCursorPlaceholder(
            text: widget.obscureText && widget.controller.text.isNotEmpty
                ? '********'
                : widget.controller.text,
            hintText: widget.hintText,
            isFocused: _placeholderFocusNode.hasFocus,
            onActivate: _activate,
            prefixIcon: widget.prefixIcon,
            focusedColor: widget.focusedColor,
          ),
        ),
      );
    }

    return Focus(
      onKeyEvent: (_, event) => _handleEditKey(event),
      child: TextField(
        controller: widget.controller,
        focusNode: _editFocusNode,
        autofocus: true,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        onChanged: widget.onChanged,
        onSubmitted: (value) {
          _deactivate(refocusPlaceholder: false);
          widget.onSubmitted?.call(value);
        },
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.08),
          prefixIcon: Icon(widget.prefixIcon, color: widget.focusedColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: widget.focusedColor, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: widget.focusedColor, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: widget.focusedColor, width: 2),
          ),
        ),
      ),
    );
  }
}
