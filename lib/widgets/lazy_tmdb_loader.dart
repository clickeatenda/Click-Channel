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

  /// Limpa o título para busca no TMDB (Versão Robusta do ContentEnricher)
  String _cleanTitle(String title) {
    var clean = title;
    // Remove prefixos estranhos
    clean = clean.replaceAll(RegExp(r'^[^\x20-\x7E\u00C0-\u017F]+'), '');
    
    // Remove padrões comuns
    clean = clean
        .replaceAll(RegExp(r'\s*\[.*?\]'), '')
        .replaceAll(RegExp(r'\s*\((\d{4})\)'), '')
        .replaceAll(RegExp(r'\s*-\s*(\d{4})\s*$'), '')
        .replaceAll(RegExp(r'\s*(FHD|HD|4K|UHD|SD)\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*(DUB|LEG|DUAL)\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\|\s*.*$'), '')
        .trim();
    
    if (clean.length < 2) clean = title;
    return clean;
  }

  // Normaliza caracteres especiais
  String _normalize(String text) {
    return text
        .replaceAll('á', 'a').replaceAll('à', 'a').replaceAll('ã', 'a').replaceAll('â', 'a')
        .replaceAll('é', 'e').replaceAll('è', 'e').replaceAll('ê', 'e')
        .replaceAll('í', 'i').replaceAll('ì', 'i').replaceAll('î', 'i')
        .replaceAll('ó', 'o').replaceAll('ò', 'o').replaceAll('õ', 'o').replaceAll('ô', 'o')
        .replaceAll('ú', 'u').replaceAll('ù', 'u').replaceAll('û', 'u')
        .replaceAll('ç', 'c')
        .replaceAll('Á', 'A').replaceAll('À', 'A').replaceAll('Ã', 'A').replaceAll('Â', 'A')
        .replaceAll('É', 'E').replaceAll('È', 'E').replaceAll('Ê', 'E')
        .replaceAll('Í', 'I').replaceAll('Ì', 'I').replaceAll('Î', 'I')
        .replaceAll('Ó', 'O').replaceAll('Ò', 'O').replaceAll('Õ', 'O').replaceAll('Ô', 'O')
        .replaceAll('Ú', 'U').replaceAll('Ù', 'U').replaceAll('Û', 'U')
        .replaceAll('Ç', 'C');
  }

  Future<void> _loadTmdb() async {
    if (mounted) {
       await Future.delayed(const Duration(milliseconds: 600));
       if (!mounted) return;
    }

    if (widget.item.type == 'channel') return;

    // REMOVIDO: A verificação "se já tem imagem tmdb retorna"
    // Motivo: Se o M3U trouxer uma URL de imagem ERRADA/QUEBRADA do tmdb, 
    // a gente quer tentar corrigir buscando de novo.
    
    if (_hasAttempted) return;
    _hasAttempted = true;
    
    if (TmdbMemoryCache.has(widget.item.title)) {
      _applyCached(TmdbMemoryCache.get(widget.item.title));
      return;
    }
    
    if (TmdbMemoryCache.isPending(widget.item.title)) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (TmdbMemoryCache.has(widget.item.title) && mounted) {
        _applyCached(TmdbMemoryCache.get(widget.item.title));
      }
      return;
    }
    
    if (!TmdbService.isConfigured) return;
    
    TmdbMemoryCache.markPending(widget.item.title);
    
    if (mounted) setState(() => _isLoading = true);
    
    try {
      final normalizedKey = widget.item.title.toLowerCase().trim();
      TmdbMetadata? metadata = await TmdbCache.get(normalizedKey);
      
      if (metadata == null) {
        final cleanTitle = _cleanTitle(widget.item.title);
        
        // ESTRATÉGIA DE VARIAÇÕES (Igual ao ContentEnricher)
        List<String> searchVariations = [cleanTitle];
        
        if (cleanTitle.length > 5) {
          final withoutArticles = cleanTitle.replaceAll(RegExp(r'^(O|A|Os|As|The|El|La|Les|Der|Die|Das)\s+', caseSensitive: false), '').trim();
          if (withoutArticles != cleanTitle && withoutArticles.length >= 3) searchVariations.add(withoutArticles);
          
          final normalized = _normalize(cleanTitle);
          if (normalized != cleanTitle && normalized.length >= 3) searchVariations.add(normalized);
          
          final withoutPunctuation = cleanTitle.replaceAll(RegExp(r'[^\w\s\u00C0-\u017F]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
          if (withoutPunctuation != cleanTitle && withoutPunctuation.length >= 3) searchVariations.add(withoutPunctuation);
        }

        print('�️ LazyDebug: Buscando "${widget.item.title}". Variações: $searchVariations');

        for (final variation in searchVariations) {
          if (variation.length < 3) continue;
          
          metadata = await TmdbService.searchContent(
            variation,
            year: widget.item.year.isNotEmpty && widget.item.year != "2024" ? widget.item.year : null,
            type: widget.item.type == 'series' || widget.item.isSeries ? 'tv' : 'movie',
          );
          
          if (metadata != null) {
            print('✅ LazyTMDB: Encontrado com variação "$variation" -> ID: ${metadata.id}');
            break;
          }
          await Future.delayed(const Duration(milliseconds: 100)); // Rate limit check
        }
        
        if (metadata != null) {
          await TmdbCache.put(normalizedKey, metadata);
        } else {
          print('❌ LazyTMDB: Não encontrado "${widget.item.title}" (Tentou: $searchVariations)');
        }
      }
      
      TmdbMemoryCache.put(widget.item.title, metadata);
      if (mounted) _applyMetadata(metadata);
      
    } catch (e) {
      debugPrint('❌ TMDB Lazy Error: $e');
      TmdbMemoryCache.markFailed(widget.item.title);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyCached(TmdbMetadata? cached) {
    if (cached != null && mounted) _applyMetadata(cached);
  }

  void _applyMetadata(TmdbMetadata? metadata) {
    if (metadata != null) {
      final enriched = widget.item.enrichWithTmdb(
        rating: metadata.rating,
        description: metadata.overview,
        genre: metadata.genres.join(', '),
        image: metadata.posterUrl,
        releaseDate: metadata.releaseDate,
      );
      
      // DEBUG CRÍTICO
      print("🔄 LazyTmdb enriqueceu '${widget.item.title}':");
      print("   Imagem ANTES: '${widget.item.image.isEmpty ? '<VAZIA>' : widget.item.image.substring(0, widget.item.image.length > 40 ? 40 : widget.item.image.length)}...'");
      print("   Imagem DEPOIS: '${enriched.image.isEmpty ? '<VAZIA>' : enriched.image.substring(0, enriched.image.length > 40 ? 40 : enriched.image.length)}...'");
      
      setState(() {
        _enrichedItem = enriched;
        _isLoading = false;
      });
      widget.onItemEnriched?.call(enriched);
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(_enrichedItem ?? widget.item, _isLoading);
  }
}
