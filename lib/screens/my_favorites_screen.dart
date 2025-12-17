import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../widgets/glass_panel.dart';
import '../widgets/custom_app_header.dart';
import '../models/content_item.dart';
import '../widgets/optimized_gridview.dart';

class MyFavoritesScreen extends StatefulWidget {
  const MyFavoritesScreen({super.key});

  @override
  State<MyFavoritesScreen> createState() => _MyFavoritesScreenState();
}

class _MyFavoritesScreenState extends State<MyFavoritesScreen> {
  int _selectedNavIndex = -1; // fora da Home, nenhum selecionado

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

  @override
  Widget build(BuildContext context) {
    final demoFavorites = List.generate(8, (i) => ContentItem(
      title: 'Favorite ${i + 1}',
      url: 'https://example.com/fav/${i + 1}',
      image: '',
      group: 'Favorites',
      type: i.isEven ? 'movie' : 'series',
      isSeries: !i.isEven,
    ));

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Column(
        children: [
          CustomAppHeader(
            title: 'Click Channel',
            navItems: _navItems,
            selectedNavIndex: _selectedNavIndex,
            onNavSelected: (index) => _navigateByIndex(index),
            userAvatarUrl:
                'https://via.placeholder.com/32x32?text=User',
            userName: 'Sarah J',
            onNotificationTap: () {},
            onProfileTap: () {
              Navigator.pushNamed(context, '/profile');
            },
            onSettingsTap: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'My Favorites',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your saved favorites across movies and series',
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
                          _buildFilterChip('All'),
                          _buildFilterChip('Movies'),
                          _buildFilterChip('Series'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Favorites Grid com navegação por controle
                    OptimizedGridView(
                      items: demoFavorites,
                      crossAxisCount: 4,
                      mainAxisSpacing: 24,
                      crossAxisSpacing: 24,
                      childAspectRatio: 0.7,
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
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        borderRadius: BorderRadius.circular(20),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _handleFavoriteTap(ContentItem item) {
    // TODO: integrar com detalhe/player conforme tipo
    debugPrint('Abrir favorito: ${item.title} (${item.type})');
  }
}
