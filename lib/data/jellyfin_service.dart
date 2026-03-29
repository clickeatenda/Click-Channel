import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/content_item.dart';
import '../core/utils/logger.dart';

/// Serviço para integração com API do Jellyfin
/// Permite buscar e reproduzir conteúdo de um servidor Jellyfin
class JellyfinService {
  static String? _baseUrl;
  static String? _accessToken;
  static String? _userId;
  static String? _username;
  static String? _password;
  static String? _libraryId;
  
  static const _storage = FlutterSecureStorage();
  static const String _tokenKey = 'jellyfin_access_token';
  static const String _userIdKey = 'jellyfin_user_id';
  
  static const String _urlKey = 'jellyfin_url';
  static const String _usernameKey = 'jellyfin_username';
  static const String _passwordKey = 'jellyfin_password';
  
  static bool _initialized = false;
  static bool _authenticated = false;

  // Getters públicos para acesso externo
  static String get baseUrl => _baseUrl ?? '';
  static String get accessToken => _accessToken ?? '';

  /// Inicializa o serviço carregando configurações do .env ou storage
  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      await dotenv.load();
      
      // Tenta carregar do Storage primeiro (configuração manual do usuário)
      _baseUrl = await _storage.read(key: _urlKey);
      _username = await _storage.read(key: _usernameKey);
      _password = await _storage.read(key: _passwordKey);

      // Se não houver no storage, tenta do .env
      if (_baseUrl == null || _baseUrl!.isEmpty) {
        _baseUrl = dotenv.env['JELLYFIN_URL'];
        _username = dotenv.env['JELLYFIN_USERNAME'];
        _password = dotenv.env['JELLYFIN_PASSWORD'];
      }
      
      _libraryId = dotenv.env['JELLYFIN_LIBRARY_ID'];
      
