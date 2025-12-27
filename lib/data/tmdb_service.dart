import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import '../core/prefs.dart';
import '../core/utils/logger.dart';

/// Serviço para buscar metadados de filmes e séries do TMDB
class TmdbService {
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static String? _apiKey;

  /// Inicializa a API key do TMDB (lê de .env via Config)
  static void init() {
    // Prioriza chave configurada em runtime via Prefs (Settings)
    try {
      final prefKey = Prefs.getTmdbApiKey();
      if (prefKey != null && prefKey.isNotEmpty) {
        _apiKey = prefKey.trim();
        AppLogger.info('✅ TMDB API key carregada (via Prefs/Settings)');
      } else {
        // Lê a chave do arquivo .env através de Config como fallback
        _apiKey = Config.tmdbApiKey;
        if (_apiKey == null || _apiKey!.isEmpty) {
          AppLogger.warning('⚠️ TMDB_API_KEY não configurada (ver .env ou Settings)');
        } else {
          AppLogger.info('✅ TMDB API key carregada (via .env)');
        }
      }
    } catch (e) {
      _apiKey = Config.tmdbApiKey;
      if (_apiKey == null || _apiKey!.isEmpty) {
        AppLogger.warning('⚠️ TMDB_API_KEY não configurada (erro ao ler Prefs)');
      }
    }

    // Dispara teste assíncrono da chave (não bloqueia init)
    testApiKeyNow();
  }
  
  

