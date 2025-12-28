import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/content_item.dart';
import '../data/tmdb_service.dart';
import '../widgets/optimized_gridview.dart';
import 'content_detail_screen.dart';

class MoviesLibraryScreen extends StatefulWidget {
  const MoviesLibraryScreen({super.key});

  @override
  State<MoviesLibraryScreen> createState() => _MoviesLibraryScreenState();
}

class _MoviesLibraryScreenState extends State<MoviesLibraryScreen> {
  List<ContentItem> movies = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    print('🎬 MoviesLibraryScreen: initState chamado!');
    _loadMovies();
  }

  Future<void> _loadMovies() async {
    print('🎬 MoviesLibraryScreen: Iniciando carregamento de filmes...');
    try {
      // CRÍTICO: Carrega filmes populares direto do TMDB (evita canais do M3U)
      print('🎬 MoviesLibraryScreen: Carregando filmes populares do TMDB...');
      
      if (mounted) {
        setState(() {
          loading = true;
        });
      }
      
      // Carrega filmes populares do TMDB
      final tmdbMovieList = await TmdbService.getPopularMovies(page: 1);
      
      // Converte TmdbMetadata em ContentItem
      List<ContentItem> data = [];
      for (final movie in tmdbMovieList) {
        data.add(ContentItem(
          title: movie.title,
          url: movie.backdropUrl ?? movie.posterUrl ?? '',
          image: movie.posterUrl ?? '',
          group: 'TMDB Popular',
          type: 'movie',
          rating: movie.rating,
          popularity: movie.popularity,
          releaseDate: movie.releaseDate,
          genre: movie.genres.join(', '),
          description: movie.overview ?? '',
          director: movie.director,
        ));
      }
      
      print('🎬 MoviesLibraryScreen: ✅ Carregados ${data.length} filmes do TMDB');
      
      // CRÍTICO: Mostra UI imediatamente, enriquece TMDB em background
      if (mounted) {
        setState(() {
          movies = data;
          loading = false;
          error = null;
        });
      }
    } catch (e) {
      print('❌ MoviesLibraryScreen: Erro ao carregar: $e');
      if (mounted) {
        setState(() {
          loading = false;
          error = e.toString();
          movies = [];
        });
      }
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
          : error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, 
                        size: 64, 
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Erro ao carregar filmes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loadMovies,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
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

                            // Grid com suporte a controle remoto (foco/enter)
                            OptimizedGridView(
                              items: movies,
                              crossAxisCount: 4,
                              childAspectRatio: 0.75,
                              crossAxisSpacing: 24,
                              mainAxisSpacing: 24,
                              physics: const BouncingScrollPhysics(),
                              showMetaChips: true,
                              metaFontSize: 10,
                              metaIconSize: 12,
                              onTap: (movie) {
                                print('🎬 Clicou em: ${movie.title}');
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ContentDetailScreen(
                                      item: movie,
                                      contentType: 'movie',
                                    ),
                                  ),
                                );
                              },
                            ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
