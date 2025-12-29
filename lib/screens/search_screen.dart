import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async'; // Para Timer debounce
import '../core/theme/app_colors.dart';
import '../models/content_item.dart';
import '../data/m3u_service.dart';
import '../widgets/media_player_screen.dart';
import 'series_detail_screen.dart';
import 'movie_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;
  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<ContentItem> _results = [];
  bool _loading = false;
  String _lastQuery = '';
  Timer? _debounce;
  
  // Filtros
  String _typeFilter = 'all'; // all, movie, series, channel
  String _qualityFilter = 'all'; // all, 4k, fhd, hd, sd

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _performSearch(widget.initialQuery!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    if (query.length < 2) {
      if (_results.isNotEmpty) {
        setState(() {
          _results = [];
          _loading = false;
          _lastQuery = '';
        });
      }
      return;
    }

    // Debounce de 800ms para evitar travamentos enquanto digita
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty || query.length < 2) return;
    if (query == _lastQuery) return;
    
    setState(() {
      _loading = true;
      _lastQuery = query;
    });

    try {
      // Buscar em todas as categorias (agora com delay devido ao debounce)
      // M3uService.searchAllContent roda em memória (~50-100ms para 50k itens)
      // Se necessário, M3uService pode ser otimizado para usar compute()
      final allItems = await M3uService.searchAllContent(query, maxResults: 300);
      
      if (mounted) {
        setState(() {
          _results = _applyFilters(allItems);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _results = [];
          _loading = false;
        });
      }
    }
  }

  List<ContentItem> _applyFilters(List<ContentItem> items) {
    return items.where((item) {
      // Filtro por tipo
      if (_typeFilter != 'all') {
        if (_typeFilter == 'movie' && item.type != 'movie') return false;
        if (_typeFilter == 'series' && !item.isSeries && item.type != 'series') return false;
        if (_typeFilter == 'channel' && item.type != 'channel') return false;
      }
      
      // Filtro por qualidade
      if (_qualityFilter != 'all') {
        final q = item.quality.toLowerCase();
        if (_qualityFilter == '4k') {
          // Só mostra 4K/UHD
          if (!q.contains('4k') && !q.contains('uhd')) return false;
        } else if (_qualityFilter == 'fhd') {
          // Só mostra FHD/FullHD (exclui 4K)
          if (!q.contains('fhd') && !q.contains('fullhd')) return false;
        } else if (_qualityFilter == 'hd') {
          // Mostra HD (inclui FHD e 4K também, pois são HD)
          if (!q.contains('hd') && !q.contains('4k') && !q.contains('uhd')) return false;
        }
      }
      
      return true;
    }).toList();
  }

  void _updateFilters() {
    if (_lastQuery.isNotEmpty) {
      // Re-aplica filtros nos resultados atuais sem refazer a busca completa se possível,
      // mas como filters são aplicados pós-busca, o ideal é refazer busca no cache ou armazenar raw
      // Para simplificar e garantir consistência:
      _performSearch(_lastQuery);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header com busca
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF0F1620),
                border: Border(bottom: BorderSide(color: Color(0x334B5563))),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                        autofocus: false,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocus,
                          autofocus: true,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          decoration: InputDecoration(
                            hintText: 'Buscar filmes, séries, canais...',
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.white10,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(Icons.search, color: Colors.white70),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, color: Colors.white54),
                                    onPressed: () {
                                      _searchController.clear();
                                      _onSearchChanged('');
                                    },
                                  )
                                : null,
                          ),
                          onChanged: _onSearchChanged,
                          onSubmitted: (val) {
                            if (_debounce?.isActive ?? false) _debounce!.cancel();
                            _performSearch(val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Filtros
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'Todos',
                          selected: _typeFilter == 'all',
                          onTap: () {
                            setState(() => _typeFilter = 'all');
                            _updateFilters();
                          },
                        ),
                        _FilterChip(
                          label: 'Filmes',
                          selected: _typeFilter == 'movie',
                          onTap: () {
                            setState(() => _typeFilter = 'movie');
                            _updateFilters();
                          },
                        ),
                        _FilterChip(
                          label: 'Séries',
                          selected: _typeFilter == 'series',
                          onTap: () {
                            setState(() => _typeFilter = 'series');
                            _updateFilters();
                          },
                        ),
                        _FilterChip(
                          label: 'Canais',
                          selected: _typeFilter == 'channel',
                          onTap: () {
                            setState(() => _typeFilter = 'channel');
                            _updateFilters();
                          },
                        ),
                        const SizedBox(width: 16),
                        Container(width: 1, height: 24, color: Colors.white24),
                        const SizedBox(width: 16),
                        _FilterChip(
                          label: '4K',
                          selected: _qualityFilter == '4k',
                          onTap: () {
                            setState(() => _qualityFilter = _qualityFilter == '4k' ? 'all' : '4k');
                            _updateFilters();
                          },
                        ),
                        _FilterChip(
                          label: 'FHD',
                          selected: _qualityFilter == 'fhd',
                          onTap: () {
                            setState(() => _qualityFilter = _qualityFilter == 'fhd' ? 'all' : 'fhd');
                            _updateFilters();
                          },
                        ),
                        _FilterChip(
                          label: 'HD',
                          selected: _qualityFilter == 'hd',
                          onTap: () {
                            setState(() => _qualityFilter = _qualityFilter == 'hd' ? 'all' : 'hd');
                            _updateFilters();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Resultados
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _results.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _lastQuery.isEmpty ? Icons.search : Icons.search_off,
                                color: Colors.white30,
                                size: 64,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _lastQuery.isEmpty
                                    ? 'Digite para buscar'
                                    : 'Nenhum resultado para "$_lastQuery"',
                                style: const TextStyle(color: Colors.white54, fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                '${_results.length} resultados encontrados',
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ),
                            Expanded(
                              child: GridView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 6,
                                  childAspectRatio: 0.55,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                                itemCount: _results.length,
                                itemBuilder: (context, index) {
                                  final item = _results[index];
                                  return _SearchResultCard(
                                    item: item,
                                    onTap: () {
                                      if (item.isSeries) {
                                        Navigator.push(context, MaterialPageRoute(
                                          builder: (_) => SeriesDetailScreen(item: item),
                                        ));
                                      } else if (item.type == 'movie') {
                                        // CRÍTICO: Rota correta para filmes
                                        Navigator.push(context, MaterialPageRoute(
                                          builder: (_) => MovieDetailScreen(item: item),
                                        ));
                                      } else {
                                        Navigator.push(context, MaterialPageRoute(
                                          builder: (_) => MediaPlayerScreen(url: item.url, item: item),
                                        ));
                                      }
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Focus(
        onFocusChange: (f) => setState(() => _focused = f),
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
               event.logicalKey == LogicalKeyboardKey.select ||
               event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
            widget.onTap();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: widget.selected ? AppColors.primary : Colors.white10,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _focused ? Colors.white : (widget.selected ? AppColors.primary : Colors.white24),
                width: _focused ? 2 : 1,
              ),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                color: widget.selected ? Colors.white : Colors.white70,
                fontSize: 13,
                fontWeight: widget.selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchResultCard extends StatefulWidget {
  final ContentItem item;
  final VoidCallback onTap;

  const _SearchResultCard({required this.item, required this.onTap});

  @override
  State<_SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<_SearchResultCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: _focused ? Border.all(color: AppColors.primary, width: 2) : null,
            boxShadow: _focused ? [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 12)] : null,
          ),
          transform: _focused ? (Matrix4.identity()..scale(1.05)) : Matrix4.identity(),
          transformAlignment: Alignment.center,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: widget.item.image,
                        fit: BoxFit.cover,
                        placeholder: (c, u) => Container(color: const Color(0xFF333333)),
                        errorWidget: (c, u, e) => Container(
                          color: const Color(0xFF333333),
                          child: Icon(
                            widget.item.type == 'channel' ? Icons.live_tv : Icons.movie,
                            color: Colors.white30,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                    // Badge de tipo
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: widget.item.type == 'movie'
                              ? Colors.blue.withOpacity(0.9)
                              : widget.item.isSeries || widget.item.type == 'series'
                                  ? Colors.purple.withOpacity(0.9)
                                  : Colors.green.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.item.type == 'movie' ? 'FILME' : (widget.item.isSeries || widget.item.type == 'series') ? 'SÉRIE' : 'CANAL',
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    // Badge de qualidade
                    if (widget.item.quality.isNotEmpty)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getQualityLabel(widget.item.quality),
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
              ),
              if (widget.item.group.isNotEmpty)
                Text(
                  widget.item.group,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 9),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getQualityLabel(String quality) {
    final q = quality.toLowerCase();
    if (q.contains('4k') || q.contains('uhd')) return '4K';
    if (q.contains('fhd') || q.contains('fullhd')) return 'FHD';
    if (q.contains('hd')) return 'HD';
    return 'SD';
  }
}
