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
    final devicePixelRatio = ui.window.devicePixelRatio;
    final targetWidth = widget.width != null ? (widget.width! * devicePixelRatio).toInt() : null;

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
        baseColor: Colors.grey[850]!,
        highlightColor: Colors.grey[800]!,
        child: Container(
          width: widget.width,
          height: widget.height,
          color: Colors.grey[850],
        ),
      ),
      errorWidget: (context, url, error) => widget.errorWidget ?? Container(
        color: Colors.white12,
        width: widget.width,
        height: widget.height,
        child: const Icon(Icons.image_not_supported, color: Colors.white24),
      ),
    );
  }
}
