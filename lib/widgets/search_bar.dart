import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

class CustomSearchBar extends StatefulWidget {
  final ValueChanged<String> onSearch;
  final VoidCallback? onClear;
  final String placeholder;

  const CustomSearchBar({
    super.key,
    required this.onSearch,
    this.onClear,
    this.placeholder = 'Buscar...',
  });

  @override
  State<CustomSearchBar> createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends State<CustomSearchBar> {
  late TextEditingController _controller;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(() {
      setState(() => _hasText = _controller.text.isNotEmpty);
      widget.onSearch(_controller.text);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              style: AppTypography.bodyMedium.copyWith(color: Colors.white),
              decoration: InputDecoration(
                hintText: widget.placeholder,
                hintStyle: AppTypography.bodyMedium.copyWith(color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_hasText)
            GestureDetector(
              onTap: _clear,
              child: const Icon(Icons.clear, color: AppColors.primary, size: 18),
            ),
        ],
      ),
    );
  }
}
