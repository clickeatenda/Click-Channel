import 'package:flutter/material.dart';
import '../models/content_item.dart';

/// Widget reutilizável para exibir metadados de conteúdo
/// Mostra: stream host, tipo de áudio (DUB/LEG), qualidade e avaliação
class MetaChipsWidget extends StatelessWidget {
  final ContentItem item;
  final double iconSize;
  final double fontSize;

  const MetaChipsWidget({
    super.key,
    required this.item,
    this.iconSize = 16,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final quality = item.quality.toUpperCase();
    // Mapear qualidade para labels mais amigáveis
    String qualityLabel = quality;
    if (quality.contains('UHD') || quality.contains('4K')) {
      qualityLabel = '4K';
    } else if (quality.contains('FHD') || quality == 'FULLHD') {
      qualityLabel = 'FHD';
    } else if (quality.contains('HD')) {
      qualityLabel = 'HD';
    } else if (quality.isEmpty || quality == 'UNKNOWN') {
      qualityLabel = 'SD';
    }
    
    // CRÍTICO: Usa rating real do item (do TMDB) em vez de hardcoded
    final List<Widget> chips = [];
    
    // Sempre mostra qualidade
    if (qualityLabel.isNotEmpty && qualityLabel != 'UNKNOWN') {
      chips.add(_buildChip(Icons.high_quality, qualityLabel));
    }
    
    // CRÍTICO: Mostra rating se for filme/série E tiver rating válido (> 0)
    // Rating do TMDB vem em escala 0-10, então sempre divide por 2 para mostrar 0-5
    if (item.type != 'channel' && item.rating > 0) {
      // Rating do TMDB é sempre 0-10, então divide por 2 para mostrar 0-5 estrelas
      final displayRating = (item.rating / 2).toStringAsFixed(1);
      chips.add(_buildChip(Icons.star, '$displayRating ★'));
      // Debug: verificar se rating está sendo exibido
      debugPrint('⭐ MetaChipsWidget: Exibindo rating ${item.rating} (${displayRating} ★) para "${item.title}"');
    } else if (item.type != 'channel') {
      // Debug: verificar por que rating não está sendo exibido
      debugPrint('⚠️ MetaChipsWidget: Rating não exibido para "${item.title}" - rating: ${item.rating}, type: ${item.type}');
    }
    
    // Se não tem chips, retorna container vazio
    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: chips,
    );
  }

  Widget _buildChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: iconSize),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: Colors.white70,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }
}
