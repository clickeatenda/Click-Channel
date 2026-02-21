import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';
import '../widgets/app_sidebar.dart';
import '../models/content_item.dart';
import '../widgets/optimized_gridview.dart';
import '../data/favorites_service.dart';
import 'movie_detail_screen.dart';
import 'series_detail_screen.dart';

class MyFavoritesScreen extends StatefulWidget {
  const MyFavoritesScreen({super.key});

  @override
  State<MyFavoritesScreen> createState() => _MyFavoritesScreenState();
}

class _MyFavoritesScreenState extends State<MyFavoritesScreen> {
  int _selectedNavIndex = -1; 
  List<ContentItem> _favorites = []; // Lista real
  bool _isLoading = true;
  String _filter = 'Todos'; // 'Todos', 'Filmes', 'Séries'

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }
  
  // Recarrega sempre que a tela ganha foco (se voltar de um detalhe onde desfavoritou)
  // Mas no Flutter 'focus' de rota é diferente. Vou usar then() na navegação.
  
  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    final favs = FavoritesService.getAll();
    if (mounted) {
      setState(() {
        _favorites = favs;
        _isLoading = false;
      });
    }
  }

  List<ContentItem> get _filteredFavorites {
    if (_filter == 'Todos') return _favorites;
    if (_filter == 'Filmes') return _favorites.where((i) => !i.isSeries).toList();
    if (_filter == 'Séries') return _favorites.where((i) => i.isSeries).toList();
    return _favorites;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Row(
        children: [
          const AppSidebar(selectedIndex: -1),
          Expanded(
            child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Meus Favoritos',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Seus filmes e séries salvos',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Filter tabs
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FavoritesFilterChip(
                            label: 'Todos',
                            selected: _filter == 'Todos',
                            onTap: () => setState(() => _filter = 'Todos'),
                          ),
                          _FavoritesFilterChip(
                            label: 'Filmes',
                            selected: _filter == 'Filmes',
                            onTap: () => setState(() => _filter = 'Filmes'),
                          ),
                          _FavoritesFilterChip(
                            label: 'Séries',
                            selected: _filter == 'Séries',
                            onTap: () => setState(() => _filter = 'Séries'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    if (_filteredFavorites.isEmpty)
                       const Center(
                          child: Padding(
                            padding: EdgeInsets.all(48.0),
                            child: Column(
                              children: [
                                Icon(Icons.favorite_border, size: 60, color: Colors.white24),
                                SizedBox(height: 16),
                                Text(
                                  'Nenhum favorito encontrado',
                                  style: TextStyle(color: Colors.white54),
                                )
                              ],
                            ),
                          )
                       )
                    else
                      // Favorites Grid
                      OptimizedGridView(
                        items: _filteredFavorites,
                        crossAxisCount: 6, // Mais denso
                        mainAxisSpacing: 24,
                        crossAxisSpacing: 24,
                        childAspectRatio: 0.65,
                        physics: const NeverScrollableScrollPhysics(),
                        onTap: (item) => _handleFavoriteTap(item),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleFavoriteTap(ContentItem item) {
    if (item.isSeries) {
         Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SeriesDetailScreen(item: item)),
        ).then((_) => _loadFavorites()); // Recarrega ao voltar
    } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MovieDetailScreen(item: item)),
        ).then((_) => _loadFavorites()); // Recarrega ao voltar
    }
  }
}

class _FavoritesFilterChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FavoritesFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_FavoritesFilterChip> createState() => _FavoritesFilterChipState();
}

class _FavoritesFilterChipState extends State<_FavoritesFilterChip> {
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
              color: widget.selected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _focused ? Colors.white : (widget.selected ? AppColors.primary.withOpacity(0.5) : Colors.transparent),
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
