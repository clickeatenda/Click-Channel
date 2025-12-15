import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';
import '../models/content_item.dart';

class ContentCard extends StatefulWidget {
  final ContentItem item;
  final Function(String) onTap;
  
  static const double cardWidth = 140; 
  // Aumentei um pouco a altura para caber o texto fixo sem cortar
  static const double cardHeight = 240; 

  const ContentCard({super.key, required this.item, required this.onTap});

  @override
  State<ContentCard> createState() => _ContentCardState();
}

class _ContentCardState extends State<ContentCard> {
  bool _isFocused = false;

  Color _getColor(String text) {
    final colors = [
      Colors.red.shade900, Colors.blue.shade900, Colors.purple.shade900, 
      Colors.green.shade900, Colors.orange.shade900, Colors.teal.shade900,
      const Color(0xFF2A2A2A)
    ];
    return colors[text.codeUnits.fold(0, (p, c) => p + c) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final double scale = _isFocused ? 1.1 : 1.0;
    
    return Padding(
      padding: const EdgeInsets.only(right: 16, bottom: 10),
      child: InkWell(
        onTap: () => widget.onTap(widget.item.url),
        onFocusChange: (val) => setState(() => _isFocused = val),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: ContentCard.cardWidth * scale,
          height: ContentCard.cardHeight * scale,
          transform: Matrix4.identity(),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            // Borda Branca Grossa para identificar o foco na TV
            border: _isFocused ? Border.all(color: Colors.white, width: 3) : Border.all(color: Colors.transparent, width: 0),
            boxShadow: _isFocused ? [
              BoxShadow(color: Colors.black.withOpacity(0.8), blurRadius: 15, spreadRadius: 2)
            ] : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. IMAGEM (Poster)
              Expanded(
                flex: 5, // A imagem ocupa a maior parte
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6), bottom: Radius.circular(0)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      widget.item.image.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: widget.item.image, 
                              fit: BoxFit.cover, 
                              memCacheHeight: 350,
                              placeholder: (context, url) => Container(color: AppColors.card),
                              errorWidget: (c, u, e) => _placeholder(),
                            )
                          : _placeholder(),
                      
                      if (_isFocused) 
                        Container(decoration: BoxDecoration(gradient: cardGradient)),
                    ],
                  ),
                ),
              ),
              
              // 2. TÍTULO (SEMPRE VISÍVEL AGORA)
              Expanded(
                flex: 2, // Espaço reservado para o texto
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.card, // Fundo escuro para o texto
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(6)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  alignment: Alignment.center,
                  child: Text(
                    widget.item.title, 
                    textAlign: TextAlign.center, 
                    maxLines: 2, 
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11, 
                      // Texto fica amarelo se focado, branco se normal
                      color: _isFocused ? AppColors.primary : Colors.white70, 
                      fontWeight: _isFocused ? FontWeight.bold : FontWeight.normal
                    )
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: _getColor(widget.item.title),
      alignment: Alignment.center,
      child: Icon(
        widget.item.type == 'channel' ? Icons.tv : Icons.movie_creation_outlined, 
        color: Colors.white54, size: 30
      ),
    );
  }
}