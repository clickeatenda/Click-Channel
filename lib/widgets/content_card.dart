import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';
import '../models/content_item.dart';

class ContentCard extends StatefulWidget {
  final ContentItem item;
  final Function(String) onTap;
  
  static const double cardWidth = 130; 
  static const double cardHeight = 200; 

  const ContentCard({super.key, required this.item, required this.onTap});

  @override
  State<ContentCard> createState() => _ContentCardState();
}

class _ContentCardState extends State<ContentCard> {
  final bool _isFocused = false;

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
    return GestureDetector(
      onTap: () {
        widget.onTap(widget.item.url);
      },
      child: Container(
        width: ContentCard.cardWidth,
        height: ContentCard.cardHeight,
        margin: const EdgeInsets.only(right: 12, bottom: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: AppColors.card,
        ),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. IMAGEM (Poster)
              Expanded(
                flex: 6,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  child: widget.item.image.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.item.image, 
                          fit: BoxFit.cover, 
                          memCacheHeight: 280,
                          placeholder: (context, url) => Container(color: AppColors.card),
                          errorWidget: (c, u, e) => _placeholder(),
                        )
                      : _placeholder(),
                ),
              ),
              
              // 2. TÍTULO (SEMPRE VISÍVEL)
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Text(
                  widget.item.title, 
                  textAlign: TextAlign.center, 
                  maxLines: 2, 
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10, 
                    color: Colors.white, 
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  )
                ),
              )
            ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    final iconData = widget.item.type == 'channel' 
        ? Icons.live_tv_rounded 
        : (widget.item.type == 'series' ? Icons.video_library : Icons.movie_creation_outlined);
    
    return Container(
      color: _getColor(widget.item.title),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(iconData, color: Colors.white70, size: 40),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              widget.item.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white60,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}