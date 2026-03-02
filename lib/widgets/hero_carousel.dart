import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../models/content_item.dart';
import 'lazy_tmdb_loader.dart';

class HeroCarousel extends StatefulWidget {
  final List<ContentItem> items;
  final Function(ContentItem) onPlay;
  final bool autofocus;

  const HeroCarousel({
    super.key, 
    required this.items, 
    required this.onPlay,
    this.autofocus = false,
  });

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  static const _itemsPerPage = 3;

  int get _totalPages => (widget.items.take(6).length / _itemsPerPage).ceil();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted) return;
      final next = _currentPage < _totalPages - 1 ? _currentPage + 1 : 0;
      setState(() => _currentPage = next);
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox(height: 200);

    final displayItems = widget.items.take(6).toList();

    return SizedBox(
      height: 220, // Reduzido de 380 para 220 — apropriado para TV 1080p
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _totalPages,
            onPageChanged: (page) => setState(() => _currentPage = page),
            itemBuilder: (context, pageIndex) {
              final startIndex = pageIndex * _itemsPerPage;
              final endIndex = (startIndex + _itemsPerPage).clamp(0, displayItems.length);
              final pageItems = displayItems.sublist(startIndex, endIndex);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: pageItems.map((originalItem) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: LazyTmdbLoader(
                          item: originalItem,
                          builder: (item, _) => _HeroCard(
                            item: item,
                            onPlay: () => widget.onPlay(item),
                            autofocus: widget.autofocus && originalItem == displayItems.first,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
          // Page indicators
          if (_totalPages > 1)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_totalPages, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentPage == index ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? AppColors.primary
                          : Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

/// Card individual do banner com foco próprio para navegação TV
class _HeroCard extends StatefulWidget {
  final ContentItem item;
  final VoidCallback onPlay;
  final bool autofocus;

  const _HeroCard({required this.item, required this.onPlay, this.autofocus = false});

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          widget.onPlay();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPlay,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: _isFocused
              ? (Matrix4.identity()..translate(0.0, -4.0)..scale(1.04))
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isFocused ? AppColors.primary : Colors.transparent,
              width: 2.5,
            ),
            boxShadow: _isFocused
                ? [BoxShadow(color: AppColors.primary.withOpacity(0.6), blurRadius: 20, spreadRadius: 2)]
                : [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background image
                widget.item.image.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: widget.item.image,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        placeholder: (_, __) => Container(color: AppColors.background),
                        errorWidget: (_, __, ___) => Container(color: const Color(0xFF1A1A1A)),
                      )
                    : Container(color: const Color(0xFF1A1A1A)),

                // Gradient overlay
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                      stops: [0.45, 1.0],
                    ),
                  ),
                ),

                // Focus highlight overlay
                if (_isFocused)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primary.withOpacity(0.15),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5],
                      ),
                    ),
                  ),

                // Content
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: _isFocused ? AppColors.primary : AppColors.primary.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'DESTAQUE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.item.title,
                        style: AppTypography.titleLarge.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          shadows: [const Shadow(blurRadius: 4, color: Colors.black87)],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.item.rating > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 12),
                            const SizedBox(width: 3),
                            Text(
                              widget.item.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: _isFocused ? 1.0 : 0.8,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isFocused ? AppColors.primary : AppColors.primary.withOpacity(0.85),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            minimumSize: const Size(0, 30),
                            elevation: _isFocused ? 4 : 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: widget.onPlay,
                          icon: const Icon(Icons.play_arrow_rounded, size: 14),
                          label: const Text('Assistir', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}