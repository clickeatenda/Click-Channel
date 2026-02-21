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
                
                return LazyTmdbLoader(
                  item: item,
                  onItemEnriched: widget.onItemUpdated,
                  builder: (enrichedItem, isLoading) {
                    return _OptimizedGridCard(
                      item: enrichedItem,
                      isLoadingTmdb: isLoading,
                      showMetaChips: widget.showMetaChips,
                      metaFontSize: widget.metaFontSize,
                      metaIconSize: widget.metaIconSize,
                      epgChannels: widget.epgChannels,
                      onTap: () => widget.onTap(enrichedItem),
                    );
                  },
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
          duration: const Duration(milliseconds: 150),
          transform: _isFocused ? (Matrix4.identity()..translate(0, -4)..scale(1.02)) : Matrix4.identity(),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF161b22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _isFocused ? const Color(0xFF007BFF) : Colors.white.withOpacity(0.05),
                width: 1),
            boxShadow: _isFocused 
                ? [BoxShadow(color: const Color(0xFF007BFF).withOpacity(0.5), blurRadius: 20, spreadRadius: 2)] 
                : [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(11), bottom: Radius.circular(11)),
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
                        url: widget.item.image,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                      // Indicador de loading do TMDB (sutil)
                      if (widget.isLoadingTmdb)
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
                    ],
                  ),
                ),
                // Área de informações - sempre visível
                Container(
                  color: Colors.transparent, // Background was set on the container already
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.item.title,
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
                      if (widget.item.type != 'channel')
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: MetaChipsWidget(
                            item: widget.item,
                            fontSize: widget.metaFontSize,
                            iconSize: widget.metaIconSize,
                          ),
                        ),
                      // EPG display (SOMENTE para canais)
                      if (widget.epgChannels != null && widget.item.type == 'channel') ...[
                        const SizedBox(height: 2),
                        Builder(
                          builder: (context) {
                            final epg = _findEpgForChannel(widget.item);
                            final current = epg?.currentProgram;
                            if (current != null) {
                              return Text(
                                '▶ ${current.title}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Color(0xFF007BFF), fontSize: 8, fontWeight: FontWeight.w600),
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
}
