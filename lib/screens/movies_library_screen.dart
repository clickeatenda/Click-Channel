import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../widgets/glass_panel.dart';
import '../widgets/custom_app_header.dart';

class MoviesLibraryScreen extends StatefulWidget {
  const MoviesLibraryScreen({super.key});

  @override
  State<MoviesLibraryScreen> createState() => _MoviesLibraryScreenState();
}

class _MoviesLibraryScreenState extends State<MoviesLibraryScreen> {
  int _selectedNavIndex = 1;
  String _searchQuery = '';

  final List<HeaderNav> _navItems = [
    HeaderNav(label: 'Home'),
    HeaderNav(label: 'Movies'),
    HeaderNav(label: 'Live TV'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Column(
        children: [
          CustomAppHeader(
            title: 'ClickFlix',
            navItems: _navItems,
            selectedNavIndex: _selectedNavIndex,
            onNavSelected: (index) =>
                setState(() => _selectedNavIndex = index),
            userAvatarUrl:
                'https://via.placeholder.com/32x32?text=User',
            userName: 'Sarah J',
            onNotificationTap: () {},
            onProfileTap: () {},
            onSearchChanged: (query) =>
                setState(() => _searchQuery = query),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Movies Library',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Filter options
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('All'),
                          _buildFilterChip('Action'),
                          _buildFilterChip('Comedy'),
                          _buildFilterChip('Drama'),
                          _buildFilterChip('Horror'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Movies Grid
                    GridView.count(
                      crossAxisCount: 4,
                      mainAxisSpacing: 24,
                      crossAxisSpacing: 24,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: List.generate(
                        12,
                        (index) => _buildMovieCard('Movie ${index + 1}'),
                      ),
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

  Widget _buildMovieCard(String title) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withOpacity(0.3),
                    AppColors.surface,
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.movie,
                  color: AppColors.primary,
                  size: 40,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '2024 • 2h 28m',
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
    );
  }
}
