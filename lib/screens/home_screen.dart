import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../models/content_item.dart';
import '../data/api_service.dart';
import '../widgets/header.dart';
import '../widgets/hero_carousel.dart';
import '../widgets/category_card.dart';
import '../widgets/player_screen.dart';
import 'category_screen.dart';
import 'series_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String currentFilter = 'all'; 
  List<String> categories = [];
  List<String> filteredCategories = [];
  List<ContentItem> heroItems = [];
  bool loading = true;
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => loading = true);
    final cats = await ApiService.fetchCategoryNames(currentFilter);
    
    // Carrega itens para o Banner (Hero)
    List<ContentItem> heroes = [];
    if (cats.isNotEmpty) {
      // Tenta pegar 1 destaque de cada uma das 5 primeiras categorias
      for (var i = 0; i < (cats.length > 5 ? 5 : cats.length); i++) {
        final items = await ApiService.fetchCategoryItems(cats[i], currentFilter);
        if (items.isNotEmpty) heroes.add(items.first);
      }
    }

    if (mounted) setState(() { categories = cats; filteredCategories = cats; heroItems = heroes; loading = false; });
  }

  void _onFilterChange(String newFilter) {
    if (currentFilter != newFilter) {
      setState(() { currentFilter = newFilter; categories = []; heroItems = []; searchQuery = ""; filteredCategories = []; });
      _loadData();
    }
  }

  void _performSearch(String query) {
    setState(() {
      searchQuery = query.toLowerCase();
      if (searchQuery.isEmpty) {
        filteredCategories = categories;
      } else {
        filteredCategories = categories
            .where((category) => category.toLowerCase().contains(searchQuery))
            .toList();
      }
    });
  }

  void _clearSearch() {
    setState(() {
      searchQuery = "";
      filteredCategories = categories;
    });
  }

  void _openPlayer(ContentItem item) {
    if (item.isSeries) {
       Navigator.push(context, MaterialPageRoute(builder: (_) => SeriesDetailScreen(item: item)));
    } else {
       Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(url: item.url)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: loading 
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Stack(
              children: [
                // AGORA USAMOS SEMPRE O LAYOUT DE GRADE (PASTAS)
                // MAS COM O CARROSSEL NO TOPO
                _buildCategoryGridLayout(),
                
                Positioned(
                  top: 0, left: 0, right: 0, 
                  child: Header(
                    onRefresh: _loadData, 
                    onFilterChanged: _onFilterChange, 
                    currentFilter: currentFilter, 
                    onSettings: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                    onSearch: _performSearch,
                    onClearSearch: _clearSearch,
                  )
                ),
              ],
            ),
    );
  }

  Widget _buildCategoryGridLayout() {
    return CustomScrollView(
      slivers: [
        const SliverPadding(padding: EdgeInsets.only(top: 80)),
        
        // 1. Carrossel de Destaques (Fica bonito na Home)
        SliverToBoxAdapter(
          child: heroItems.isNotEmpty 
            ? HeroCarousel(items: heroItems, onPlay: _openPlayer) 
            : const SizedBox.shrink()
        ),

        // 2. Título da Seção
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 20, 30, 10),
            child: Text(
              _getTitleForFilter(),
              style: AppTypography.headlineLarge,
            ),
          ),
        ),

        // 3. GRADE DE PASTAS (Categorias)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 250, 
              childAspectRatio: 1.6, // Retangular (Pasta)
              crossAxisSpacing: 20, 
              mainAxisSpacing: 20,
            ),
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => CategoryCard(
                name: filteredCategories[i],
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryScreen(
                  categoryName: filteredCategories[i],
                  type: currentFilter,
                ))),
              ),
              childCount: filteredCategories.length,
            ),
          ),
        ),
      ],
    );
  }

  String _getTitleForFilter() {
    switch (currentFilter) {
      case 'movie': return "Pastas de Filmes";
      case 'series': return "Pastas de Séries";
      case 'channel': return "Pastas de Canais";
      default: return "Todas as Categorias";
    }
  }
}