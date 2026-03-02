import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';
import '../models/content_item.dart';
import '../data/m3u_service.dart';
import '../widgets/blinking_cursor_placeholder.dart';
import '../widgets/media_player_screen.dart';
import '../widgets/app_sidebar.dart';
import 'series_detail_screen.dart';
import 'movie_detail_screen.dart';
import 'home_screen.dart' show topBackgroundNotifier;

class SearchScreen extends StatefulWidget {
  final String? initialQuery;
  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final FocusNode _placeholderFocus = FocusNode(); // Foco para o estado de navegação
  
  List<ContentItem> _rawResults = []; 
  List<ContentItem> _results = [];    
  bool _loading = false;
  String _lastQuery = '';
  Timer? _debounce;
  
  // Controle de ativação do teclado
  bool _isInputActive = false; 
  bool _isPlaceholderFocused = false;
  
  // Filtros
  String _typeFilter = 'all'; 

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _performSearch(widget.initialQuery!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _placeholderFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _placeholderFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    if (query.length < 2) {
      if (_results.isNotEmpty) {
        setState(() {
          _rawResults = [];
          _results = [];
          _loading = false;
          _lastQuery = '';
        });
      }
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 800), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _loading = true;
      _lastQuery = query;
    });

    try {
      final allItems = await M3uService.searchAllContent(query, maxResults: 300);
      
      if (mounted) {
        setState(() {
          _rawResults = allItems;
          _results = _applyFilters(allItems);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _rawResults = [];
          _results = [];
          _loading = false;
        });
      }
    }
  }

  List<ContentItem> _applyFilters(List<ContentItem> items) {
    return items.where((item) {
      if (_typeFilter != 'all') {
        if (_typeFilter == 'movie' && item.type != 'movie') return false;
        if (_typeFilter == 'series' && !item.isSeries && item.type != 'series') return false;
        if (_typeFilter == 'channel' && item.type != 'channel') return false;
      }
      return true;
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
                  duration: const Duration(milliseconds: 600),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Container(
                          key: ValueKey(imageUrl),
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: NetworkImage(imageUrl),
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
                          key: const ValueKey('default_bg'),
                          color: AppColors.backgroundDark,
                        ),
                );
              },
            ),
          ),
          Row(
            children: [
              const AppSidebar(selectedIndex: -1),
              Expanded(
                child: Column(
                  children: [
                    // Header com busca
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F1620),
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
                                            ? 'Digite para buscar'
                                            : 'Nenhum resultado para "$_lastQuery"',
                                        style: const TextStyle(color: Colors.white54, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text(
                                        '${_results.length} resultados encontrados',
                                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                                      ),
                                    ),
                                    Expanded(
                                      child: GridView.builder(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 6,
                                          childAspectRatio: 0.55,
                                          crossAxisSpacing: 12,
                                          mainAxisSpacing: 12,
                                        ),
                                        itemCount: _results.length,
                                        itemBuilder: (context, index) {
                                          final item = _results[index];
                                          return _SearchResultCard(
                                            item: item,
                                            onTap: () {
                                              if (item.isSeries) {
                                                Navigator.push(context, MaterialPageRoute(
                                                  builder: (_) => SeriesDetailScreen(item: item),
                                                ));
                                              } else if (item.type == 'movie') {
                                                Navigator.push(context, MaterialPageRoute(
                                                  builder: (_) => MovieDetailScreen(item: item),
                                                ));
                                              } else {
                                                Navigator.push(context, MaterialPageRoute(
                                                  builder: (_) => MediaPlayerScreen(url: item.url, item: item),
                                                ));
                                              }
                                            },
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
        ],
      ),
    );
  }

  // CAMPO DE BUSCA FINAL (V23)
  // Usa BlinkingCursorPlaceholder para navegação (zero gatilho de teclado OS)
  // Swapa para TextField real apenas quando ativado.
  Widget _buildSearchField() {
    if (_isInputActive) {
      return Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
            _deactivateInput();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Digite para buscar...',
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.white.withOpacity(0.2),
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
            prefixIcon: const Icon(Icons.keyboard, color: AppColors.primary),
            suffixIcon: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: _deactivateInput,
            ),
          ),
          onChanged: _onSearchChanged,
          onSubmitted: (val) {
            if (_debounce?.isActive ?? false) _debounce!.cancel();
            _performSearch(val);
            _deactivateInput();
          },
        ),
      );
    }

    return Focus(
      focusNode: _placeholderFocus,
      onFocusChange: (f) {
        setState(() => _isPlaceholderFocused = f);
        if (f) SystemChannels.textInput.invokeMethod('TextInput.hide');
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            FocusScope.of(context).nextFocus();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            FocusScope.of(context).previousFocus();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            FocusScope.of(context).previousFocus();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            FocusScope.of(context).nextFocus();
            return KeyEventResult.handled;
          }

          // Ativação por Enter ou Tecla de Caractere
          final isChar = event.logicalKey.keyLabel.length == 1 && _isAlphanumeric(event.logicalKey.keyLabel);
          if (event.logicalKey == LogicalKeyboardKey.enter || 
              event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.gameButtonA || 
              isChar) {
            _activateInput();
            return isChar ? KeyEventResult.ignored : KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: _activateInput,
        child: BlinkingCursorPlaceholder(
          text: _searchController.text,
          hintText: _isPlaceholderFocused && _searchController.text.isEmpty 
              ? 'Pressione OK para buscar' 
              : 'Buscar filmes, séries...',
          isFocused: _isPlaceholderFocused,
          onActivate: _activateInput,
          prefixIcon: Icons.search,
        ),
      ),
    );
  }

  bool _isAlphanumeric(String s) {
    return RegExp(r'^[a-zA-Z0-9]$').hasMatch(s);
  }

  void _activateInput() {
    setState(() => _isInputActive = true);
    // Delay para garantir construção e foco
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        _searchFocus.requestFocus();
        SystemChannels.textInput.invokeMethod('TextInput.show');
      }
    });
  }

  void _deactivateInput() {
    setState(() => _isInputActive = false);
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    _placeholderFocus.requestFocus();
  }
}

