import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/content_item.dart';
import '../data/m3u_service.dart';
import '../data/tmdb_service.dart';
import '../core/theme/app_colors.dart';
import '../widgets/app_sidebar.dart';
import 'home_screen.dart' show topBackgroundNotifier;
import 'detail_screens.dart' hide SeriesDetailScreen; 
import 'series_detail_screen.dart';
import 'movie_detail_screen.dart';
import 'dart:ui';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _placeholderFocus = FocusNode();
  final FocusNode _searchFocus = FocusNode();
  
  List<ContentItem> _rawResults = [];
  List<ContentItem> _results = [];
  bool _loading = false;
  String _lastQuery = '';
  String _typeFilter = 'all'; // all, movie, series, channel
  bool _isInputActive = false;

  @override
  void initState() {
    super.initState();
    // Inicia com o foco no placeholder (TV friendly)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _placeholderFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _placeholderFocus.dispose();
    // Limpar o background ao sair para evitar que a tela anterior fique "suja"
    WidgetsBinding.instance.addPostFrameCallback((_) {
      topBackgroundNotifier.value = null;
    });
    super.dispose();
  }

  void _activateInput() {
    setState(() {
      _isInputActive = true;
    });
    Future.delayed(const Duration(milliseconds: 50), () {
      _searchFocus.requestFocus();
    });
  }

  void _deactivateInput() {
    setState(() {
      _isInputActive = false;
    });
    _placeholderFocus.requestFocus();
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _rawResults = [];
        _results = [];
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _lastQuery = query;
    });

    try {
      final results = await M3uService.searchAllContent(query);
      if (mounted) {
        setState(() {
          _rawResults = results;
          _results = _applyFilters(results);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  List<ContentItem> _applyFilters(List<ContentItem> items) {
    return items.where((item) {
      if (_typeFilter == 'all') return true;
      if (_typeFilter == 'movie' && item.type == 'movie') return true;
      if (_typeFilter == 'series' && item.type == 'series') return true;
      if (_typeFilter == 'channel' && item.type == 'channel') return true;
      return false;
    }).toList();
  }

  void _updateFilters() {
    if (_rawResults.isNotEmpty) {
      setState(() {
        _results = _applyFilters(_rawResults);
      });
    } else if (_lastQuery.isNotEmpty) {
      _performSearch(_lastQuery);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // DYNAMIC BACKGROUND LAYER
          Positioned.fill(
            child: ValueListenableBuilder<String?>(
              valueListenable: topBackgroundNotifier,
              builder: (context, imageUrl, _) {
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
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
                              color: AppColors.backgroundDark.withOpacity(0.75),
                            ),
                          ),
                        )
                      : Container(
                          key: const ValueKey('empty_bg'),
                          color: AppColors.backgroundDark,
                        ),
                );
              },
            ),
          ),
          
          // MAIN CONTENT WITH SIDEBAR
          PopScope(
            canPop: !_isInputActive,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              if (_isInputActive) {
                _deactivateInput();
              }
            },
            child: Row(
              children: [
                const AppSidebar(selectedIndex: -1),
                Expanded(
                  child: Column(
                    children: [
                      // Header com busca
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: const BoxDecoration(
                          color: Color(0x990F1620),
                          border: Border(bottom: BorderSide(color: Color(0x334B5563))),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                                  onPressed: () => Navigator.pop(context),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildSearchField(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Filtros
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _FilterChip(
                                    label: 'Todos',
                                    selected: _typeFilter == 'all',
                                    onTap: () {
                                      setState(() => _typeFilter = 'all');
                                      _updateFilters();
                                    },
                                  ),
                                  _FilterChip(
                                    label: 'Filmes',
                                    selected: _typeFilter == 'movie',
                                    onTap: () {
                                      setState(() => _typeFilter = 'movie');
                                      _updateFilters();
                                    },
                                  ),
                                  _FilterChip(
                                    label: 'Séries',
                                    selected: _typeFilter == 'series',
                                    onTap: () {
                                      setState(() => _typeFilter = 'series');
                                      _updateFilters();
                                    },
                                  ),
                                  _FilterChip(
                                    label: 'Canais',
                                    selected: _typeFilter == 'channel',
                                    onTap: () {
                                      setState(() => _typeFilter = 'channel');
                                      _updateFilters();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // RESULTADOS
                      Expanded(
                        child: _loading
                            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                            : _results.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _lastQuery.isEmpty ? Icons.search : Icons.search_off,
                                          color: Colors.white30,
                                          size: 64,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          _lastQuery.isEmpty 
                                              ? 'Busque por filmes, séries ou canais' 
                                              : 'Nenhum resultado encontrado para "$_lastQuery"',
                                          style: const TextStyle(color: Colors.white54, fontSize: 18),
                                        ),
                                      ],
                                    ),
                                  )
                                : GridView.builder(
                                    padding: const EdgeInsets.all(24),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 6,
                                      childAspectRatio: 0.67,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 24,
                                    ),
                                    itemCount: _results.length,
                                    itemBuilder: (context, index) {
                                      final item = _results[index];
                                      return _SearchResultCard(
                                        item: item,
                                        onTap: () => _openDetails(item),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    if (!_isInputActive) {
      return Focus(
        focusNode: _placeholderFocus,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && 
              (event.logicalKey == LogicalKeyboardKey.select || 
               event.logicalKey == LogicalKeyboardKey.enter)) {
            _activateInput();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: _activateInput,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _placeholderFocus.hasFocus ? AppColors.primary : Colors.white10,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.white60),
                const SizedBox(width: 12),
                Text(
                  _lastQuery.isEmpty ? 'Pesquisar...' : _lastQuery,
                  style: const TextStyle(color: Colors.white60, fontSize: 16),
                ),
                if (_placeholderFocus.hasFocus) ...[
                  const Spacer(),
                  const _BlinkingCursorPlaceholder(),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          _deactivateInput();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: TextField(
        focusNode: _searchFocus,
        controller: _searchController,
        autofocus: true,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Digite aqui...',
          hintStyle: const TextStyle(color: Colors.white30),
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          suffixIcon: IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () {
              _searchController.clear();
              _performSearch('');
            },
          ),
        ),
        onChanged: (val) => _performSearch(val),
        onSubmitted: (val) => _deactivateInput(),
      ),
    );
  }

  void _openDetails(ContentItem item) async {
    // Ao abrir detalhes, podemos setar o background
    if (item.image.isNotEmpty) {
      topBackgroundNotifier.value = item.image;
    }

    if (item.type == 'movie') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MovieDetailScreen(item: item)),
      );
    } else if (item.type == 'series') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SeriesDetailScreen(item: item)),
      );
    } else {
      // Stream de TV (futuro: abrir player diretamente ou info)
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter)) {
            onTap();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Builder(
          builder: (context) {
            final hasFocus = Focus.of(context).hasFocus;
            return GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : (hasFocus ? Colors.white10 : Colors.white.withOpacity(0.05)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: hasFocus ? Colors.white54 : (selected ? AppColors.primary : Colors.transparent),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected || hasFocus ? Colors.white : Colors.white60,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SearchResultCard extends StatefulWidget {
  final ContentItem item;
  final VoidCallback onTap;

  const _SearchResultCard({required this.item, required this.onTap});

  @override
  State<_SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<_SearchResultCard> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          topBackgroundNotifier.value = widget.item.image;
        }
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final hasFocus = _focusNode.hasFocus;
            return AnimatedScale(
              scale: hasFocus ? 1.05 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: hasFocus ? AppColors.primary : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: hasFocus ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 12,
                            spreadRadius: 2,
                          )
                        ] : [],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: CachedNetworkImage(
                          imageUrl: widget.item.image,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          placeholder: (context, url) => Container(color: Colors.white.withOpacity(0.05)),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.white10,
                            child: const Icon(Icons.movie, color: Colors.white24),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hasFocus ? Colors.white : Colors.white70,
                      fontWeight: hasFocus ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BlinkingCursorPlaceholder extends StatefulWidget {
  const _BlinkingCursorPlaceholder();

  @override
  State<_BlinkingCursorPlaceholder> createState() => _BlinkingCursorPlaceholderState();
}

class _BlinkingCursorPlaceholderState extends State<_BlinkingCursorPlaceholder> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _controller, child: Container(width: 2, height: 20, color: AppColors.primary));
  }
}
