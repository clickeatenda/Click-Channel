import 'package:flutter/material.dart';
import 'dart:io';
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
  void didUpdateWidget(AdaptiveCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      // Reseta animação se a URL mudar (ex: carregou capa do TMDB)
      _fadeController.reset();
      // O forward será chamado pelo builder da nova imagem
    }
  }

  @override
  Widget build(BuildContext context) {
    // Validação: se URL está vazia, mostra placeholder
    if (widget.url.isEmpty || widget.url.trim().isEmpty) {
      return _buildPlaceholder();
    }

    // FIX: Suporte a imagens em Base64 (data:image/...)
    // Muitas playlists embedam ícones pequenos direto no M3U para evitar requests externos.
    if (widget.url.startsWith('data:image')) {
      try {
        final uriData = UriData.parse(widget.url);
        return Image.memory(
          uriData.contentAsBytes(),
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
        );
      } catch (e) {
        print('❌ Erro ao decodificar Base64 image: $e');
        return _buildErrorWidget();
      }
    }

    // WINDOWS REVERT: Voltamos a usar CachedNetworkImage pois o usuário relatou que funcionava antes.
    // O problema original ("falha em SSL/UserAgent") já foi tratado globalmente no main.dart e aqui.
    // Mantemos apenas a checagem de Base64 acima.

    // OTIMIZAÇÃO DE MEMÓRIA PARA MOBILE/TV (Firestick)
    const int optimizeMemCacheHeight = 400;

    return CachedNetworkImage(
      key: ValueKey(widget.url),
      imageUrl: widget.url,
      cacheManager: AppImageCacheManager.instance,
      memCacheHeight: optimizeMemCacheHeight,
      memCacheWidth: 300,
      maxWidthDiskCache: 600,
      maxHeightDiskCache: 800,
      
      imageBuilder: (context, imageProvider) {
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
      errorWidget: (context, url, error) {
        return widget.errorWidget ?? _buildErrorWidget();
      },
    );
  }

  Widget _buildPlaceholder() {
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

  Widget _buildErrorWidget() {
    return _buildPlaceholder();
  }
}
