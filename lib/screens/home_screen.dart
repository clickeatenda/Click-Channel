import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'detail_screens.dart' hide SeriesDetailScreen;
import 'series_detail_screen.dart';
import 'movie_detail_screen.dart';
import 'search_screen.dart';
import '../data/watch_history_service.dart';
import '../data/m3u_service.dart';
import '../data/jellyfin_service.dart';
import '../data/epg_service.dart';
import '../data/tmdb_service.dart';
import '../utils/content_enricher.dart';
import '../core/config.dart';
import '../core/theme/app_colors.dart';
import '../models/content_item.dart';
import '../models/epg_program.dart';
import 'dart:convert'; // For jsonEncode/Decode
import 'dart:ui'; // For ImageFilter
import 'package:shared_preferences/shared_preferences.dart'; // For caching

import '../widgets/media_player_screen.dart';
import '../widgets/adaptive_cached_image.dart';
import '../widgets/meta_chips_widget.dart';
import '../data/favorites_service.dart'; // NOVO import
import '../widgets/app_sidebar.dart';
import '../routes/app_routes.dart';

final ValueNotifier<String?> topBackgroundNotifier = ValueNotifier<String?>(null);

class HomeScreen extends StatefulWidget {
  final int initialIndex;
  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }



  Future<bool> _onWillPop() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Sair do Aplicativo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Deseja realmente sair?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sair', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    
    if (shouldExit == true) {
      SystemNavigator.pop();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF111318);  // --bg-dark

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: bg,
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
                                image: CachedNetworkImageProvider(imageUrl),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                              child: Container(
                                color: bg.withOpacity(0.65), // Escurece o fundo para destacar o conteúdo
                              ),
                            ),
                          )
                        : Container(
                            key: const ValueKey('default_bg'),
                            color: bg,
                          ),
                  );
                },
              ),
            ),
            // CONTEÚDO PRINCIPAL
            SafeArea(
              child: Row(
                children: [
                  // BARRA LATERAL (SIDEBAR)
                  FocusTraversalGroup(
                    policy: WidgetOrderTraversalPolicy(),
                    child: AppSidebar(
                      selectedIndex: _selectedIndex,
                      onNavSelected: (index) {
                        setState(() => _selectedIndex = index);
                      },
                    ),
                  ),

                  // CONTEÚDO POR ABA
                  Expanded(
                    child: FocusTraversalGroup(
                      policy: WidgetOrderTraversalPolicy(),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(opacity: animation, child: child);
                        },
                        child: _buildNavigationBody(_selectedIndex),
                      ),
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

  Widget _buildNavigationBody(int index) {
    switch (index) {
      case 0:
        return const _HomeBody(key: ValueKey('tab_home'));
      case 1:
        return const MoviesLibraryBody(key: ValueKey('tab_movies'));
      case 2:
        return const SeriesLibraryBody(key: ValueKey('tab_series'));
      case 3:
        return const LiveChannelsBody(key: ValueKey('tab_live'));
      case 4:
        return const PremiumBody(key: ValueKey('tab_premium'));
      default:
        return const _HomeBody(key: ValueKey('tab_home_default'));
    }
  }
}

// (Seção "Continuar Assistindo" removida; não utilizada e estava corrompida)

// =====================
// APP LOGO WIDGET
// =====================

class _AppLogo extends StatelessWidget {
  const _AppLogo();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.asset(
        'assets/images/logo.png',
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary, 
                  AppColors.primaryLight,
                ],
              ),
            ),
            child: const Icon(Icons.live_tv, color: Colors.white, size: 24),
          );
        },
      ),
    );
  }
}

// =====================
// TEST PANEL
// =====================

class _TestPanel extends StatefulWidget {
  @override
  State<_TestPanel> createState() => _TestPanelState();
}

class _TestPanelState extends State<_TestPanel> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isExpanded)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1620),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE11D48)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '🧪 Telas de Teste',
                      style: TextStyle(
                        color: Color(0xFFE11D48),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _isExpanded = false),
                      child: const Icon(Icons.close,
                          color: Colors.white70, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 180,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    onPressed: null,
                    icon: const Icon(Icons.tv, size: 18),
                    label: const Text(
                      'Série Detail',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 180,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const MyFavoritesScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.favorite, size: 18),
                    label: const Text(
                      'Meus Favoritos',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 180,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const PlayerDashboardScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_circle, size: 18),
                    label: const Text(
                      'Reprodutor',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE11D48),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE11D48).withOpacity(0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              _isExpanded ? Icons.close : Icons.apps,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }
}

