import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../models/content_item.dart';
// import '../widgets/content_card.dart';
import '../widgets/optimized_gridview.dart';
import '../widgets/media_player_screen.dart';
import '../data/api_service.dart';
import '../data/m3u_service.dart';
import '../data/epg_service.dart';
import '../models/epg_program.dart';
import '../core/config.dart';
import '../utils/channel_grouping.dart';
import 'series_detail_screen.dart'; // Importação correta

class CategoryScreen extends StatefulWidget {
  final String categoryName;
  final String type;

  const CategoryScreen({super.key, required this.categoryName, required this.type});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  List<ContentItem> items = [];
  List<ContentItem> filteredItems = [];
  int visibleCount = 0;
  final int pageSize = 240;
  bool loading = true;
  ContentItem? bannerItem;
  bool _epgLoaded = false;
  Map<String, EpgChannel> _epgChannels = {};
  
  // Filtros
  String _qualityFilter = 'all'; // all, 4k, fhd, hd
  String _sortBy = 'default'; // default, name, quality

  @override
  void initState() {
    super.initState();
    _loadItems();
    _loadEpg();
  }

  Future<void> _loadEpg() async {
    if (!EpgService.isLoaded) {
      await EpgService.loadFromCache();
    }
    if (mounted && EpgService.isLoaded) {
      final channels = EpgService.getAllChannels();
      final map = <String, EpgChannel>{};
      for (final c in channels) {
        map[c.displayName.trim().toLowerCase()] = c;
      }
      setState(() {
        _epgChannels = map;
        _epgLoaded = true;
      });
    }
  }

