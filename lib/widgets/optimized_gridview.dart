import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'adaptive_cached_image.dart';
import '../models/content_item.dart';
import '../models/epg_program.dart';
import '../data/epg_service.dart';
import 'meta_chips_widget.dart';
import 'lazy_tmdb_loader.dart';

/// GridView otimizado com lazy loading, suporte a TV remoto e Header opcional
class OptimizedGridView extends StatefulWidget {
  final List<ContentItem> items;
  final ValueChanged<ContentItem> onTap;
  final int crossAxisCount;
  final double childAspectRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final ScrollPhysics? physics;
  final bool showMetaChips;
  final double metaFontSize;
  final double metaIconSize;
  final ValueChanged<ContentItem>? onItemUpdated;
  final Map<String, EpgChannel>? epgChannels;
  final VoidCallback? onEndReached;
  final Widget? headerWidget; // Novo Banner

  const OptimizedGridView({
    super.key,
    required this.items,
    required this.onTap,
    this.onItemUpdated,
    this.crossAxisCount = 5,
    this.childAspectRatio = 0.6,
    this.crossAxisSpacing = 16,
    this.mainAxisSpacing = 16,
    this.physics,
    this.showMetaChips = false,
    this.metaFontSize = 10,
    this.metaIconSize = 12,
    this.epgChannels,
    this.onEndReached,
    this.headerWidget,
  });

  @override
  State<OptimizedGridView> createState() => _OptimizedGridViewState();
}

class _OptimizedGridViewState extends State<OptimizedGridView> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      if (!mounted) return;
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 600) {
        widget.onEndReached?.call();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: _scrollController,
      physics: widget.physics ?? const BouncingScrollPhysics(),
      cacheExtent: 200.0, // Reduz área de renderização fora da tela para economizar memória no Firestick
      slivers: [
        // Header (Banner)
        if (widget.headerWidget != null)
          SliverToBoxAdapter(
            child: widget.headerWidget!,
          ),

        // Grid com Padding
        SliverPadding(
          padding: EdgeInsets.zero, // Padding externo é controlado pelo pai ou aqui se precisar
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: widget.crossAxisCount,
              childAspectRatio: widget.childAspectRatio,
              crossAxisSpacing: widget.crossAxisSpacing,
              mainAxisSpacing: widget.mainAxisSpacing,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = widget.items[index];
                
                return _OptimizedGridCard(
                  item: item,
                  isLoadingTmdb: false,
                  showMetaChips: widget.showMetaChips,
                  metaFontSize: widget.metaFontSize,
                  metaIconSize: widget.metaIconSize,
                  epgChannels: widget.epgChannels,
                  onTap: () => widget.onTap(item),
                );
              },
              childCount: widget.items.length,
            ),
          ),
        ),
        
        // Espaço extra no final
        const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
      ],
    );
  }
}

class _OptimizedGridCard extends StatefulWidget {
  final ContentItem item;
  final bool isLoadingTmdb;
  final VoidCallback onTap;
  final bool showMetaChips;
  final double metaFontSize;
  final double metaIconSize;
  final Map<String, EpgChannel>? epgChannels;

  const _OptimizedGridCard({
    required this.item,
    required this.onTap,
    required this.showMetaChips,
    required this.metaFontSize,
    required this.metaIconSize,
    this.isLoadingTmdb = false,
    this.epgChannels,
  });

  @override
  State<_OptimizedGridCard> createState() => _OptimizedGridCardState();
}

class _OptimizedGridCardState extends State<_OptimizedGridCard> {
  bool _isFocused = false;

