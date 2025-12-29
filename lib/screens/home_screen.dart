import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'detail_screens.dart';
import 'series_detail_screen.dart' as sdetail;
import 'movie_detail_screen.dart';
import 'search_screen.dart';
import '../data/watch_history_service.dart';
import '../data/m3u_service.dart';
import '../data/epg_service.dart';
import '../data/tmdb_service.dart';
import '../utils/content_enricher.dart';
import '../core/config.dart';
import '../core/theme/app_colors.dart';
import '../models/content_item.dart';
import '../models/epg_program.dart';

import '../widgets/media_player_screen.dart';
import '../widgets/adaptive_cached_image.dart';
import '../widgets/meta_chips_widget.dart';
import '../routes/app_routes.dart';

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



  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF111318);  // --bg-dark
    const bg2 = Color(0xFF0F1620); // --bg-darker

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: const BoxDecoration(
                color: bg2,
                border: Border(
                  bottom: BorderSide(color: Color(0x334B5563)),
                ),
              ),
              child: Row(
                children: [
                  // Logo + título
                  GestureDetector(
                    onTap: () => setState(() => _selectedIndex = 0),
                    child: const Row(
                      children: [
                        _AppLogo(),
                        SizedBox(width: 8),
                        Text(
                          'Click Channel',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),

                  // NAV
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _NavItem(
                            label: 'Início',
                            selected: _selectedIndex == 0,
                            onTap: () => setState(() => _selectedIndex = 0),
                            autofocus: true,
                          ),
                          _NavItem(
                            label: 'Filmes',
                            selected: _selectedIndex == 1,
                            onTap: () => setState(() => _selectedIndex = 1),
                          ),
                          _NavItem(
                            label: 'Séries',
                            selected: _selectedIndex == 2,
                            onTap: () => setState(() => _selectedIndex = 2),
                          ),
                          _NavItem(
                            label: 'Canais',
                            selected: _selectedIndex == 3,
                            onTap: () => setState(() => _selectedIndex = 3),
                          ),
                          _NavItem(
                            label: 'SharkFlix',
                            selected: _selectedIndex == 4,
                            onTap: () => setState(() => _selectedIndex = 4),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),
                  // Search - com Focus para Fire TV
                  _SearchButton(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const SearchScreen(),
                      ));
                    },
                  ),
                  const SizedBox(width: 12),
                  const _ProfileMenu(),
                ],
              ),
            ),

            // CONTEÚDO POR ABA
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: const [
                  _HomeBody(),
                  MoviesLibraryBody(),
                  SeriesLibraryBody(),
                  LiveChannelsBody(),
                  PremiumBody(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool autofocus;

  const _NavItem({
    required this.label,
    required this.selected,
    required this.onTap,
    this.autofocus = false,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFE11D48);
    final active = widget.selected || _focused;

    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (f) {
        setState(() => _focused = f);
        if (f) print('📍 Nav focado: ${widget.label}');
      },
      onKey: (node, event) {
        if (event is RawKeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          print('🎯 Nav selecionado: ${widget.label}');
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: InkWell(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: _focused ? Colors.white.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border(
              bottom: BorderSide(
                color: widget.selected ? primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: active ? Colors.white : Colors.white70,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão de busca com suporte a Focus para Fire TV
class _SearchButton extends StatefulWidget {
  final VoidCallback onTap;
  const _SearchButton({required this.onTap});

  @override
  State<_SearchButton> createState() => _SearchButtonState();
}

class _SearchButtonState extends State<_SearchButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
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
          width: 200,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _focused ? Colors.white.withOpacity(0.15) : Colors.white10,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _focused ? AppColors.primary : const Color(0x334B5563),
              width: _focused ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: _focused ? Colors.white : Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                'Buscar filmes, séries...',
                style: TextStyle(
                  color: _focused ? Colors.white : Colors.white54, 
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Botão de Configurações (engrenagem)
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white70),
          onPressed: () {
            Navigator.pushNamed(context, '/settings');
          },
        ),
        const SizedBox(width: 4),
        // Botão de Perfil (pessoa)
        GestureDetector(
          onTap: () {
            Navigator.pushNamed(context, '/profile');
          },
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.white.withOpacity(0.1),
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
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
                colors: [Color(0xFFE11D48), Color(0xFFEC4C63)],
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
  const _HomeBody();
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Carregar histórico
      final watched = await WatchHistoryService.getWatchedItems(limit: 15);
      final watching = await WatchHistoryService.getWatchingItems(limit: 15);
      
      if (mounted) {
        setState(() {
          watchedItems = watched;
          watchingItems = watching;
        });
      }
      
      // CRÍTICO: Carrega destaques TMDB (Popular Movies/Series) + Canais M3U se houver playlist
      // Destaques TMDB não dependem de playlist, sempre disponíveis se TMDB configurado
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
          } catch (_) {
            if (!mounted) return;
            setState(() {
              featuredMovies = [];
              featuredSeries = [];
              featuredChannels = [];
              loading = false;
            });
          }
        } else {
          if (!mounted) return;
          setState(() {
            featuredMovies = [];
            featuredSeries = [];
            featuredChannels = [];
            loading = false;
          });
        }
      }
    } catch (_) {
      if (!mounted) return;
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
          
          // Destaques
          if (loading) const Center(child: CircularProgressIndicator()),
          
          // Filmes em destaque
          if (!loading && featuredMovies.isNotEmpty) ...[
            _FeaturedCarousel(items: featuredMovies, title: 'Filmes em destaque'),
            const SizedBox(height: 20),
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
          if (featuredList.isNotEmpty)
            _FeaturedCarousel(items: featuredList, title: 'Filmes em destaque'),
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
          // Últimos Adicionados
          if (latest.isNotEmpty) ...[
            const _SectionTitle(title: 'Últimos Adicionados'),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: latest.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) => SizedBox(
                  width: 120,
                  child: _MovieThumb(item: latest[index]),
                ),
              ),
            ),
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
                          info: count != null ? '$count títulos' : 'Categoria',
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

      final meta = await M3uService.fetchCategoryMetaFromEnv(typeFilter: 'series', maxItems: 400);
      
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
        if (featured.isNotEmpty) _FeaturedCarousel(items: featured, title: 'Séries em destaque'),
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
        if (latest.isNotEmpty) ...[
          const _SectionTitle(title: 'Últimas séries adicionadas'),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: latest.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => SizedBox(width: 120, child: _SeriesThumb(item: latest[i])),
            ),
          ),
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
                    info: '${counts[cat] ?? 0} títulos',
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

      final meta = await M3uService.fetchCategoryMetaFromEnv(typeFilter: 'channel', maxItems: 400);
      final f = await M3uService.getCuratedFeaturedPrefer('channel', count: 5, pool: 20, maxItems: 400);
      final l = await M3uService.getLatestByType('channel', count: 10, maxItems: 400);
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
        if (featured.isNotEmpty) _FeaturedCarousel(items: featured, title: 'Canais em destaque', showEpg: true),
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
                    info: '${counts[cat] ?? 0} canais',
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
                color: const Color(0xFF1A1F2E),
                borderRadius: BorderRadius.circular(12),
                border: _focused 
                    ? Border.all(color: AppColors.primary, width: 2) 
                    : Border.all(color: Colors.white.withOpacity(0.1)),
                boxShadow: _focused 
                    ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12)] 
                    : null,
              ),
              transform: _focused ? (Matrix4.identity()..scale(1.02)) : Matrix4.identity(),
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
  List<String> categories = [];
  Map<String, int> counts = {};
  Map<String, String> thumbs = {};
  bool loading = true;

  bool _isShark(ContentItem it) {
    final g = it.group.toLowerCase();
    final t = it.title.toLowerCase();
    return g.contains('shark') || g.contains('sharkflix') || t.contains('sharkflix');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Use movies cache as base and filter by group
      final latestMovies = await M3uService.getLatestByType('movie', count: 100, maxItems: 600);
      final shark = latestMovies.where(_isShark).toList();
      final f = shark.take(6).toList();
      final l = shark.skip(6).take(20).toList();
      // Categories for shark subset
      final setCats = <String>{};
      final mapCounts = <String, int>{};
      final mapThumbs = <String, String>{};
      for (final it in shark) {
        setCats.add(it.group);
        mapCounts[it.group] = (mapCounts[it.group] ?? 0) + 1;
        mapThumbs.putIfAbsent(it.group, () => it.image);
      }
      if (!mounted) return;
      setState(() {
        featured = f;
        latest = l;
        categories = setCats.toList()..sort((a,b)=>a.toLowerCase().compareTo(b.toLowerCase()));
        counts = mapCounts;
        thumbs = mapThumbs;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('SharkFlix', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (featured.isNotEmpty) _FeaturedCarousel(items: featured),
        const SizedBox(height: 16),
        const _SectionTitle(title: 'Últimos adicionados'),
        const SizedBox(height: 12),
        if (latest.isNotEmpty)
          SizedBox(
            height: 250,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: latest.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) => SizedBox(width: 150, child: _MovieThumb(item: latest[i])),
            ),
          ),
        const SizedBox(height: 24),
        const Text('Coleções', style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 3.8,
          children: categories
              .map((cat) => _CategoryImageCard(
                    label: cat,
                    info: '${counts[cat] ?? 0} títulos',
                    image: thumbs[cat] ?? '',
                    onTap: () {
                      Navigator.pushNamed(context, '/category', arguments: {'categoryName': cat, 'type': 'movie'});
                    },
                  ))
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
  
  const _WatchingCarousel({required this.items, this.onRefresh});

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
              final item = watching.item;
              return GestureDetector(
                onTap: () {
                  if (item.isSeries) {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => sdetail.SeriesDetailScreen(item: item),
                    ));
                  } else if (item.type == 'channel') {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => MediaPlayerScreen(url: item.url, item: item),
                    )).then((_) => onRefresh?.call());
                  } else {
                    // Filmes: abre tela de detalhes
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => MovieDetailScreen(item: item),
                    )).then((_) => onRefresh?.call());
                  }
                },
                child: Container(
                  width: 200,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                            // Overlay escuro
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
                            // Botão play
                            const Center(
                              child: Icon(Icons.play_circle_filled, color: Colors.white, size: 40),
                            ),
                            // Barra de progresso
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
                                  value: watching.progress,
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
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        watching.remainingTime,
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                    ],
                  ),
                ),
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
  
  const _WatchedCarousel({required this.items});

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
              return GestureDetector(
                onTap: () {
                  if (item.isSeries) {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => sdetail.SeriesDetailScreen(item: item),
                    ));
                  } else {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => MediaPlayerScreen(url: item.url, item: item),
                    ));
                  }
                },
                child: Container(
                  width: 110,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: item.image,
                            fit: BoxFit.cover,
                            width: 110,
                            placeholder: (c, u) => Container(color: const Color(0xFF333333)),
                            errorWidget: (c, u, e) => Container(
                              color: const Color(0xFF333333),
                              child: const Icon(Icons.movie, color: Colors.white30, size: 32),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
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
  const _FeaturedCarousel({required this.items, this.title = 'Em destaque hoje', this.showEpg = false});

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
              return _FeaturedCard(item: item, index: index + 1, showEpg: showEpg);
            },
          ),
        ),
      ],
    );
  }
}

