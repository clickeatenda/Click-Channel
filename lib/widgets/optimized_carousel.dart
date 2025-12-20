import 'package:flutter/material.dart';
import '../models/content_item.dart';
import 'adaptive_cached_image.dart';

/// Widget otimizado para carousel com lazy loading
class OptimizedCarousel extends StatefulWidget {
  final List<ContentItem> items;
  final double height;
  final ValueChanged<ContentItem> onItemTap;
  final int maxItemsToLoad;

  const OptimizedCarousel({
    super.key,
    required this.items,
    this.height = 300,
    required this.onItemTap,
    this.maxItemsToLoad = 5,
  });

  @override
  State<OptimizedCarousel> createState() => _OptimizedCarouselState();
}

class _OptimizedCarouselState extends State<OptimizedCarousel> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _currentPage = index),
        itemCount: widget.items.length,
        itemBuilder: (context, index) {
          final item = widget.items[index];
          // Apenas construir widgets que estão visíveis
          final isVisible = (index - _currentPage).abs() < 2;
          
          return isVisible
              ? _CarouselCard(item: item, onTap: () => widget.onItemTap(item))
              : const SizedBox();
        },
      ),
    );
  }
}

class _CarouselCard extends StatelessWidget {
  final ContentItem item;
  final VoidCallback onTap;

  const _CarouselCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AdaptiveCachedImage(
                url: item.image,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorWidget: const Icon(Icons.image_not_supported, color: Colors.grey),
              ),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  dynamic _getCacheManager() {
    // Retorna null para usar o cache padrão
    return null;
  }
}