class _FilterChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
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

class _SearchResultCard extends StatefulWidget {
  final ContentItem item;
  final VoidCallback onTap;

  const _SearchResultCard({required this.item, required this.onTap});

  @override
  State<_SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<_SearchResultCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) {
        setState(() => _focused = f);
        if (f && widget.item.image.isNotEmpty) {
          topBackgroundNotifier.value = widget.item.image;
        }
      },
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
          transform: _focused ? (Matrix4.identity()..translate(0, -4)..scale(1.02)) : Matrix4.identity(),
          transformAlignment: Alignment.center,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 7,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                      child: CachedNetworkImage(
                        imageUrl: widget.item.image,
                        fit: BoxFit.cover,
                        placeholder: (c, u) => Container(color: const Color(0xFF0F1620)),
                        errorWidget: (c, u, e) => Container(
                          color: const Color(0xFF0F1620),
                          child: Icon(
                            widget.item.type == 'channel' ? Icons.live_tv : Icons.movie,
                            color: Colors.white30,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: widget.item.type == 'movie'
                              ? Colors.blue.withOpacity(0.9)
                              : widget.item.isSeries || widget.item.type == 'series'
                                  ? Colors.purple.withOpacity(0.9)
                                  : Colors.green.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.item.type == 'movie' ? 'FILME' : (widget.item.isSeries || widget.item.type == 'series') ? 'SÉRIE' : 'CANAL',
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    if (widget.item.quality.isNotEmpty)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black87.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getQualityLabel(widget.item.quality),
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                      if (widget.item.group.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.item.group,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white54, fontSize: 9),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getQualityLabel(String quality) {
    final q = quality.toLowerCase();
    if (q.contains('4k') || q.contains('uhd')) return '4K';
    if (q.contains('fhd') || q.contains('fullhd')) return 'FHD';
    if (q.contains('hd')) return 'HD';
    return 'SD';
  }
}