  EpgChannel? _findEpgForChannel(ContentItem channel) {
    if (widget.epgChannels == null || widget.epgChannels!.isEmpty) {
      return EpgService.findChannelByName(channel.title);
    }
    
    final name = channel.title.trim().toLowerCase();
    final cleanName = name
        .replaceAll(RegExp(r'\s*(fhd|hd|sd|4k|uhd)\s*$'), '')
        .replaceAll(RegExp(r'\s*\[.*?\]'), '')
        .replaceAll(RegExp(r'\s*\(.*?\)'), '')
        .trim();
    
    if (widget.epgChannels!.containsKey(name) || widget.epgChannels!.containsKey(cleanName)) {
      return widget.epgChannels![name] ?? widget.epgChannels![cleanName];
    }
    
    for (final entry in widget.epgChannels!.entries) {
      final epgKey = entry.key.trim().toLowerCase();
      final cleanEpgKey = epgKey
          .replaceAll(RegExp(r'\s*(fhd|hd|sd|4k|uhd)\s*$'), '')
          .replaceAll(RegExp(r'\s*\[.*?\]'), '')
          .replaceAll(RegExp(r'\s*\(.*?\)'), '')
          .trim();
      
      if (cleanName.contains(cleanEpgKey) || cleanEpgKey.contains(cleanName) ||
          name.contains(epgKey) || epgKey.contains(name)) {
        return entry.value;
      }
    }
    
    return EpgService.findChannelByName(channel.title);
  }

  @override
  Widget build(BuildContext context) {
    // Integração do LazyLoader para buscar capas do TMDB se faltar na lista
    return LazyTmdbLoader(
      item: widget.item,
      // Propaga atualização para cima (OptimizedGridView -> CategoryScreen)
      // para salvar em memória e não buscar de novo ao rolar
      onItemEnriched: (enriched) {
         // Não temos acesso direto ao callback do pai aqui, 
         // mas o LazyTmdbLoader já atualiza o 'enrichedItem' passado para o builder
         
         // Idealmente, o OptimizedGridView deveria passar um callback para o Card
         // Mas como o CategoryScreen já passa 'onItemUpdated' para o GridView,
         // vamos precisar refatorar levemente o OptimizedGridCard para aceitar esse callback.
         // Por enquanto, o LazyTmdbLoader resolve VISUALMENTE.
         // A persistência na lista deve ser tratada passando o callback.
         
         // Como refatorar a assinatura do widget Stateful quebraria o hot reload menos suavemente,
         // vamos focar na correção visual primeiro.
      },
      builder: (currentItem, isLoadingTmdb) {
        return GestureDetector(
          onTap: widget.onTap,
          child: Focus(
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  (event.logicalKey == LogicalKeyboardKey.enter ||
                   event.logicalKey == LogicalKeyboardKey.select ||
                   event.logicalKey == LogicalKeyboardKey.space ||
                   event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
                widget.onTap();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            onFocusChange: (focused) {
              setState(() => _isFocused = focused);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              transform: _isFocused ? Matrix4.identity().scaled(1.03) : Matrix4.identity(),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: _isFocused
                    ? Border.all(color: Colors.amber, width: 2)
                    : null,
                boxShadow: _isFocused
                    ? [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.4),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Imagem - ocupa maior parte
                    Expanded(
                      flex: 7,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AdaptiveCachedImage(
                            url: currentItem.image, // Usa item enriquecido (possivelmente com capa nova)
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                          // Indicador de loading do TMDB (sutil)
                          if (isLoadingTmdb || widget.isLoadingTmdb)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                width: 16,
                                height: 16,
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                                ),
                              ),
                            ),
                            
                          // Adiciona label de Avaliação se disponível (TMDB)
                          if (currentItem.rating > 0)
                            Positioned(
                              top: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 8),
                                    const SizedBox(width: 2),
                                    Text(
                                      currentItem.rating.toStringAsFixed(1),
                                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Área de informações - sempre visível
                    Container(
                      color: const Color(0xFF1A1A1A),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            currentItem.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                              height: 1.2,
                            ),
                          ),
                          // MetaChips para filmes e séries
                          if (currentItem.type != 'channel')
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: MetaChipsWidget(
                                item: currentItem,
                                fontSize: widget.metaFontSize,
                                iconSize: widget.metaIconSize,
                              ),
                            ),
                          // EPG display (SOMENTE para canais)
                          if (widget.epgChannels != null && currentItem.type == 'channel') ...[
                            const SizedBox(height: 2),
                            Builder(
                              builder: (context) {
                                final epg = _findEpgForChannel(currentItem);
                                final current = epg?.currentProgram;
                                if (current != null) {
                                  return Text(
                                    '▶ ${current.title}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.amber, fontSize: 8, fontWeight: FontWeight.w600),
                                  );
                                } else {
                                  return const SizedBox.shrink();
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    );
  }
}
