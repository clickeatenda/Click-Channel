import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';
import '../models/content_item.dart';
import '../widgets/media_player_screen.dart';
import '../data/m3u_service.dart';
import '../data/tmdb_service.dart';
import '../utils/content_enricher.dart';
import '../core/config.dart';
import '../data/favorites_service.dart';
import '../data/watch_history_service.dart';
import 'dart:ui';

/// Tela de detalhes completa de filme com todas as informações otimizada para TV
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
  bool isFavorite = false;
  bool isWatched = false; // NOVO: Controle de status assistido

  ContentItem get _displayItem => enrichedItem ?? widget.item;

  @override
  void dispose() {
    // Limpeza agressiva removida para evitar tela cinza ao voltar
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    isFavorite = FavoritesService.isFavorite(widget.item);
    _checkWatchedStatus(); // NOVO
    _loadMetadata();
    _loadTmdbMetadata(); 
    _loadSimilarItems();
  }

  Future<void> _checkWatchedStatus() async {
    final watched = await WatchHistoryService.isWatched(widget.item.url);
    if (mounted) {
      setState(() {
        isWatched = watched;
      });
    }
  }

  Future<void> _toggleWatched() async {
    if (isWatched) {
      await WatchHistoryService.removeFromWatched(widget.item.url);
    } else {
      await WatchHistoryService.addToWatched(widget.item);
    }
    
    setState(() {
      isWatched = !isWatched;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(isWatched ? Icons.visibility : Icons.visibility_off, color: Colors.white),
              const SizedBox(width: 8),
              Text(isWatched ? 'Marcado como assistido' : 'Removido dos assistidos'),
            ],
          ),
          backgroundColor: isWatched ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          width: 300,
        ),
      );
    }
  }

  Future<void> _toggleFavorite() async {
    await FavoritesService.toggleFavorite(widget.item);
    setState(() {
      isFavorite = !isFavorite;
    });
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

  void _playMovie() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaPlayerScreen(
          url: _displayItem.url,
          item: _displayItem,
        ),
      ),
    );
  }

  Future<void> _loadMetadata() async {
    try {
      final enriched = await ContentEnricher.enrichItem(widget.item);
      if (mounted) {
        setState(() {
          enrichedItem = enriched;
          loadingMetadata = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          enrichedItem = widget.item;
          loadingMetadata = false;
        });
      }
    }
  }

  Future<void> _loadTmdbMetadata() async {
    try {
      final metadata = await TmdbService.searchContent(
        widget.item.title,
        year: widget.item.year.isNotEmpty ? widget.item.year : null,
        type: 'movie',
      );
      
      if (mounted) {
        setState(() {
          tmdbMetadata = metadata;
          loadingTmdb = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => loadingTmdb = false);
      }
    }
  }

  Future<void> _loadSimilarItems() async {
    try {
      List<ContentItem> items = [];
      if (widget.item.group != 'Jellyfin' && Config.playlistRuntime != null && Config.playlistRuntime!.isNotEmpty) {
        items = await M3uService.fetchCategoryItemsFromEnv(
          category: _displayItem.group,
          typeFilter: _displayItem.type,
          maxItems: 10, // Reduzido para performance
        );
        items.removeWhere((i) => i.title == _displayItem.title);
        
        // Enriquecimento leve (limite pequeno)
        final enriched = await ContentEnricher.enrichItems(items.take(8).toList());
        items = enriched;
      }
      if (mounted) {
        setState(() {
          similarItems = items.take(10).toList();
          loadingSimilar = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => loadingSimilar = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loadingMetadata) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black, // Fundo preto puro para performance
      body: Stack(
        children: [
          // Background Hero (edge-to-edge na parte superior)
          if (_displayItem.image.isNotEmpty)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.75,
              child: CachedNetworkImage(
                imageUrl: _displayItem.image,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          // Gradiente Escuro (Fade do backdrop para o conteúdo sólido)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.background.withOpacity(0.1),
                    AppColors.background.withOpacity(0.7),
                    AppColors.background,
                  ],
                  stops: const [0.0, 0.45, 0.8],
                ),
              ),
            ),
          ),
          // Conteúdo
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   // COLUNA DA ESQUERDA: Pôster + Info
                   SizedBox(
                     width: 240, 
                     child: Column(
                       children: [
                         // Botão Voltar
                         Align(
                           alignment: Alignment.centerLeft,
                           child: Padding(
                             padding: const EdgeInsets.only(bottom: 16),
                             child: IconButton(
                               onPressed: () => Navigator.pop(context),
                               icon: const Icon(Icons.arrow_back, color: Colors.white),
                               style: IconButton.styleFrom(
                                 backgroundColor: Colors.white10,
                                 padding: const EdgeInsets.all(12),
                               ),
                             ),
                           ),
                         ),
                         
                         ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: _displayItem.image,
                              width: 240,
                              height: 360,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: Colors.white10, height: 360),
                              errorWidget: (_, __, ___) => Container(color: Colors.grey[900], height: 360),
                            ),
                         ),
                         const SizedBox(height: 16),
                         
                         // Info Panel Glassmorphism
                         ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                                ),
                                child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildInfoRow('Ano', _displayItem.year),
                                const SizedBox(height: 8),
                                _buildInfoRow('Nota', _displayItem.rating > 0 ? _displayItem.rating.toStringAsFixed(1) : 'N/A'),
                                if (widget.item.quality.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black87,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.white12),
                                      ),
                                      child: Text(
                                        widget.item.quality.toUpperCase(), 
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                    ),
                                  ),
                                ],
                                ],
                              ),
                            ),
                          ),
                         ),
                       ],
                     ),
                   ),
                   
                   const SizedBox(width: 32),
                   
                   // COLUNA DA DIREITA: Informações e Conteúdo
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                          const SizedBox(height: 60), // Alinha com o poster
                          Text(
                            _displayItem.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                            ),
                          ),
                          
                          if ((_displayItem.originalTitle ?? '').isNotEmpty && _displayItem.originalTitle != _displayItem.title) ...[
                            const SizedBox(height: 8),
                            Text(
                              _displayItem.originalTitle!,
                              style: const TextStyle(color: Colors.white54, fontSize: 16, fontStyle: FontStyle.italic),
                            ),
                          ],

                          const SizedBox(height: 16),
                          
                          // Botões de Ação
                          Wrap(
                           spacing: 12,
                           runSpacing: 12,
                           children: [
                             ElevatedButton.icon(
                               autofocus: true,
                               onPressed: _playMovie,
                               icon: const Icon(Icons.play_arrow),
                               label: const Text('Assistir'),
                               style: ElevatedButton.styleFrom(
                                 backgroundColor: AppColors.primary,
                                 foregroundColor: Colors.white,
                                 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                               ),
                             ),
                             OutlinedButton.icon(
                               onPressed: _toggleFavorite,
                               icon: Icon(isFavorite ? Icons.check : Icons.add, size: 18),
                               label: Text(isFavorite ? 'Salvo' : 'Minha Lista'),
                               style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: isFavorite ? AppColors.primary : Colors.white38)),
                             ),
                             OutlinedButton.icon(
                               onPressed: _toggleWatched,
                               icon: Icon(isWatched ? Icons.visibility : Icons.visibility_off, size: 18),
                               label: Text(isWatched ? 'Assistido' : 'Marcar Assistido'),
                               style: OutlinedButton.styleFrom(
                                 foregroundColor: isWatched ? AppColors.primary : Colors.white, 
                                 side: BorderSide(color: isWatched ? AppColors.primary.withOpacity(0.5) : Colors.white12)
                               ),
                             ),
                           ],
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Gêneros
                          if (_displayItem.genre.isNotEmpty) ...[
                              Wrap(
                                spacing: 8,
                                children: _displayItem.genre.split(',').take(3).map((g) => Chip(
                                  label: Text(g.trim().toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white)),
                                  backgroundColor: AppColors.primary.withOpacity(0.5),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  side: BorderSide.none,
                                )).toList(),
                              ),
                              const SizedBox(height: 16),
                          ],
                          
                          // Sinopse
                          Text(
                            _displayItem.description.isNotEmpty ? _displayItem.description : 'Sinopse não disponível.',
                            maxLines: 6,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
                          ),
                          
                          const SizedBox(height: 32),
                          const Divider(color: Colors.white12),
                          const SizedBox(height: 16),
                          
                          // Elenco
                          if (tmdbMetadata != null && tmdbMetadata!.cast.isNotEmpty) ...[
                             const Text('Elenco', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                             const SizedBox(height: 12),
                             SizedBox(
                               height: 100,
                               child: ListView.separated(
                                 scrollDirection: Axis.horizontal,
                                 itemCount: tmdbMetadata!.cast.take(10).length,
                                 separatorBuilder: (_, __) => const SizedBox(width: 12),
                                 itemBuilder: (ctx, i) {
                                   final actor = tmdbMetadata!.cast[i];
                                   return _buildCastMemberFromTmdb(actor);
                                 },
                               ),
                             ),
                             const SizedBox(height: 24),
                          ],
                          
                          // Similares
                          const Text(
                              'Filmes Similares',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                            if (loadingSimilar)
                              const Center(child: CircularProgressIndicator())
                            else if (similarItems.isEmpty)
                              const Text('Nenhum filme similar encontrado', style: TextStyle(color: Colors.white54))
                            else
                              SizedBox(
                                height: 200,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: similarItems.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                                  itemBuilder: (context, index) {
                                    final item = similarItems[index];
                                    return _SimilarMovieCard(item: item);
                                  },
                                ),
                              ),
                       ],
                     ),
                   ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCastMemberFromTmdb(CastMember member) {
    return SizedBox(
      width: 80,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white10,
              image: member.profileUrl != null
                ? DecorationImage(image: NetworkImage(member.profileUrl!), fit: BoxFit.cover)
                : null
            ),
            child: member.profileUrl == null ? const Icon(Icons.person, color: Colors.white54) : null,
          ),
          const SizedBox(height: 4),
          Text(member.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 10), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

