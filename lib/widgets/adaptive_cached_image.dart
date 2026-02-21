import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../core/image_cache_manager.dart';

/// Widget de imagem com lazy loading, fade-in animation e cache otimizado
class AdaptiveCachedImage extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? errorWidget;
  final Duration fadeInDuration;

  const AdaptiveCachedImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorWidget,
    this.fadeInDuration = const Duration(milliseconds: 300),
  });

  @override
  State<AdaptiveCachedImage> createState() => _AdaptiveCachedImageState();
}

class _AdaptiveCachedImageState extends State<AdaptiveCachedImage> {
  @override
  Widget build(BuildContext context) {
    // Validação: se URL está vazia, mostra placeholder
    if (widget.url.isEmpty || widget.url.trim().isEmpty) {
      return widget.errorWidget ?? _buildErrorPlaceholder();
    }

    // OTIMIZAÇÃO DE MEMÓRIA PARA FIRESTICK
    const int optimizeMemCacheHeight = 400;

    return CachedNetworkImage(
      imageUrl: widget.url,
      cacheManager: AppImageCacheManager.instance,
      httpHeaders: const {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
      memCacheHeight: optimizeMemCacheHeight,
      memCacheWidth: 300,
      maxWidthDiskCache: 600,
      maxHeightDiskCache: 800,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      fadeInDuration: widget.fadeInDuration,
      fadeOutDuration: const Duration(milliseconds: 200),
      // Usa placeholder transparente para evitar flashes cinzas em rebuilds/remounts
      placeholder: (context, url) => Container(
        width: widget.width,
        height: widget.height,
        color: Colors.transparent, 
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white10)),
          ),
        ),
      ),
      errorWidget: (context, url, error) => widget.errorWidget ?? _buildErrorPlaceholder(),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      width: widget.width,
      height: widget.height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image, color: Colors.white24, size: 28),
          const SizedBox(height: 4),
          Text(
            'Sem imagem',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}
