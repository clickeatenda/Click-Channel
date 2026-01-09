import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';
import '../models/content_item.dart';
import '../widgets/media_player_screen.dart';
import '../data/m3u_service.dart';
import '../utils/content_enricher.dart';
import '../core/config.dart';
import '../data/favorites_service.dart';

/// Tela de detalhes completa de filme/série com todas as informações
class MovieDetailScreen extends StatefulWidget {
  final ContentItem item;

  const MovieDetailScreen({super.key, required this.item});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  List<ContentItem> similarItems = [];
  bool loadingSimilar = true;
  ContentItem? enrichedItem;
  bool loadingMetadata = true;
  bool isFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
    _loadSimilarItems();
    _checkFavorite();
  }

  Future<void> _checkFavorite() async {
    final fav = await FavoritesService.isFavorite(widget.item);
    if (mounted) setState(() => isFavorite = fav);
  }

  Future<void> _toggleFavorite() async {
    await FavoritesService.toggleFavorite(widget.item);
    _checkFavorite();
    
    if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFavorite ? 'Adicionado aos Favoritos' : 'Removido dos Favoritos'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          )
       );
    }
  }

  Future<void> _loadMetadata() async {
    // Enriquece o item com dados do TMDB
    try {
      final enriched = await ContentEnricher.enrichItem(widget.item);
      if (mounted) {
        setState(() {
          enrichedItem = enriched;
          loadingMetadata = false;
        });
      }
    } catch (e) {
      // Se falhar, usa item original
      if (mounted) {
        setState(() {
          enrichedItem = widget.item;
          loadingMetadata = false;
        });
      }
    }
  }

  Future<void> _loadSimilarItems() async {
    try {
      List<ContentItem> items = [];
      if (Config.playlistRuntime != null && Config.playlistRuntime!.isNotEmpty) {
        items = await M3uService.fetchCategoryItemsFromEnv(
          category: _displayItem.group,
          typeFilter: _displayItem.type,
          maxItems: 20,
        );
        // Remove o item atual
        items.removeWhere((i) => i.title == _displayItem.title);
        
        // Enriquece itens similares
        final enriched = await ContentEnricher.enrichItems(items.take(10).toList());
        items = enriched;
      }
      if (mounted) {
        setState(() {
          similarItems = items.take(5).toList();
          loadingSimilar = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => loadingSimilar = false);
      }
    }
  }

  ContentItem get _displayItem => enrichedItem ?? widget.item;

  @override
  Widget build(BuildContext context) {
    if (loadingMetadata) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background blur com poster
          if (_displayItem.image.isNotEmpty)
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: _displayItem.image,
                fit: BoxFit.cover,
                color: Colors.black.withOpacity(0.7),
                colorBlendMode: BlendMode.darken,
                errorWidget: (_, __, ___) => Container(color: Colors.black),
              ),
            ),
          // Overlay escuro
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.black.withOpacity(0.95),
                  ],
                ),
              ),
            ),
          ),
          // Conteúdo
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // COLUNA ESQUERDA - Informações
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Botão voltar
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(height: 16),
                          
                          // Tags de gênero
                          Wrap(
                            spacing: 8,
                            children: [
                              if (_displayItem.genre.isNotEmpty)
                                ..._displayItem.genre.split(',').take(2).map((g) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        g.trim().toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          // Ano, Classificação, Duração
                          Row(
                            children: [
                              Text(
                                _displayItem.year,
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                              const SizedBox(width: 12),
                              if (_displayItem.quality.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[800],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _displayItem.quality.toUpperCase(),
                                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Título
                          Text(
                            _displayItem.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Rating e Match Score
                          Row(
                            children: [
                              // Rating OMDB/TMDB
                              if (_displayItem.rating > 0)
                                Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 24),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${_displayItem.rating.toStringAsFixed(1)} / 10',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              if (_displayItem.rating > 0) const SizedBox(width: 24),
                              
                              if (_displayItem.popularity > 0)
                                Row(
                                  children: [
                                    const Icon(Icons.trending_up, color: Colors.green, size: 20),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${(_displayItem.popularity.clamp(0, 100)).toInt()}% Relevância',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          
                          // Botões de ação
                          Row(
                            children: [
                              // Assistir
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MediaPlayerScreen(
                                        url: _displayItem.url,
                                        item: _displayItem,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.play_arrow, size: 24),
                                label: const Text('Assistir', style: TextStyle(fontSize: 16)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Favoritos
                              OutlinedButton.icon(
                                onPressed: _toggleFavorite,
                                icon: Icon(
                                  isFavorite ? Icons.check : Icons.add,
                                  size: 20,
                                  color: isFavorite ? AppColors.accent : Colors.white,
                                ),
                                label: Text(
                                  isFavorite ? 'Favorito' : 'Favoritos',
                                  style: TextStyle(
                                     color: isFavorite ? AppColors.accent : Colors.white
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: isFavorite ? AppColors.accent : Colors.white38
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),
                          
                          // Sinopse
                          const Text(
                            'Sinopse',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _displayItem.description.isNotEmpty
                                ? _displayItem.description
                                : 'Sinopse não disponível.',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 40),
                          
                          // Relacionados
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Relacionados',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (loadingSimilar)
                            const Center(child: CircularProgressIndicator())
                          else if (similarItems.isEmpty)
                            const Text(
                              'Nenhum conteúdo similar encontrado',
                              style: TextStyle(color: Colors.white54),
                            )
                          else
                            SizedBox(
                              height: 280,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: similarItems.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  final item = similarItems[index];
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => MovieDetailScreen(item: item),
                                        ),
                                      );
                                    },
                                    child: SizedBox(
                                      width: 160,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: CachedNetworkImage(
                                                imageUrl: item.image,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                placeholder: (_, __) => Container(
                                                  color: Colors.grey[900],
                                                  child: const Center(
                                                    child: CircularProgressIndicator(),
                                                  ),
                                                ),
                                                errorWidget: (_, __, ___) => Container(
                                                  color: Colors.grey[900]!,
                                                  child: const Icon(
                                                    Icons.image_not_supported,
                                                    color: Colors.white24,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            item.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48),
                    
                    // COLUNA DIREITA - Poster
                    SizedBox(
                      width: 320,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 80),
                          // Poster grande
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: _displayItem.image,
                              width: double.infinity,
                              height: 480,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                color: Colors.grey[900]!,
                                height: 480,
                                child: const Icon(
                                  Icons.image_not_supported,
                                  color: Colors.white24,
                                  size: 64,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

