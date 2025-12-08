import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

class CategoryCard extends StatefulWidget {
  final String name;
  final VoidCallback onTap;

  const CategoryCard({super.key, required this.name, required this.onTap});

  @override
  State<CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<CategoryCard> {
  bool _isFocused = false;

  // Gera uma cor consistente baseada no nome da categoria
  Color _getDynamicColor(String text) {
    final colors = [
      Colors.red.shade900, Colors.blue.shade900, Colors.purple.shade900, 
      Colors.teal.shade900, Colors.orange.shade900, Colors.indigo.shade900
    ];
    return colors[text.codeUnits.fold(0, (p, c) => p + c) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      onFocusChange: (val) => setState(() => _isFocused = val),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: _isFocused ? Matrix4.identity().scaled(1.05) : Matrix4.identity(),
        decoration: BoxDecoration(
          color: _isFocused ? AppColors.primary : _getDynamicColor(widget.name).withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: _isFocused ? Border.all(color: Colors.white, width: 2) : Border.all(color: Colors.white10),
          boxShadow: _isFocused 
              ? [BoxShadow(color: AppColors.primary.withOpacity(0.5), blurRadius: 15)] 
              : [],
        ),
        child: Stack(
          children: [
            // Ícone de fundo decorativo
            Positioned(
              right: -10,
              bottom: -10,
              child: Icon(Icons.folder, size: 80, color: Colors.white.withOpacity(0.1)),
            ),
            // Nome da Categoria
            Center(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  widget.name,
                  textAlign: TextAlign.center,
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [const Shadow(blurRadius: 2, color: Colors.black)],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}