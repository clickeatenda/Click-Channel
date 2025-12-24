import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/content_item.dart';
import '../core/config.dart';
import '../data/m3u_service.dart';
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
      // CRÍTICO: Só carrega dados se houver playlist configurada
      // SEM fallback para backend - app deve estar limpo sem playlist
      final hasM3u = Config.playlistRuntime != null && Config.playlistRuntime!.isNotEmpty;
      if (!hasM3u) {
        print('⚠️ MoviesLibraryScreen: Sem playlist configurada - retornando lista vazia');
        if (mounted) {
          setState(() {
            movies = [];
            loading = false;
            error = null;
          });
        }
        return;
      }

      List<ContentItem> data = [];
      data = await M3uService.fetchFromEnv(limit: 100);
      print('🎬 MoviesLibraryScreen: ✅ Carregados ${data.length} itens da M3U');
      // Filter only movies (non-series)
      data = data.where((item) => !item.isSeries).toList();
      print('🎬 MoviesLibraryScreen: ${data.length} filmes após filtro');
      
      print('🎬 MoviesLibraryScreen: Recebidos ${data.length} filmes');
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