  /// Verifica se a API key está configurada
  static bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  /// Testa a API key atual de forma síncrona (awaitable) e retorna true se válida
  static Future<bool> testApiKeyNow() async {
    if (_apiKey == null || _apiKey!.isEmpty) return false;

    try {
      final testUrl = '$_baseUrl/movie/550?api_key=$_apiKey';
      final res = await http.get(Uri.parse(testUrl)).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        AppLogger.info('✅ TMDB: API key válida e funcionando (teste)');
        return true;
      } else if (res.statusCode == 401) {
        AppLogger.error('❌ TMDB: API key INVÁLIDA ou EXPIRADA! Status 401 (teste)');
        return false;
      } else if (res.statusCode == 429) {
        AppLogger.warning('⚠️ TMDB: Rate limit atingido no teste inicial');
        return false;
      } else {
        AppLogger.warning('⚠️ TMDB: Status ${res.statusCode} no teste da API key');
        return false;
      }
    } catch (e) {
      AppLogger.warning('⚠️ TMDB: Erro ao testar API key: $e');
      return false;
    }
  }

  /// Busca informações completas de um filme/série pelo título
  static Future<TmdbMetadata?> searchContent(String title, {String? year, String type = 'movie'}) async {
    if (!isConfigured) {
      AppLogger.warning('TMDB API key não configurada');
      return null;
    }

    try {
      // CRÍTICO: Verifica se API key está configurada
      if (_apiKey == null || _apiKey!.isEmpty) {
        AppLogger.error('❌ TMDB: API key não configurada!');
        return null;
      }
      
      // TMDB API v3 usa api_key como query parameter
      final searchUrl = '$_baseUrl/search/$type?api_key=$_apiKey&query=${Uri.encodeComponent(title)}&language=pt-BR';
      
      AppLogger.debug('🔍 TMDB API: Buscando "$title" (tipo: $type${year != null ? ", ano: $year" : ""})');
      AppLogger.debug('   URL: ${searchUrl.replaceAll(_apiKey!, "***API_KEY***")}&...');
      
      // Tenta com ano primeiro (mais preciso)
      if (year != null && year.isNotEmpty && year.length == 4) {
        try {
          final searchUrlWithYear = '$searchUrl&year=$year';
          final searchRes = await http.get(Uri.parse(searchUrlWithYear)).timeout(const Duration(seconds: 15));
          AppLogger.info('📡 TMDB: Status ${searchRes.statusCode} (com ano $year)');
          
          if (searchRes.statusCode == 200) {
            final searchData = json.decode(searchRes.body);
            if (searchData['results'] != null && (searchData['results'] as List).isNotEmpty) {
              final result = searchData['results'][0];
              final foundTitle = result['title'] ?? result['name'] ?? 'Sem título';
              AppLogger.info('✅ TMDB: Encontrado "$foundTitle" (com ano)');
              return await _fetchDetails(result['id'], type);
            }
          } else if (searchRes.statusCode == 401) {
            AppLogger.error('❌ TMDB: API key inválida ou expirada! Status 401');
            return null;
          } else if (searchRes.statusCode == 429) {
            AppLogger.warning('⚠️ TMDB: Rate limit atingido. Aguardando...');
            await Future.delayed(const Duration(seconds: 2));
            // Continua para tentar sem ano
          } else {
            final errorBody = searchRes.body.length > 200 ? searchRes.body.substring(0, 200) : searchRes.body;
            AppLogger.warning('⚠️ TMDB: Erro ${searchRes.statusCode} (com ano): $errorBody');
          }
        } catch (e) {
          AppLogger.error('❌ TMDB: Erro na busca com ano: $e');
        }
      }

      // Se não encontrou com ano, tenta sem
      try {
        final searchRes = await http.get(Uri.parse(searchUrl)).timeout(const Duration(seconds: 15));
        AppLogger.info('📡 TMDB: Status ${searchRes.statusCode} (sem ano)');
        
        if (searchRes.statusCode == 200) {
          final searchData = json.decode(searchRes.body);
          if (searchData['results'] != null && (searchData['results'] as List).isNotEmpty) {
            final results = searchData['results'] as List;
            final result = results[0];
            final foundTitle = result['title'] ?? result['name'] ?? 'Sem título';
            final foundRating = (result['vote_average'] ?? 0.0).toDouble();
            
            AppLogger.info('✅ TMDB: Encontrado "$foundTitle" (sem ano)');
            AppLogger.debug('   Total de resultados: ${results.length}');
            AppLogger.debug('   Melhor match: "$foundTitle" - Rating: $foundRating');
            
            // Log dos primeiros 3 resultados para análise
            for (int i = 0; i < results.length && i < 3; i++) {
              final r = results[i];
              final t = r['title'] ?? r['name'] ?? 'Sem título';
              final rat = (r['vote_average'] ?? 0.0).toDouble();
              final yr = r['release_date'] ?? r['first_air_date'] ?? 'N/A';
              AppLogger.debug('   Resultado ${i + 1}: "$t" (${yr.substring(0, yr.length > 4 ? 4 : yr.length)}) - Rating: $rat');
            }
            
            return await _fetchDetails(result['id'], type);
          } else {
            AppLogger.warning('⚠️ TMDB: Nenhum resultado encontrado para "$title"');
            AppLogger.debug('   Response body (primeiros 200 chars): ${searchRes.body.length > 200 ? searchRes.body.substring(0, 200) : searchRes.body}');
          }
        } else if (searchRes.statusCode == 401) {
          AppLogger.error('❌ TMDB: API key inválida ou expirada! Status 401');
          return null;
        } else if (searchRes.statusCode == 429) {
          AppLogger.warning('⚠️ TMDB: Rate limit atingido');
          return null;
        } else {
          final errorBody = searchRes.body.length > 200 ? searchRes.body.substring(0, 200) : searchRes.body;
          AppLogger.error('❌ TMDB: Erro ${searchRes.statusCode}: $errorBody');
        }
      } catch (e) {
        AppLogger.error('❌ TMDB: Erro na busca sem ano: $e');
      }
    } catch (e, stackTrace) {
      AppLogger.error('❌ TMDB: Erro ao buscar "$title": $e');
      AppLogger.debug('Stack trace: $stackTrace');
    }
    return null;
  }

  /// Busca detalhes completos pelo ID
  static Future<TmdbMetadata?> _fetchDetails(int id, String type) async {
    try {
      final url = '$_baseUrl/$type/$id?api_key=$_apiKey&language=pt-BR&append_to_response=credits';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final metadata = TmdbMetadata.fromJson(data, type);
        AppLogger.debug('✅ TMDB: Detalhes carregados - Rating: ${metadata.rating}, Descrição: ${metadata.overview?.isNotEmpty ?? false}');
        return metadata;
      } else {
        AppLogger.warning('⚠️ TMDB: Erro ${res.statusCode} ao buscar detalhes do ID $id');
      }
    } catch (e, stackTrace) {
      AppLogger.error('❌ TMDB: Erro ao buscar detalhes do ID $id: $e');
      AppLogger.debug('Stack trace: $stackTrace');
    }
    return null;
  }

  /// Busca lista de filmes populares
  static Future<List<TmdbMetadata>> getPopularMovies({int page = 1}) async {
    if (!isConfigured) return [];
    
    try {
      final url = '$_baseUrl/movie/popular?api_key=$_apiKey&language=pt-BR&page=$page';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final results = data['results'] as List;
        return results.map((json) => TmdbMetadata.fromJson(json, 'movie')).toList();
      }
    } catch (e) {
      AppLogger.error('Erro ao buscar filmes populares', error: e);
    }
    return [];
  }

  /// Busca lista de filmes mais bem avaliados
  static Future<List<TmdbMetadata>> getTopRatedMovies({int page = 1}) async {
    if (!isConfigured) return [];
    
    try {
      final url = '$_baseUrl/movie/top_rated?api_key=$_apiKey&language=pt-BR&page=$page';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final results = data['results'] as List;
        return results.map((json) => TmdbMetadata.fromJson(json, 'movie')).toList();
      }
    } catch (e) {
      AppLogger.error('Erro ao buscar filmes mais avaliados', error: e);
    }
    return [];
  }

  /// Busca lista de filmes mais recentes
  static Future<List<TmdbMetadata>> getLatestMovies({int page = 1}) async {
    if (!isConfigured) return [];
    
    try {
      final url = '$_baseUrl/movie/now_playing?api_key=$_apiKey&language=pt-BR&page=$page';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final results = data['results'] as List;
        return results.map((json) => TmdbMetadata.fromJson(json, 'movie')).toList();
      }
    } catch (e) {
      AppLogger.error('Erro ao buscar filmes recentes', error: e);
    }
    return [];
  }

  /// Busca lista de séries populares
  static Future<List<TmdbMetadata>> getPopularSeries({int page = 1}) async {
    if (!isConfigured) return [];
    
    try {
      final url = '$_baseUrl/tv/popular?api_key=$_apiKey&language=pt-BR&page=$page';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final results = data['results'] as List;
        return results.map((json) => TmdbMetadata.fromJson(json, 'tv')).toList();
      }
    } catch (e) {
      AppLogger.error('Erro ao buscar séries populares', error: e);
    }
    return [];
  }

  /// Busca lista de séries mais bem avaliadas
  static Future<List<TmdbMetadata>> getTopRatedSeries({int page = 1}) async {
    if (!isConfigured) return [];
    
    try {
      final url = '$_baseUrl/tv/top_rated?api_key=$_apiKey&language=pt-BR&page=$page';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final results = data['results'] as List;
        return results.map((json) => TmdbMetadata.fromJson(json, 'tv')).toList();
      }
    } catch (e) {
      AppLogger.error('Erro ao buscar séries mais avaliadas', error: e);
    }
    return [];
  }
}

