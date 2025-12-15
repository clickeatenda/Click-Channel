import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/content_item.dart';
import '../data/api_service.dart';
import '../widgets/content_card.dart';
import 'player_dashboard_screen.dart';

class MoviesLibraryScreen extends StatefulWidget {
  const MoviesLibraryScreen({super.key});

  @override
  State<MoviesLibraryScreen> createState() => _MoviesLibraryScreenState();
}

class _MoviesLibraryScreenState extends State<MoviesLibraryScreen> {
  List<ContentItem> movies = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadMovies();
  }

  Future<void> _loadMovies() async {
    final data = await ApiService.fetchAllMovies(limit: 100);
    if (mounted) {
      setState(() {
        movies = data;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SafeArea(
              child: SingleChildScrollView(
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
                    const SizedBox(height: 8),
                    Text(
                      'Explore nossa coleção de ${movies.length} filmes',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Grid de filmes do backend
                    GridView.count(
                      crossAxisCount: 4,
                      mainAxisSpacing: 24,
                      crossAxisSpacing: 24,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: movies.map((movie) {
                        return ContentCard(
                          item: movie,
                          onTap: (_) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    PlayerDashboardScreen(
                                      contentTitle: movie.title,
                                      contentUrl: movie.url,
                                    ),
                              ),
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
