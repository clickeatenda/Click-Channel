import 'package:flutter/material.dart';
import '../models/content_item.dart';
import '../data/tmdb_service.dart';
import '../data/tmdb_cache.dart';

/// Cache em memória para evitar buscas repetidas durante a sessão
class _TmdbMemoryCache {
  static final Map<String, TmdbMetadata?> _cache = {};
  static final Set<String> _pending = {};
  
  static String _normalizeKey(String title) {
    return title.toLowerCase().trim()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }
  
  static TmdbMetadata? get(String title) {
    return _cache[_normalizeKey(title)];
  }
  
  static bool has(String title) {
    return _cache.containsKey(_normalizeKey(title));
  }
  
  static bool isPending(String title) {
    return _pending.contains(_normalizeKey(title));
  }
  
  static void markPending(String title) {
    _pending.add(_normalizeKey(title));
  }
  
  static void put(String title, TmdbMetadata? metadata) {
    final key = _normalizeKey(title);
    _cache[key] = metadata;
    _pending.remove(key);
  }
}

/// Widget que carrega dados do TMDB de forma lazy (sob demanda)
/// Usa cache em memória e disco para evitar chamadas repetidas
class LazyTmdbLoader extends StatefulWidget {
  final ContentItem item;
  final Widget Function(ContentItem enrichedItem, bool isLoading) builder;
  
  const LazyTmdbLoader({
    super.key,
    required this.item,
    required this.builder,
  });

  @override
  State<LazyTmdbLoader> createState() => _LazyTmdbLoaderState();
}

class _LazyTmdbLoaderState extends State<LazyTmdbLoader> {
  ContentItem? _enrichedItem;
  bool _isLoading = false;
  bool _hasAttempted = false;

  @override
  void initState() {
    super.initState();
    _loadTmdb();
  }

  @override
  void didUpdateWidget(LazyTmdbLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.title != widget.item.title) {
      _hasAttempted = false;
      _enrichedItem = null;
      _loadTmdb();
    }
  }

  Future<void> _loadTmdb() async {
    // Não busca para canais
    if (widget.item.type == 'channel') {
      return;
    }
    
    // Se já tem rating, não precisa buscar
    if (widget.item.rating > 0) {
      return;
    }
    
    // Evita buscas duplicadas
    if (_hasAttempted) return;
    _hasAttempted = true;
    
    // Verifica cache em memória primeiro (instantâneo)
    if (_TmdbMemoryCache.has(widget.item.title)) {
      final cached = _TmdbMemoryCache.get(widget.item.title);
      if (cached != null && mounted) {
        setState(() {
          _enrichedItem = widget.item.enrichWithTmdb(
            rating: cached.rating,
            description: cached.overview,
            genre: cached.genres.join(', '),
            image: cached.posterUrl,
          );
        });
      }
      return;
    }
    
    // Se já está buscando este item, aguarda
    if (_TmdbMemoryCache.isPending(widget.item.title)) {
      // Aguarda um pouco e verifica novamente
      await Future.delayed(const Duration(milliseconds: 500));
      if (_TmdbMemoryCache.has(widget.item.title) && mounted) {
        final cached = _TmdbMemoryCache.get(widget.item.title);
        if (cached != null) {
          setState(() {
            _enrichedItem = widget.item.enrichWithTmdb(
              rating: cached.rating,
              description: cached.overview,
              genre: cached.genres.join(', '),
              image: cached.posterUrl,
            );
          });
        }
      }
      return;
    }
    
    // Marca como pendente
    _TmdbMemoryCache.markPending(widget.item.title);
    
    if (mounted) {
      setState(() => _isLoading = true);
    }
    
    try {
      // Tenta cache em disco primeiro
      final normalizedKey = widget.item.title.toLowerCase().trim();
      TmdbMetadata? metadata = await TmdbCache.get(normalizedKey);
      
      // Se não tem em cache, busca da API
      if (metadata == null && TmdbService.isConfigured) {
        metadata = await TmdbService.searchContent(
          widget.item.title,
          year: widget.item.year.isNotEmpty && widget.item.year != "2024" ? widget.item.year : null,
          type: widget.item.type == 'series' ? 'tv' : 'movie',
        );
        
        // Salva no cache em disco
        if (metadata != null) {
          await TmdbCache.put(normalizedKey, metadata);
        }
      }
      
      // Salva no cache em memória (mesmo se null para evitar buscas repetidas)
      _TmdbMemoryCache.put(widget.item.title, metadata);
      
      if (metadata != null && mounted) {
        setState(() {
          _enrichedItem = widget.item.enrichWithTmdb(
            rating: metadata!.rating,
            description: metadata.overview,
            genre: metadata.genres.join(', '),
            image: metadata.posterUrl,
          );
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _TmdbMemoryCache.put(widget.item.title, null); // Marca como "não encontrado"
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(_enrichedItem ?? widget.item, _isLoading);
  }
}