/// Modelo de metadados do TMDB
class TmdbMetadata {
  final int id;
  final String title;
  final String? overview;
  final double rating; // 0-10
  final double popularity;
  final String? releaseDate;
  final String? posterPath;
  final String? backdropPath;
  final List<String> genres;
  final int? runtime; // minutos
  final int? budget;
  final int? revenue;
  final List<String> languages;
  final List<CastMember> cast;
  final String? director;
  final String type; // 'movie' ou 'tv'

  TmdbMetadata({
    required this.id,
    required this.title,
    this.overview,
    this.rating = 0.0,
    this.popularity = 0.0,
    this.releaseDate,
    this.posterPath,
    this.backdropPath,
    this.genres = const [],
    this.runtime,
    this.budget,
    this.revenue,
    this.languages = const [],
    this.cast = const [],
    this.director,
    required this.type,
    });

    /// Serializa metadados para cache local
    Map<String, dynamic> toCacheJson() {
      return {
        'id': id,
        'title': title,
        'overview': overview,
        'rating': rating,
        'popularity': popularity,
        'releaseDate': releaseDate,
        'posterPath': posterPath,
        'backdropPath': backdropPath,
        'genres': genres,
        'runtime': runtime,
        'type': type,
      };
    }

    /// Reconstrói metadados a partir do formato de cache
    factory TmdbMetadata.fromCacheJson(Map<String, dynamic> json) {
      return TmdbMetadata(
        id: json['id'] ?? 0,
        title: json['title'] ?? '',
        overview: json['overview'],
        rating: (json['rating'] ?? 0.0).toDouble(),
        popularity: (json['popularity'] ?? 0.0).toDouble(),
        releaseDate: json['releaseDate'],
        posterPath: json['posterPath'],
        backdropPath: json['backdropPath'],
        genres: (json['genres'] as List?)?.map((e) => e.toString()).toList() ?? [],
        runtime: json['runtime'],
        budget: null,
        revenue: null,
        languages: const [],
        cast: const [],
        director: null,
        type: json['type'] ?? 'movie',
      );
    }

