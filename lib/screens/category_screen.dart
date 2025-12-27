import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../models/content_item.dart';
import '../widgets/optimized_gridview.dart';
import '../widgets/media_player_screen.dart';
import '../data/m3u_service.dart';
import '../data/epg_service.dart';
import '../models/epg_program.dart';
import '../core/config.dart';
import '../core/utils/logger.dart';
import '../utils/content_enricher.dart';
import 'series_detail_screen.dart';
import 'movie_detail_screen.dart';

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
  String _sortBy = 'default'; // default, name, quality, alphabetical, rating, latest

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
    // CRÍTICO: Só carrega dados se houver playlist configurada
    // SEM fallback para backend - app deve estar limpo sem playlist
    List<ContentItem> data = [];
    try {
      final source = Config.playlistRuntime;
      if (source == null || source.isEmpty) {
        print('⚠️ CategoryScreen: Sem playlist configurada - retornando lista vazia');
        if (mounted) {
          setState(() {
            items = [];
            filteredItems = [];
            loading = false;
          });
        }
        return;
      }
      
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
    } catch (e) {
      AppLogger.error('❌ CategoryScreen: Erro ao carregar itens', error: e);
      data = [];
    }

    // CRÍTICO: Mostra UI primeiro, depois enriquece com TMDB em background
    if (mounted) {
      setState(() {
        items = data;
        filteredItems = _applyFilters(data);
        visibleCount = filteredItems.length > pageSize ? pageSize : filteredItems.length;
        // Log útil para depuração em device
        AppLogger.info('📂 CategoryScreen "${widget.categoryName}" (${widget.type}) carregou ${items.length} itens');
        if (items.isNotEmpty) {
          final withImage = items.where((i) => i.image.isNotEmpty).toList();
          bannerItem = withImage.isNotEmpty ? withImage[Random().nextInt(withImage.length)] : items.first;
        }
        loading = false;
      });
    }
    
    // Enriquece com TMDB em background (não bloqueia UI)
    // Enriquece banner e TODOS os itens visíveis do grid
    if (data.isNotEmpty) {
      AppLogger.info('🔍 TMDB: Enriquecendo itens da categoria "${widget.categoryName}" (${widget.type})...');
      // CRÍTICO: Enriquece TODOS os itens visíveis (até pageSize = 240)
      // Isso garante que todos os itens exibidos tenham TMDB
      final itemsToEnrich = <ContentItem>[];
      if (bannerItem != null) {
        itemsToEnrich.add(bannerItem!);
        AppLogger.info('🔍 TMDB: Banner incluído: "${bannerItem!.title}"');
      }
      // Enriquece todos os itens visíveis (não apenas 100)
      final gridItems = data.take(pageSize).toList();
      itemsToEnrich.addAll(gridItems);
      
      AppLogger.info('🔍 TMDB: Enriquecendo ${itemsToEnrich.length} itens (${bannerItem != null ? "1 banner + " : ""}${gridItems.length} do grid)...');
      AppLogger.debug('🔍 TMDB: Primeiros 3 itens para enriquecer:');
      for (int i = 0; i < itemsToEnrich.length && i < 3; i++) {
        AppLogger.debug('  [$i] "${itemsToEnrich[i].title}" - Rating atual: ${itemsToEnrich[i].rating}');
      }
      
      final enriched = await ContentEnricher.enrichItems(itemsToEnrich);
      final enrichedWithRating = enriched.where((e) => e.rating > 0).length;
      AppLogger.info('✅ TMDB: ${enriched.length} itens processados, $enrichedWithRating com rating');
      
      // Debug: mostra primeiros 3 itens enriquecidos
      AppLogger.debug('🔍 TMDB: Primeiros 3 itens após enriquecimento:');
      for (int i = 0; i < enriched.length && i < 3; i++) {
        AppLogger.debug('  [$i] "${enriched[i].title}" - Rating: ${enriched[i].rating}');
      }
      
      // CRÍTICO: Atualiza itens usando índice direto (ordem preservada)
      final updatedItems = <ContentItem>[];
      int enrichedIndex = 0;
      
      // Atualiza banner se foi enriquecido
      ContentItem? updatedBanner = bannerItem;
      if (bannerItem != null && enriched.isNotEmpty) {
        updatedBanner = enriched[enrichedIndex++];
        AppLogger.info('✅ TMDB: Banner "${updatedBanner.title}" - Rating: ${updatedBanner.rating} (original: ${bannerItem!.rating})');
      }
      
      // Atualiza itens do grid usando índice direto
      for (int i = 0; i < data.length; i++) {
        if (i < gridItems.length && enrichedIndex < enriched.length) {
          // Item está na lista de enriquecidos
          final enrichedItem = enriched[enrichedIndex++];
          updatedItems.add(enrichedItem);
          
          // Debug: mostra primeiros 5 itens enriquecidos
          if (i < 5) {
            final ratingChanged = enrichedItem.rating != data[i].rating;
            AppLogger.info('✅ TMDB: Item[$i] "${enrichedItem.title}" - Rating: ${enrichedItem.rating} (original: ${data[i].rating}) ${ratingChanged ? "✅ MUDOU" : "❌ IGUAL"}');
          }
        } else {
          // Item não foi enriquecido, mantém original
          updatedItems.add(data[i]);
        }
      }
      
      final finalItemsWithRating = updatedItems.where((e) => e.rating > 0).length;
      AppLogger.info('✅ TMDB: ${finalItemsWithRating}/${updatedItems.length} itens com rating após atualização');
      
      // CRÍTICO: Força atualização do estado mesmo se não houver mudanças aparentes
      if (mounted) {
        setState(() {
          // Força nova lista para garantir que o Flutter detecte mudanças
          items = List.from(updatedItems);
          filteredItems = _applyFilters(items);
          if (updatedBanner != null) {
            bannerItem = updatedBanner;
          }
        });
        
        // Verifica se os dados foram realmente aplicados
        final finalItemsWithRating = filteredItems.where((e) => e.rating > 0).length;
        AppLogger.info('✅ TMDB: Estado atualizado - ${finalItemsWithRating} itens filtrados com rating');
        
        // Debug: mostra primeiros 3 itens para verificar
        for (int i = 0; i < filteredItems.length && i < 3; i++) {
          final item = filteredItems[i];
          AppLogger.debug('📋 Item[$i]: "${item.title}" - Rating: ${item.rating}, Type: ${item.type}');
        }
      }
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
    
    // Aplicar ordenação usando ContentSorter
    switch (_sortBy) {
      case 'alphabetical':
      case 'name':
        result = ContentSorter.sortByAlphabetical(result);
        break;
      case 'rating':
        result = ContentSorter.sortByRating(result);
        break;
      case 'latest':
        result = ContentSorter.sortByLatest(result);
        break;
      case 'quality':
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
        break;
      case 'popularity':
        result = ContentSorter.sortByPopularity(result);
        break;
      case 'default':
      default:
        // Mantém ordem original
        break;
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
                // Header compacto com título e botão voltar
                Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 8,
                    right: 16,
                    bottom: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary.withOpacity(0.2), AppColors.background],
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.categoryName,
                              style: AppTypography.headlineMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${widget.type.toUpperCase()} • ${filteredItems.length} itens',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Barra de filtros compacta
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
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
                        _buildFilterChip('Padrão', _sortBy == 'default', () {
                          setState(() => _sortBy = 'default');
                          _updateFilters();
                        }),
                        _buildFilterChip('A-Z', _sortBy == 'alphabetical', () {
                          setState(() => _sortBy = 'alphabetical');
                          _updateFilters();
                        }),
                        _buildFilterChip('Avaliação', _sortBy == 'rating', () {
                          setState(() => _sortBy = 'rating');
                          _updateFilters();
                        }),
                        _buildFilterChip('Data', _sortBy == 'latest', () {
                          setState(() => _sortBy = 'latest');
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
                // Grid content principal - MESMO VISUAL PARA TODOS
                Expanded(
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
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: OptimizedGridView(
                            items: filteredItems.take(visibleCount).toList(),
                            epgChannels: _epgChannels,
                                onTap: (item) {
                                  if (item.isSeries || item.type == 'series') {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => SeriesDetailScreen(item: item)));
                                  } else if (item.type == 'channel') {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => MediaPlayerScreen(url: item.url, item: item)));
                                  } else {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailScreen(item: item)));
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
                // Botão "Carregar mais" removido conforme solicitado
              ],
            ),
    );
  }
}