// Home (Início)
class _HomeBody extends StatefulWidget {
  const _HomeBody({super.key});
  @override
  State<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<_HomeBody> {
  List<ContentItem> featuredMovies = [];
  List<ContentItem> featuredSeries = [];
  List<ContentItem> featuredChannels = [];
  List<ContentItem> watchedItems = [];
  List<WatchingItem> watchingItems = [];
  bool loading = true;

  // Keys for caching
  static const String _keyMovies = 'home_featured_movies';
  static const String _keySeries = 'home_featured_series';
  static const String _keyChannels = 'home_featured_channels';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final moviesJson = prefs.getString(_keyMovies);
      final seriesJson = prefs.getString(_keySeries);
      final channelsJson = prefs.getString(_keyChannels);

      bool hasData = false;
      
      if (moviesJson != null) {
        final List list = jsonDecode(moviesJson);
        featuredMovies = list.map((x) => ContentItem.fromJson(x)).toList();
        hasData = true;
      }
      
      if (seriesJson != null) {
        final List list = jsonDecode(seriesJson);
        featuredSeries = list.map((x) => ContentItem.fromJson(x)).toList();
        hasData = true;
      }

      if (channelsJson != null) {
        final List list = jsonDecode(channelsJson);
        featuredChannels = list.map((x) => ContentItem.fromJson(x)).toList();
        hasData = true;
      }

      if (hasData && mounted) {
        print('✅ Home: Dados carregados do cache (Instant Load)');
        setState(() {
          loading = false;
        });
      }
    } catch (e) {
      print('⚠️ Home: Erro ao carregar cache: $e');
    }
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (featuredMovies.isNotEmpty) {
        prefs.setString(_keyMovies, jsonEncode(featuredMovies.map((x) => x.toJson()).toList()));
      }
      if (featuredSeries.isNotEmpty) {
        prefs.setString(_keySeries, jsonEncode(featuredSeries.map((x) => x.toJson()).toList()));
      }
      if (featuredChannels.isNotEmpty) {
        prefs.setString(_keyChannels, jsonEncode(featuredChannels.map((x) => x.toJson()).toList()));
      }
      print('✅ Home: Dados salvos no cache');
    } catch (e) {
       print('⚠️ Home: Erro ao salvar cache: $e');
    }
  }

  Future<void> _load() async {
    try {
      // 1. Carregar histórico (Rápido)
      final watched = await WatchHistoryService.getWatchedItems(limit: 15);
      final watching = await WatchHistoryService.getWatchingItems(limit: 15);
      
      if (mounted) {
        setState(() {
          watchedItems = watched;
          watchingItems = watching;
        });
      }

      // 2. Carregar Cache (Instantâneo)
      await _loadCachedData();
      
      // 3. Buscar destaques do TMDB em paralelo (Lento - Rede)
      try {
        // Buscar destaques do TMDB em paralelo
        final tmdbResults = await Future.wait([
          TmdbService.getPopularMovies(page: 1),
          TmdbService.getPopularSeries(page: 1),
        ]);
        
        // Converter TmdbMetadata para ContentItem
        List<ContentItem> tmdbMovies = tmdbResults[0]
          .take(10)
          .map((m) => ContentItem(
            title: m.title,
            url: '', // TMDB items não têm URL de streaming
            image: m.posterPath != null ? 'https://image.tmdb.org/t/p/w342${m.posterPath}' : '',
            group: 'TMDB Popular',
            type: 'movie',
            id: m.id.toString(),
            rating: m.rating,
            year: m.releaseDate?.substring(0, 4) ?? '',
            description: m.overview ?? '',
          ))
          .toList();
          
        List<ContentItem> tmdbSeries = tmdbResults[1]
          .take(10)
          .map((s) => ContentItem(
            title: s.title,
            url: '', // TMDB items não têm URL de streaming
            image: s.posterPath != null ? 'https://image.tmdb.org/t/p/w342${s.posterPath}' : '',
            group: 'TMDB Popular',
            type: 'series',
            id: s.id.toString(),
            rating: s.rating,
            year: s.releaseDate?.substring(0, 4) ?? '',
            description: s.overview ?? '',
          ))
          .toList();
        
        print('✅ TMDB: Carregados ${tmdbMovies.length} filmes + ${tmdbSeries.length} séries em destaque');
        
        // Carrega canais M3U se houver playlist
        List<ContentItem> channels = [];
        final hasM3u = Config.playlistRuntime != null && Config.playlistRuntime!.isNotEmpty;
        if (hasM3u) {
          channels = await M3uService.getCuratedFeaturedPrefer('channel', count: 6, pool: 50, maxItems: 600);
          print('✅ M3U: Carregados ${channels.length} canais em destaque');
        }
        
        if (!mounted) return;
        setState(() {
          featuredMovies = tmdbMovies;
          featuredSeries = tmdbSeries;
          featuredChannels = channels;
          loading = false;
        });
        
        // 4. Salvar atualização no cache
        _saveToCache();

      } catch (e) {
        print('⚠️ Erro ao carregar destaques TMDB: $e');
        // Se TMDB falhar, tenta M3U como fallback
        final hasM3u = Config.playlistRuntime != null && Config.playlistRuntime!.isNotEmpty;
        if (hasM3u) {
          try {
            final results = await Future.wait([
              M3uService.getCuratedFeaturedPrefer('movie', count: 6, pool: 30, maxItems: 600),
              M3uService.getCuratedFeaturedPrefer('series', count: 6, pool: 30, maxItems: 600),
              M3uService.getCuratedFeaturedPrefer('channel', count: 6, pool: 50, maxItems: 600),
            ]);
            
            print('⚠️ Usando fallback M3U para destaques');
            if (!mounted) return;
            setState(() {
              featuredMovies = results[0];
              featuredSeries = results[1];
              featuredChannels = results[2];
              loading = false;
            });
            _saveToCache(); // Salva fallback também
          } catch (_) {
            if (!mounted) return;
             // Se falhar tudo, mantém o cache (apenas remove loading se não tiver dados)
            setState(() {
              loading = false;
            });
          }
        } else {
          if (!mounted) return;
           // Sem M3U e sem TMDB (erro), mantém cache
          setState(() {
            loading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) return;
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Carrossel "Assistindo" (continuar assistindo)
          if (watchingItems.isNotEmpty) ...[
            _WatchingCarousel(items: watchingItems, onRefresh: _load),
            const SizedBox(height: 16),
          ],
          
          // Carrossel "Últimos assistidos"
          if (watchedItems.isNotEmpty) ...[
            _WatchedCarousel(items: watchedItems),
            const SizedBox(height: 16),
          ],
          
          // Carrossel "Minha Lista" (Favoritos) - Atualização em tempo real
          ValueListenableBuilder<List<ContentItem>>(
            valueListenable: FavoritesService.favoritesNotifier,
            builder: (context, favorites, _) {
              if (favorites.isEmpty) return const SizedBox.shrink();
              return Column(
                children: [
                   // Reusa _FeaturedCarousel que já funciona bem
                  _FeaturedCarousel(items: favorites, title: 'Minha Lista'),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
          
          // Destaques
          if (loading) const Center(child: CircularProgressIndicator()),
          
          // Filmes em destaque (Hero)
          if (!loading && featuredMovies.isNotEmpty) ...[
            _HeroBanner(items: featuredMovies.take(5).toList(), autofocus: true),
            const SizedBox(height: 24),
          ],

          // Séries em destaque
          if (!loading && featuredSeries.isNotEmpty) ...[
            _FeaturedCarousel(items: featuredSeries, title: 'Séries em destaque'),
            const SizedBox(height: 20),
          ],
          
          // Canais em destaque
          if (!loading && featuredChannels.isNotEmpty) ...[
            _FeaturedCarousel(
              items: (featuredChannels.toList()..shuffle()).take(10).toList(),
              title: 'Canais em destaque',
              showEpg: true, // CRÍTICO: Mostra EPG nos cards de canais
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}

// Declaração da classe principal de Filmes (para a State abaixo)
class MoviesLibraryBody extends StatefulWidget {
  const MoviesLibraryBody({super.key});
  @override
  State<MoviesLibraryBody> createState() => _MoviesLibraryBodyState();
}
class _MoviesLibraryBodyState extends State<MoviesLibraryBody> {
  final ScrollController _scrollController = ScrollController();
  List<ContentItem> movies = [];
  List<ContentItem> featuredItems = [];
  List<ContentItem> latestItems = [];
  List<ContentItem> popularItems = []; // Mais vistos
  List<ContentItem> topRatedItems = []; // Mais avaliados
  List<String> movieCategories = [];
  List<String> filteredCategories = [];
  Map<String, int> categoryCounts = {};
  Map<String, String> categoryThumbs = {};
  bool loading = true;
  bool enriching = false;
  bool loadingMore = false;
  bool hasMore = true;
  final int _pageSize = 120;
  int _currentPage = 1;
  String? _lastPlaylistUrl;
  String _qualityFilter = 'all'; // all, 4k, fhd, hd

  void _applyFilters() {
    if (_qualityFilter == 'all') {
      filteredCategories = List.from(movieCategories);
    } else {
      // Filtra categorias que contêm a qualidade no nome ou têm conteúdo dessa qualidade
      filteredCategories = movieCategories.where((cat) {
        final catLower = cat.toLowerCase();
        if (_qualityFilter == '4k') return catLower.contains('4k') || catLower.contains('uhd');
        if (_qualityFilter == 'fhd') return catLower.contains('fhd') || catLower.contains('full');
        if (_qualityFilter == 'hd') return catLower.contains('hd') && !catLower.contains('fhd') && !catLower.contains('uhd');
        return true;
      }).toList();
      // Se não filtrou nada, mostra todas
      if (filteredCategories.isEmpty) filteredCategories = List.from(movieCategories);
    }
  }

  @override
  void initState() {
    super.initState();
    print('🎬 MoviesLibraryBody: initState chamado!');
    _lastPlaylistUrl = Config.playlistRuntime;
    _scrollController.addListener(_onScroll);
    _loadMovies(reset: true);
  }

  @override
  void didUpdateWidget(covariant MoviesLibraryBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload only if playlist URL changed
    if (_lastPlaylistUrl != Config.playlistRuntime) {
      print('🔄 MoviesLibraryBody: URL mudou, recarregando...');
      _lastPlaylistUrl = Config.playlistRuntime;
      setState(() {
        loading = true;
        loadingMore = false;
        hasMore = true;
        movies = [];
      });
      _loadMovies(reset: true);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void reloadMovies() {
    setState(() {
      loading = true;
      loadingMore = false;
      hasMore = true;
      movies = [];
    });
    _loadMovies(reset: true);
  }

  void _onScroll() {
    if (!_scrollController.hasClients || loadingMore || !hasMore) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (loadingMore || !hasMore) return;
    setState(() => loadingMore = true);
    _currentPage += 1;
    await _loadMovies();
  }

  Future<void> _loadMovies({bool reset = false}) async {
    print('🎬 MoviesLibraryBody: Carregando categorias de filmes...');
    try {
      // Melhor fluxo: buscar TMDB em paralelo para mostrar destaques imediatamente
      // e buscar M3U (lista de filmes) separadamente. Evita mostrar canais como
      // filmes recomendados quando TMDB ainda não carregou.
      final hasPlaylist = Config.playlistRuntime != null && Config.playlistRuntime!.isNotEmpty;

      // Iniciar fetchs TMDB (não aguardamos aqui, atualizaremos quando retornarem)
      Future<List<dynamic>>? tmdbPopularFuture;
      Future<List<dynamic>>? tmdbTopRatedFuture;
      if (reset) {
        try {
          tmdbPopularFuture = TmdbService.getPopularMovies(page: 1);
          tmdbTopRatedFuture = TmdbService.getTopRatedMovies(page: 1);
        } catch (e) {
          print('❌ Erro ao iniciar TMDB: $e');
        }
      }

      // Se não há playlist, ainda queremos mostrar destaques TMDB (app não deve depender de M3U)
      if (!hasPlaylist) {
        print('🎬 MoviesLibraryBody: sem playlist - exibindo apenas destaques TMDB');
        // Apply immediately placeholders enquanto TMDB carrega
        if (mounted) {
          setState(() {
            movieCategories = [];
            categoryCounts = {};
            categoryThumbs = {};
            movies = [];
            hasMore = false;
            loading = false;
            loadingMore = false;
            _applyFilters();
          });
        }
        // Atualiza destaques quando TMDB terminar
        tmdbPopularFuture?.then((tmdbPopular) {
          final featured = tmdbPopular.take(5).map((m) => ContentItem(
            title: m.title,
            url: '',
            image: m.posterPath != null ? 'https://image.tmdb.org/t/p/w342${m.posterPath}' : '',
            group: 'TMDB Popular',
            type: 'movie',
            id: m.id.toString(),
            rating: m.rating,
            year: m.releaseDate?.substring(0, 4) ?? '',
            description: m.overview ?? '',
          )).toList();
          if (mounted) setState(() => featuredItems = featured);
        }).catchError((e) { print('❌ TMDB popular falhou: $e'); return Future.value(null); });

        tmdbTopRatedFuture?.then((tmdbTopRated) {
          final latest = tmdbTopRated.take(10).map((m) => ContentItem(
            title: m.title,
            url: '',
            image: m.posterPath != null ? 'https://image.tmdb.org/t/p/w342${m.posterPath}' : '',
            group: 'TMDB TopRated',
            type: 'movie',
            id: m.id.toString(),
            rating: m.rating,
            year: m.releaseDate?.substring(0, 4) ?? '',
            description: m.overview ?? '',
          )).toList();
          if (mounted) setState(() => latestItems = latest);
        }).catchError((e) { print('❌ TMDB toprated falhou: $e'); return Future.value(null); });

        return;
      }

      // Se houver playlist, carregamos M3U (paginado) para a lista principal, mas
      // não usamos M3U para os destaques — os destaques virão do TMDB quando disponíveis.
      print('🎬 MoviesLibraryBody: via M3U (paginado) - carregando lista enquanto TMDB carrega em paralelo');
      const maxItems = 999999;
      final result = await M3uService.fetchPagedFromEnv(
        page: _currentPage,
        pageSize: _pageSize,
        maxItems: maxItems,
        typeFilter: 'movie',
      );

      // Carrega meta apenas se reset (primeira vez) e não tem categorias ainda
      Map<String, String> metaThumbs = categoryThumbs;
      if (reset && movieCategories.isEmpty) {
        final meta = await M3uService.fetchCategoryMetaFromEnv(
          typeFilter: 'movie',
          maxItems: 999999,
        );
        metaThumbs = meta.thumbs;
      }

      // UI inicial com lista M3U (rápido) e destaques vazios enquanto TMDB responde
      if (mounted) {
        setState(() {
          movieCategories = result.categories;
          categoryCounts = result.categoryCounts;
          categoryThumbs = metaThumbs;
          featuredItems = featuredItems; // mantém o que já existe (possivelmente vazio)
          latestItems = latestItems;
          popularItems = [];
          topRatedItems = [];
          movies = (reset || movies.isEmpty) ? result.items : [...movies, ...result.items];
          hasMore = movies.length < result.total;
          loading = false;
          loadingMore = false;
          _applyFilters();
        });
      }

      // Quando TMDB terminar, atualiza os destaques — isso evita mostrar canais como filmes
      tmdbPopularFuture?.then((tmdbPopular) {
        final featured = tmdbPopular.take(5).map((m) => ContentItem(
          title: m.title,
          url: '',
          image: m.posterPath != null ? 'https://image.tmdb.org/t/p/w342${m.posterPath}' : '',
          group: 'TMDB Popular',
          type: 'movie',
          id: m.id.toString(),
          rating: m.rating,
          year: m.releaseDate?.substring(0, 4) ?? '',
          description: m.overview ?? '',
        )).toList();
        if (mounted) setState(() => featuredItems = featured);
      }).catchError((e) { print('❌ TMDB popular falhou: $e'); return Future.value(null); });

      tmdbTopRatedFuture?.then((tmdbTopRated) {
        final latest = tmdbTopRated.take(10).map((m) => ContentItem(
          title: m.title,
          url: '',
          image: m.posterPath != null ? 'https://image.tmdb.org/t/p/w342${m.posterPath}' : '',
          group: 'TMDB TopRated',
          type: 'movie',
          id: m.id.toString(),
          rating: m.rating,
          year: m.releaseDate?.substring(0, 4) ?? '',
          description: m.overview ?? '',
        )).toList();
        if (mounted) setState(() => latestItems = latest);
      }).catchError((e) { print('❌ TMDB toprated falhou: $e'); return Future.value(null); });

      // Enriquecer com dados do TMDB (em background, não bloqueia UI)
      if (reset && movies.isNotEmpty) {
        setState(() => enriching = true);
        final sample = movies.take(200).toList();
        print('🔍 TMDB: Enriquecendo ${sample.length} itens em background...');
        final enriched = await ContentEnricher.enrichItems(sample);
        int enrichedCount = 0;
        for (var i = 0; i < enriched.length && i < movies.length; i++) {
          if (enriched[i].rating > 0 || enriched[i].description.isNotEmpty) {
            movies[i] = enriched[i];
            enrichedCount++;
          }
        }
        print('✅ TMDB: ${enrichedCount} itens enriquecidos com sucesso');
        if (mounted) {
          final sorted = List<ContentItem>.from(latestItems)..sort((a, b) => b.rating.compareTo(a.rating));
          setState(() {
            movies = movies;
            featuredItems = featuredItems;
            latestItems = latestItems;
            popularItems = movies.take(20).toList();
            topRatedItems = sorted.take(20).toList();
            enriching = false;
          });
        }
      }
      
      // Se carregou listas vazias mas temos playlist, tenta um refresh em 5 segundos
      // para pegar os dados do background parse se ele terminar.
      if (movies.isEmpty && hasPlaylist && mounted) {
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && movies.isEmpty) _loadMovies(reset: true);
        });
      }
    } catch (e) {
      print('❌ MoviesLibraryBody: Erro ao carregar categorias: $e');
      if (mounted) {
        setState(() {
          loading = false;
          loadingMore = false;
          hasMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final featuredList = featuredItems;
    final latest = latestItems;

    if (loading && movies.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Destaques em carrossel
          if (featuredItems.isNotEmpty) _HeroBanner(items: featuredItems.take(5).toList(), autofocus: true),
          const SizedBox(height: 24),
          // Header com título e filtros
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Biblioteca de Filmes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Filtros de qualidade
              _QualityFilterChip(label: 'Todos', selected: _qualityFilter == 'all', onTap: () {
                setState(() { _qualityFilter = 'all'; _applyFilters(); });
              }),
              const SizedBox(width: 8),
              _QualityFilterChip(label: '4K', selected: _qualityFilter == '4k', onTap: () {
                setState(() { _qualityFilter = '4k'; _applyFilters(); });
              }),
              const SizedBox(width: 8),
              _QualityFilterChip(label: 'FHD', selected: _qualityFilter == 'fhd', onTap: () {
                setState(() { _qualityFilter = 'fhd'; _applyFilters(); });
              }),
              const SizedBox(width: 8),
              _QualityFilterChip(label: 'HD', selected: _qualityFilter == 'hd', onTap: () {
                setState(() { _qualityFilter = 'hd'; _applyFilters(); });
              }),
            ],
          ),
          const SizedBox(height: 24),
          // Continuar Assistindo (Filmes)
          if (movies.isNotEmpty)
            FutureBuilder<List<WatchingItem>>(
              future: WatchHistoryService.getWatchingItems(limit: 10),
              builder: (context, snapshot) {
                final watching = snapshot.data?.where((w) => w.item.type == 'movie').toList() ?? [];
                if (watching.isEmpty) return const SizedBox.shrink();
                return Column(
                  children: [
                    _WatchingCarousel(items: watching, onRefresh: () => setState(() {})),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),

          // Minha Lista (Filmes)
          ValueListenableBuilder<List<ContentItem>>(
            valueListenable: FavoritesService.favoritesNotifier,
            builder: (context, favorites, _) {
              final movieFavs = favorites.where((f) => f.type == 'movie').toList();
              if (movieFavs.isEmpty) return const SizedBox.shrink();
              return Column(
                children: [
                   _FeaturedCarousel(items: movieFavs, title: 'Minha Lista'),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),

          // Últimos Adicionados (Carousel style)
          if (latest.isNotEmpty) ...[
            _FeaturedCarousel(items: latest, title: 'Últimos Adicionados'),
            const SizedBox(height: 24),
          ],

          const SizedBox(height: 24),
          const Text(
            'Categorias',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          loading
              ? const Center(child: CircularProgressIndicator())
              : filteredCategories.isEmpty
                  ? const Text('Nenhuma categoria encontrada', style: TextStyle(color: Colors.white70))
                  : GridView.count(
                      crossAxisCount: 3,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 3.8,
                      children: filteredCategories.map((cat) {
                        final count = categoryCounts[cat];
                        final thumb = categoryThumbs[cat] ?? '';
                        return _CategoryImageCard(
                          label: cat,
                          info: '',
                          image: thumb,
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/category',
                              arguments: {
                                'categoryName': cat,
                                'type': 'movie',
                              },
                            );
                          },
                        );
                      }).toList(),
                    ),
          if (loadingMore) ...[
            const SizedBox(height: 16),
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(),
              ),
            ),
          ],
          if (!loadingMore && !hasMore && movies.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Center(
              child: Text('Fim da lista', style: TextStyle(color: Colors.white54)),
            ),
          ],
        ],
      ),
    );
  }
}

class SeriesLibraryBody extends StatelessWidget {
  const SeriesLibraryBody({super.key});
  @override
  Widget build(BuildContext context) => const _SeriesBody();
}

class _SeriesBody extends StatefulWidget {
  const _SeriesBody();
  @override
  State<_SeriesBody> createState() => _SeriesBodyState();
}

class _SeriesBodyState extends State<_SeriesBody> {
  List<ContentItem> featured = [];
  List<ContentItem> latest = [];
  List<String> categories = [];
  List<String> filteredCategories = [];
  Map<String, int> counts = {};
  Map<String, String> thumbs = {};
  bool loading = true;
  String _qualityFilter = 'all';

  void _applyFilters() {
    if (_qualityFilter == 'all') {
      filteredCategories = List.from(categories);
    } else {
      filteredCategories = categories.where((cat) {
        final catLower = cat.toLowerCase();
        if (_qualityFilter == '4k') return catLower.contains('4k') || catLower.contains('uhd');
        if (_qualityFilter == 'fhd') return catLower.contains('fhd') || catLower.contains('full');
        if (_qualityFilter == 'hd') return catLower.contains('hd') && !catLower.contains('fhd') && !catLower.contains('uhd');
        return true;
      }).toList();
      if (filteredCategories.isEmpty) filteredCategories = List.from(categories);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // CRÍTICO: Só carrega dados se houver playlist configurada
      // SEM fallback para backend - app deve estar limpo sem playlist
      final hasM3u = Config.playlistRuntime != null && Config.playlistRuntime!.isNotEmpty;
      if (!hasM3u) {
        print('⚠️ SeriesLibraryBody: Sem playlist configurada - retornando listas vazias');
        if (!mounted) return;
        setState(() {
          categories = [];
          counts = {};
          thumbs = {};
          featured = [];
          latest = [];
          loading = false;
          _applyFilters();
        });
        return;
      }

      final meta = await M3uService.fetchCategoryMetaFromEnv(typeFilter: 'series', maxItems: 999999);
      
      // Featured e latest - SEMPRE TMDB (ignora M3U para destaques)
      List<ContentItem> f = [];
      List<ContentItem> l = [];
      
      if (true) { // Sempre carrega do TMDB
        try {
          print('🔍 TMDB: Carregando séries em destaque...');
          final tmdbPopular = await TmdbService.getPopularSeries(page: 1);
          final tmdbTopRated = await TmdbService.getTopRatedSeries(page: 1);
          
          f = tmdbPopular.take(5).map((s) => ContentItem(
            title: s.title,
            url: '',
            image: s.posterPath != null ? 'https://image.tmdb.org/t/p/w342${s.posterPath}' : '',
            group: 'TMDB Popular',
            type: 'series',
            id: s.id.toString(),
            rating: s.rating,
            year: s.releaseDate?.substring(0, 4) ?? '',
            description: s.overview ?? '',
          )).toList();
          
          l = tmdbTopRated.take(10).map((s) => ContentItem(
            title: s.title,
            url: '',
            image: s.posterPath != null ? 'https://image.tmdb.org/t/p/w342${s.posterPath}' : '',
            group: 'TMDB TopRated',
            type: 'series',
            id: s.id.toString(),
            rating: s.rating,
            year: s.releaseDate?.substring(0, 4) ?? '',
            description: s.overview ?? '',
          )).toList();
          
          print('✅ TMDB: ${f.length} séries em destaque + ${l.length} top rated');
        } catch (e) {
          print('❌ Erro ao carregar séries TMDB: $e');
        }
      }
      
      // CRÍTICO: Não enriquece TMDB (já tem dados)
      List<ContentItem> enrichedFeatured = f;
      List<ContentItem> enrichedLatest = l;
      
      if (!mounted) return;
      setState(() {
        categories = meta.categories;
        counts = meta.counts;
        thumbs = meta.thumbs;
        featured = enrichedFeatured;
        latest = enrichedLatest;
        loading = false;
        _applyFilters();
      });

      // Se carregou categorias vazias mas temos playlist, tenta um refresh em 5 segundos
      // para pegar os dados do background parse se ele terminar.
      if (categories.isEmpty && hasM3u && mounted) {
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && categories.isEmpty) _load();
        });
      }
    } catch (e) {
      print('❌ SeriesLibraryBody: Erro ao carregar: $e');
      if (!mounted) return;
      setState(() {
        categories = [];
        counts = {};
        thumbs = {};
        featured = [];
        latest = [];
        loading = false;
        _applyFilters();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (featured.isNotEmpty) _HeroBanner(items: featured.take(5).toList(), autofocus: true),
        const SizedBox(height: 24),
        // Header com título e filtros
        Row(
          children: [
            const Expanded(
              child: Text('Séries', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            ),
            _QualityFilterChip(label: 'Todos', selected: _qualityFilter == 'all', onTap: () {
              setState(() { _qualityFilter = 'all'; _applyFilters(); });
            }),
            const SizedBox(width: 8),
            _QualityFilterChip(label: '4K', selected: _qualityFilter == '4k', onTap: () {
              setState(() { _qualityFilter = '4k'; _applyFilters(); });
            }),
            const SizedBox(width: 8),
            _QualityFilterChip(label: 'FHD', selected: _qualityFilter == 'fhd', onTap: () {
              setState(() { _qualityFilter = 'fhd'; _applyFilters(); });
            }),
            const SizedBox(width: 8),
            _QualityFilterChip(label: 'HD', selected: _qualityFilter == 'hd', onTap: () {
              setState(() { _qualityFilter = 'hd'; _applyFilters(); });
            }),
          ],
        ),
        const SizedBox(height: 16),
        // Continuar Assistindo (Séries)
        if (loading == false)
          FutureBuilder<List<WatchingItem>>(
            future: WatchHistoryService.getWatchingItems(limit: 10),
            builder: (context, snapshot) {
              final watching = snapshot.data?.where((w) => w.item.type == 'series').toList() ?? [];
              if (watching.isEmpty) return const SizedBox.shrink();
              return Column(
                children: [
                  _WatchingCarousel(items: watching, onRefresh: () => setState(() {})),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),

        // Minha Lista (Séries)
        ValueListenableBuilder<List<ContentItem>>(
          valueListenable: FavoritesService.favoritesNotifier,
          builder: (context, favorites, _) {
            final seriesFavs = favorites.where((f) => f.type == 'series').toList();
            if (seriesFavs.isEmpty) return const SizedBox.shrink();
            return Column(
              children: [
                 _FeaturedCarousel(items: seriesFavs, title: 'Minha Lista'),
                const SizedBox(height: 24),
              ],
            );
          },
        ),

        if (latest.isNotEmpty) ...[
          _FeaturedCarousel(items: latest, title: 'Últimas séries adicionadas'),
          const SizedBox(height: 24),
        ],
        const SizedBox(height: 24),
        const Text('Categorias', style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 3.8,
          children: filteredCategories
              .map((cat) => _CategoryImageCard(
                    label: cat,
                    info: '',
                    image: thumbs[cat] ?? '',
                    onTap: () {
                      Navigator.pushNamed(context, '/category', arguments: {'categoryName': cat, 'type': 'series'});
                    },
                  ))
              .toList(),
        ),
      ]),
    );
  }
}

class LiveChannelsBody extends StatelessWidget {
  const LiveChannelsBody({super.key});
  @override
  Widget build(BuildContext context) => const _ChannelsBody();
}

class _ChannelsBody extends StatefulWidget {
  const _ChannelsBody();
  @override
  State<_ChannelsBody> createState() => _ChannelsBodyState();
}

class _ChannelsBodyState extends State<_ChannelsBody> {
  List<ContentItem> featured = [];
  List<ContentItem> latest = [];
  List<String> categories = [];
  List<String> filteredCategories = [];
  Map<String, int> counts = {};
  Map<String, String> thumbs = {};
  bool loading = true;
  String _qualityFilter = 'all';
  
  // EPG data
  bool _epgLoaded = false;
  Map<String, EpgChannel> _epgChannels = {};

  void _applyFilters() {
    if (_qualityFilter == 'all') {
      filteredCategories = List.from(categories);
    } else {
      filteredCategories = categories.where((cat) {
        final catLower = cat.toLowerCase();
        if (_qualityFilter == '4k') return catLower.contains('4k') || catLower.contains('uhd');
        if (_qualityFilter == 'fhd') return catLower.contains('fhd') || catLower.contains('full');
        if (_qualityFilter == 'hd') return catLower.contains('hd') && !catLower.contains('fhd') && !catLower.contains('uhd');
        return true;
      }).toList();
      if (filteredCategories.isEmpty) filteredCategories = List.from(categories);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
    _loadEpg();
  }

  Future<void> _loadEpg() async {
    // Carrega EPG em background
    try {
      if (!EpgService.isLoaded) {
        await EpgService.loadFromCache();
      }
      if (mounted && EpgService.isLoaded) {
        // Mapear canais do EPG por nome para lookup rápido
        final channels = EpgService.getAllChannels();
        final map = <String, EpgChannel>{};
        for (final ch in channels) {
          map[ch.displayName.toLowerCase()] = ch;
        }
        setState(() {
          _epgChannels = map;
          _epgLoaded = true;
        });
      }
    } catch (_) {}
  }


  Future<void> _load() async {
    try {
      // CRÍTICO: Só carrega dados se houver playlist configurada
      // SEM fallback para backend - app deve estar limpo sem playlist
      final hasM3u = Config.playlistRuntime != null && Config.playlistRuntime!.isNotEmpty;
      if (!hasM3u) {
        print('⚠️ LiveChannelsBody: Sem playlist configurada - retornando listas vazias');
        if (!mounted) return;
        setState(() {
          categories = [];
          counts = {};
          thumbs = {};
          featured = [];
          latest = [];
          loading = false;
          _applyFilters();
        });
        return;
      }

      final meta = await M3uService.fetchCategoryMetaFromEnv(typeFilter: 'channel', maxItems: 999999);
      final f = await M3uService.getCuratedFeaturedPrefer('channel', count: 5, pool: 999999, maxItems: 999999);
      final l = await M3uService.getLatestByType('channel', count: 10, maxItems: 999999);
      if (!mounted) return;
      setState(() {
        categories = meta.categories;
        counts = meta.counts;
        thumbs = meta.thumbs;
        featured = f;
        latest = l;
        loading = false;
        _applyFilters();
      });
    } catch (e) {
      print('❌ LiveChannelsBody: Erro ao carregar: $e');
      if (!mounted) return;
      setState(() {
        categories = [];
        counts = {};
        thumbs = {};
        featured = [];
        latest = [];
        loading = false;
        _applyFilters();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (featured.isNotEmpty) _FeaturedCarousel(items: featured, title: 'Canais em destaque', showEpg: true, autofocus: true),
        const SizedBox(height: 24),
        // Header com título e filtros
        Row(
          children: [
            const Expanded(
              child: Text('Canais ao Vivo', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            ),
            // Botão de EPG
            const _EpgButton(),
            const SizedBox(width: 16),
            _QualityFilterChip(label: 'Todos', selected: _qualityFilter == 'all', onTap: () {
              setState(() { _qualityFilter = 'all'; _applyFilters(); });
            }),
            const SizedBox(width: 8),
            _QualityFilterChip(label: '4K', selected: _qualityFilter == '4k', onTap: () {
              setState(() { _qualityFilter = '4k'; _applyFilters(); });
            }),
            const SizedBox(width: 8),
            _QualityFilterChip(label: 'FHD', selected: _qualityFilter == 'fhd', onTap: () {
              setState(() { _qualityFilter = 'fhd'; _applyFilters(); });
            }),
            const SizedBox(width: 8),
            _QualityFilterChip(label: 'HD', selected: _qualityFilter == 'hd', onTap: () {
              setState(() { _qualityFilter = 'hd'; _applyFilters(); });
            }),
          ],
        ),
        const SizedBox(height: 16),
        

        
        const Text('Categorias', style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 3.8,
          children: filteredCategories
              .map((cat) => _CategoryImageCard(
                    label: cat,
                    info: '',
                    image: thumbs[cat] ?? '',
                    onTap: () {
                      Navigator.pushNamed(context, '/category', arguments: {'categoryName': cat, 'type': 'channel'});
                    },
                  ))
              .toList(),
        ),
      ]),
    );
  }
}

/// Card de canal com EPG integrado - mostra programa atual e próximo
class _ChannelWithEpgCard extends StatefulWidget {
  final ContentItem channel;

  const _ChannelWithEpgCard({
    required this.channel,
  });

  @override
  State<_ChannelWithEpgCard> createState() => _ChannelWithEpgCardState();
}

class _ChannelWithEpgCardState extends State<_ChannelWithEpgCard> {
  bool _focused = false;

  bool _loading = false;
  String? _error;

  void _handleTap() async {
    if (widget.channel.url.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      // Simula delay mínimo para mostrar loading
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      setState(() { _loading = false; });
      Navigator.push(
        context, 
        MaterialPageRoute(
          builder: (_) => MediaPlayerScreen(url: widget.channel.url, item: widget.channel),
        ),
      );
    } catch (e) {
      setState(() { _loading = false; _error = 'Erro ao abrir canal'; });
    }
  }

  EpgChannel? _resolveEpgForWidget() {
    final name = widget.channel.title.trim().toLowerCase();
    for (final ch in EpgService.getAllChannels()) {
      final k = ch.displayName.trim().toLowerCase();
      if (k == name || name.contains(k) || k.contains(name)) {
        return ch;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final epgChannel = _resolveEpgForWidget();
    final currentProgram = epgChannel?.currentProgram;
    final nextProgram = epgChannel?.nextProgram;
    final progress = currentProgram?.progress ?? 0.0;
    
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          _handleTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: _handleTap,
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 320,
              decoration: BoxDecoration(
                color: const Color(0xFF161b22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _focused ? AppColors.primary : Colors.white.withOpacity(0.05),
                    width: 1),
                boxShadow: _focused 
                    ? [BoxShadow(color: AppColors.primary.withOpacity(0.5), blurRadius: 20, spreadRadius: 2)] 
                    : [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              transform: _focused ? (Matrix4.identity()..scale(1.05)) : Matrix4.identity(),
              transformAlignment: Alignment.center,
              child: Row(
                children: [
                  // Logo/Imagem do canal
                  Container(
                    width: 80,
                    height: 130,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                    ),
                    child: Stack(
                      children: [
                        // Imagem
                        if (widget.channel.image.isNotEmpty)
                          ClipRRect(
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                            child: CachedNetworkImage(
                              imageUrl: widget.channel.image,
                              width: 80,
                              height: 130,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const Center(
                                child: Icon(Icons.live_tv, color: Colors.white38, size: 32),
                              ),
                            ),
                          )
                        else
                          const Center(child: Icon(Icons.live_tv, color: Colors.white38, size: 32)),
                        
                        // Badge AO VIVO
                        if (currentProgram != null)
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.fiber_manual_record, color: Colors.white, size: 8),
                                  SizedBox(width: 3),
                                  Text('AO VIVO', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Info do canal e programa
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nome do canal
                          Text(
                            widget.channel.title,
                            style: TextStyle(
                              color: _focused ? Colors.white : Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          
                          // Programa atual
                          if (currentProgram != null) ...[
                            Row(
                              children: [
                                const Icon(Icons.play_circle, color: Colors.green, size: 14),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    currentProgram.title,
                                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Barra de progresso
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.white.withOpacity(0.1),
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                                minHeight: 3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            // Horário
                            Text(
                              '${_formatTime(currentProgram.start)} - ${_formatTime(currentProgram.end)}',
                              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9),
                            ),
                          ] else ...[
                            Text(
                              EpgService.epgUrl == null || EpgService.epgUrl!.isEmpty
                                ? 'EPG não configurado'
                                : 'Programação não disponível',
                              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                            ),
                          ],
                          
                          const Spacer(),
                          
                          // Próximo programa
                          if (nextProgram != null) ...[
                            Row(
                              children: [
                                Icon(Icons.schedule, color: Colors.white.withOpacity(0.4), size: 12),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'A seguir: ${nextProgram.title}',
                                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_loading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.4),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
            if (_error != null)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(
                    child: Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class PremiumBody extends StatelessWidget {
  const PremiumBody({super.key});
  @override
  Widget build(BuildContext context) => const _SharkflixBody();
}

class _SharkflixBody extends StatefulWidget {
  const _SharkflixBody();
  @override
  State<_SharkflixBody> createState() => _SharkflixBodyState();
}

class _SharkflixBodyState extends State<_SharkflixBody> {
  List<ContentItem> featured = [];
  List<ContentItem> latest = [];
  // Use a proper model or map for categories to store ID and Type
  List<Map<String, dynamic>> categories = [];
  Map<String, int> counts = {};
  Map<String, String> thumbs = {};
  bool loading = true;
  
  // Jellyfin specific state
  bool jellyfinAuthenticated = false;
  bool jellyfinConfigured = false;

  @override
  void initState() {
    super.initState();
    _checkJellyfinConfig();
  }

  Future<void> _checkJellyfinConfig() async {
    await JellyfinService.initialize();
    if (mounted) {
      setState(() {
        jellyfinConfigured = JellyfinService.isConfigured;
        jellyfinAuthenticated = JellyfinService.isAuthenticated;
      });
      
      if (jellyfinConfigured) {
        _loadFromJellyfin();
      } else {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _loadFromJellyfin() async {
    if (!mounted) return;
    setState(() => loading = true);
    
    // Authenticate if needed
    if (!jellyfinAuthenticated) {
      try {
        final success = await JellyfinService.authenticate().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('⏱️ SharkFlix: Timeout na autenticação Jellyfin');
            return false;
          },
        );
        if (mounted) setState(() => jellyfinAuthenticated = success);
        if (!success) {
          if (mounted) setState(() => loading = false);
          return;
        }
      } catch (e) {
        print('❌ SharkFlix: Erro na autenticação: $e');
        if (mounted) setState(() => loading = false);
        return;
      }
    }

    try {
      // Carrega dados com timeout para evitar travamento
      final results = await Future.wait([
        JellyfinService.getFeaturedItems(count: 4).timeout(const Duration(seconds: 15)), // Reduzido de 6 para 4
        JellyfinService.getLatestItems(count: 6).timeout(const Duration(seconds: 15)), // Reduzido de 20 para 6
        JellyfinService.getLibraries().timeout(const Duration(seconds: 10)),
      ]).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('⏱️ SharkFlix: Timeout ao carregar dados do Jellyfin');
          return [<ContentItem>[], <ContentItem>[], <Map<String, dynamic>>[]];
        },
      );
      
      if (!mounted) return;
      
      final f = results[0] as List<ContentItem>;
      final l = results[1] as List<ContentItem>;
      final libs = results[2] as List<Map<String, dynamic>>;
      
      final catList = <Map<String, dynamic>>[];
      final mapCounts = <String, int>{};
      final mapThumbs = <String, String>{};

      for (final lib in libs) {
        try {
          final name = lib['Name'] as String;
          final id = lib['Id'] as String;
          final type = lib['CollectionType'] ?? 'movies';

          catList.add({
            'name': name,
            'id': id,
            'type': type == 'tvshows' ? 'series' : 'movie',
          });
          
          mapCounts[name] = 0;
        } catch (e) {
          print('⚠️ SharkFlix: Erro ao processar biblioteca: $e');
        }
      }

      if (!mounted) return;
      setState(() {
        featured = f;
        latest = l;
        categories = catList..sort((a,b) => (a['name'] as String).compareTo(b['name'] as String));
        counts = mapCounts;
        thumbs = mapThumbs;
        loading = false;
      });
      
      print('✅ SharkFlix: Dados carregados - ${f.length} destaques, ${l.length} recentes, ${catList.length} bibliotecas');
    } catch (e, stackTrace) {
      print('❌ SharkFlix Jellyfin Error: $e');
      print('Stack: $stackTrace');
      if (mounted) {
        setState(() {
          loading = false;
          // Mantém listas vazias para evitar null errors
          featured = [];
          latest = [];
          categories = [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    
    // Check if configured
    if (!jellyfinConfigured) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.dns, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text('Configure o servidor Jellyfin', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Vá em Settings > Jellyfin Integration', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/settings'),
              child: const Text('Ir para Configurações'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _checkJellyfinConfig,
              child: const Text('Recarregar'),
            ),
          ],
        ),
      );
    }

    // Check auth failure
    if (!jellyfinAuthenticated) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            const Text('Falha na autenticação Jellyfin', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Verifique seu usuário e senha nas configurações', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/settings'),
              child: const Text('Verificar Configurações'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _checkJellyfinConfig,
              child: const Text('Tentar Novamente'),
            ),
          ],
        ),
      );
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('SharkFlix', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            // Removed toggle button
          ],
        ),
        
        const SizedBox(height: 16),
        
        if (featured.isNotEmpty) 
          _FeaturedCarousel(items: featured),
          
        const SizedBox(height: 16),
        
        // Continuar Assistindo (SharkFlix - Jellyfin)
        if (!loading)
          FutureBuilder<List<WatchingItem>>(
            future: WatchHistoryService.getWatchingItems(limit: 10),
            builder: (context, snapshot) {
              // Filtra itens que vieram do Jellyfin (SharkFlix) ou todos? 
              // Vou mostrar todos que forem Filmes/Series para conveniência
              final watching = snapshot.data?.where((w) => w.item.type == 'movie' || w.item.type == 'series').toList() ?? [];
              if (watching.isEmpty) return const SizedBox.shrink();
              return Column(
                children: [
                  _WatchingCarousel(items: watching, onRefresh: () => setState(() {})),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),

        // Minha Lista (SharkFlix - Jellyfin)
        ValueListenableBuilder<List<ContentItem>>(
          valueListenable: FavoritesService.favoritesNotifier,
          builder: (context, favorites, _) {
            if (favorites.isEmpty) return const SizedBox.shrink();
            return Column(
              children: [
                 _FeaturedCarousel(items: favorites, title: 'Minha Lista'),
                const SizedBox(height: 24),
              ],
            );
          },
        ),

        if (latest.isNotEmpty) ...[
          _FeaturedCarousel(items: latest, title: 'Últimos adicionados'),
          const SizedBox(height: 12),
        ]
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('Nenhum conteúdo encontrado.', style: TextStyle(color: Colors.white54)),
          ),
          
        const SizedBox(height: 24),
        const Text('Bibliotecas', style: TextStyle(color: Colors.white70, fontSize: 13)), // Changed from "Coleções"
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 3.8,
          children: categories
              .map((cat) {
                 final name = cat['name'] as String;
                 return _CategoryImageCard(
                    label: name,
                    info: 'Biblioteca',
                    image: thumbs[name] ?? '',
                    onTap: () {
                      Navigator.pushNamed(context, '/category', arguments: {
                        'categoryName': name, 
                        'type': cat['type'] ?? 'movie',
                        'isJellyfin': true, // Always true for SharkFlix
                        'libraryId': cat['id'],
                      });
                    },
                  );
              })
              .toList(),
        ),
      ]),
    );
  }
}

// Carrossel "Continuar assistindo"
class _WatchingCarousel extends StatelessWidget {
  final List<WatchingItem> items;
  final VoidCallback? onRefresh;
  final bool autofocus;
  
  const _WatchingCarousel({required this.items, this.onRefresh, this.autofocus = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.play_circle_outline, color: Colors.white70, size: 20),
                SizedBox(width: 8),
                Text('Continuar assistindo', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
            TextButton(
              onPressed: () {
                // TODO: Ver tudo
              },
              child: const Text('Ver tudo', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final watching = items[index];
              return _WatchingCard(
                watching: watching,
                onRefresh: onRefresh,
                autofocus: autofocus && index == 0,
              );
            },
          ),
        ),
      ],
    );
  }
}

// Carrossel "Últimos assistidos"
class _WatchedCarousel extends StatelessWidget {
  final List<ContentItem> items;
  final bool autofocus;
  
  const _WatchedCarousel({required this.items, this.autofocus = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.history, color: Colors.white70, size: 20),
                SizedBox(width: 8),
                Text('Últimos assistidos', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
            TextButton(
              onPressed: () {
                // TODO: Ver tudo
              },
              child: const Text('Ver tudo', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              // Usando _MovieThumb que já suporta foco (TV)
              return SizedBox(
                width: 110,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _MovieThumb(item: item, autofocus: autofocus && index == 0),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// Carrossel de destaques
class _FeaturedCarousel extends StatelessWidget {
  final List<ContentItem> items;
  final String title;
  final bool showEpg;
  final bool autofocus;
  const _FeaturedCarousel({required this.items, this.title = 'Em destaque hoje', this.showEpg = false, this.autofocus = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            const Icon(Icons.chevron_right, color: Colors.white70, size: 20),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _FeaturedCard(item: item, index: index + 1, showEpg: showEpg, autofocus: autofocus && index == 0);
            },
          ),
        ),
      ],
    );
  }
}

// Card de destaque para filmes, séries e canais (com EPG opcional)
class _FeaturedCard extends StatefulWidget {
  final ContentItem item;
  final int index;
  final bool showEpg;
  final bool autofocus;
  const _FeaturedCard({Key? key, required this.item, required this.index, this.showEpg = false, this.autofocus = false}) : super(key: key);

  @override
  State<_FeaturedCard> createState() => _FeaturedCardState();
}

class _FeaturedCardState extends State<_FeaturedCard> {
  bool _focused = false;

  void _handleTap() {
    if (widget.item.isSeries || widget.item.type == 'series') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => SeriesDetailScreen(item: widget.item)));
      return;
    }
    if (widget.item.type == 'channel') {
      if (widget.item.url.isEmpty) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => MediaPlayerScreen(url: widget.item.url, item: widget.item)));
      return;
    }
    // Filmes: abre tela de detalhes
    Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailScreen(item: widget.item)));
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.item.title;
    final subtitle = widget.item.group.isNotEmpty ? widget.item.group : 'Filme';
    final image = widget.item.image;

    EpgChannel? epg;
    EpgProgram? current;
    if (widget.showEpg && widget.item.type == 'channel') {
      final epgMap = EpgService.getAllChannels().asMap().map((_, c) => MapEntry(c.displayName.trim().toLowerCase(), c));
      final name = widget.item.title.trim().toLowerCase();
      epg = epgMap[name];
      if (epg == null) {
        final matches = epgMap.values.where(
          (c) => name.contains(c.displayName.trim().toLowerCase()) || c.displayName.trim().toLowerCase().contains(name),
        );
        if (matches.isNotEmpty) {
          epg = matches.first;
        }
      }
      if (epg != null) {
        current = epg.currentProgram;
      }
    }

    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (f) {
        setState(() => _focused = f);
        if (f && image.isNotEmpty) {
          topBackgroundNotifier.value = image;
        }
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          _handleTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 280,
          margin: const EdgeInsets.only(right: 12, bottom: 8),
          transform: _focused ? (Matrix4.identity()..translate(0.0, -4.0)..scale(1.05)) : Matrix4.identity(),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: image.isEmpty
                ? const LinearGradient(colors: [Color(0xFF243B55), Color(0xFF141E30)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                : null,
            border: Border.all(
                color: _focused ? AppColors.primary : Colors.transparent, width: 2),
            boxShadow: _focused ? [
              BoxShadow(color: AppColors.primary.withOpacity(0.6), blurRadius: 30, spreadRadius: 4)
            ] : [
              BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image.isNotEmpty)
                AdaptiveCachedImage(
                  url: image,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                color: _focused ? Colors.transparent : Colors.black.withOpacity(0.3),
              ),
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    // CRÍTICO: Mostra qualidade e rating para filmes e séries
                    if (widget.item.type != 'channel')
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: MetaChipsWidget(
                          item: widget.item,
                          fontSize: 10,
                          iconSize: 12,
                        ),
                      ),
                    // CRÍTICO: Para canais, mostra qualidade + EPG compacto
                    if (widget.item.type == 'channel') ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            // Qualidade
                            if (widget.item.quality.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.high_quality, color: Colors.white70, size: 12),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.item.quality.toUpperCase(),
                                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            // EPG compacto ao lado
                            if (widget.showEpg && epg != null && current != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.live_tv, color: Colors.greenAccent, size: 12),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        current.title,
                                        style: const TextStyle(color: Colors.greenAccent, fontSize: 10),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _SeriesThumb extends StatefulWidget {
  final ContentItem item;
  const _SeriesThumb({required this.item});

  @override
  State<_SeriesThumb> createState() => _SeriesThumbState();
}

class _SeriesThumbState extends State<_SeriesThumb> {
  bool _focused = false;

  void _handleTap() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => SeriesDetailScreen(item: widget.item)));
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.item.title;
    final image = widget.item.image;
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          _handleTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: const Color(0xFF161b22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _focused ? AppColors.primary : Colors.transparent, 
                width: 2),
            boxShadow: _focused ? [BoxShadow(color: AppColors.primary.withOpacity(0.5), blurRadius: 20, spreadRadius: 2)] : [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          transform: _focused ? (Matrix4.identity()..translate(0, -4)..scale(1.02)) : Matrix4.identity(),
          transformAlignment: Alignment.center,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 7,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                  child: image.isNotEmpty
                    ? AdaptiveCachedImage(url: image, fit: BoxFit.cover, errorWidget: const Icon(Icons.tv, color: Colors.white38, size: 28))
                    : Container(color: const Color(0xFF0F1620), child: const Center(child: Icon(Icons.tv, color: Colors.white38, size: 28))),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600, height: 1.2)),
                    // CRÍTICO: Mostra qualidade e rating usando MetaChipsWidget
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: MetaChipsWidget(
                        item: widget.item,
                        fontSize: 8,
                        iconSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelThumb extends StatefulWidget {
  final ContentItem item;
  const _ChannelThumb({required this.item});

  @override
  State<_ChannelThumb> createState() => _ChannelThumbState();
}

class _ChannelThumbState extends State<_ChannelThumb> {
  bool _focused = false;

  void _handleTap() {
    if (widget.item.url.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => MediaPlayerScreen(url: widget.item.url, item: widget.item)));
  }

  void _handleLongPress() {
    // Abre o guia de programação do canal
    AppRoutes.goToEpg(context, channel: widget.item);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.item.title;
    final image = widget.item.image;
    return Focus(
      onFocusChange: (f) {
        setState(() => _focused = f);
        if (f && image.isNotEmpty) {
          topBackgroundNotifier.value = image;
        }
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          _handleTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: _handleTap,
        onLongPress: _handleLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: const Color(0xFF161b22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _focused ? AppColors.primary : Colors.transparent, 
                width: 2),
            boxShadow: _focused ? [
                BoxShadow(color: AppColors.primary.withOpacity(0.6), blurRadius: 30, spreadRadius: 4)
            ] : [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          transform: _focused ? (Matrix4.identity()..translate(0.0, -6.0)..scale(1.05)) : Matrix4.identity(),
          transformAlignment: Alignment.center,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 7,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                  child: image.isNotEmpty
                    ? CachedNetworkImage(imageUrl: image, fit: BoxFit.cover, errorWidget: (c,u,e)=>const Icon(Icons.movie, color: Colors.white38, size: 28))
                    : Container(color: const Color(0xFF0F1620), child: const Center(child: Icon(Icons.movie, color: Colors.white38, size: 28))),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600, height: 1.2)),
                    // CRÍTICO: Mostra qualidade e rating usando MetaChipsWidget
                    if (widget.item.type != 'channel')
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: MetaChipsWidget(
                          item: widget.item,
                          fontSize: 8,
                          iconSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MovieThumb extends StatefulWidget {
  final ContentItem item;
  final bool autofocus;
  const _MovieThumb({required this.item, this.autofocus = false});

  @override
  State<_MovieThumb> createState() => _MovieThumbState();
}

class _MovieThumbState extends State<_MovieThumb> {
  bool _focused = false;

  void _handleTap() {
    // Se for série, abre tela de sériesindependente do type ser 'movie' (comum em listas de recém adicionados)
    if (widget.item.isSeries || widget.item.type == 'series') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => SeriesDetailScreen(item: widget.item)));
      return;
    }
    // Filmes: abre tela de detalhes, não player direto
    if (widget.item.type == 'movie') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailScreen(item: widget.item)));
      return;
    }
    if (widget.item.url.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => MediaPlayerScreen(url: widget.item.url, item: widget.item)));
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.item.title;
    final image = widget.item.image;
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (f) {
        setState(() => _focused = f);
        if (f && image.isNotEmpty) {
          topBackgroundNotifier.value = image;
        }
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          _handleTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: const Color(0xFF161b22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _focused ? AppColors.primary : Colors.white.withOpacity(0.05), 
                width: 1),
            boxShadow: _focused ? [
                BoxShadow(color: AppColors.primary.withOpacity(0.6), blurRadius: 30, spreadRadius: 4)
            ] : [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          transform: _focused ? (Matrix4.identity()..translate(0.0, -6.0)..scale(1.05)) : Matrix4.identity(),
          transformAlignment: Alignment.center,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 7,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                  child: image.isNotEmpty
                    ? CachedNetworkImage(imageUrl: image, fit: BoxFit.cover, errorWidget: (c,u,e)=>const Icon(Icons.movie, color: Colors.white38, size: 28))
                    : Container(color: const Color(0xFF0F1620), child: const Center(child: Icon(Icons.movie, color: Colors.white38, size: 28))),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600, height: 1.2)),
                    // CRÍTICO: Mostra qualidade e rating usando MetaChipsWidget
                    if (widget.item.type != 'channel')
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: MetaChipsWidget(
                          item: widget.item,
                          fontSize: 8,
                          iconSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryImageCard extends StatefulWidget {
  final String label;
  final String info;
  final String image;
  final VoidCallback onTap;
  final bool autofocus;

  const _CategoryImageCard({
    required this.label,
    required this.info,
    required this.image,
    required this.onTap,
    this.autofocus = false,
  });

  @override
  State<_CategoryImageCard> createState() => _CategoryImageCardState();
}

class _CategoryImageCardState extends State<_CategoryImageCard> {
  bool _focused = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _focused ? Colors.white.withOpacity(0.16) : const Color(0x33111B2B);
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (f) {
        setState(() => _focused = f);
        if (f) {
          print('📌 Categoria focada: ${widget.label}');
        }
      },
      onKey: (node, event) {
        if (event is RawKeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.space ||
             event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          print('🎯 Abrindo categoria: ${widget.label}');
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: _focused ? (Matrix4.identity()..scale(1.05)) : Matrix4.identity(),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFF161b22),
            border: Border.all(
              color: _focused ? AppColors.primary : Colors.white.withOpacity(0.05),
              width: 1,
            ),
            boxShadow: _focused ? [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ] : [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Stack(
            children: [
              if (widget.image.isNotEmpty)
                Positioned.fill(
                  child: AdaptiveCachedImage(
                    url: widget.image,
                    fit: BoxFit.cover,
                    errorWidget: Container(color: const Color(0x33111B2B)),
                  ),
                ),
              Positioned.fill(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  color: Colors.black.withOpacity(_focused ? 0.0 : 0.45),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        if (widget.info.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.info,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white70, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});
  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

// Widget de botão EPG
class _EpgButton extends StatelessWidget {
  const _EpgButton();
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => AppRoutes.goToEpg(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month, color: Colors.white70, size: 14),
            SizedBox(width: 6),
            Text('Guia TV', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// Widget de filtro de qualidade reutilizável
class _QualityFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  
  const _QualityFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}


// Card para 'Continuar Assistindo' com foco
class _WatchingCard extends StatefulWidget {
  final WatchingItem watching;
  final VoidCallback? onRefresh;
  final bool autofocus;

  const _WatchingCard({required this.watching, this.onRefresh, this.autofocus = false});

  @override
  State<_WatchingCard> createState() => _WatchingCardState();
}

class _WatchingCardState extends State<_WatchingCard> {
  bool _focused = false;

  void _handleTap() {
    final item = widget.watching.item;
    if (item.isSeries) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => SeriesDetailScreen(item: item),
      ));
    } else if (item.type == 'channel') {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => MediaPlayerScreen(url: item.url, item: item),
      )).then((_) => widget.onRefresh?.call());
    } else {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => MovieDetailScreen(item: item),
      )).then((_) => widget.onRefresh?.call());
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.watching.item;
    final progress = widget.watching.progress;
    final remaining = widget.watching.remainingTime;

    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (f) {
        setState(() => _focused = f);
        if (f && item.image.isNotEmpty) {
          topBackgroundNotifier.value = item.image;
        }
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          _handleTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 200,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: _focused ? Border.all(color: AppColors.primary, width: 2) : null,
            boxShadow: _focused ? [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 12)] : null,
          ),
          transform: _focused ? (Matrix4.identity()..scale(1.05)) : Matrix4.identity(),
          transformAlignment: Alignment.center,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: item.image,
                        fit: BoxFit.cover,
                        placeholder: (c, u) => Container(color: const Color(0xFF333333)),
                        errorWidget: (c, u, e) => Container(
                          color: const Color(0xFF333333),
                          child: const Icon(Icons.movie, color: Colors.white30, size: 40),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                        ),
                      ),
                    ),
                    const Center(
                      child: Icon(Icons.play_circle_filled, color: Colors.white, size: 40),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                          minHeight: 4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      remaining,
                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================
// HERO BANNER WIDGET
// =====================

class _HeroBanner extends StatefulWidget {
  final List<ContentItem> items;
  final bool autofocus;
  const _HeroBanner({required this.items, this.autofocus = false});

  @override
  State<_HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<_HeroBanner> {
  int _currentIndex = 0;
  bool _focused = false;

  void _handleTap() {
    final item = widget.items[_currentIndex];
    if (item.type == 'movie') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailScreen(item: item)));
    } else if (item.type == 'series') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => SeriesDetailScreen(item: item)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final item = widget.items[_currentIndex];
    final image = item.image;

    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (f) {
        setState(() => _focused = f);
        if (f && image.isNotEmpty) {
          topBackgroundNotifier.value = image;
        }
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          _handleTap();
          return KeyEventResult.handled;
        }
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowRight) {
             setState(() => _currentIndex = (_currentIndex + 1) % widget.items.length);
             return KeyEventResult.handled;
        }
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
             setState(() => _currentIndex = (_currentIndex - 1 + widget.items.length) % widget.items.length);
             return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 350,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: _focused ? Border.all(color: AppColors.primary, width: 2) : Border.all(color: Colors.white.withOpacity(0.05), width: 1),
            boxShadow: _focused ? [BoxShadow(color: AppColors.primary.withOpacity(0.5), blurRadius: 20, spreadRadius: 2)] : [
                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10))
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Hero Image
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: image.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: image,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      )
                    : Container(color: const Color(0xFF161b22)),
              ),
              // Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      const Color(0xFF111318),
                      const Color(0xFF111318).withOpacity(0.8),
                      const Color(0xFF111318).withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              // Content
              Positioned(
                bottom: 24,
                left: 32,
                right: 32,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge 
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.2),
                        border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('EM DESTAQUE', style: TextStyle(color: AppColors.primaryLight, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (item.rating > 0.0) ...[
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text('${item.rating} ', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                        if (item.year.isNotEmpty) ...[
                          const Text(' • ', style: TextStyle(color: Colors.white54)),
                          Text(item.year, style: const TextStyle(color: Colors.white70)),
                        ],
                        const Text(' • ', style: TextStyle(color: Colors.white54)),
                        Text(item.type == 'movie' ? 'Filme' : 'Série', style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _handleTap,
                          icon: const Icon(Icons.play_arrow, color: Colors.white),
                          label: const Text('Assistir Agora', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Dots indicators
                        Row(
                           children: List.generate(widget.items.length, (index) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: _currentIndex == index ? 24 : 8,
                              height: 6,
                              decoration: BoxDecoration(
                                 color: _currentIndex == index ? AppColors.primary : Colors.white24,
                                 borderRadius: BorderRadius.circular(8)
                              ),
                           )),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