  factory TmdbMetadata.fromJson(Map<String, dynamic> json, String type) {
    // Extrair gêneros
    final genresList = <String>[];
    if (json['genres'] != null) {
      for (var g in json['genres']) {
        if (g['name'] != null) genresList.add(g['name']);
      }
    }

    // Extrair idiomas
    final languagesList = <String>[];
    if (json['spoken_languages'] != null) {
      for (var l in json['spoken_languages']) {
        if (l['iso_639_1'] != null) languagesList.add(l['iso_639_1'].toUpperCase());
      }
    }

    // Extrair elenco
    final castList = <CastMember>[];
    if (json['credits'] != null && json['credits']['cast'] != null) {
      final castData = json['credits']['cast'] as List;
      for (var c in castData.take(4)) {
        castList.add(CastMember(
          name: c['name'] ?? '',
          character: c['character'] ?? '',
          profilePath: c['profile_path'],
        ));
      }
    }

    // Extrair diretor
    String? director;
    if (json['credits'] != null && json['credits']['crew'] != null) {
      try {
        final crew = json['credits']['crew'] as List;
        final directorData = crew.cast<Map<String, dynamic>>().firstWhere(
          (c) => c['job'] == 'Director',
          orElse: () => <String, dynamic>{},
        );
        if (directorData.isNotEmpty && directorData['name'] != null) {
          director = directorData['name'];
        }
      } catch (e) {
        // Ignora erro ao buscar diretor
        AppLogger.debug('⚠️ TMDB: Erro ao buscar diretor: $e');
      }
    }

    return TmdbMetadata(
      id: json['id'] ?? 0,
      title: json['title'] ?? json['name'] ?? '',
      overview: json['overview'],
      rating: (json['vote_average'] ?? 0.0).toDouble(),
      popularity: (json['popularity'] ?? 0.0).toDouble(),
      releaseDate: json['release_date'] ?? json['first_air_date'],
      posterPath: json['poster_path'],
      backdropPath: json['backdrop_path'],
      genres: genresList,
      runtime: json['runtime'] ?? json['episode_run_time']?.first,
      budget: json['budget'],
      revenue: json['revenue'],
      languages: languagesList,
      cast: castList,
      director: director,
      type: type,
    );
  }

  /// URL completa do poster
  String? get posterUrl => posterPath != null ? 'https://image.tmdb.org/t/p/w500$posterPath' : null;

  /// URL completa do backdrop
  String? get backdropUrl => backdropPath != null ? 'https://image.tmdb.org/t/p/original$backdropPath' : null;
}

class CastMember {
  final String name;
  final String character;
  final String? profilePath;

  CastMember({
    required this.name,
    required this.character,
    this.profilePath,
  });

  String? get profileUrl => profilePath != null ? 'https://image.tmdb.org/t/p/w185$profilePath' : null;
}

