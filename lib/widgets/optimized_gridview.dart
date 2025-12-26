import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'adaptive_cached_image.dart';
import '../models/content_item.dart';
import '../models/epg_program.dart';
import '../data/epg_service.dart';
import 'meta_chips_widget.dart';

/// GridView otimizado com lazy loading e suporte a TV remoto
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
  final Map<String, EpgChannel>? epgChannels;

  const OptimizedGridView({
    super.key,
    required this.items,
    required this.onTap,
    this.crossAxisCount = 5,
    this.childAspectRatio = 0.6,
    this.crossAxisSpacing = 16,
    this.mainAxisSpacing = 16,
    this.physics,
    this.showMetaChips = false,
    this.metaFontSize = 10,
    this.metaIconSize = 12,
    this.epgChannels,
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
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: _scrollController,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
        childAspectRatio: widget.childAspectRatio,
        crossAxisSpacing: widget.crossAxisSpacing,
        mainAxisSpacing: widget.mainAxisSpacing,
      ),
      physics: widget.physics ?? const BouncingScrollPhysics(),
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        return _OptimizedGridCard(
          item: widget.items[index],
          showMetaChips: widget.showMetaChips,
          metaFontSize: widget.metaFontSize,
          metaIconSize: widget.metaIconSize,
          epgChannels: widget.epgChannels,
          onTap: () => widget.onTap(widget.items[index]),
        );
      },
    );
  }
}

class _OptimizedGridCard extends StatefulWidget {
  final ContentItem item;
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
    this.epgChannels,
  });

  @override
  State<_OptimizedGridCard> createState() => _OptimizedGridCardState();
}

class _OptimizedGridCardState extends State<_OptimizedGridCard> {
  bool _isFocused = false;

  EpgChannel? _findEpgForChannel(ContentItem channel) {
    if (widget.epgChannels == null || widget.epgChannels!.isEmpty) {
      // Tenta usar EpgService.findChannelByName se não tem mapa
      return EpgService.findChannelByName(channel.title);
    }
    
    final name = channel.title.trim().toLowerCase();
    // Remove sufixos comuns que podem atrapalhar o match
    final cleanName = name
        .replaceAll(RegExp(r'\s*(fhd|hd|sd|4k|uhd)\s*$'), '')
        .replaceAll(RegExp(r'\s*\[.*?\]'), '')
        .replaceAll(RegExp(r'\s*\(.*?\)'), '')
        .trim();
    
    // Tenta match exato primeiro
    if (widget.epgChannels!.containsKey(name) || widget.epgChannels!.containsKey(cleanName)) {
      return widget.epgChannels![name] ?? widget.epgChannels![cleanName];
    }
    
    // Fuzzy match melhorado
    for (final entry in widget.epgChannels!.entries) {
      final epgKey = entry.key.trim().toLowerCase();
      final cleanEpgKey = epgKey
          .replaceAll(RegExp(r'\s*(fhd|hd|sd|4k|uhd)\s*$'), '')
          .replaceAll(RegExp(r'\s*\[.*?\]'), '')
          .replaceAll(RegExp(r'\s*\(.*?\)'), '')
          .trim();
      
      // Match se um contém o outro (após limpeza)
      if (cleanName.contains(cleanEpgKey) || cleanEpgKey.contains(cleanName) ||
          name.contains(epgKey) || epgKey.contains(name)) {
        return entry.value;
      }
    }
    
    // Fallback: usa EpgService
    return EpgService.findChannelByName(channel.title);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Focus(
        onKey: (node, event) {
          // Suporte completo para TV remote: Enter, Select, Space, GameButtonA
          if (event is RawKeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
               event.logicalKey == LogicalKeyboardKey.select ||
               event.logicalKey == LogicalKeyboardKey.space ||
               event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
            print('▶️ Item selecionado: ${widget.item.title}');
            widget.onTap();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        onFocusChange: (focused) {
          setState(() => _isFocused = focused);
          if (focused) {
            print('🔍 Item focado: ${widget.item.title}');
          }
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
                        url: widget.item.image,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
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
                      // CRÍTICO: Sempre mostra MetaChipsWidget para filmes e séries (qualidade + rating)
                      // Para canais, não mostra (mostra EPG em vez disso)
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
}
