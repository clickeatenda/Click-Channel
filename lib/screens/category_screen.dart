import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../models/content_item.dart';
import '../widgets/optimized_gridview.dart';
import '../widgets/media_player_screen.dart';
import '../data/m3u_service.dart';
import '../data/epg_service.dart';
import '../data/tmdb_service.dart';
import '../models/epg_program.dart';
import '../core/config.dart';
import '../core/utils/logger.dart';
import '../utils/content_enricher.dart'; // Para ContentSorter
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
  String _sortBy = 'latest'; // PADRÃO: mais recentes primeiro
  
  // Busca
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
    _loadEpg();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    List<ContentItem> data = [];
    bool usedTmdbFallback = false;
    
    try {
      final source = Config.playlistRuntime;
      if (source == null || source.isEmpty) {
        print('⚠️ CategoryScreen: Sem playlist configurada - tentando TMDB');
        data = await _loadFromTmdb();
        usedTmdbFallback = true;
      } else {
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
        
        if (data.isEmpty) {
          AppLogger.info('⚠️ M3U: Categoria "${widget.categoryName}" retornou vazio - tentando TMDB');
          data = await _loadFromTmdb();
          usedTmdbFallback = true;
        } else {
          final allAreChannels = data.every((item) => item.type.toLowerCase() == 'channel');
          if (allAreChannels && widget.type.toLowerCase() != 'channel') {
            AppLogger.info('⚠️ M3U: "${widget.categoryName}" retornou ${data.length} canais quando esperava ${widget.type} - usando TMDB');
            data = await _loadFromTmdb();
            usedTmdbFallback = true;
          }
        }
      }
    } catch (e) {
      AppLogger.error('❌ CategoryScreen: Erro ao carregar itens', error: e);
      data = await _loadFromTmdb();
      usedTmdbFallback = true;
    }
    
    if (usedTmdbFallback && data.isNotEmpty) {
      AppLogger.info('✅ Usando fallback TMDB para categoria "${widget.categoryName}" (${widget.type}) - ${data.length} itens');
    }

    if (mounted) {
      setState(() {
        items = data;
        filteredItems = _applyFilters(data);
        visibleCount = filteredItems.length > pageSize ? pageSize : filteredItems.length;
        AppLogger.info('📂 CategoryScreen "${widget.categoryName}" (${widget.type}) carregou ${items.length} itens');
        if (items.isNotEmpty) {
          final withImage = items.where((i) => i.image.isNotEmpty).toList();
          bannerItem = withImage.isNotEmpty ? withImage[Random().nextInt(withImage.length)] : items.first;
        }
        loading = false;
      });
    }
  }

  Future<List<ContentItem>> _loadFromTmdb() async {
    try {
      final isMovie = widget.type.toLowerCase() == 'movie';
      final isSeries = widget.type.toLowerCase() == 'series';
      
      if (!isMovie && !isSeries) {
        AppLogger.info('⚠️ TMDB: Tipo "${widget.type}" não suportado, retornando vazio');
        return [];
      }
      
      late List<dynamic> tmdbItems;
      
      final categoryLower = widget.categoryName.toLowerCase();
      if (categoryLower.contains('top') || categoryLower.contains('melhor') || categoryLower.contains('avaliado')) {
        tmdbItems = isMovie 
          ? await TmdbService.getTopRatedMovies(page: 1)
          : await TmdbService.getTopRatedSeries(page: 1);
      } else if (categoryLower.contains('recente') || categoryLower.contains('novo') || categoryLower.contains('latest')) {
        tmdbItems = isMovie 
          ? await TmdbService.getLatestMovies(page: 1)
          : await TmdbService.getLatestMovies(page: 1);
      } else {
        tmdbItems = isMovie 
          ? await TmdbService.getPopularMovies(page: 1)
          : await TmdbService.getPopularSeries(page: 1);
      }
      
      final items = tmdbItems
        .map((m) => ContentItem(
          title: m.title ?? 'Sem título',
          url: '',
          image: m.posterPath != null ? 'https://image.tmdb.org/t/p/w342${m.posterPath}' : '',
          group: 'TMDB ${widget.categoryName}',
          type: isMovie ? 'movie' : 'series',
          id: m.id.toString(),
          rating: m.rating ?? 0,
          year: m.releaseDate?.substring(0, 4) ?? '',
          description: m.overview ?? '',
        ))
        .toList();
      
      AppLogger.info('✅ TMDB Fallback: Carregados ${items.length} itens para "${widget.categoryName}" (${widget.type})');
      return items;
    } catch (e) {
      AppLogger.error('❌ TMDB Fallback: Erro ao carregar', error: e);
      return [];
    }
  }

  List<ContentItem> _applyFilters(List<ContentItem> source) {
    var result = source.toList();
    
    // 1. Aplicar busca por texto
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((item) {
        return item.title.toLowerCase().contains(query) ||
               item.description.toLowerCase().contains(query) ||
               item.genre.toLowerCase().contains(query);
      }).toList();
    }
    
    // 2. Aplicar filtro de qualidade
    if (_qualityFilter != 'all') {
      result = result.where((item) {
        final q = item.quality.toLowerCase();
        if (_qualityFilter == '4k') return q.contains('4k') || q.contains('uhd');
        if (_qualityFilter == 'fhd') return q.contains('fhd') || q.contains('fullhd');
        if (_qualityFilter == 'hd') return q.contains('hd');
        return true;
      }).toList();
    }
    
    // 3. Aplicar ordenação
    switch (_sortBy) {
      case 'alphabetical':
      case 'name':
        result = ContentSorter.sortByAlphabetical(result);
        break;
      case 'rating':
        result = ContentSorter.sortByRating(result);
        break;
      case 'latest':
        // Ordena por mais recente (ano + título)
        result.sort((a, b) {
          // Primeiro por ano (mais recente primeiro)
          final yearCompare = b.year.compareTo(a.year);
          if (yearCompare != 0) return yearCompare;
          // Se mesmo ano, ordena por título
          return a.title.compareTo(b.title);
        });
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
        // Mantém ordem original do M3U
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

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _updateFilters();
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchController.clear();
        _searchQuery = '';
        _updateFilters();
      }
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

  void _onItemUpdated(ContentItem enriched) {
    // Atualiza na lista principal em memória (sem setState para evitar rebuild total)
    // Isso garante que próximas ordenações usem os dados enriquecidos (data, rating)
    final index = items.indexWhere((i) => i.title == enriched.title); // Usa título como chave primária para séries agrupadas
    if (index != -1) {
      items[index] = enriched;
    }
    
    // Atualiza na lista filtrada também
    final fIndex = filteredItems.indexWhere((i) => i.title == enriched.title);
    if (fIndex != -1) {
      filteredItems[fIndex] = enriched;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // Header com título, busca e botão voltar
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
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _showSearch
                              ? TextField(
                                  controller: _searchController,
                                  autofocus: true,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'Buscar em ${widget.categoryName}...',
                                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  onChanged: _onSearchChanged,
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.categoryName,
                                      style: AppTypography.headlineMedium,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${widget.type == 'series' ? 'SÉRIES' : widget.type == 'movie' ? 'FILMES' : 'CANAIS'} • ${filteredItems.length} itens${visibleCount < filteredItems.length ? " (Exibindo $visibleCount)" : ""}',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                          ),
                          // Botão de busca
                          IconButton(
                            icon: Icon(
                              _showSearch ? Icons.close : Icons.search,
                              color: Colors.white,
                            ),
                            onPressed: _toggleSearch,
                          ),
                        ],
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
                        // Filtros de qualidade
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
                        // Ordenação
                        _buildFilterChip('📅 Recentes', _sortBy == 'latest', () {
                          setState(() => _sortBy = 'latest');
                          _updateFilters();
                        }),
                        _buildFilterChip('⭐ Avaliação', _sortBy == 'rating', () {
                          setState(() => _sortBy = 'rating');
                          _updateFilters();
                        }),
                        _buildFilterChip('🔥 Popular', _sortBy == 'popularity', () {
                          setState(() => _sortBy = 'popularity');
                          _updateFilters();
                        }),
                        _buildFilterChip('A-Z', _sortBy == 'alphabetical', () {
                          setState(() => _sortBy = 'alphabetical');
                          _updateFilters();
                        }),
                        _buildFilterChip('📊 Qualidade', _sortBy == 'quality', () {
                          setState(() => _sortBy = 'quality');
                          _updateFilters();
                        }),
                        _buildFilterChip('Padrão', _sortBy == 'default', () {
                          setState(() => _sortBy = 'default');
                          _updateFilters();
                        }),
                      ],
                    ),
                  ),
                ),
                // Grid content principal
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
                      : filteredItems.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.search_off, color: Colors.white30, size: 48),
                                const SizedBox(height: 8),
                                Text(
                                  'Nenhum resultado para "$_searchQuery"',
                                  style: const TextStyle(color: Colors.white54),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.clear),
                                  label: const Text('Limpar busca'),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
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
                              onItemUpdated: _onItemUpdated, // Callback para atualizar dados em background
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
              ],
            ),
    );
  }
}