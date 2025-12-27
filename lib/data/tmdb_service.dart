import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import '../core/utils/logger.dart';

/// Serviço para buscar metadados de filmes e séries do TMDB
class TmdbService {
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static String? _apiKey;

  /// Token TMDB hardcoded (read-only token JWT)
  /// O token contém a API key no campo "aud": "[REDACTED_TMDB_API_KEY]"
  static const String _hardcodedToken = '[REDACTED_TMDB_JWT]';
  
  /// API Key extraída do token JWT (campo "aud")
  static const String _hardcodedApiKey = '[REDACTED_TMDB_API_KEY]';

  /// Inicializa a API key do TMDB (usa API key hardcoded ou .env)
  static void init() {
    // Prioriza API key hardcoded extraída do token, fallback para .env
    _apiKey = _hardcodedApiKey;
    if (_apiKey == null || _apiKey!.isEmpty) {
      _apiKey = Config.tmdbApiKey;
      if (_apiKey == null || _apiKey!.isEmpty) {
        AppLogger.warning('⚠️ TMDB_API_KEY não configurada');
      } else {
        AppLogger.info('✅ TMDB API key do .env carregada');
      }
    } else {
      AppLogger.info('✅ TMDB API key hardcoded carregada: ${_apiKey!.substring(0, 8)}...');
    }
    
    // CRÍTICO: Testa a API key imediatamente após inicialização
    _testApiKey();
  }
  
  /// Testa se a API key está funcionando
  static Future<void> _testApiKey() async {
    if (_apiKey == null || _apiKey!.isEmpty) return;
    
    try {
      // Testa com um filme conhecido (ID 550 = Fight Club)
      final testUrl = '$_baseUrl/movie/550?api_key=$_apiKey';
      final res = await http.get(Uri.parse(testUrl)).timeout(const Duration(seconds: 5));
      
      if (res.statusCode == 200) {
        AppLogger.info('✅ TMDB: API key válida e funcionando');
      } else if (res.statusCode == 401) {
        AppLogger.error('❌ TMDB: API key INVÁLIDA ou EXPIRADA! Status 401');
        AppLogger.error('❌ TMDB: Verifique se a API key está correta e ativa');
      } else if (res.statusCode == 429) {
        AppLogger.warning('⚠️ TMDB: Rate limit atingido no teste inicial');
      } else {
        AppLogger.warning('⚠️ TMDB: Status ${res.statusCode} no teste da API key');
      }
    } catch (e) {
      AppLogger.warning('⚠️ TMDB: Erro ao testar API key: $e');
    }
  }

  /// Verifica se a API key está configurada
  static bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  /// Busca informações completas de um filme/série pelo título
  static Future<TmdbMetadata?> searchContent(String title, {String? year, String type = 'movie'}) async {
    if (!isConfigured) {
      AppLogger.warning('TMDB API key não configurada');
      return null;
    }

    try {
      AppLogger.info('🔍 TMDB: Buscando "$title" (tipo: $type${year != null ? ", ano: $year" : ""})');
      
      // CRÍTICO: Verifica se API key está configurada
      if (_apiKey == null || _apiKey!.isEmpty) {
        AppLogger.error('❌ TMDB: API key não configurada!');
        return null;
      }
      
      // TMDB API v3 usa api_key como query parameter
      final searchUrl = '$_baseUrl/search/$type?api_key=$_apiKey&query=${Uri.encodeComponent(title)}&language=pt-BR';
      
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
            final result = searchData['results'][0];
            final foundTitle = result['title'] ?? result['name'] ?? 'Sem título';
            AppLogger.info('✅ TMDB: Encontrado "$foundTitle" (sem ano)');
            return await _fetchDetails(result['id'], type);
          } else {
            AppLogger.warning('⚠️ TMDB: Nenhum resultado encontrado para "$title"');
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

