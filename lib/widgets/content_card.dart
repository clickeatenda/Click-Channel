import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'adaptive_cached_image.dart';
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
  bool _isFocused = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Color _getColor(String text) {
    final colors = [
      Colors.red.shade900, Colors.blue.shade900, Colors.purple.shade900, 
      Colors.green.shade900, Colors.orange.shade900, Colors.teal.shade900,
      const Color(0xFF2A2A2A)
    ];
    return colors[text.codeUnits.fold(0, (p, c) => p + c) % colors.length];
  }

  void _handleActivate() {
    widget.onTap(widget.item.url);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.gameButtonA) {
            _handleActivate();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: _handleActivate,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: ContentCard.cardWidth,
          height: ContentCard.cardHeight,
          margin: const EdgeInsets.only(right: 12, bottom: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: AppColors.card,
            border: _isFocused 
                ? Border.all(color: AppColors.primary, width: 3)
                : null,
            boxShadow: _isFocused 
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          transform: _isFocused ? Matrix4.translationValues(0, -4, 0) : Matrix4.identity(),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // 1. IMAGEM (Poster)
              Expanded(
                flex: 6,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  child: AdaptiveCachedImage(
                    url: widget.item.image,
                    fit: BoxFit.cover,
                    errorWidget: _placeholder(),
                  ),
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