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
        // CRÍTICO: Limpeza mais robusta para lidar com caracteres corrompidos e prefixos estranhos
        var cleanTitle = item.title;
        
        // CRÍTICO: Remove prefixos estranhos que aparecem nos logs (ex: "Ô£╗")
        // Remove caracteres não-ASCII problemáticos no início
        cleanTitle = cleanTitle.replaceAll(RegExp(r'^[^\x20-\x7E\u00C0-\u017F]+'), '');
        
        // Remove apenas padrões específicos, mantendo o título o mais próximo possível do original
        cleanTitle = cleanTitle
            .replaceAll(RegExp(r'\s*\[.*?\]'), '') // Remove [1080p], [LEG], etc.
            .replaceAll(RegExp(r'\s*\((\d{4})\)'), '') // Remove apenas (2024), mantém outros parênteses
            .replaceAll(RegExp(r'\s*-\s*(\d{4})\s*$'), '') // Remove - 2024 no final
            .replaceAll(RegExp(r'\s*FHD\s*', caseSensitive: false), '')
            .replaceAll(RegExp(r'\s*HD\s*', caseSensitive: false), '')
            .replaceAll(RegExp(r'\s*4K\s*', caseSensitive: false), '')
            .replaceAll(RegExp(r'\s*UHD\s*', caseSensitive: false), '')
            .replaceAll(RegExp(r'\s*SD\s*', caseSensitive: false), '')
            .trim();
        
        // Se título ficou muito curto após limpeza, usa original
        if (cleanTitle.length < 3) {
          cleanTitle = item.title;
        }
        
        AppLogger.debug('🔍 TMDB: Buscando "${cleanTitle}" (original: "${item.title}")');
        
        // CRÍTICO: Tenta múltiplas variações do título para melhor matching
        TmdbMetadata? metadata;
        List<String> searchVariations = [cleanTitle];
        
        // Normaliza caracteres especiais (remove acentos para melhor matching)
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
        
        // Adiciona variações: sem artigos, sem pontuação, normalizado, etc.
        if (cleanTitle.length > 5) {
          // Remove artigos comuns no início
          final withoutArticles = cleanTitle.replaceAll(RegExp(r'^(O|A|Os|As|The|El|La|Les|Der|Die|Das)\s+', caseSensitive: false), '').trim();
          if (withoutArticles != cleanTitle && withoutArticles.length >= 3) {
            searchVariations.add(withoutArticles);
          }
          
          // Versão normalizada (sem acentos)
          final normalized = normalize(cleanTitle);
          if (normalized != cleanTitle && normalized.length >= 3) {
            searchVariations.add(normalized);
          }
          
          // Remove pontuação especial (mas mantém espaços)
          final withoutPunctuation = cleanTitle.replaceAll(RegExp(r'[^\w\s\u00C0-\u017F]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
          if (withoutPunctuation != cleanTitle && withoutPunctuation.length >= 3) {
            searchVariations.add(withoutPunctuation);
          }
          
          // Combinação: sem artigos + normalizado
          if (withoutArticles != cleanTitle) {
            final normalizedWithoutArticles = normalize(withoutArticles);
            if (normalizedWithoutArticles != cleanTitle && normalizedWithoutArticles.length >= 3) {
              searchVariations.add(normalizedWithoutArticles);
            }
          }
        }
        
        // CRÍTICO: Log detalhado de todas as variações que serão tentadas
        AppLogger.info('🔍 TMDB: Tentando ${searchVariations.length} variações para "${item.title}":');
        for (int i = 0; i < searchVariations.length; i++) {
          AppLogger.info('   Variação ${i + 1}: "${searchVariations[i]}"');
        }
        
        // Tenta cada variação até encontrar
        for (int i = 0; i < searchVariations.length; i++) {
          final variation = searchVariations[i];
          if (variation.length < 3) {
            AppLogger.debug('   ⏭️ Variação ${i + 1} muito curta, pulando');
            continue;
          }

          AppLogger.info('   🔎 Tentando variação ${i + 1}/${searchVariations.length}: "$variation"');

          // Tenta ler do cache local antes de consultar a API TMDB
          try {
            final normalizedKey = variation.toLowerCase().replaceAll(RegExp(r'[^\w\s\u00C0-\u017F]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
            final cached = await TmdbCache.get(normalizedKey);
            if (cached != null) {
              AppLogger.info('   🗄️ Cache: encontrado para "$variation" (chave: $normalizedKey) - Rating: ${cached.rating}');
              metadata = cached;
            }
          } catch (e) {
            AppLogger.debug('   ⚠️ Erro ao acessar cache TMDB: $e');
          }

          if (metadata == null) {
            metadata = await TmdbService.searchContent(
              variation,
              year: item.year != "2024" && item.year.isNotEmpty && item.year.length == 4 ? item.year : null,
              type: item.isSeries || item.type == 'series' ? 'tv' : 'movie',
            );
            // Se encontrou na API, persiste no cache para próximas buscas
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
            AppLogger.info('   ✅ SUCESSO com variação ${i + 1}: "$variation" - Rating: ${metadata.rating}');
            break; // Encontrou, para de tentar
          } else {
            AppLogger.debug('   ❌ Variação ${i + 1} não encontrou resultados');
          }
          
          // Pequeno delay entre tentativas para evitar rate limit
          if (i < searchVariations.length - 1) {
            await Future.delayed(const Duration(milliseconds: 150));
          }
        }

        if (metadata != null) {
          // CRÍTICO: Enriquece mesmo se rating for 0 (pode ter descrição, gênero, etc.)
          // CRÍTICO: SEMPRE usa rating do TMDB se disponível (mesmo que seja 0)
          final enrichedItem = item.enrichWithTmdb(
            rating: metadata.rating, // SEMPRE usa rating do TMDB (pode ser 0)
            description: metadata.overview?.isNotEmpty == true ? metadata.overview! : item.description,
            genre: metadata.genres.isNotEmpty ? metadata.genres.join(', ') : item.genre,
            popularity: metadata.popularity,
            releaseDate: metadata.releaseDate,
          );
          
          // Debug: verifica se rating foi aplicado corretamente
          if (metadata.rating > 0) {
            AppLogger.info('✅ TMDB: Enriquecido "${item.title}" - Rating: ${metadata.rating} -> Item.rating: ${enrichedItem.rating}');
            successCount++;
          } else {
            AppLogger.debug('ℹ️ TMDB: Encontrado "${item.title}" mas sem rating (tem descrição: ${metadata.overview?.isNotEmpty ?? false})');
            successCount++; // Conta como sucesso mesmo sem rating
          }
          enriched.add(enrichedItem);
        } else {
          AppLogger.debug('⚠️ TMDB: Não encontrado "${item.title}" (tentou: ${searchVariations.join(", ")})');
          enriched.add(item);
        }
      } catch (e, stackTrace) {
        AppLogger.error('❌ TMDB: Erro ao enriquecer "${item.title}": $e');
        AppLogger.debug('Stack trace: $stackTrace');
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

