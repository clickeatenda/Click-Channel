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
import '../core/config.dart';
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
  
  // Filtros
  String _qualityFilter = 'all'; // all, 4k, fhd, hd
  String _sortBy = 'default'; // default, name, quality

  @override
  void initState() {
    super.initState();
    _loadItems();
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
                          ),
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