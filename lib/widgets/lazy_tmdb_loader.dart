import 'package:flutter/material.dart';
import '../models/content_item.dart';
import '../data/tmdb_service.dart';
import '../data/tmdb_cache.dart';

/// Cache em memória para evitar buscas repetidas durante a sessão
class TmdbMemoryCache {
  static final Map<String, TmdbMetadata?> _cache = {};
  static final Set<String> _pending = {};
  static final Set<String> _failed = {}; // Títulos que falharam
  
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
  
  static bool hasFailed(String title) {
    return _failed.contains(_normalizeKey(title));
  }
  
  static bool isPending(String title) {
    return _pending.contains(_normalizeKey(title));
  }
  
  static void markPending(String title) {
    _pending.add(_normalizeKey(title));
  }
  
  static void markFailed(String title) {
    final key = _normalizeKey(title);
    _failed.add(key);
    _pending.remove(key);
  }
  
  static void put(String title, TmdbMetadata? metadata) {
    final key = _normalizeKey(title);
    _cache[key] = metadata;
    _pending.remove(key);
    if (metadata == null) {
      _failed.add(key);
    }
  }
  
  static void clear() {
    _cache.clear();
    _pending.clear();
    _failed.clear();
  }
}

/// Widget que carrega dados do TMDB de forma lazy (sob demanda)
/// Usa cache em memória e disco para evitar chamadas repetidas
class LazyTmdbLoader extends StatefulWidget {
  final ContentItem item;
  final Widget Function(ContentItem enrichedItem, bool isLoading) builder;
  final Function(ContentItem enrichedItem)? onItemEnriched;
  
  const LazyTmdbLoader({
    super.key,
    required this.item,
    required this.builder,
    this.onItemEnriched,
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

  /// Limpa o título para busca no TMDB
  String _cleanTitle(String title) {
    var clean = title;
    
    // Remove prefixos estranhos (caracteres não-ASCII no início)
    clean = clean.replaceAll(RegExp(r'^[^\x20-\x7E\u00C0-\u017F]+'), '');
    
    // Remove padrões comuns de qualidade/idioma
    clean = clean
        .replaceAll(RegExp(r'\s*\[.*?\]'), '') // Remove [1080p], [LEG], etc.
        .replaceAll(RegExp(r'\s*\((\d{4})\)'), '') // Remove (2024)
        .replaceAll(RegExp(r'\s*-\s*(\d{4})\s*$'), '') // Remove - 2024 no final
        .replaceAll(RegExp(r'\s*(FHD|HD|4K|UHD|SD)\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*(DUB|LEG|DUAL)\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\|\s*.*$'), '') // Remove texto após |
        .trim();
    
    // Se ficou muito curto, usa original
    if (clean.length < 2) {
      clean = title;
    }
    
    return clean;
  }

  Future<void> _loadTmdb() async {
    // THROTTLE / DEBOUNCE: Aguarda user parar de rolar rápido
    if (mounted) {
       await Future.delayed(const Duration(milliseconds: 600));
       if (!mounted) return; // Se saiu da tela, cancela
    }

    // Não busca para canais (mas reporta carregado para callback se precisar)
    if (widget.item.type == 'channel') {
      return;
    }
    
    // Se já tem rating e imagem do TMDB, não precisa buscar
    // Mas notifica o pai se ele não tiver esses dados
    if (widget.item.rating > 0 && widget.item.image.contains('tmdb.org')) {
      return;
    }
    
    // Evita buscas duplicadas
    if (_hasAttempted) return;
    _hasAttempted = true;
    
    // Verifica cache em memória primeiro (instantâneo)
    if (TmdbMemoryCache.has(widget.item.title)) {
      final cached = TmdbMemoryCache.get(widget.item.title);
      if (cached != null && mounted) {
        final enriched = widget.item.enrichWithTmdb(
          rating: cached.rating,
          description: cached.overview,
          genre: cached.genres.join(', '),
          image: cached.posterUrl,
          releaseDate: cached.releaseDate,
        );
        setState(() {
          _enrichedItem = enriched;
        });
        widget.onItemEnriched?.call(enriched);
      }
      return;
    }
    
    // Se já está buscando este item, aguarda
    if (TmdbMemoryCache.isPending(widget.item.title)) {
      // Aguarda e verifica novamente
      await Future.delayed(const Duration(milliseconds: 800));
      if (TmdbMemoryCache.has(widget.item.title) && mounted) {
        final cached = TmdbMemoryCache.get(widget.item.title);
        if (cached != null) {
          final enriched = widget.item.enrichWithTmdb(
            rating: cached.rating,
            description: cached.overview,
            genre: cached.genres.join(', '),
            image: cached.posterUrl,
            releaseDate: cached.releaseDate,
          );
          setState(() {
            _enrichedItem = enriched;
          });
          widget.onItemEnriched?.call(enriched);
        }
      }
      return;
    }
    
    // Verifica se TMDB está configurado
    if (!TmdbService.isConfigured) {
      print('⚠️ LazyTMDB: TMDB não configurado');
      return;
    }
    
    // Marca como pendente
    TmdbMemoryCache.markPending(widget.item.title);
    
    if (mounted) {
      setState(() => _isLoading = true);
    }
    
    try {
      // Tenta cache em disco primeiro
      final normalizedKey = widget.item.title.toLowerCase().trim();
      TmdbMetadata? metadata = await TmdbCache.get(normalizedKey);
      
      // Se não tem em cache, busca da API
      if (metadata == null) {
        final cleanTitle = _cleanTitle(widget.item.title);
        print('🔍 LazyTMDB: Buscando "$cleanTitle" (original: "${widget.item.title}") (ano: ${widget.item.year})');
        
        metadata = await TmdbService.searchContent(
          cleanTitle,
          year: widget.item.year.isNotEmpty && widget.item.year != "2024" ? widget.item.year : null,
          type: widget.item.type == 'series' || widget.item.isSeries ? 'tv' : 'movie',
        );
        
        // Se não encontrou, tenta sem o ano
        if (metadata == null && widget.item.year.isNotEmpty) {
          metadata = await TmdbService.searchContent(
            cleanTitle,
            type: widget.item.type == 'series' || widget.item.isSeries ? 'tv' : 'movie',
          );
        }
        
        // Salva no cache em disco (mesmo se null)
        if (metadata != null) {
          await TmdbCache.put(normalizedKey, metadata);
          print('✅ LazyTMDB: Encontrado "${widget.item.title}" -> Rating: ${metadata.rating}, Date: ${metadata.releaseDate}');
        } else {
          print('❌ LazyTMDB: Não encontrado "${widget.item.title}"');
        }
      } else {
        print('💾 LazyTMDB: Cache hit "${widget.item.title}"');
      }
      
      // Salva no cache em memória
      TmdbMemoryCache.put(widget.item.title, metadata);
      
      if (metadata != null && mounted) {
        final enriched = widget.item.enrichWithTmdb(
          rating: metadata.rating,
          description: metadata.overview,
          genre: metadata.genres.join(', '),
          image: metadata.posterUrl,
          releaseDate: metadata.releaseDate,
        );
        setState(() {
          _enrichedItem = enriched;
          _isLoading = false;
        });
        widget.onItemEnriched?.call(enriched);
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('❌ TMDB Error: $e');
      TmdbMemoryCache.markFailed(widget.item.title);
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
