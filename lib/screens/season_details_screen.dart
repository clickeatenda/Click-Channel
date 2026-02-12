import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';
import '../models/content_item.dart';
import '../utils/content_enricher.dart';
import '../widgets/media_player_screen.dart';
import '../data/watch_history_service.dart';

class SeasonDetailsScreen extends StatefulWidget {
  final String seasonName;
  final List<ContentItem> episodes;
  final String seriesTitle;
  final String? posterUrl;

  const SeasonDetailsScreen({
    super.key,
    required this.seasonName,
    required this.episodes,
    required this.seriesTitle,
    this.posterUrl,
  });

  @override
  State<SeasonDetailsScreen> createState() => _SeasonDetailsScreenState();
}

class _SeasonDetailsScreenState extends State<SeasonDetailsScreen> {
  late List<ContentItem> _episodes;

  @override
  void initState() {
    super.initState();
    _episodes = List.from(widget.episodes);
  }
  
  // Método para recarregar o estado ao voltar do player (para atualizar checks)
  void _refresh() {
    setState(() {}); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${widget.seriesTitle} - ${widget.seasonName}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header com info da temporada
          if (widget.posterUrl != null)
             Container(
               height: 150,
               width: double.infinity,
               decoration: BoxDecoration(
                 image: DecorationImage(
                   image: CachedNetworkImageProvider(widget.posterUrl!),
                   fit: BoxFit.cover,
                   colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.7), BlendMode.darken),
                   alignment: Alignment.topCenter,
                 ),
               ),
               child: Center(
                 child: Text(
                   "${_episodes.length} Episódios",
                   style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                 ),
               ),
             ),
             
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _episodes.length,
              itemBuilder: (ctx, index) {
                final ep = _episodes[index];
                return _EpisodeListTile(
                  key: ValueKey(ep.url),
                  episode: ep, 
                  index: index,
                  playlist: _episodes, // Passa a lista completa para o player
                  onReturn: _refresh,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EpisodeListTile extends StatefulWidget {
  final ContentItem episode;
  final int index;
  final List<ContentItem> playlist;
  final VoidCallback onReturn;

  const _EpisodeListTile({
    super.key,
    required this.episode,
    required this.index,
    required this.playlist,
    required this.onReturn,
  });

  @override
  State<_EpisodeListTile> createState() => _EpisodeListTileState();
}

class _EpisodeListTileState extends State<_EpisodeListTile> {
  late ContentItem _displayItem;
  bool _hasEnriched = false;
  bool _isWatched = false;

  @override
  void initState() {
    super.initState();
    _displayItem = widget.episode;
    
    // Inicia carregamento Lazy e verificação de assistido
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🕵️ [DEBUG-FORCE] EpisodeTile Init - Item: ${_displayItem.title} | ID: ${_displayItem.id}');
      _lazyEnrich();
      _checkWatched();
    });
  }
  
  @override
  void didUpdateWidget(_EpisodeListTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Verificar novamente se o widget pai for reconstruído (refresh)
    if (widget.episode != oldWidget.episode) {
      _displayItem = widget.episode;
      _checkWatched();
    } else {
       // Mesmo se o episódio for igual, pode ter sido assistido recentemente
       _checkWatched();
    }
  }

  Future<void> _checkWatched() async {
    final watched = await WatchHistoryService.isWatched(_displayItem.url);
    if (mounted && watched != _isWatched) {
      setState(() => _isWatched = watched);
    }
  }
  
  Future<void> _toggleWatched() async {
    if (_isWatched) {
      await WatchHistoryService.removeFromWatched(_displayItem.url);
    } else {
      await WatchHistoryService.markItemAsWatched(_displayItem);
    }
    await _checkWatched();
    if (mounted) setState(() {}); 
  }

  Future<void> _lazyEnrich() async {
    if (_hasEnriched) return;
    if (_displayItem.description.isEmpty || _displayItem.description == _displayItem.title) {
       try {
         final enriched = await ContentEnricher.enrichItem(_displayItem);
         if (mounted) {
           setState(() {
             _displayItem = enriched;
             _hasEnriched = true;
           });
         }
       } catch (e) {
         // Silently fail
       }
    }
  }

  void _play(BuildContext context) {
    print('🕵️ [DEBUG-FORCE] OPENING PLAYER - Item: ${_displayItem.title} | ID: ${_displayItem.id}');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaPlayerScreen(
          url: _displayItem.url,
          item: _displayItem,
          playlist: widget.playlist,
          playlistIndex: widget.index,
        ),
      ),
    ).then((_) {
      _checkWatched();
      widget.onReturn();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _displayItem.image.isNotEmpty;

    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && 
            (event.logicalKey == LogicalKeyboardKey.enter || 
             event.logicalKey == LogicalKeyboardKey.select)) {
          _play(context);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: () => _play(context),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: focused ? AppColors.primary.withOpacity(0.3) : (_isWatched ? AppColors.accent.withOpacity(0.1) : Colors.white.withOpacity(0.05)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: focused ? AppColors.primary : (_isWatched ? AppColors.accent.withOpacity(0.5) : Colors.transparent),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // Thumb
                  ClipRRect(
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                    child: SizedBox(
                      width: 120,
                      height: 68,
                      child: Stack(
                        children: [
                          Positioned.fill(
                             child: hasImage 
                              ? CachedNetworkImage(
                                  imageUrl: _displayItem.image,
                                  fit: BoxFit.cover,
                                  placeholder: (_,__) => Container(color: Colors.grey[900]),
                                  errorWidget: (_,__,___) => Container(color: Colors.grey[900], child: const Icon(Icons.movie, color: Colors.white24)),
                                )
                              : Container(color: Colors.grey[900], child: Center(child: Text("${widget.index+1}", style: const TextStyle(color: Colors.white24, fontSize: 20)))),
                          ),
                          // Verificação visual sobre o thumb
                          if (_isWatched)
                            Positioned.fill(
                              child: Container(
                                color: Colors.black54,
                                child: const Center(
                                  child: Icon(Icons.check_circle, color: AppColors.accent, size: 32),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Info
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _displayItem.title, 
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _isWatched ? Colors.white70 : Colors.white,
                                    fontWeight: _isWatched ? FontWeight.normal : FontWeight.bold,
                                    fontSize: 14,
                                    decoration: _isWatched ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _displayItem.description.isNotEmpty && _displayItem.description != _displayItem.title 
                                ? _displayItem.description 
                                : "Episódio ${widget.index + 1}",
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Botão de Marcar Visto
                  IconButton(
                    icon: Icon(
                      _isWatched ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: _isWatched ? AppColors.accent : Colors.white24,
                    ),
                    onPressed: _toggleWatched,
                    tooltip: _isWatched ? "Marcar como não visto" : "Marcar como visto",
                  ),

                  // Play Icon (ou Restart se watched)
                  Padding(
                    padding: const EdgeInsets.only(right: 16, left: 8),
                    child: Icon(
                      _isWatched ? Icons.replay : Icons.play_circle_outline,
                      color: focused ? Colors.white : (_isWatched ? Colors.white54 : AppColors.primary),
                      size: 32,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }
}
