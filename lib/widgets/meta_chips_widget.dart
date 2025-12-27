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
    
    // CRÍTICO: Mostra rating para filmes e séries (baseado no TMDB).
    // Mesmo que o rating ainda seja 0 (ainda não enriquecido), exibimos um placeholder
    // para garantir consistência visual. TMDB fornece rating 0-10; aqui mostramos 0-5 com 1 casa.
    if (item.type != 'channel') {
      String ratingLabel;
      if (item.rating > 0) {
        // Mostra a avaliação no formato 0-10 (ex: 6.8/10) para coincidir com a tela de detalhe
        ratingLabel = '${item.rating.toStringAsFixed(1)}/10';
        debugPrint('⭐ MetaChipsWidget: Exibindo rating ${item.rating} (${ratingLabel}) para "${item.title}"');
      } else {
        // Placeholder enquanto o enriquecimento não ocorrer
        ratingLabel = '— ★';
        debugPrint('ℹ️ MetaChipsWidget: Placeholder de rating para "${item.title}" (rating ainda não disponível)');
      }
      chips.add(_buildChip(Icons.star, ratingLabel));
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
