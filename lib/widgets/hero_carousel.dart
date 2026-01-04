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

  const HeroCarousel({super.key, required this.items, required this.onPlay});

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  final PageController _pageController = PageController();
  final FocusNode _focusNode = FocusNode();
  int _currentPage = 0;
  Timer? _timer;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    // Troca de slide a cada 5 segundos
    _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      final itemsPerPage = 3;
      final totalPages = (widget.items.take(6).length / itemsPerPage).ceil();
      
      if (_currentPage < totalPages - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }
  
  void _goToNext() {
    final itemsPerPage = 3;
    final totalPages = (widget.items.take(6).length / itemsPerPage).ceil();
    
    if (_currentPage < totalPages - 1) {
      setState(() => _currentPage++);
      _pageController.animateToPage(_currentPage, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }
  
  void _goToPrevious() {
    if (_currentPage > 0) {
      setState(() => _currentPage--);
      _pageController.animateToPage(_currentPage, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox(height: 280);

    // Mostrar no máximo os primeiros 6 itens (2 páginas de 3)
    final displayItems = widget.items.take(6).toList();
    final itemsPerPage = 3;
    final totalPages = (displayItems.length / itemsPerPage).ceil();

    return Focus(
      focusNode: _focusNode,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          // Navegação horizontal
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _goToNext();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _goToPrevious();
            return KeyEventResult.handled;
          }
          // Ativar (reproduzir) o item atual
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.gameButtonA) {
            final itemIndex = _currentPage * itemsPerPage;
            if (itemIndex < displayItems.length) {
              widget.onPlay(displayItems[itemIndex]);
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          border: _isFocused 
              ? Border.all(color: AppColors.primary, width: 3)
              : null,
        ),
        child: SizedBox(
          height: 380,
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: totalPages,
                onPageChanged: (int page) => setState(() => _currentPage = page),
                itemBuilder: (context, pageIndex) {
                  final startIndex = pageIndex * itemsPerPage;
                  final endIndex = (startIndex + itemsPerPage).clamp(0, displayItems.length);
                  final pageItems = displayItems.sublist(startIndex, endIndex);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: pageItems.map((originalItem) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: LazyTmdbLoader(
                              item: originalItem,
                              builder: (item, isLoading) {
                                return _buildHeroItem(item);
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
              // Indicadores (Dots)
              if (totalPages > 1)
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(totalPages, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index ? AppColors.primary : Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroItem(ContentItem item) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Imagem de Fundo
          item.image.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: item.image,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  memCacheHeight: 500,
                  placeholder: (_, __) => Container(color: AppColors.background),
                  errorWidget: (_, __, ___) => Container(color: const Color(0xFF1A1A1A)),
                )
              : Container(color: const Color(0xFF1A1A1A)),

          // 2. Degradê Preto
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black87],
                stops: [0.5, 1.0],
              ),
            ),
          ),

          // 3. Conteúdo
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    "DESTAQUE",
                    style: AppTypography.labelMedium.copyWith(fontSize: 9),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  style: AppTypography.titleLarge.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.rating > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        item.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.primaryForeground,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    minimumSize: const Size(0, 36),
                  ),
                  onPressed: () => widget.onPlay(item),
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text("Assistir", style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}