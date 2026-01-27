import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../widgets/glass_panel.dart';
import '../widgets/custom_app_header.dart';
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

  final List<HeaderNav> _navItems = [
    HeaderNav(label: 'Início'),
    HeaderNav(label: 'Filmes'),
    HeaderNav(label: 'Séries'),
    HeaderNav(label: 'Canais'),
    HeaderNav(label: 'SharkFlix'),
  ];

  void _navigateByIndex(int index) {
    if (index >= 0 && index <= 4) {
      Navigator.pushNamed(context, '/home', arguments: index);
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
      body: Column(
        children: [
          CustomAppHeader(
            title: 'Click Channel',
            navItems: _navItems,
            selectedNavIndex: _selectedNavIndex,
            onNavSelected: (index) => _navigateByIndex(index),
            userAvatarUrl: 'https://via.placeholder.com/32x32?text=User',
            userName: 'Usuário',
            onNotificationTap: () {},
            onProfileTap: () {
              Navigator.pushNamed(context, '/profile');
            },
            onSettingsTap: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
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
                          _buildFilterChip('Todos'),
                          _buildFilterChip('Filmes'),
                          _buildFilterChip('Séries'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    if (_filteredFavorites.isEmpty)
                       Center(
                          child: Padding(
                            padding: const EdgeInsets.all(48.0),
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

  Widget _buildFilterChip(String label) {
    final isSelected = _filter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () => setState(() => _filter = label),
        child: GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          borderRadius: BorderRadius.circular(20),
          backgroundColor: isSelected ? AppColors.primary.withOpacity(0.5) : null,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
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
