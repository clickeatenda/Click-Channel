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

class _AdaptiveCachedImageState extends State<AdaptiveCachedImage> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(duration: widget.fadeInDuration, vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_fadeController);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Validação: se URL está vazia, mostra placeholder
    // Aceita qualquer URL não vazia (deixa CachedNetworkImage lidar com erros)
    if (widget.url.isEmpty || widget.url.trim().isEmpty) {
      return widget.errorWidget ?? Container(
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

    // OTIMIZAÇÃO DE MEMÓRIA CRÍTICA PARA FIRESTICK:
    // Força decode da imagem em tamanho reduzido (thumbnail)
    // Isso evita OOM (Out Of Memory) ao carregar listas grandes com posters 4K
    const int optimizeMemCacheHeight = 400; // Altura suficiente para cards na TV (Grid tem ~200-300px)

    return CachedNetworkImage(
      imageUrl: widget.url,
      cacheManager: AppImageCacheManager.instance,
      // Parâmetros de otimização de memória
      memCacheHeight: optimizeMemCacheHeight,
      memCacheWidth: 300, // Limita largura também
      maxWidthDiskCache: 600, // Limita tamanho no disco
      maxHeightDiskCache: 800,
      
      imageBuilder: (context, imageProvider) {
        // Trigger fade-in animation quando imagem é carregada
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _fadeController.forward();
        });
        return FadeTransition(
          opacity: _fadeAnimation,
          child: Image(image: imageProvider, width: widget.width, height: widget.height, fit: widget.fit),
        );
      },
      placeholder: (context, url) => Shimmer.fromColors(
        baseColor: const Color(0xFF2A2A2A),
        highlightColor: const Color(0xFF3A3A3A),
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(Icons.image, color: Colors.white10, size: 32),
          ),
        ),
      ),
      errorWidget: (context, url, error) => widget.errorWidget ?? Container(
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
      ),
    );
  }
}
