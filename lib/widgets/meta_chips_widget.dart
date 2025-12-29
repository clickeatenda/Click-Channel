import 'package:flutter/material.dart';
import '../models/content_item.dart';

/// Widget reutilizável para exibir metadados de conteúdo
/// Mostra: qualidade e avaliação (rating)
class MetaChipsWidget extends StatelessWidget {
  final ContentItem item;
  final double iconSize;
  final double fontSize;

  const MetaChipsWidget({
    super.key,
    required this.item,
    this.iconSize = 12,
    this.fontSize = 9,
  });

  @override
  Widget build(BuildContext context) {
    // Debug: log do item para verificar se está chegando
    // print('🔍 MetaChipsWidget: "${item.title}" - type: ${item.type}, rating: ${item.rating}');
    
    final quality = item.quality.toUpperCase();
    String qualityLabel = 'SD';
    Color qualityColor = Colors.grey;
    
    if (quality.contains('UHD') || quality.contains('4K')) {
      qualityLabel = '4K';
      qualityColor = Colors.amber;
    } else if (quality.contains('FHD') || quality == 'FULLHD') {
      qualityLabel = 'FHD';
      qualityColor = Colors.green;
    } else if (quality.contains('HD')) {
      qualityLabel = 'HD';
      qualityColor = Colors.blue;
    }
    
    // Para canais, mostra apenas qualidade
    if (item.type == 'channel') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMiniChip(qualityLabel, qualityColor),
        ],
      );
    }
    
    // Para filmes e séries, mostra qualidade + rating
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildMiniChip(qualityLabel, qualityColor),
        const SizedBox(width: 4),
        _buildRatingChip(item.rating),
      ],
    );
  }

  Widget _buildMiniChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5), width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRatingChip(double rating) {
    final hasRating = rating > 0;
    final ratingText = hasRating ? rating.toStringAsFixed(1) : '—';
    final ratingColor = hasRating 
        ? (rating >= 7 ? Colors.green : rating >= 5 ? Colors.amber : Colors.red)
        : Colors.grey;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: ratingColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: ratingColor.withOpacity(0.5), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, color: ratingColor, size: iconSize),
          const SizedBox(width: 2),
          Text(
            ratingText,
            style: TextStyle(
              color: ratingColor,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

