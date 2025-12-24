import 'dart:ui' as ui;
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

    final devicePixelRatio = ui.window.devicePixelRatio;
    final targetWidth = widget.width != null ? (widget.width! * devicePixelRatio).toInt() : null;

    // Debug: log URL para verificar se está sendo passada corretamente
    if (widget.url.isNotEmpty && widget.url.length < 100) {
      print('🖼️ AdaptiveCachedImage: Tentando carregar: ${widget.url.substring(0, widget.url.length > 50 ? 50 : widget.url.length)}...');
    }
    
    return CachedNetworkImage(
      imageUrl: widget.url,
      cacheManager: AppImageCacheManager.instance,
      imageBuilder: (context, imageProvider) {
        final provider = targetWidth != null ? ResizeImage(imageProvider, width: targetWidth) : imageProvider;
        // Trigger fade-in animation quando imagem é carregada
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _fadeController.forward();
        });
        return FadeTransition(
          opacity: _fadeAnimation,
          child: Image(image: provider, width: widget.width, height: widget.height, fit: widget.fit),
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
