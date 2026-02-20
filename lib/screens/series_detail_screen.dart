import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';
import '../core/config.dart';
import '../models/content_item.dart';
import '../models/series_details.dart';
import '../data/api_service.dart';
import '../data/m3u_service.dart';
import '../widgets/media_player_screen.dart';
import '../utils/content_enricher.dart';

import '../data/favorites_service.dart'; // NOVO import
import '../data/jellyfin_service.dart';

import 'season_details_screen.dart';

/// Tela de detalhes completa de série com todas as informações
/// Layout similar ao MovieDetailScreen
class SeriesDetailScreen extends StatefulWidget {
  final ContentItem item;
  const SeriesDetailScreen({super.key, required this.item});

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  SeriesDetails? details;
  bool loading = true;
  String? selectedSeason;
  String? selectedAudioType;
  List<String> availableAudioTypes = [];
  ContentItem? enrichedItem;
  bool loadingMetadata = true;
  List<ContentItem> similarItems = [];
  bool loadingSimilar = true;
  bool isFavorite = false; // Novo estado

  @override
  void dispose() {
    // Limpeza AGRESSIVA de memória ao sair da tela
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    isFavorite = FavoritesService.isFavorite(widget.item);
    
    // Carrega detalhes básicos (crítico para UI)
    _loadDetails();
    
    // TMDB DESATIVADO TEMPORARIAMENTE PARA TESTE DE PERFORMANCE
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   if (mounted) {
    //     _loadMetadata();
    //      Future.delayed(const Duration(milliseconds: 500), () {
    //        if(mounted) _loadSimilarItems();
    //      });
    //   }
    // });
    
    // Marca como carregado imediatamente (sem esperar TMDB)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          enrichedItem = widget.item;
          loadingMetadata = false;
          loadingSimilar = false;
        });
      }
    });
  }

  Future<void> _toggleFavorite() async {
    await FavoritesService.toggleFavorite(widget.item);
    if (!mounted) return;
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
              Text(isFavorite ? 'Série adicionada aos Favoritos' : 'Série removida dos Favoritos'),
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



  Future<void> _loadMetadata() async {
    // Enriquece o item com dados do TMDB EM BACKGROUND
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

  Future<void> _loadDetails() async {
    // Carrega detalhes da série (temporadas/episódios) com proteção contra crash
    SeriesDetails? d;
    
    try {
      if (widget.item.group == 'Jellyfin' || widget.item.id.length > 30) {
        // Lógica JELLYFIN (Prioritária)
        try {
          final seasons = await JellyfinService.getSeasons(widget.item.id);
          final Map<String, List<ContentItem>> seasonsMap = {};
          
          for (final s in seasons) {
             final seasonName = s.title;
             final episodes = await JellyfinService.getEpisodes(widget.item.id, s.id);
             seasonsMap[seasonName] = episodes;
          }
          
          d = SeriesDetails(seasons: seasonsMap);
        } catch (e) {
          print('❌ Erro ao carregar detalhes Jellyfin: $e');
        }
      } else if (Config.playlistRuntime != null && Config.playlistRuntime!.isNotEmpty) {
        // Lógica M3U (Fallback) - com timeout para evitar travamento
        try {
          availableAudioTypes = await M3uService.getAvailableAudioTypesForSeries(widget.item.title, widget.item.group)
              .timeout(const Duration(seconds: 10), onTimeout: () => []);
          d = await M3uService.fetchSeriesDetailsFromM3u(widget.item.title, widget.item.group)
              .timeout(const Duration(seconds: 15), onTimeout: () => null);
        } catch (e) {
          print('❌ Erro ao carregar detalhes M3U: $e');
        }
      } else {
        d = await ApiService.fetchSeriesDetails(widget.item.id);
      }
    } catch (e, st) {
      print('❌ Erro CRÍTICO ao carregar detalhes da série: $e');
      print(st);
    }
    
    if (mounted) {
      setState(() {
        details = d;
        if (d != null && d.seasons.isNotEmpty) {
          var keys = d.seasons.keys.toList();
          // Ordenação numérica inteligente das temporadas
          keys.sort((a, b) {
            int na = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            int nb = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            return na.compareTo(nb);
          });
          selectedSeason = keys.first;
        }
        loading = false;
      });
    }
  }

  Future<void> _loadSimilarItems() async {
    // Carrega séries similares EM BACKGROUND (não é crítico)
    try {
      List<ContentItem> items = [];
      if (Config.playlistRuntime != null && Config.playlistRuntime!.isNotEmpty) {
        items = await M3uService.fetchCategoryItemsFromEnv(
          category: _displayItem.group,
          typeFilter: 'series',
          maxItems: 10,
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
    if (loadingMetadata || loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary))
      );
    }
    if (details == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Text("Série indisponível", style: TextStyle(color: Colors.white))
        )
      );
    }

    // Ordenação da lista para exibição
    final sortedSeasons = details!.seasons.keys.toList();
    sortedSeasons.sort((a, b) {
      int na = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      int nb = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return na.compareTo(nb);
    });

    return Scaffold(
      backgroundColor: Colors.black, // Fundo preto puro para performance
      body: Stack(
        children: [
          // Background estático OTIMIZADO (sem CachedNetworkImage pesado em background)
          // Background Image REMOVIDA para performance extrema no Firestick
          // Apenas fundo preto (definido no Scaffold backgroundColor)

          
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
                         // Botão Voltar (Importante!)
                         Align(
                           alignment: Alignment.centerLeft,
                           child: Padding(
                             padding: const EdgeInsets.only(bottom: 16),
                             child: FloatingActionButton.small(
                               onPressed: () => Navigator.pop(context),
                               backgroundColor: Colors.white10,
                               child: const Icon(Icons.arrow_back, color: Colors.white),
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
                              memCacheWidth: 240,
                              errorWidget: (_, __, ___) => Container(color: Colors.grey[900], height: 360),
                            ),
                         ),
                         const SizedBox(height: 16),
                         // Info Panel simplificado
                         Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildInfoRow('Temporadas', '${sortedSeasons.length}'), 
                                if (selectedSeason != null && details != null && details!.seasons[selectedSeason] != null) ...[
                                  const SizedBox(height: 8),
                                  _buildInfoRow('Episódios', '${details!.seasons[selectedSeason]!.length}'),
                                ]
                              ],
                            ),
                         ),
                       ],
                     ),
                   ),
                   
                   const SizedBox(width: 32),
                   
                   // COLUNA DA DIREITA
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                          const SizedBox(height: 60), // Espaço topo alinhar com poster
                          Text(
                            _displayItem.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Botões
                          Wrap(
                           spacing: 12,
                           runSpacing: 12,
                           children: [
                             ElevatedButton.icon(
                               onPressed: (selectedSeason != null && details != null && details!.seasons.isNotEmpty && details!.seasons[selectedSeason]!.isNotEmpty) 
                                ? () {
                                   final firstEpisode = details!.seasons[selectedSeason]!.first;
                                   Navigator.push(context, MaterialPageRoute(builder: (_) => MediaPlayerScreen(url: firstEpisode.url, item: firstEpisode)));
                                 }
                                : null,
                               icon: const Icon(Icons.play_arrow),
                               label: const Text('Assistir'),
                               style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                             ),
                             OutlinedButton.icon(
                               onPressed: _toggleFavorite,
                               icon: Icon(isFavorite ? Icons.check : Icons.add, size: 18),
                               label: Text(isFavorite ? 'Salvo' : 'Minha Lista'),
                               style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: isFavorite ? AppColors.primary : Colors.white38)),
                             ),
                           ],
                          ),
                          
                          const SizedBox(height: 24),
                          Text(_displayItem.description.isNotEmpty ? _displayItem.description : 'Sem sinopse.', maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
                          
                          const SizedBox(height: 32),
                          const Divider(color: Colors.white12),
                          const SizedBox(height: 16),
                          
                          // Selector de Temporadas Otimizado
                          SizedBox(
                            height: 40,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: sortedSeasons.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (ctx, i) {
                                final season = sortedSeasons[i];
                                return _SeasonChip(
                                  label: '$season',
                                  isActive: season == selectedSeason,
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SeasonDetailsScreen(
                                          seasonName: '$season',
                                          episodes: details!.seasons[season]!,
                                          seriesTitle: widget.item.title,
                                          posterUrl: widget.item.image,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 20, bottom: 20),
                              child: Text(
                                'Clique na temporada acima para ver os episódios',
                                style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
                              ),
                            ),
                          ),
                          // Lista de episodios desativada em favor da nova tela
                          if (false && selectedSeason != null && details != null && details!.seasons.containsKey(selectedSeason))
                             Builder(
                               builder: (context) {
                                 final episodes = details!.seasons[selectedSeason]!;
                                 final limit = 20; 
                                 final displayedEpisodes = episodes.take(limit).toList();
                                 return Column(
                                   children: [
                                     ...displayedEpisodes.asMap().entries.map((entry) => _EpisodeItem(episode: entry.value, index: entry.key)).toList(),
                                      if (episodes.length > limit)
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text('Mais ${episodes.length - limit} episódios...', style: const TextStyle(color: Colors.white54)),
                                        ),
                                   ],
                                 );
                               }
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

/// Widget para chip de temporada com suporte a foco
class _SeasonChip extends StatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback onPressed;

  const _SeasonChip({
    required this.label,
    required this.isActive,
    required this.onPressed,
  });

  @override
  State<_SeasonChip> createState() => _SeasonChipState();
}

class _SeasonChipState extends State<_SeasonChip> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && 
            (event.logicalKey == LogicalKeyboardKey.enter || 
             event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isActive 
                ? AppColors.primary 
                : (_isFocused ? Colors.white12 : Colors.transparent),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: widget.isActive 
                  ? AppColors.primary 
                  : (_isFocused ? Colors.white : Colors.white24),
              width: _isFocused ? 2 : 1,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: (widget.isActive || _isFocused) ? Colors.white : Colors.white70,
              fontWeight: (widget.isActive || _isFocused) ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget para item de episódio com suporte a foco de controle remoto
class _EpisodeItem extends StatefulWidget {
  final ContentItem episode;
  final int index;

  const _EpisodeItem({
    required this.episode,
    required this.index,
  });

  @override
  State<_EpisodeItem> createState() => _EpisodeItemState();
}

class _EpisodeItemState extends State<_EpisodeItem> {
  bool _isFocused = false;

  void _play() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaPlayerScreen(
          url: widget.episode.url,
          item: widget.episode,
        ),
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
          _play();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: _play,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _isFocused 
                ? AppColors.primary.withOpacity(0.3) 
                : Colors.grey[900]!.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isFocused ? AppColors.primary : Colors.white10,
              width: _isFocused ? 2 : 1,
            ),
            boxShadow: _isFocused ? [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ] : null,
          ),
          child: ListTile(
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _isFocused ? AppColors.primary : Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${widget.index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            title: Text(
              widget.episode.title,
              style: TextStyle(
                color: Colors.white,
                fontWeight: _isFocused ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Episódio ${widget.index + 1}',
              style: const TextStyle(color: Colors.white54),
            ),
            trailing: Icon(
              Icons.play_circle_fill, 
              color: _isFocused ? Colors.white : AppColors.primary,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }
}

/// Card para série similar com suporte a foco
class _SimilarSeriesCard extends StatefulWidget {
  final ContentItem item;
  const _SimilarSeriesCard({required this.item});

  @override
  State<_SimilarSeriesCard> createState() => _SimilarSeriesCardState();
}

class _SimilarSeriesCardState extends State<_SimilarSeriesCard> {
  bool _isFocused = false;

  void _open() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SeriesDetailScreen(item: widget.item),
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
          duration: const Duration(milliseconds: 200),
          width: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isFocused ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: widget.item.image,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    memCacheWidth: 140, // Otimização de memória
                    placeholder: (_, __) => Container(color: Colors.white12),
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.white10,
                      child: const Icon(Icons.movie, color: Colors.white30),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _isFocused ? Colors.white : Colors.white70,
                  fontSize: 12,
                  fontWeight: _isFocused ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
