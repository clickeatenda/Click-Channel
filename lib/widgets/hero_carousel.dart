import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../models/content_item.dart';

class HeroCarousel extends StatefulWidget {
  final List<ContentItem> items;
  final Function(ContentItem) onPlay;

  const HeroCarousel({super.key, required this.items, required this.onPlay});

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Troca de slide a cada 8 segundos
    _timer = Timer.periodic(const Duration(seconds: 8), (Timer timer) {
      if (_currentPage < widget.items.length - 1) {
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

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox(height: 280);

    return SizedBox(
      height: 320,
      child: PageView.builder(
        controller: _pageController,
        itemCount: widget.items.length,
        onPageChanged: (int page) => setState(() => _currentPage = page),
        itemBuilder: (context, index) {
          final item = widget.items[index];
          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. Imagem de Fundo - melhor enquadramento
              item.image.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: item.image,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter, // Alinha no topo para melhor enquadramento
                      memCacheHeight: 400,
                      placeholder: (_, __) => Container(color: AppColors.background),
                      errorWidget: (_, __, ___) => Container(color: const Color(0xFF1A1A1A)),
                    )
                  : Container(color: const Color(0xFF1A1A1A)),

              // 2. Degradê Preto (Fundo para o texto)
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, AppColors.background],
                    stops: [0.4, 1.0],
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Colors.black.withOpacity(0.9), Colors.transparent],
                    stops: const [0.0, 0.6],
                  ),
                ),
              ),

              // 3. Conteúdo (Título e Botões)
              Positioned(
                left: 32,
                bottom: 24,
                width: 500,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(999)),
                      child: Text("DESTAQUE", style: AppTypography.labelMedium.copyWith(fontSize: 10)),
                    ),
                    const SizedBox(height: 8),
                    Text(item.title,
                        style: AppTypography.displayLarge.copyWith(fontSize: 22),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.primaryForeground,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: () => widget.onPlay(item),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text("Assistir", style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              )
            ],
          );
        },
      ),
    );
  }
}