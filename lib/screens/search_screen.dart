import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/content_item.dart';
import '../data/m3u_service.dart';
import '../data/search_history_service.dart';
import '../core/theme/app_colors.dart';
import '../widgets/app_sidebar.dart';
import 'home_screen.dart' show topBackgroundNotifier;
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
  final LayerLink _autocompleteLayerLink = LayerLink();
  OverlayEntry? _autocompleteOverlay;

  List<ContentItem> _rawResults = [];
  List<ContentItem> _results = [];
  List<String> _searchHistory = [];
  List<String> _autocompleteSuggestions = [];
  bool _loading = false;
  String _lastQuery = '';
  String _typeFilter = 'all';
  String _genreFilter = 'all';
  String _yearFilter = 'all';
  String _qualityFilter = 'all';
  bool _isInputActive = false;
  bool _showHistory = false;

  // Quality label mapping
  static const _qualityLabels = {
    'all': 'Todos',
    'uhd4k': '4K',
    'fhd': 'FHD',
    'hd': 'HD',
    'sd': 'SD',
  };

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _placeholderFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _removeAutocompleteOverlay();
    _searchController.dispose();
    _searchFocus.dispose();
    _placeholderFocus.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      topBackgroundNotifier.value = null;
    });
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    final history = await SearchHistoryService.getSearchHistory();
    if (mounted) setState(() => _searchHistory = history);
  }

  void _activateInput() {
    setState(() {
      _isInputActive = true;
      _showHistory = _searchController.text.isEmpty;
    });
    Future.delayed(const Duration(milliseconds: 50), () {
      _searchFocus.requestFocus();
    });
  }

  void _deactivateInput() {
    _removeAutocompleteOverlay();
    setState(() {
      _isInputActive = false;
      _showHistory = false;
    });
    _placeholderFocus.requestFocus();
  }

  // ── Autocomplete overlay ───────────────────────────────────────────────────

  void _showAutocompleteOverlay(List<String> suggestions) {
    _removeAutocompleteOverlay();
    if (suggestions.isEmpty) return;

    _autocompleteOverlay = OverlayEntry(
      builder: (context) => Positioned(
        width: 400,
        child: CompositedTransformFollower(
          link: _autocompleteLayerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 52),
          child: Material(
            elevation: 8,
            color: const Color(0xFF1A2232),
            borderRadius: BorderRadius.circular(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: suggestions.map((s) {
                  return InkWell(
                    onTap: () {
                      _searchController.text = s;
                      _performSearch(s);
                      _removeAutocompleteOverlay();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.search, size: 16, color: Colors.white38),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(s,
                                style: const TextStyle(color: Colors.white70, fontSize: 14)),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_autocompleteOverlay!);
  }

  void _removeAutocompleteOverlay() {
    _autocompleteOverlay?.remove();
    _autocompleteOverlay = null;
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.isEmpty) {
      _removeAutocompleteOverlay();
      setState(() {
        _showHistory = true;
        _autocompleteSuggestions = [];
        _rawResults = [];
        _results = [];
        _loading = false;
      });
      return;
    }

    setState(() => _showHistory = false);

    // Generate autocomplete suggestions from history
    final historySuggestions = _searchHistory
        .where((h) => h.toLowerCase().startsWith(query.toLowerCase()) && h != query)
        .take(5)
        .toList();

    if (historySuggestions.isNotEmpty) {
      _autocompleteSuggestions = historySuggestions;
      _showAutocompleteOverlay(historySuggestions);
    } else {
      _removeAutocompleteOverlay();
    }

    await _performSearch(query);
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

    if (query.length >= 2) {
      await SearchHistoryService.addQuery(query);
      _loadSearchHistory();
    }

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
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Computed filter options ────────────────────────────────────────────────

  List<String> get _availableGenres {
    final genres = <String>{};
    for (final item in _rawResults) {
      if (item.genre.isNotEmpty) {
        genres.addAll(item.genre.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
      }
    }
    return ['all', ...genres.toList()..sort()];
  }

  List<String> get _availableYears {
    final years = <String>{};
    for (final item in _rawResults) {
      if (item.year.isNotEmpty) years.add(item.year.trim());
    }
    return ['all', ...years.toList()..sort((a, b) => b.compareTo(a))];
  }

  List<String> get _availableQualities {
    final qualities = <String>{};
    for (final item in _rawResults) {
      if (item.quality.isNotEmpty) qualities.add(item.quality.trim().toLowerCase());
    }
    // Return in canonical order
    return [
      'all',
      if (qualities.contains('uhd4k')) 'uhd4k',
      if (qualities.contains('fhd')) 'fhd',
      if (qualities.contains('hd')) 'hd',
      if (qualities.contains('sd')) 'sd',
    ];
  }

  // ── Filtering logic ────────────────────────────────────────────────────────

  List<ContentItem> _applyFilters(List<ContentItem> items) {
    return items.where((item) {
      // Type
      if (_typeFilter != 'all' && item.type != _typeFilter) return false;

      // Genre
      if (_genreFilter != 'all') {
        final genres = item.genre.split(',').map((e) => e.trim().toLowerCase());
        if (!genres.contains(_genreFilter.toLowerCase())) return false;
      }

      // Year
      if (_yearFilter != 'all' && item.year.trim() != _yearFilter) return false;

      // Quality
      if (_qualityFilter != 'all' && item.quality.trim().toLowerCase() != _qualityFilter) return false;

      return true;
    }).toList();
  }

  void _updateFilters() {
    if (_rawResults.isNotEmpty) {
      setState(() => _results = _applyFilters(_rawResults));
    } else if (_lastQuery.isNotEmpty) {
      _performSearch(_lastQuery);
    }
  }

  bool get _hasActiveFilters =>
      _typeFilter != 'all' || _genreFilter != 'all' || _yearFilter != 'all' || _qualityFilter != 'all';

  void _clearAllFilters() {
    setState(() {
      _typeFilter = 'all';
      _genreFilter = 'all';
      _yearFilter = 'all';
      _qualityFilter = 'all';
    });
    _updateFilters();
  }

  // ── Filter dialog ──────────────────────────────────────────────────────────

  void _showFilterDialog(
    String title,
    List<String> options,
    String currentValue,
    ValueChanged<String> onSelected, {
    Map<String, String>? labelOverrides,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A2232),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 320,
            height: 300,
            child: options.length == 1
                ? const Center(
                    child: Text('Nenhuma opção disponível.\nFaça uma busca primeiro.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54)),
                  )
                : ListView.builder(
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options[index];
                      final label = labelOverrides?[option] ?? (option == 'all' ? 'Todos' : option);
                      final isSelected = option == currentValue;
                      return ListTile(
                        dense: true,
                        title: Text(label,
                            style: TextStyle(
                              color: isSelected ? AppColors.primary : Colors.white70,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            )),
                        trailing: isSelected ? const Icon(Icons.check, color: AppColors.primary, size: 18) : null,
                        onTap: () {
                          onSelected(option);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // Dynamic blurred background
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
                            child: Container(color: AppColors.backgroundDark.withOpacity(0.80)),
                          ),
                        )
                      : Container(key: const ValueKey('empty_bg'), color: AppColors.backgroundDark),
                );
              },
            ),
          ),

          PopScope(
            canPop: !_isInputActive,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              if (_isInputActive) _deactivateInput();
            },
            child: Row(
              children: [
                const AppSidebar(selectedIndex: -1),
                Expanded(
                  child: Column(
                    children: [
                      // ── Top Bar ──────────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        decoration: const BoxDecoration(
                          color: Color(0xA00F1620),
                          border: Border(bottom: BorderSide(color: Color(0x334B5563))),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Search field row
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back, color: Colors.white70),
                                  onPressed: () => Navigator.pop(context),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: CompositedTransformTarget(
                                    link: _autocompleteLayerLink,
                                    child: _buildSearchField(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Dropdown filters
                                _DropdownFilterChip(
                                  label: 'Gênero',
                                  value: _genreFilter == 'all' ? null : _genreFilter,
                                  active: _genreFilter != 'all',
                                  onTap: () => _showFilterDialog(
                                    'Gênero',
                                    _availableGenres,
                                    _genreFilter,
                                    (val) { setState(() => _genreFilter = val); _updateFilters(); },
                                  ),
                                ),
                                _DropdownFilterChip(
                                  label: 'Ano',
                                  value: _yearFilter == 'all' ? null : _yearFilter,
                                  active: _yearFilter != 'all',
                                  onTap: () => _showFilterDialog(
                                    'Ano',
                                    _availableYears,
                                    _yearFilter,
                                    (val) { setState(() => _yearFilter = val); _updateFilters(); },
                                  ),
                                ),
                                _DropdownFilterChip(
                                  label: 'Qualidade',
                                  value: _qualityFilter == 'all' ? null : _qualityLabels[_qualityFilter],
                                  active: _qualityFilter != 'all',
                                  onTap: () => _showFilterDialog(
                                    'Qualidade',
                                    _availableQualities,
                                    _qualityFilter,
                                    (val) { setState(() => _qualityFilter = val); _updateFilters(); },
                                    labelOverrides: _qualityLabels,
                                  ),
                                ),
                                if (_hasActiveFilters)
                                  TextButton.icon(
                                    onPressed: _clearAllFilters,
                                    icon: const Icon(Icons.filter_alt_off, size: 16, color: Colors.redAccent),
                                    label: const Text('Limpar', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Type chips row
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _FilterChipWidget(
                                    label: 'Todos',
                                    selected: _typeFilter == 'all',
                                    onTap: () { setState(() => _typeFilter = 'all'); _updateFilters(); },
                                  ),
                                  _FilterChipWidget(
                                    label: 'Filmes',
                                    selected: _typeFilter == 'movie',
                                    onTap: () { setState(() => _typeFilter = 'movie'); _updateFilters(); },
                                  ),
                                  _FilterChipWidget(
                                    label: 'Séries',
                                    selected: _typeFilter == 'series',
                                    onTap: () { setState(() => _typeFilter = 'series'); _updateFilters(); },
                                  ),
                                  _FilterChipWidget(
                                    label: 'Canais',
                                    selected: _typeFilter == 'channel',
                                    onTap: () { setState(() => _typeFilter = 'channel'); _updateFilters(); },
                                  ),
                                  if (_rawResults.isNotEmpty) ...[
                                    const SizedBox(width: 16),
                                    Text(
                                      '${_results.length} resultado${_results.length != 1 ? 's' : ''}',
                                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Content area ─────────────────────────────────────
                      Expanded(
                        child: _loading
                            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                            : _showHistory && _searchHistory.isNotEmpty
                                ? _buildHistoryPanel()
                                : _results.isEmpty
                                    ? _buildEmptyState()
                                    : _buildResultsGrid(),
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

  // ── Sub-widgets ────────────────────────────────────────────────────────────

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
                  _lastQuery.isEmpty ? 'Pesquisar filmes, séries ou canais...' : _lastQuery,
                  style: const TextStyle(color: Colors.white60, fontSize: 15),
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
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Digite aqui...',
          hintStyle: const TextStyle(color: Colors.white30),
          filled: true,
          fillColor: Colors.white.withOpacity(0.08),
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
          prefixIcon: const Icon(Icons.search, color: Colors.white60),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
        ),
        onChanged: _onSearchChanged,
        onSubmitted: (val) {
          _removeAutocompleteOverlay();
          _deactivateInput();
        },
      ),
    );
  }

  Widget _buildHistoryPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: Colors.white54, size: 18),
              const SizedBox(width: 8),
              const Text('Buscas recentes',
                  style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  await SearchHistoryService.clearHistory();
                  setState(() => _searchHistory = []);
                },
                child: const Text('Limpar tudo', style: TextStyle(color: Colors.white38, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _searchHistory
                .map((query) => _HistoryChip(
                      query: query,
                      onTap: () {
                        _searchController.text = query;
                        _onSearchChanged(query);
                      },
                      onDelete: () async {
                        await SearchHistoryService.removeQuery(query);
                        _loadSearchHistory();
                      },
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
                : _hasActiveFilters
                    ? 'Nenhum resultado com os filtros aplicados'
                    : 'Nenhum resultado para "$_lastQuery"',
            style: const TextStyle(color: Colors.white54, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          if (_hasActiveFilters) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _clearAllFilters,
              icon: const Icon(Icons.filter_alt_off, size: 16),
              label: const Text('Remover filtros'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultsGrid() {
    return GridView.builder(
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
    );
  }

  void _openDetails(ContentItem item) async {
    if (item.image.isNotEmpty) topBackgroundNotifier.value = item.image;

    if (item.type == 'movie') {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailScreen(item: item)));
    } else if (item.type == 'series') {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => SeriesDetailScreen(item: item)));
    }
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _FilterChipWidget extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipWidget({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.select ||
               event.logicalKey == LogicalKeyboardKey.enter)) {
            onTap();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Builder(builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary
                    : hasFocus
                        ? Colors.white10
                        : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: hasFocus
                      ? Colors.white54
                      : selected
                          ? AppColors.primary
                          : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: selected || hasFocus ? Colors.white : Colors.white60,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _DropdownFilterChip extends StatefulWidget {
  final String label;
  final String? value;
  final bool active;
  final VoidCallback onTap;

  const _DropdownFilterChip({
    required this.label,
    required this.onTap,
    this.value,
    this.active = false,
  });

  @override
  State<_DropdownFilterChip> createState() => _DropdownFilterChipState();
}

class _DropdownFilterChipState extends State<_DropdownFilterChip> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final displayLabel = widget.value != null ? '${widget.label}: ${widget.value}' : widget.label;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: widget.active ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.active
                    ? AppColors.primary
                    : _focused
                        ? Colors.white54
                        : Colors.white12,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayLabel,
                  style: TextStyle(
                    color: widget.active ? AppColors.primary : Colors.white70,
                    fontSize: 12,
                    fontWeight: widget.active ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_drop_down,
                    color: widget.active ? AppColors.primary : Colors.white54, size: 16),
              ],
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
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      onFocusChange: (hasFocus) {
        if (hasFocus) topBackgroundNotifier.value = widget.item.image;
        setState(() {});
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: LayoutBuilder(builder: (context, constraints) {
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
                        width: 2.5,
                      ),
                      boxShadow: hasFocus
                          ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12, spreadRadius: 2)]
                          : [],
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: widget.item.image,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            placeholder: (context, url) =>
                                Container(color: Colors.white.withOpacity(0.05)),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.white10,
                              child: const Icon(Icons.movie, color: Colors.white24),
                            ),
                          ),
                        ),
                        // Quality badge
                        if (widget.item.quality.isNotEmpty && widget.item.quality != 'sd')
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: _qualityColor(widget.item.quality),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _qualityLabel(widget.item.quality),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: hasFocus ? Colors.white : Colors.white70,
                    fontWeight: hasFocus ? FontWeight.bold : FontWeight.normal,
                    fontSize: 11,
                  ),
                ),
                if (widget.item.year.isNotEmpty)
                  Text(
                    widget.item.year,
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Color _qualityColor(String quality) {
    switch (quality.toLowerCase()) {
      case 'uhd4k':
        return const Color(0xFFFFD700);
      case 'fhd':
        return const Color(0xFF00E5FF);
      case 'hd':
        return const Color(0xFF69FF47);
      default:
        return Colors.white70;
    }
  }

  String _qualityLabel(String quality) {
    switch (quality.toLowerCase()) {
      case 'uhd4k':
        return '4K';
      case 'fhd':
        return 'FHD';
      case 'hd':
        return 'HD';
      default:
        return quality.toUpperCase();
    }
  }
}

class _BlinkingCursorPlaceholder extends StatefulWidget {
  const _BlinkingCursorPlaceholder();

  @override
  State<_BlinkingCursorPlaceholder> createState() => _BlinkingCursorPlaceholderState();
}

class _BlinkingCursorPlaceholderState extends State<_BlinkingCursorPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
        opacity: _controller,
        child: Container(width: 2, height: 20, color: AppColors.primary));
  }
}

class _HistoryChip extends StatefulWidget {
  final String query;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryChip({required this.query, required this.onTap, required this.onDelete});

  @override
  State<_HistoryChip> createState() => _HistoryChipState();
}

class _HistoryChipState extends State<_HistoryChip> {
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
          padding: const EdgeInsets.only(left: 12, right: 4, top: 6, bottom: 6),
          decoration: BoxDecoration(
            color: _focused ? AppColors.primary.withOpacity(0.15) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _focused ? AppColors.primary : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.history, size: 14, color: Colors.white54),
              const SizedBox(width: 6),
              Text(
                widget.query,
                style: TextStyle(
                  color: _focused ? Colors.white : Colors.white70,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: widget.onDelete,
                child: const Icon(Icons.close, size: 13, color: Colors.white38),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}