  Future<void> _loadItems() async {
    // Preferir M3U quando houver playlist setada; fallback para backend
    List<ContentItem> data = [];
    try {
      if (Config.playlistRuntime != null && Config.playlistRuntime!.isNotEmpty) {
        // Usa cache completo para evitar lista vazia em categorias grandes (Netflix/Prime)
        if (widget.type.toLowerCase() == 'series') {
          data = await M3uService.fetchSeriesAggregatedForCategory(
            category: widget.categoryName,
            maxItems: 1000,
          );
        } else {
          data = await M3uService.fetchCategoryItemsFromEnv(
            category: widget.categoryName,
            typeFilter: widget.type,
            maxItems: 1000,
          );
        }
      } else {
        data = await ApiService.fetchCategoryItems(widget.categoryName, widget.type, limit: 200);
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        items = data;
        filteredItems = _applyFilters(data);
        visibleCount = filteredItems.length > pageSize ? pageSize : filteredItems.length;
        // Log útil para depuração em device
        try {
          // ignore: avoid_print
          print('📂 CategoryScreen "${widget.categoryName}" (${widget.type}) carregou ${items.length} itens');
        } catch (_) {}
        if (items.isNotEmpty) {
          final withImage = items.where((i) => i.image.isNotEmpty).toList();
          bannerItem = withImage.isNotEmpty ? withImage[Random().nextInt(withImage.length)] : items.first;
        }
        loading = false;
      });
    }
  }

  List<ContentItem> _applyFilters(List<ContentItem> source) {
    var result = source.where((item) {
      if (_qualityFilter == 'all') return true;
      final q = item.quality.toLowerCase();
      if (_qualityFilter == '4k') return q.contains('4k') || q.contains('uhd');
      if (_qualityFilter == 'fhd') return q.contains('fhd') || q.contains('fullhd');
      if (_qualityFilter == 'hd') return q.contains('hd');
      return true;
    }).toList();
    
    if (_sortBy == 'name') {
      result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    } else if (_sortBy == 'quality') {
      result.sort((a, b) {
        int qScore(String q) {
          q = q.toLowerCase();
          if (q.contains('4k') || q.contains('uhd')) return 4;
          if (q.contains('fhd') || q.contains('fullhd')) return 3;
          if (q.contains('hd')) return 2;
          return 1;
        }
        return qScore(b.quality).compareTo(qScore(a.quality));
      });
    }
    
    return result;
  }

  void _updateFilters() {
    setState(() {
      filteredItems = _applyFilters(items);
      visibleCount = filteredItems.length > pageSize ? pageSize : filteredItems.length;
    });
  }

  // --- Channel grouping UI helpers ---
  List<Widget> _buildChannelGroups(List<ContentItem> source) {
    final map = groupChannelVariants(source);
    final widgets = <Widget>[];
    for (final entry in map.entries) {
      final groupName = entry.key;
      final variants = entry.value;
      final epg = _findEpgForChannel(variants.first);

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
          child: ExpansionTile(
            collapsedBackgroundColor: Colors.transparent,
            tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            title: Text(groupName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: epg != null && epg.currentProgram != null
                ? Text('Agora: ${epg.currentProgram!.title}', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12))
                : null,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: variants.map((v) => _buildVariantCard(v)).toList(),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (widgets.isEmpty) {
      widgets.add(const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(child: Text('Nenhum canal encontrado nesta categoria.', style: TextStyle(color: Colors.white54))),
      ));
    }

    return widgets;
  }

  Widget _buildVariantCard(ContentItem item) {
    final epg = _findEpgForChannel(item);
    final current = epg?.currentProgram;
    return GestureDetector(
      onTap: () {
        if (item.url.isEmpty) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => MediaPlayerScreen(url: item.url, item: item)));
      },
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: const Color(0xFF111318),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: item.image.isNotEmpty
                      ? CachedNetworkImage(imageUrl: item.image, width: double.infinity, height: 80, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(color: Colors.white12, height: 80))
                      : Container(width: double.infinity, height: 80, color: Colors.white12),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                    child: Text(item.quality.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ),
                Positioned(
                  bottom: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(6)),
                    child: Row(
                      children: [
                        const Icon(Icons.play_arrow, color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        Text(item.quality.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (current != null)
              Text('Agora: ${current.title}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.amber, fontSize: 11))
            else
              const Text('Sem programação', style: TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  EpgChannel? _findEpgForChannel(ContentItem channel) {
    if (!_epgLoaded || _epgChannels.isEmpty) return null;
    final name = channel.title.trim().toLowerCase();
    if (_epgChannels.containsKey(name)) {
      return _epgChannels[name];
    }
    // Fallback: fuzzy match
    for (final entry in _epgChannels.entries) {
      if (name.contains(entry.key) || entry.key.contains(name)) {
        return entry.value;
      }
    }
    return null;
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white10,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? AppColors.primary : Colors.white24),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // Header with breadcrumbs (shows category and type)
                Container(
                  padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, left: 16, right: 16, bottom: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.categoryName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            Text(widget.type.toUpperCase(), style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildFilterChip('Todos', _qualityFilter == 'all', () { setState(() => _qualityFilter = 'all'); _updateFilters(); }),
                      _buildFilterChip('4K', _qualityFilter == '4k', () { setState(() => _qualityFilter = '4k'); _updateFilters(); }),
                      _buildFilterChip('FHD', _qualityFilter == 'fhd', () { setState(() => _qualityFilter = 'fhd'); _updateFilters(); }),
                      _buildFilterChip('HD', _qualityFilter == 'hd', () { setState(() => _qualityFilter = 'hd'); _updateFilters(); }),
                      const Spacer(),
                      DropdownButton<String>(
                        value: _sortBy,
                        dropdownColor: AppColors.background,
                        items: const [
                          DropdownMenuItem(value: 'default', child: Text('Padrão')),
                          DropdownMenuItem(value: 'name', child: Text('Nome')),
                          DropdownMenuItem(value: 'quality', child: Text('Qualidade')),
                        ],
                        onChanged: (v) { if (v != null) setState(() { _sortBy = v; _updateFilters(); }); },
                      ),
                    ],
                  ),
                ),
                // Header compacto - apenas título e botão voltar
                Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 8,
                    right: 16,
                    bottom: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary.withOpacity(0.3), AppColors.background],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.categoryName,
                          style: AppTypography.headlineMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // Barra de filtros
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const Text('Filtrar:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        const SizedBox(width: 12),
                        _buildFilterChip('Todos', _qualityFilter == 'all', () {
                          setState(() => _qualityFilter = 'all');
                          _updateFilters();
                        }),
                        _buildFilterChip('4K', _qualityFilter == '4k', () {
                          setState(() => _qualityFilter = '4k');
                          _updateFilters();
                        }),
                        _buildFilterChip('FHD', _qualityFilter == 'fhd', () {
                          setState(() => _qualityFilter = 'fhd');
                          _updateFilters();
                        }),
                        _buildFilterChip('HD', _qualityFilter == 'hd', () {
                          setState(() => _qualityFilter = 'hd');
                          _updateFilters();
                        }),
                        const SizedBox(width: 16),
                        Container(width: 1, height: 20, color: Colors.white24),
                        const SizedBox(width: 16),
                        const Text('Ordenar:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        const SizedBox(width: 8),
                        _buildFilterChip('Padrão', _sortBy == 'default', () {
                          setState(() => _sortBy = 'default');
                          _updateFilters();
                        }),
                        _buildFilterChip('A-Z', _sortBy == 'name', () {
                          setState(() => _sortBy = 'name');
                          _updateFilters();
                        }),
                        _buildFilterChip('Qualidade', _sortBy == 'quality', () {
                          setState(() => _sortBy = 'quality');
                          _updateFilters();
                        }),
                      ],
                    ),
                  ),
                ),
                // Seção "Últimos adicionados" - horizontal scroll
                if (items.length > 5)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Últimos adicionados', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                            Icon(Icons.chevron_right, color: Colors.white54, size: 18),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 160,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: items.length > 15 ? 15 : items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final epg = _findEpgForChannel(item);
                              final current = epg?.currentProgram;
                              final next = epg?.nextProgram;
                              final epgConfigured = EpgService.epgUrl != null && EpgService.epgUrl!.isNotEmpty;
                              return GestureDetector(
                                onTap: () {
                                  if (item.isSeries) {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => SeriesDetailScreen(item: item)));
                                  } else {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => MediaPlayerScreen(url: item.url, item: item)));
                                  }
                                },
                                child: Container(
                                  width: 100,
                                  margin: const EdgeInsets.only(right: 10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: CachedNetworkImage(
                                            imageUrl: item.image,
                                            fit: BoxFit.cover,
                                            width: 100,
                                            placeholder: (c, u) => Container(color: const Color(0xFF333333)),
                                            errorWidget: (c, u, e) => Container(
                                              color: const Color(0xFF333333),
                                              child: const Icon(Icons.movie, color: Colors.white30, size: 32),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                                      ),
                                      if (!epgConfigured)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 2),
                                          child: Text(
                                            'EPG não configurado',
                                            style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.w600),
                                          ),
                                        )
                                      else if (epg == null)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 2),
                                          child: Text(
                                            'Sem programação',
                                            style: TextStyle(color: Colors.white38, fontSize: 9),
                                          ),
                                        )
                                      else if (current != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Agora: ${current.title}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.w600),
                                        ),
                                        if (next != null)
                                          Text(
                                            'Próx: ${next.title}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: Colors.white54, fontSize: 8),
                                          ),
                                      ]
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
                // Grid content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: items.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.inbox, color: Colors.white30, size: 48),
                                const SizedBox(height: 8),
                                const Text('Nenhum item nesta categoria por enquanto.', style: TextStyle(color: Colors.white54)),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Tentar novamente'),
                                  onPressed: () {
                                    setState(() => loading = true);
                                    _loadItems();
                                  },
                                ),
                              ],
                            ),
                          )
                        : (widget.type.toLowerCase() == 'channel'
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _buildChannelGroups(filteredItems.take(visibleCount).toList()),
                              )
                            : OptimizedGridView(
                                items: filteredItems.take(visibleCount).toList(),
                                onTap: (item) {
                                  if (item.isSeries) {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => SeriesDetailScreen(item: item)));
                                  } else {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => MediaPlayerScreen(url: item.url, item: item)));
                                  }
                                },
                                crossAxisCount: 6,
                                childAspectRatio: 0.55,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                showMetaChips: true,
                                metaFontSize: 9,
                                metaIconSize: 11,
                              ) ),
                  ),
                ),
                if (filteredItems.length > visibleCount)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.unfold_more),
                      label: Text('Carregar mais (${visibleCount}/${filteredItems.length})'),
                      onPressed: () {
                        setState(() {
                          visibleCount = (visibleCount + pageSize).clamp(0, filteredItems.length);
                        });
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}