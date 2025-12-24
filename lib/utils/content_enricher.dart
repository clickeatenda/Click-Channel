import '../models/content_item.dart';
import '../data/tmdb_service.dart';
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
    final enriched = <ContentItem>[];
    int successCount = 0;
    
    for (final item in items) {
      // Só busca para filmes e séries (não canais)
      if (item.type == 'channel') {
        enriched.add(item);
        continue;
      }

      try {
        // Limpa título para busca (remove informações extras como ano, qualidade, etc.)
        final cleanTitle = item.title
            .replaceAll(RegExp(r'\s*\(.*?\)'), '') // Remove (2024), (HD), etc.
            .replaceAll(RegExp(r'\s*\[.*?\]'), '') // Remove [1080p], etc.
            .replaceAll(RegExp(r'\s*-\s*\d{4}'), '') // Remove - 2024
            .trim();
        
        final metadata = await TmdbService.searchContent(
          cleanTitle,
          year: item.year != "2024" && item.year.isNotEmpty ? item.year : null,
          type: item.isSeries || item.type == 'series' ? 'tv' : 'movie',
        );

        if (metadata != null && metadata.rating > 0) {
          // Enriquecer com dados do TMDB
          final enrichedItem = item.enrichWithTmdb(
            rating: metadata.rating,
            description: metadata.overview?.isNotEmpty == true ? metadata.overview : item.description,
            genre: metadata.genres.isNotEmpty ? metadata.genres.join(', ') : item.genre,
            popularity: metadata.popularity,
            releaseDate: metadata.releaseDate,
          );
          AppLogger.info('✅ TMDB: Enriquecido "${item.title}" - Rating: ${metadata.rating}');
          enriched.add(enrichedItem);
          successCount++;
        } else {
          if (metadata == null) {
            AppLogger.debug('⚠️ TMDB: Não encontrado "${item.title}"');
          }
          enriched.add(item);
        }
      } catch (e) {
        AppLogger.error('❌ TMDB: Erro ao enriquecer "${item.title}"', error: e);
        enriched.add(item);
      }
    }

    AppLogger.info('✅ ContentEnricher: ${successCount}/${items.length} itens enriquecidos com sucesso');
    return enriched;
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

  /// Filtra e ordena por tipo
  static List<ContentItem> filterAndSort(
    List<ContentItem> items, {
    String? type,
    String sortBy = 'popularity', // 'popularity', 'rating', 'latest'
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
      case 'popularity':
      default:
        return sortByPopularity(filtered);
    }
  }
}