      if (_baseUrl != null && _baseUrl!.isNotEmpty) {
        print('🐙 JellyfinService: Configurado para $_baseUrl');
        
        // Tenta recuperar token salvo
        _accessToken = await _storage.read(key: _tokenKey);
        _userId = await _storage.read(key: _userIdKey);
        
        if (_accessToken != null && _userId != null) {
          _authenticated = true;
          print('🐙 JellyfinService: Token recuperado do storage');
        }
        
        _initialized = true;
      } else {
        print('⚠️ JellyfinService: JELLYFIN_URL não configurado');
      }
    } catch (e) {
      print('❌ JellyfinService: Erro ao inicializar: $e');
    }
  }

  /// Salva as configurações do servidor
  static Future<void> saveConfig({
    required String url,
    required String username,
    required String password,
  }) async {
    _baseUrl = url;
    _username = username;
    _password = password;
    
    await _storage.write(key: _urlKey, value: url);
    await _storage.write(key: _usernameKey, value: username);
    await _storage.write(key: _passwordKey, value: password);
    
    _initialized = true;
    _authenticated = false; // Força re-autenticação com novas credenciais
    await _storage.delete(key: _tokenKey); // Limpa token antigo
    
    print('✅ JellyfinService: Configurações salvas');
  }

  /// Limpa as configurações salvas
  static Future<void> clearConfig() async {
    _baseUrl = null;
    _username = null;
    _password = null;
    _accessToken = null;
    _authenticated = false;
    
    await _storage.delete(key: _urlKey);
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _passwordKey);
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
    
    print('🧹 JellyfinService: Configurações limpas');
  }

  /// Retorna as credenciais atuais
  static Future<Map<String, String>> getCredentials() async {
    // Garante que está carregado
    if (!_initialized) await initialize();
    return {
      'url': _baseUrl ?? '',
      'username': _username ?? '',
      'password': _password ?? '',
    };
  }

  /// Verifica se o serviço está configurado e pronto para uso
  static bool get isConfigured => _baseUrl != null && _baseUrl!.isNotEmpty;
  
  /// Verifica se o usuário está autenticado
  static bool get isAuthenticated => _authenticated && _accessToken != null;

  /// Autentica com o servidor Jellyfin
  /// Retorna true se autenticação bem-sucedida
  static Future<bool> authenticate({String? username, String? password}) async {
    if (!_initialized) await initialize();
    if (!isConfigured) {
      print('❌ JellyfinService: Serviço não configurado');
      return false;
    }

    final user = username ?? _username;
    final pass = password ?? _password;

    if (user == null || pass == null || user.isEmpty || pass.isEmpty) {
      print('❌ JellyfinService: Credenciais não fornecidas');
      return false;
    }

    try {
      final url = '$_baseUrl/Users/AuthenticateByName';
      final deviceId = Platform.isAndroid ? 'clickchannel_android' : 'clickchannel_mobile';
      
      final headers = {
        'Content-Type': 'application/json',
        'X-Emby-Authorization': 'MediaBrowser Client="ClickChannel", Device="Mobile", DeviceId="$deviceId", Version="1.0"',
      };

      final body = jsonEncode({
        'Username': user,
        'Pw': pass,
      });

      print('🐙 JellyfinService: Tentando autenticar usuário $user...');
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['AccessToken'];
        _userId = data['User']['Id'];
        _authenticated = true;

        // Salva token de forma segura
        await _storage.write(key: _tokenKey, value: _accessToken);
        await _storage.write(key: _userIdKey, value: _userId);

        print('✅ JellyfinService: Autenticado com sucesso! UserId: $_userId');
        return true;
      } else {
        print('❌ JellyfinService: Falha na autenticação (${response.statusCode}): ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ JellyfinService: Erro ao autenticar: $e');
      return false;
    }
  }

  /// Desconecta do servidor e limpa credenciais
  static Future<void> logout() async {
    _accessToken = null;
    _userId = null;
    _authenticated = false;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
    print('🐙 JellyfinService: Logout realizado');
  }

  /// Busca bibliotecas disponíveis no servidor
  static Future<List<Map<String, dynamic>>> getLibraries() async {
    if (!isAuthenticated) {
      print('❌ JellyfinService: Não autenticado');
      return [];
    }

    try {
      final url = '$_baseUrl/Library/MediaFolders';
      final headers = {'X-MediaBrowser-Token': _accessToken!};

      final response = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final libraries = List<Map<String, dynamic>>.from(data['Items'] ?? []);
        print('✅ JellyfinService: ${libraries.length} bibliotecas encontradas');
        return libraries;
      } else {
        print('❌ JellyfinService: Erro ao buscar bibliotecas (${response.statusCode})');
        return [];
      }
    } catch (e) {
      print('❌ JellyfinService: Erro ao buscar bibliotecas: $e');
      return [];
    }
  }

  /// Busca itens de uma biblioteca específica
  static Future<List<ContentItem>> getItems({
    String? libraryId,
    String? searchTerm,
    String? itemType,
    int limit = 50,
  }) async {
    if (!isAuthenticated) {
      final authenticated = await authenticate();
      if (!authenticated) return [];
    }

    try {
      final libId = libraryId ?? _libraryId;
      final params = <String, String>{
        'Limit': limit.toString(),
      };

      // By default, Jellyfin Items API without Recursive only shows root folders/items.
      // To get all movies/series, we need Recursive=true, but MUST filter types so we don't get seasons/episodes loosely.
      if (itemType == null) {
        params['Recursive'] = 'true';
        params['IncludeItemTypes'] = 'Movie,Series';
      } else {
        params['IncludeItemTypes'] = itemType;
        // For seasons/episodes, we don't necessarily want recursive if we have a direct parent
        // but we'll leave it out or explicitly false if needed.
      }

      final fields = 'Overview,PrimaryImageAspectRatio,ProductionYear,CommunityRating,Genres,MediaSources,ImageTags';
      params['Fields'] = fields;

      if (libId != null && libId.isNotEmpty) {
        params['ParentId'] = libId;
      }

      if (searchTerm != null && searchTerm.isNotEmpty) {
        params['SearchTerm'] = searchTerm;
      }

      if (itemType != null) {
        params['IncludeItemTypes'] = itemType; // 'Movie', 'Series', etc.
      }

      final uri = Uri.parse('$_baseUrl/Items').replace(queryParameters: params);

      final headers = {
        'X-MediaBrowser-Token': _accessToken!,
        'Accept-Language': 'pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7',
      };

      print('🐙 JellyfinService: Buscando itens de $uri');
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = List<Map<String, dynamic>>.from(data['Items'] ?? []);
        print('✅ JellyfinService: ${items.length} itens encontrados');
        
        return items.map((item) => _mapJellyfinToContentItem(item)).toList();
      } else {
        print('❌ JellyfinService: Erro ao buscar itens (${response.statusCode})');
        return [];
      }
    } catch (e) {
      print('❌ JellyfinService: Erro ao buscar itens: $e');
      return [];
    }
  }

  /// Busca os itens mais recentes adicionados
  static Future<List<ContentItem>> getLatestItems({int count = 20}) async {
    if (!isAuthenticated) {
      final authenticated = await authenticate();
      if (!authenticated) return [];
    }

    try {
      final url = '$_baseUrl/Users/$_userId/Items/Latest?Limit=$count&IncludeItemTypes=Movie,Series&Fields=Overview,PrimaryImageAspectRatio,ProductionYear,CommunityRating,Genres,MediaSources,ImageTags';
      final headers = {
        'X-MediaBrowser-Token': _accessToken!,
        'Accept-Language': 'pt-BR,pt;q=0.9',
      };

      print('🐙 JellyfinService: Buscando últimos itens...');
      final response = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final items = List<Map<String, dynamic>>.from(jsonDecode(response.body));
        print('✅ JellyfinService: ${items.length} itens recentes encontrados');
        
        return items.map((item) => _mapJellyfinToContentItem(item)).toList();
      } else {
        print('❌ JellyfinService: Erro ao buscar últimos itens (${response.statusCode})');
        return [];
      }
    } catch (e) {
      print('❌ JellyfinService: Erro ao buscar últimos itens: $e');
      return [];
    }
  }

  /// Busca itens em destaque
  static Future<List<ContentItem>> getFeaturedItems({int count = 6}) async {
    if (!isAuthenticated) {
      final authenticated = await authenticate();
      if (!authenticated) return [];
    }

    try {
      final params = {
        'Recursive': 'true',
        'Limit': count.toString(),
        'IncludeItemTypes': 'Movie,Series',
        'SortBy': 'CommunityRating,DateCreated',
        'SortOrder': 'Descending',
        'Fields': 'Overview,PrimaryImageAspectRatio,ProductionYear,CommunityRating,Genres,MediaSources,ImageTags',
      };

      final uri = Uri.parse('$_baseUrl/Items').replace(queryParameters: params);
      final headers = {
        'X-MediaBrowser-Token': _accessToken!,
        'Accept-Language': 'pt-BR,pt;q=0.9',
      };

      print('🐙 JellyfinService: Buscando itens em destaque...');
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = List<Map<String, dynamic>>.from(data['Items'] ?? []);
        print('✅ JellyfinService: ${items.length} itens em destaque encontrados');
        
        return items.map((item) => _mapJellyfinToContentItem(item)).toList();
      } else {
        print('❌ JellyfinService: Erro ao buscar itens em destaque (${response.statusCode})');
        return [];
      }
    } catch (e) {
      print('❌ JellyfinService: Erro ao buscar itens em destaque: $e');
      return [];
    }
  }

  /// Gera URL de streaming para um item
  static String getStreamUrl(String itemId, {String? mediaSourceId}) {
    if (!isAuthenticated || _accessToken == null) {
      print('❌ JellyfinService: Não autenticado para gerar URL');
      return '';
    }

    // Permite transcoding/remuxing se necessário (mais compatível)
    final params = {
      'api_key': _accessToken!,
      'Static': 'true',
    };

    if (mediaSourceId != null) {
      params['MediaSourceId'] = mediaSourceId;
    }

    final uri = Uri.parse('$_baseUrl/Videos/$itemId/stream').replace(queryParameters: params);
    return uri.toString();
  }

  /// Gera URL de imagem para um item
  static String getImageUrl(String itemId, String imageTag, {String imageType = 'Primary'}) {
    if (_baseUrl == null) return '';
    return '$_baseUrl/Items/$itemId/Images/$imageType?tag=$imageTag';
  }
  
  /// Gera URL de legenda para um item
  static String getSubtitleUrl(String itemId, int streamIndex, String format) {
    if (!isAuthenticated || _accessToken == null || _baseUrl == null) {
      return '';
    }
    
    return '$_baseUrl/Videos/$itemId/$streamIndex/Subtitles.$format?api_key=$_accessToken';
  }

  // Force recompile verify
  
  /// Busca informações de mídia incluindo legendas disponíveis
  static Future<Map<String, dynamic>?> getMediaInfo(String itemId) async {
    if (!isAuthenticated || _accessToken == null) {
      print('❌ JellyfinService: Não autenticado');
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/Users/$_userId/Items/$itemId?api_key=$_accessToken'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('❌ JellyfinService: Erro ao buscar info de mídia: $e');
      return null;
    }
  }
  /// Busca temporadas de uma série
  static Future<List<ContentItem>> getSeasons(String seriesId) async {
    return getItems(
      libraryId: seriesId, // Usa o ID da série como pai
      itemType: 'Season',
      limit: 100,
    );
  }

  /// Busca episódios de uma temporada
  static Future<List<ContentItem>> getEpisodes(String seriesId, String seasonId) async {
    return getItems(
      libraryId: seasonId, // Usa o ID da temporada como pai
      itemType: 'Episode',
      limit: 1000,
    );
  }

  /// Converte um item do Jellyfin para ContentItem
  static ContentItem _mapJellyfinToContentItem(Map<String, dynamic> jellyfinItem) {
    final itemId = jellyfinItem['Id'] ?? '';
    final name = jellyfinItem['Name'] ?? 'Sem Título';
    final type = jellyfinItem['Type']?.toString().toLowerCase() ?? 'movie';
    final overview = jellyfinItem['Overview'] ?? '';
    final year = jellyfinItem['ProductionYear']?.toString() ?? '';
    final rating = (jellyfinItem['CommunityRating'] ?? 0.0).toDouble();
    final genres = List<String>.from(jellyfinItem['Genres'] ?? []);
    final genreStr = genres.isNotEmpty ? genres.first : '';

    // Gerar URL de imagem
    String imageUrl = '';
    print('DEBUG-COVER: ${jellyfinItem['Name']} - ImageTags: ${jellyfinItem['ImageTags']}');
    if (jellyfinItem['ImageTags'] != null && jellyfinItem['ImageTags']['Primary'] != null) {
      final imageTag = jellyfinItem['ImageTags']['Primary'];
      imageUrl = getImageUrl(itemId, imageTag);
      print('DEBUG-COVER: Generated URL -> $imageUrl');
    }

    // Gerar URL de streaming
    final streamUrl = getStreamUrl(itemId);

    // Determinar tipo de conteúdo
    final contentType = type == 'series' ? 'series' : type == 'movie' ? 'movie' : 'channel';
    final isSeries = type == 'series';

    // Determinar qualidade baseada nos MediaSources
    String quality = 'HD';
    if (jellyfinItem['MediaSources'] != null) {
      final sources = jellyfinItem['MediaSources'] as List;
      for (final source in sources) {
        if (source['MediaStreams'] != null) {
          final streams = source['MediaStreams'] as List;
          for (final stream in streams) {
            if (stream['Type'] == 'Video') {
              final width = stream['Width'] as int? ?? 0;
              // Ajustado para margem de segurança
              if (width >= 3800) {
                quality = '4K';
                break;
              } else if (width >= 1900) {
                quality = 'FHD';
              }
            }
          }
        }
        if (quality == '4K') break; 
      }
    }

    return ContentItem(
      id: itemId,
      title: name,
      url: streamUrl,
      image: imageUrl,
      group: 'Jellyfin', // Pode ser customizado baseado em coleções
      type: contentType,
      isSeries: isSeries,
      rating: rating,
      year: year,
      description: overview,
      genre: genreStr,
      quality: quality,
      originalTitle: jellyfinItem['OriginalTitle'],
    );
  }

  /// Testa a conexão com o servidor
  static Future<bool> testConnection() async {
    if (!isConfigured) return false;

    try {
      final url = '$_baseUrl/System/Info/Public';
      print('🐙 JellyfinService: Testando conexão com $url');
      
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final serverName = data['ServerName'] ?? 'Desconhecido';
        final version = data['Version'] ?? 'Desconhecida';
        print('✅ JellyfinService: Conectado ao servidor $serverName (v$version)');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ JellyfinService: Erro ao testar conexão: $e');
      return false;
    }
  }
}
