import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../models/content_item.dart';

class HeroSection extends StatelessWidget {
  final ContentItem item;
  final Function(String) onPlay;

  const HeroSection({super.key, required this.item, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 600, // Altura conforme doc
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          CachedNetworkImage(
            imageUrl: item.image,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            memCacheHeight: 800,
            placeholder: (_, __) => Container(color: AppColors.background),
            errorWidget: (_, __, ___) => Container(color: AppColors.background),
          ),
          
          // Gradient Overlay
          Container(decoration: BoxDecoration(gradient: heroGradient)),

          // Content
          Positioned(
            left: 48, // paddingMedium
            bottom: 96,
            width: 600,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(999)),
                  child: Text("EM ALTA", style: AppTypography.labelMedium),
                ),
                const SizedBox(height: 16),
                Text(item.title, style: AppTypography.displayLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),
                Text("Uma experiência cinematográfica incrível aguarda por você neste título exclusivo.", 
                    style: AppTypography.titleLarge.copyWith(color: AppColors.mutedForeground)),
                const SizedBox(height: 32),
                Row(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.primaryForeground,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                      ),
                      onPressed: () => onPlay(item.url),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text("Assistir Agora"),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.foreground,
                        side: const BorderSide(color: AppColors.foreground),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                      ),
                      onPressed: () {},
                      icon: const Icon(Icons.info_outline),
                      label: const Text("Mais Informações"),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}