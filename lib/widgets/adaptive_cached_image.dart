import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../core/image_cache_manager.dart';

class AdaptiveCachedImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? errorWidget;

  const AdaptiveCachedImage({super.key, required this.url, this.width, this.height, this.fit = BoxFit.cover, this.errorWidget});

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = ui.window.devicePixelRatio;
    final targetWidth = width != null ? (width! * devicePixelRatio).toInt() : null;

    return CachedNetworkImage(
      imageUrl: url,
      cacheManager: AppImageCacheManager.instance,
      imageBuilder: (context, imageProvider) {
        final provider = targetWidth != null ? ResizeImage(imageProvider, width: targetWidth) : imageProvider;
        return Image(image: provider, width: width, height: height, fit: fit);
      },
      placeholder: (context, url) => Shimmer.fromColors(
        baseColor: Colors.grey[850]!,
        highlightColor: Colors.grey[800]!,
        child: Container(
          width: width,
          height: height,
          color: Colors.grey[850],
        ),
      ),
      errorWidget: (context, url, error) => errorWidget ?? Container(color: Colors.white12, width: width, height: height, child: const Icon(Icons.image_not_supported, color: Colors.white24)),
    );
  }
}
