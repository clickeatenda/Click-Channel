import 'package:flutter/material.dart';
import '../models/content_item.dart';

/// Callback para carregar mais itens quando atinge o threshold
typedef OnLoadMore = Future<List<ContentItem>> Function(int pageNumber);

/// Widget de grid view com paginação virtual para listas grandes (>1000 itens)
class VirtualPaginatedGridView extends StatefulWidget {
  final List<ContentItem> items;
  final OnLoadMore onLoadMore;
  final ValueChanged<ContentItem> onItemTap;
  final int crossAxisCount;
  final double childAspectRatio;
  final int itemsPerPage;
  final double scrollThresholdPct;
  final Widget Function(BuildContext, ContentItem, int) itemBuilder;

  const VirtualPaginatedGridView({
    super.key,
    required this.items,
    required this.onLoadMore,
    required this.onItemTap,
    required this.itemBuilder,
    this.crossAxisCount = 6,
    this.childAspectRatio = 0.6,
    this.itemsPerPage = 240,
    this.scrollThresholdPct = 0.8,
  });

  @override
  State<VirtualPaginatedGridView> createState() => _VirtualPaginatedGridViewState();
}

class _VirtualPaginatedGridViewState extends State<VirtualPaginatedGridView> {
  late ScrollController _scrollController;
  int _currentPage = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Listener para detecção de scroll próximo ao final
  void _onScroll() {
    if (!_isLoading && _shouldLoadMore()) {
      _loadMoreItems();
    }
  }

  /// Verifica se deve carregar mais itens baseado no threshold
  bool _shouldLoadMore() {
    if (_scrollController.position.pixels == 0.0) return false;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final threshold = maxScroll * widget.scrollThresholdPct;

    return currentScroll >= threshold;
  }

  /// Carrega mais itens
  Future<void> _loadMoreItems() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      final newItems = await widget.onLoadMore(_currentPage);
      if (mounted) {
        setState(() {
          _currentPage++;
          _isLoading = false;
        });
        print('✅ Paginação: Carregados ${newItems.length} novos itens (página $_currentPage)');
      }
    } catch (e) {
      print('⚠️ Paginação: Erro ao carregar mais itens: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: _scrollController,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
        childAspectRatio: widget.childAspectRatio,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: widget.items.length + (_isLoading ? widget.crossAxisCount : 0),
      itemBuilder: (context, index) {
        // Se é um item skeleton (loading), mostra placeholder
        if (index >= widget.items.length) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: BorderRadius.circular(8),
            ),
          );
        }

        return widget.itemBuilder(context, widget.items[index], index);
      },
    );
  }
}

/// Versão com ListView para listas verticais grandes
class VirtualPaginatedListView extends StatefulWidget {
  final List<ContentItem> items;
  final OnLoadMore onLoadMore;
  final ValueChanged<ContentItem> onItemTap;
  final int itemsPerPage;
  final double scrollThresholdPct;
  final Widget Function(BuildContext, ContentItem, int) itemBuilder;

  const VirtualPaginatedListView({
    super.key,
    required this.items,
    required this.onLoadMore,
    required this.onItemTap,
    required this.itemBuilder,
    this.itemsPerPage = 240,
    this.scrollThresholdPct = 0.8,
  });

  @override
  State<VirtualPaginatedListView> createState() => _VirtualPaginatedListViewState();
}

class _VirtualPaginatedListViewState extends State<VirtualPaginatedListView> {
  late ScrollController _scrollController;
  int _currentPage = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_isLoading && _shouldLoadMore()) {
      _loadMoreItems();
    }
  }

  bool _shouldLoadMore() {
    if (_scrollController.position.pixels == 0.0) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final threshold = maxScroll * widget.scrollThresholdPct;
    return currentScroll >= threshold;
  }

  Future<void> _loadMoreItems() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final newItems = await widget.onLoadMore(_currentPage);
      if (mounted) {
        setState(() {
          _currentPage++;
          _isLoading = false;
        });
        print('✅ Paginação: Carregados ${newItems.length} novos itens (página $_currentPage)');
      }
    } catch (e) {
      print('⚠️ Paginação: Erro ao carregar mais itens: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: widget.items.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= widget.items.length) {
          return Container(
            height: 150,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: BorderRadius.circular(8),
            ),
          );
        }
        return widget.itemBuilder(context, widget.items[index], index);
      },
    );
  }
}