/// Card para filme similar com suporte a foco otimizado
class _SimilarMovieCard extends StatefulWidget {
  final ContentItem item;
  const _SimilarMovieCard({required this.item});

  @override
  State<_SimilarMovieCard> createState() => _SimilarMovieCardState();
}

class _SimilarMovieCardState extends State<_SimilarMovieCard> {
  bool _isFocused = false;

  void _open() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MovieDetailScreen(item: widget.item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && 
            (event.logicalKey == LogicalKeyboardKey.enter || 
             event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          _open();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: _open,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 140,
          transform: _isFocused ? (Matrix4.identity()..translate(0, -4)..scale(1.02)) : Matrix4.identity(),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF161b22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isFocused ? AppColors.primary : Colors.white.withOpacity(0.05),
              width: _isFocused ? 3 : 1,
            ),
            boxShadow: _isFocused 
                ? [BoxShadow(color: AppColors.primary.withOpacity(0.6), blurRadius: 24, spreadRadius: 4)] 
                : [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 7,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                  child: CachedNetworkImage(
                    imageUrl: widget.item.image,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (_, __) => Container(color: const Color(0xFF0F1620)),
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFF0F1620),
                      child: const Icon(Icons.movie, color: Colors.white30),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _isFocused ? Colors.white : Colors.white70,
                          fontSize: 11,
                          fontWeight: _isFocused ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ]
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
