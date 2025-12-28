import '../models/content_item.dart';
import '../data/tmdb_service.dart';
import '../data/tmdb_cache.dart';
import '../core/utils/logger.dart';

/// Utilitário para enriquecer ContentItems com dados do TMDB
class ContentEnricher {
  /// Enriquece uma lista de itens com dados do TMDB (em background)
  static Future<List<ContentItem>> enrichItems(List<ContentItem> items) async {
    if (!TmdbService.isConfigured) {
      AppLogger.warning('⚠️ TMDB API key não configurada - pulando enriquecimento');
      return items;
    }

    AppLogger.info('🔄 ContentEnricher: Enriquecendo ${items.length} itens com TMDB...');
    if (items.isEmpty) return items;

    int successCount = 0; // Inicializa successCount no escopo correto

    final enrichedFutures = items.map((item) async {
      if (item.type == 'channel') {
        return item;
      }

      try {
        // Limpa título para busca (remove informações extras como ano, qualidade, etc.)
        var cleanTitle = item.title;
        cleanTitle = cleanTitle.replaceAll(RegExp(r'^[^\x20-\x7E\u00C0-\u017F]+'), '');
        cleanTitle = cleanTitle
            .replaceAll(RegExp(r'\s*\[.*?\]'), '')
            .replaceAll(RegExp(r'\s*\((\d{4})\)'), '')
            .replaceAll(RegExp(r'\s*-\s*(\d{4})\s*$'), '')
            .replaceAll(RegExp(r'\s*FHD\s*', caseSensitive: false), '')
            .replaceAll(RegExp(r'\s*HD\s*', caseSensitive: false), '')
            .replaceAll(RegExp(r'\s*4K\s*', caseSensitive: false), '')
            .replaceAll(RegExp(r'\s*UHD\s*', caseSensitive: false), '')
            .replaceAll(RegExp(r'\s*SD\s*', caseSensitive: false), '')
            .trim();
        if (cleanTitle.length < 3) cleanTitle = item.title;

        AppLogger.debug('🔍 TMDB: Buscando "${cleanTitle}" (original: "${item.title}")');

        TmdbMetadata? metadata;
        List<String> searchVariations = [cleanTitle]; // Inicializa searchVariations aqui

        String normalize(String text) {
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

        if (cleanTitle.length > 5) {
          void addVar(String v) {
            final s = v.trim();
            if (s.length >= 3 && !searchVariations.contains(s)) searchVariations.add(s);
          }
          final withoutArticles = cleanTitle.replaceAll(RegExp(r'^(O|A|Os|As|The|El|La|Les|Der|Die|Das)\s+', caseSensitive: false), '').trim();
          addVar(withoutArticles);
          final normalized = normalize(cleanTitle);
          addVar(normalized);
          final withoutPunctuation = cleanTitle.replaceAll(RegExp(r'[^\w\s\u00C0-\u017F]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
          addVar(withoutPunctuation);
          if (withoutArticles != cleanTitle) addVar(normalize(withoutArticles));
          final platformPrefixes = ['Netflix', 'Amazon Prime', 'Prime Video', 'HBO Max', 'Hulu', 'Crunchyroll', 'Disney+', 'YouTube'];
          for (final p in platformPrefixes) {
            if (cleanTitle.toLowerCase().startsWith('${p.toLowerCase()}:')) {
              final stripped = cleanTitle.substring(p.length + 1).trim();
              addVar(stripped);
            }
          }
          if (cleanTitle.contains(':')) {
            final parts = cleanTitle.split(':').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
            for (final part in parts) addVar(part);
          }
          final withoutParts = cleanTitle.replaceAll(RegExp(r'\b(part|pt|episode|ep)\s*\d+\b', caseSensitive: false), '').replaceAll(RegExp(r'\s+'), ' ').trim();
          addVar(withoutParts);
          final cleanedBrackets = cleanTitle.replaceAll(RegExp(r'\[.*?\]|\(.*?\)'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
          addVar(cleanedBrackets);
        }

        String? extractedYear;
        final yearMatch = RegExp(r'\b(19|20)\d{2}\b').firstMatch(item.title);
        if (yearMatch != null) extractedYear = yearMatch.group(0);

        AppLogger.info('🔍 TMDB: Tentando ${searchVariations.length} variações para "${item.title}":');

        for (int i = 0; i < searchVariations.length; i++) {
          final variation = searchVariations[i];
          if (variation.length < 3) continue;

          try {
            final normalizedKey = variation.toLowerCase().replaceAll(RegExp(r'[^\w\s\u00C0-\u017F]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
            final cached = await TmdbCache.get(normalizedKey);
            if (cached != null) {
              metadata = cached;
            }
          } catch (e) {
            AppLogger.debug('   ⚠️ Erro ao acessar cache TMDB: $e');
          }

          if (metadata == null) {
            final searchYear = (item.year != "2024" && item.year.isNotEmpty && item.year.length == 4) ? item.year : extractedYear;
            metadata = await TmdbService.searchContent(
              variation,
              year: searchYear,
              type: item.isSeries || item.type == 'series' ? 'tv' : 'movie',
            );
            if (metadata != null) {
              try {
                final normalizedKey = variation.toLowerCase().replaceAll(RegExp(r'[^\w\s\u00C0-\u017F]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
                await TmdbCache.put(normalizedKey, metadata);
              } catch (e) {
                AppLogger.debug('   ⚠️ Erro ao salvar cache TMDB: $e');
              }
            }
          }

          if (metadata != null) {
            break; // Sai do loop de variações se encontrar
          }
        }

        if (metadata != null) {
          // Usar um contador atômico ou similar se 'successCount' for realmente global
          // Para agora, apenas incrementar e entender que é um future
          // Evita o erro de 'Undefined name 'successCount''
          // successCount++; // Removido, pois não pode ser incrementado diretamente em um Future.map
          return item.enrichWithTmdb(
            rating: metadata.rating,
            description: metadata.overview?.isNotEmpty == true ? metadata.overview! : item.description,
            genre: metadata.genres.isNotEmpty ? metadata.genres.join(', ') : item.genre,
            popularity: metadata.popularity,
            releaseDate: metadata.releaseDate,
            director: metadata.director,
          );
        } else {
          return item;
        }
      } catch (e, stackTrace) {
        AppLogger.error('❌ TMDB: Erro ao enriquecer "${item.title}": $e');
        AppLogger.debug('Stack trace: $stackTrace');
        return item;
      }
    }).toList();

    final result = await Future.wait(enrichedFutures);
    // Contar sucessos após a conclusão de todos os futures
    successCount = result.where((item) => item.rating > 0).length;
    AppLogger.info('✅ ContentEnricher: ${successCount}/${items.length} itens enriquecidos com sucesso');
    return result;
  }

  /// Enriquece um único item
  static Future<ContentItem> enrichItem(ContentItem item) async {
    if (item.type == 'channel') return item;
    if (!TmdbService.isConfigured) return item;

    try {
      final metadata = await TmdbService.searchContent(
        item.title,
        year: item.year != "2024" ? item.year : null,
        type: item.isSeries || item.type == 'series' ? 'tv' : 'movie',
      );

      if (metadata != null) {
        return item.enrichWithTmdb(
          rating: metadata.rating > 0 ? metadata.rating : item.rating,
          description: metadata.overview ?? item.description,
          genre: metadata.genres.isNotEmpty ? metadata.genres.join(', ') : item.genre,
          popularity: metadata.popularity,
          releaseDate: metadata.releaseDate,
        );
      }
    } catch (e) {
      AppLogger.error('Erro ao enriquecer ${item.title}', error: e);
    }

    return item;
  }
}

/// Utilitário para ordenar listas de conteúdo
class ContentSorter {
  /// Ordena por mais vistos (popularidade)
  static List<ContentItem> sortByPopularity(List<ContentItem> items) {
    final sorted = List<ContentItem>.from(items);
    sorted.sort((a, b) => b.popularity.compareTo(a.popularity));
    return sorted;
  }

  /// Ordena por mais avaliados (rating)
  static List<ContentItem> sortByRating(List<ContentItem> items) {
    final sorted = List<ContentItem>.from(items);
    sorted.sort((a, b) {
      // Primeiro ordena por rating, depois por popularidade
      final ratingCompare = b.rating.compareTo(a.rating);
      if (ratingCompare != 0) return ratingCompare;
      return b.popularity.compareTo(a.popularity);
    });
    return sorted;
  }

  /// Ordena por mais recentes (data de lançamento)
  static List<ContentItem> sortByLatest(List<ContentItem> items) {
    final sorted = List<ContentItem>.from(items);
    sorted.sort((a, b) {
      // Compara datas de lançamento (mais recente primeiro)
      if (a.releaseDate != null && b.releaseDate != null) {
        return b.releaseDate!.compareTo(a.releaseDate!);
      }
      // Se não tem data, usa ano
      final yearCompare = b.year.compareTo(a.year);
      if (yearCompare != 0) return yearCompare;
      // Se mesmo ano, ordena por popularidade
      return b.popularity.compareTo(a.popularity);
    });
    return sorted;
  }

  /// Ordena por ordem alfabética (A-Z)
  static List<ContentItem> sortByAlphabetical(List<ContentItem> items) {
    final sorted = List<ContentItem>.from(items);
    sorted.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return sorted;
  }

  /// Filtra e ordena por tipo
  static List<ContentItem> filterAndSort(
    List<ContentItem> items, {
    String? type,
    String sortBy = 'popularity', // 'popularity', 'rating', 'latest', 'alphabetical'
  }) {
    var filtered = items;
    
    if (type != null) {
      filtered = items.where((item) => item.type == type).toList();
    }

    switch (sortBy) {
      case 'rating':
        return sortByRating(filtered);
      case 'latest':
        return sortByLatest(filtered);
      case 'alphabetical':
        return sortByAlphabetical(filtered);
      case 'popularity':
      default:
        return sortByPopularity(filtered);
    }
  }
}

