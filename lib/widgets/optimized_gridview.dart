import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'adaptive_cached_image.dart';
import '../models/content_item.dart';
import '../models/epg_program.dart';
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
    if (widget.epgChannels == null || widget.epgChannels!.isEmpty) return null;
    final name = channel.title.trim().toLowerCase();
    if (widget.epgChannels!.containsKey(name)) {
      return widget.epgChannels![name];
    }
    // Fuzzy match
    for (final entry in widget.epgChannels!.entries) {
      if (name.contains(entry.key.trim().toLowerCase()) || 
          entry.key.trim().toLowerCase().contains(name)) {
        return entry.value;
      }
    }
    return null;
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
                      if (widget.showMetaChips)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: MetaChipsWidget(
                            item: widget.item,
                            fontSize: widget.metaFontSize,
                            iconSize: widget.metaIconSize,
                          ),
                        ),
                      // EPG display
                      if (widget.epgChannels != null) ...[
                        const SizedBox(height: 2),
                        Builder(
                          builder: (context) {
                            final epg = _findEpgForChannel(widget.item);
                            final current = epg?.currentProgram;
                            final next = epg?.nextProgram;
                            if (current != null) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Agora: ${current.title}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.amber, fontSize: 8, fontWeight: FontWeight.w600),
                                  ),
                                  if (next != null)
                                    Text(
                                      'Próx: ${next.title}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white54, fontSize: 7),
                                    ),
                                ],
                              );
                            } else if (epg != null && next != null) {
                              return Text(
                                'Em breve: ${next.title}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70, fontSize: 8),
                              );
                            } else {
                              return const Text(
                                'Sem programação',
                                style: TextStyle(color: Colors.white38, fontSize: 8),
                              );
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
