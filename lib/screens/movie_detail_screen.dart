import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';
import '../models/content_item.dart';
import '../widgets/media_player_screen.dart';
import '../data/m3u_service.dart';
import '../data/tmdb_service.dart';
import '../utils/content_enricher.dart';
import '../core/config.dart';
import '../core/utils/logger.dart';

import '../data/favorites_service.dart'; // NOVO import

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
  TmdbMetadata? tmdbMetadata;
  bool loadingMetadata = true;
  bool loadingTmdb = true;
  bool isFavorite = false; // Novo estado

  @override
  void initState() {
    super.initState();
    isFavorite = FavoritesService.isFavorite(widget.item); // Inicializa estado
    _loadMetadata();
    _loadTmdbMetadata(); 
    _loadSimilarItems();
  }

  Future<void> _toggleFavorite() async {
    await FavoritesService.toggleFavorite(widget.item);
    setState(() {
      isFavorite = !isFavorite;
    });
    // Feedback visual/tátil
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(isFavorite ? Icons.check_circle : Icons.delete, color: Colors.white),
              const SizedBox(width: 8),
              Text(isFavorite ? 'Adicionado aos Favoritos' : 'Removido dos Favoritos'),
            ],
          ),
          backgroundColor: isFavorite ? Colors.green : Colors.red,
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          width: 300,
        ),
      );
    }
  }



  /// Carrega dados básicos do item (descrição, genero, etc)
  Future<void> _loadMetadata() async {
    // Enriquece o item com dados do TMDB (descrição, gênero, popularidade)
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

  /// Carrega metadados detalhados do TMDB (cast, diretor, orçamento, receita)
  /// LAZY-LOAD: Executado em background, não bloqueia a UI
  Future<void> _loadTmdbMetadata() async {
    try {
      AppLogger.info('🎬 Lazy-loading TMDB metadata para: ${widget.item.title}');
      
      final metadata = await TmdbService.searchContent(
        widget.item.title,
        year: widget.item.year.isNotEmpty ? widget.item.year : null,
        type: widget.item.isSeries ? 'tv' : 'movie',
      );
      
      if (metadata != null) {
        AppLogger.info('✅ TMDB metadata carregado: cast=${metadata.cast.length}, director=${metadata.director}');
      } else {
        AppLogger.warning('⚠️ TMDB metadata não encontrado');
      }
      
      if (mounted) {
        setState(() {
          tmdbMetadata = metadata;
          loadingTmdb = false;
        });
      }
    } catch (e) {
      AppLogger.error('❌ Erro ao carregar TMDB metadata: $e');
      if (mounted) {
        setState(() => loadingTmdb = false);
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
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey[800],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'PG-13',
                                  style: TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                '2H 28M',
                                style: TextStyle(color: Colors.white70, fontSize: 14),
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
                              // Rating com estrela (do TMDB)
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
                              // Match Score (baseado em popularidade)
                              if (_displayItem.popularity > 0)
                                Row(
                                  children: [
                                    const Icon(Icons.trending_up, color: Colors.green, size: 20),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${(_displayItem.popularity.clamp(0, 100)).toInt()}% Match',
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
                              // Watch Now
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
                                label: const Text('Watch Now', style: TextStyle(fontSize: 16)),
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
                              // My List (Botão Atualizado)
                              OutlinedButton.icon(
                                onPressed: _toggleFavorite,
                                icon: Icon(
                                  isFavorite ? Icons.check : Icons.add,
                                  size: 20,
                                  color: Colors.white,
                                ),
                                label: Text(isFavorite ? 'Minha Lista' : 'Adicionar'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: isFavorite ? Colors.white10 : Colors.transparent,
                                  side: BorderSide(
                                    color: isFavorite ? AppColors.primary : Colors.white38,
                                    width: isFavorite ? 2 : 1,
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Trailer
                              IconButton(
                                onPressed: () {},
                                icon: const Icon(Icons.videocam, color: Colors.white70),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white10,
                                  padding: const EdgeInsets.all(12),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Share
                              IconButton(
                                onPressed: () {},
                                icon: const Icon(Icons.share, color: Colors.white70),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white10,
                                  padding: const EdgeInsets.all(12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),
                          
                          // Synopsis
                          const Text(
                            'Synopsis',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
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
                          
                          // Top Cast - Dynamic from TMDB
                          const Text(
                            'TOP CAST',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (loadingTmdb)
                            const SizedBox(
                              height: 120,
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else if (tmdbMetadata?.cast.isNotEmpty ?? false)
                            Row(
                              children: tmdbMetadata!.cast.take(4).map((member) {
                                return Expanded(
                                  child: _buildCastMemberFromTmdb(member),
                                );
                              }).toList(),
                            )
                          else
                            const Text(
                              'Cast information not available',
                              style: TextStyle(color: Colors.white54, fontSize: 14),
                            ),
                          const SizedBox(height: 40),
                          
                          // More Like This
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'More Like This',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left, color: Colors.white70),
                                    onPressed: () {},
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right, color: Colors.white70),
                                    onPressed: () {},
                                  ),
                                ],
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
                    
                    // COLUNA DIREITA - Poster e Info Panel
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
                              placeholder: (_, __) => Container(
                                color: Colors.grey[900]!,
                                height: 480,
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
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
                          const SizedBox(height: 24),
                          
                          // Info Panel - Dynamic from TMDB
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey[900]!.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Director - from TMDB
                                if (tmdbMetadata?.director != null && tmdbMetadata!.director!.isNotEmpty)
                                  _buildInfoRow('Director', tmdbMetadata!.director!)
                                else
                                  _buildInfoRow('Director', 'N/A'),
                                
                                const SizedBox(height: 12),
                                
                                // Budget - from TMDB, formatted
                                if (tmdbMetadata?.budget != null && tmdbMetadata!.budget! > 0)
                                  _buildInfoRow('Budget', '\$${(tmdbMetadata!.budget! / 1000000).toStringAsFixed(1)}M')
                                else
                                  _buildInfoRow('Budget', 'N/A'),
                                
                                const SizedBox(height: 12),
                                
                                // Box Office - from TMDB, formatted
                                if (tmdbMetadata?.revenue != null && tmdbMetadata!.revenue! > 0)
                                  _buildInfoRow('Box Office', '\$${(tmdbMetadata!.revenue! / 1000000).toStringAsFixed(1)}M')
                                else
                                  _buildInfoRow('Box Office', 'N/A'),
                                
                                const SizedBox(height: 12),
                                
                                // Runtime - from TMDB
                                if (tmdbMetadata?.runtime != null && tmdbMetadata!.runtime! > 0)
                                  _buildInfoRow('Runtime', '${tmdbMetadata!.runtime}m')
                                else
                                  _buildInfoRow('Runtime', 'N/A'),
                                
                                if (widget.item.quality.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  _buildInfoRow('Quality', widget.item.quality.toUpperCase()),
                                ],
                              ],
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

  Widget _buildCastMemberFromTmdb(CastMember member) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[800],
            border: Border.all(color: Colors.white24, width: 2),
          ),
          child: member.profilePath != null
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: member.profileUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: Colors.grey[900],
                      child: const Icon(Icons.person, color: Colors.white54, size: 30),
                    ),
                    errorWidget: (_, __, ___) => const Icon(Icons.person, color: Colors.white54, size: 30),
                  ),
                )
              : const Icon(Icons.person, color: Colors.white54, size: 30),
        ),
        const SizedBox(height: 8),
        Text(
          member.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          member.character,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 9,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