// Card de destaque para filmes, séries e canais (com EPG opcional)
class _FeaturedCard extends StatelessWidget {
  final ContentItem item;
  final int index;
  final bool showEpg;
  const _FeaturedCard({Key? key, required this.item, required this.index, this.showEpg = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final title = item.title;
    final subtitle = item.group.isNotEmpty ? item.group : 'Filme';
    final image = item.image;

    EpgChannel? epg;
    EpgProgram? current;
    if (showEpg && item.type == 'channel') {
      final epgMap = EpgService.getAllChannels().asMap().map((_, c) => MapEntry(c.displayName.trim().toLowerCase(), c));
      final name = item.title.trim().toLowerCase();
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

    return InkWell(
      onTap: () {
        if (item.isSeries || item.type == 'series') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => sdetail.SeriesDetailScreen(item: item)));
          return;
        }
        if (item.type == 'channel') {
          if (item.url.isEmpty) return;
          Navigator.push(context, MaterialPageRoute(builder: (_) => MediaPlayerScreen(url: item.url, item: item)));
          return;
        }
        // Filmes: abre tela de detalhes
        Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailScreen(item: item)));
      },
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: image.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(image),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.3), BlendMode.darken),
                )
              : null,
          gradient: image.isEmpty
              ? const LinearGradient(colors: [Color(0xFF243B55), Color(0xFF141E30)], begin: Alignment.topLeft, end: Alignment.bottomRight)
              : null,
          border: Border.all(color: Colors.white12),
        ),
        child: Stack(
          children: [
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
                  if (item.type != 'channel')
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: MetaChipsWidget(
                        item: item,
                        fontSize: 10,
                        iconSize: 12,
                      ),
                    ),
                  // CRÍTICO: Para canais, mostra qualidade + EPG compacto
                  if (item.type == 'channel') ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          // Qualidade
                          if (item.quality.isNotEmpty)
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
                                    item.quality.toUpperCase(),
                                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          // EPG compacto ao lado
                          if (showEpg && epg != null && current != null) ...[
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
    Navigator.push(context, MaterialPageRoute(builder: (_) => sdetail.SeriesDetailScreen(item: widget.item)));
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
            color: const Color(0xFF1A1A1A),
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
                flex: 7,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
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
        onLongPress: _handleLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
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
                flex: 7,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  child: image.isNotEmpty
                    ? CachedNetworkImage(imageUrl: image, fit: BoxFit.cover, errorWidget: (c,u,e)=>const Icon(Icons.live_tv, color: Colors.white38, size: 28))
                    : Container(color: const Color(0xFF0F1620), child: const Center(child: Icon(Icons.live_tv, color: Colors.white38, size: 28))),
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
  const _MovieThumb({required this.item});

  @override
  State<_MovieThumb> createState() => _MovieThumbState();
}

class _MovieThumbState extends State<_MovieThumb> {
  bool _focused = false;

  void _handleTap() {
    // Filmes: abre tela de detalhes, não player direto
    if (widget.item.type == 'movie' && !widget.item.isSeries) {
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
            color: const Color(0xFF1A1A1A),
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
                flex: 7,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
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

  const _CategoryImageCard({
    required this.label,
    required this.info,
    required this.image,
    required this.onTap,
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
          duration: const Duration(milliseconds: 160),
          transform: _focused ? (Matrix4.identity()..scale(1.05)) : Matrix4.identity(),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: activeColor,
            border: Border.all(
              color: _focused ? Colors.amber : const Color(0x334B5563),
              width: _focused ? 3 : 1,
            ),
            boxShadow: _focused ? [
              BoxShadow(
                color: Colors.amber.withOpacity(0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ] : [],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Stack(
            children: [
              if (widget.image.isNotEmpty)
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: widget.image,
                    fit: BoxFit.cover,
                    placeholder: (c,u)=>Container(color: const Color(0x33111B2B)),
                    errorWidget: (c,u,e)=>Container(color: const Color(0x33111B2B)),
                  ),
                ),
              Positioned.fill(child: Container(color: Colors.black.withOpacity(0.45))),
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
                        const SizedBox(height: 4),
                        Text(
                          widget.info,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
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


// Card de destaque para filmes, séries e canais (com EPG opcional)
