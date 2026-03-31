import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../models/content_item.dart';
import '../widgets/optimized_gridview.dart';
import '../widgets/media_player_screen.dart';
import '../data/m3u_service.dart';
import '../data/jellyfin_service.dart';
import '../utils/content_enricher.dart'; 
import 'series_detail_screen.dart';
import 'movie_detail_screen.dart';
import '../widgets/app_sidebar.dart';
import 'home_screen.dart' show topBackgroundNotifier;

class CategoryScreen extends StatefulWidget {
  final String categoryName;
  final String type;
  final bool isJellyfin;
  final String? libraryId;

  const CategoryScreen({
    super.key, 
    required this.categoryName, 
    required this.type,
    this.isJellyfin = false,
    this.libraryId,
  });

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  List<ContentItem> items = [];
  List<ContentItem> featuredItems = [];
  List<ContentItem> filteredItems = [];
  int visibleCount = 0;
  final int pageSize = 60; // Reduzido drasticamente para evitar OOM no Firestick
  bool loading = true;
  ContentItem? bannerItem;
  bool _epgLoaded = false;
  
  // Filtros
  String selectedQuality = 'all';
  String sortBy = 'popularity';

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => loading = true);
    try {
      List<ContentItem> allItems = [];
      if (widget.isJellyfin && widget.libraryId != null) {
        // CORREÇÃO: Usando o método correto getItems
        allItems = await JellyfinService.getItems(libraryId: widget.libraryId!);
      } else {
        allItems = await M3uService.fetchCategoryItemsFromEnv(
          category: widget.categoryName,
          typeFilter: widget.type,
        );
      }

      // Enriquecimento básico se necessário
      if (allItems.isNotEmpty && allItems.length < 50) {
         allItems = await ContentEnricher.enrichItems(allItems);
      }

      if (mounted) {
        setState(() {
          items = allItems;
          _applyFilters();
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  void _applyFilters() {
    // Aplicação de filtros e ordenação usando ContentSorter (que está em content_enricher.dart)
    var result = widget.isJellyfin ? items : ContentSorter.filterAndSort(
      items,
      sortBy: sortBy,
    );

    if (selectedQuality != 'all') {
      result = result.where((i) => i.quality.toLowerCase().contains(selectedQuality.toLowerCase())).toList();
    }

    setState(() {
      filteredItems = result;
      visibleCount = min(pageSize, filteredItems.length);
      if (filteredItems.isNotEmpty) {
        bannerItem = filteredItems.first;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // DYNAMIC BACKGROUND LAYER
          Positioned.fill(
            child: ValueListenableBuilder<String?>(
              valueListenable: topBackgroundNotifier,
              builder: (context, imageUrl, _) {
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Container(
                          key: ValueKey(imageUrl),
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: NetworkImage(imageUrl),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                            child: Container(
                              color: AppColors.backgroundDark.withOpacity(0.75),
                            ),
                          ),
                        )
                      : Container(
                          key: const ValueKey('default_bg'),
                          color: AppColors.backgroundDark,
                        ),
                );
              },
            ),
          ),
          Row(
            children: [
              FocusTraversalGroup(
                policy: WidgetOrderTraversalPolicy(),
                child: const AppSidebar(selectedIndex: -1),
              ),
              Expanded(
                child: FocusTraversalGroup(
                  policy: WidgetOrderTraversalPolicy(),
                  child: loading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                      : Column(
                          children: [
                          // Header com busca/info
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                            child: Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.categoryName,
                                      // CORREÇÃO: Usando headlineLarge em vez de h1
                                      style: AppTypography.headlineLarge,
                                    ),
                                    Text(
                                      '${filteredItems.length} itens encontrados',
                                      style: AppTypography.bodySmall.copyWith(color: Colors.white54),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                // Botões de Filtro
                                _buildFilterButtons(),
                              ],
                            ),
                          ),
                          // Grid de Conteúdo
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: OptimizedGridView(
                                items: filteredItems.take(visibleCount).toList(),
                                headerWidget: null,
                                onEndReached: () {
                                  if (visibleCount < filteredItems.length) {
                                    setState(() {
                                      visibleCount = min(visibleCount + pageSize, filteredItems.length);
                                    });
                                  }
                                },
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
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButtons() {
    return Row(
      children: [
        _FilterChip(
          label: 'Popularidade',
          selected: sortBy == 'popularity',
          onTap: () {
            setState(() => sortBy = 'popularity');
            _applyFilters();
          },
        ),
        _FilterChip(
          label: 'Rating',
          selected: sortBy == 'rating',
          onTap: () {
            setState(() => sortBy = 'rating');
            _applyFilters();
          },
        ),
        _FilterChip(
          label: 'Recentes',
          selected: sortBy == 'latest',
          onTap: () {
            setState(() => sortBy = 'latest');
            _applyFilters();
          },
        ),
      ],
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
      padding: const EdgeInsets.only(left: 12),
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
              color: widget.selected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _focused ? Colors.white : (widget.selected ? AppColors.primary.withOpacity(0.5) : Colors.white10),
                width: 1,
              ),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                color: widget.selected ? AppColors.primary : Colors.white70,
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