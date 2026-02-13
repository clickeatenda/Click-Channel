import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import '../models/content_item.dart';

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
  static String get accessToken => _accessToken ?? '';
  
  /// Retorna o DeviceId consistente
  static String _getDeviceId() {
    if (Platform.isAndroid) return 'clickchannel_android';
    if (Platform.isIOS) return 'clickchannel_ios';
    if (Platform.isWindows) return 'clickchannel_windows';
    return 'clickchannel_web';
  }

  /// Gera o header de autorização padrão
  static String getAuthorizationHeader() {
    return 'MediaBrowser Client="ClickChannel", Device="App", DeviceId="${_getDeviceId()}", Version="1.0.0"';
  }

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

      // Sanitize URL (remove trailing slash)
      if (_baseUrl != null) {
         while (_baseUrl!.endsWith('/')) {
           _baseUrl = _baseUrl!.substring(0, _baseUrl!.length - 1);
         }
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
    // Remove trailing slash
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

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
      
      final headers = {
        'Content-Type': 'application/json',
        'X-Emby-Authorization': getAuthorizationHeader(),
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
        'Recursive': 'true',
        'Limit': limit.toString(),
        'Fields': 'Overview,PrimaryImageAspectRatio,ProductionYear,CommunityRating,Genres,MediaSources,Id,EpisodeId,SeriesId',
      };

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
      final url = '$_baseUrl/Users/$_userId/Items/Latest?Limit=$count&IncludeItemTypes=Movie,Series&Fields=Overview,PrimaryImageAspectRatio,ProductionYear,CommunityRating,Genres,MediaSources';
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
        'Fields': 'Overview,PrimaryImageAspectRatio,ProductionYear,CommunityRating,Genres,MediaSources',
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
    };

    if (mediaSourceId != null) {
      params['MediaSourceId'] = mediaSourceId;
    }

    final uri = Uri.parse('$_baseUrl/Videos/$itemId/stream').replace(queryParameters: params);
    return uri.toString();
  }

  /// Gera URL de HLS transcoding para itens que não suportam Direct Play.
  /// Usa o endpoint /master.m3u8 do Jellyfin para transcodificar server-side.
  static String getHlsTranscodingUrl(String itemId, {String? mediaSourceId}) {
    if (!isAuthenticated || _accessToken == null) {
      print('❌ JellyfinService: Não autenticado para gerar URL HLS');
      return '';
    }

    final params = {
      'api_key': _accessToken!,
      'DeviceId': 'ClickChannel',
      'PlaySessionId': DateTime.now().millisecondsSinceEpoch.toString(),
      'VideoCodec': 'h264',
      'AudioCodec': 'aac,mp3',
      'MaxAudioChannels': '2',
      'TranscodingMaxAudioChannels': '2',
      'VideoBitRate': '8000000', // 8 Mbps
      'AudioBitRate': '192000',
      'MaxStreamingBitrate': '10000000', // 10 Mbps
      'TranscodingContainer': 'ts',
      'TranscodingProtocol': 'hls',
      'SegmentContainer': 'ts',
      'MinSegments': '2',
      'BreakOnNonKeyFrames': 'true',
      'RequireAvc': 'false',
      'SubtitleMethod': 'Encode',
    };

    if (mediaSourceId != null) {
      params['MediaSourceId'] = mediaSourceId;
    }

    final uri = Uri.parse('$_baseUrl/Videos/$itemId/master.m3u8').replace(queryParameters: params);
    print('🔄 [JELLYFIN] HLS Transcoding URL: $uri');
    return uri.toString();
  }

  /// Gera URL de imagem para um item
  static String getImageUrl(String itemId, String imageTag, {
    String imageType = 'Primary',
    int? maxWidth,
    int? maxHeight,
    int? quality = 90,
  }) {
    if (_baseUrl == null) return '';
    
    var url = '$_baseUrl/Items/$itemId/Images/$imageType?tag=$imageTag&quality=$quality';
    
    if (maxWidth != null) url += '&maxWidth=$maxWidth';
    if (maxHeight != null) url += '&maxHeight=$maxHeight';
    
    return url;
  }
  
  static String getSubtitleUrl(String itemId, int streamIndex, String format, {String? mediaSourceId}) {
    if (!isAuthenticated || _accessToken == null || _baseUrl == null) {
      return '';
    }
    final targetId = mediaSourceId ?? itemId;
    // Correct API format: /Videos/{Id}/{MediaSourceId}/Subtitles/{Index}/Stream.{Format}
    return '$_baseUrl/Videos/$itemId/$targetId/Subtitles/$streamIndex/Stream.$format?api_key=$_accessToken';
  }


  /// Baixa a legenda e salva em arquivo temporário (Fix Auth v22)
  /// Baixa a legenda e retorna o caminho do arquivo local
  static Future<String?> downloadSubtitle(String itemId, int streamIndex, String format, {String? mediaSourceId}) async {
    if (!isAuthenticated) return null;

    try {
      final apiKey = _accessToken ?? '';
      // Usa MediaSourceId se disponível, senão usa ItemId
      final targetId = mediaSourceId ?? itemId;
      
      // Adiciona api_key na URL também para garantir
      // Correct API format: /Videos/{Id}/{MediaSourceId}/Subtitles/{Index}/Stream.{Format}
      final url = '$_baseUrl/Videos/$itemId/$targetId/Subtitles/$streamIndex/Stream.$format?api_key=$apiKey';
      print('📥 [JELLYFIN] Baixando legenda: $url');

      final headers = {
        'X-Emby-Authorization': getAuthorizationHeader(),
      };

      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) => true; // Bypass SSL

      final request = await client.getUrl(Uri.parse(url));
      headers.forEach((k, v) => request.headers.add(k, v));
      
      final response = await request.close();
      
      if (response.statusCode == 200) {
        // Usa diretório temporário seguro via plugin
        final tempDir = await getTemporaryDirectory();
        // Sanitizar nome do arquivo
        final safeId = itemId.replaceAll(RegExp(r'[^\w\.-]'), '');
        final fileName = 'clickchannel_sub_${safeId}_$streamIndex.$format';
        final file = File('${tempDir.path}/$fileName');
        
        // Deleta se já existir para evitar conflito/lock
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (e) {
            print('⚠️ [JELLYFIN] Falha ao deletar arquivo antigo de legenda: $e');
          }
        }
        
        final bytes = await response.fold<List<int>>([], (buffer, chunk) => buffer..addAll(chunk));

        if (bytes.isNotEmpty) {
           String content;
           try {
             content = utf8.decode(bytes);
           } catch (e) {
             content = latin1.decode(bytes);
           }

           // CRÍTICO: Verificar conteúdo
           if (content.trim().startsWith('<!DOCTYPE') || content.trim().startsWith('<html')) {
              print('❌ [JELLYFIN] ERRO CRÍTICO: O arquivo baixado é HTML/Erro!');
              return null;
           }

           final sink = file.openWrite();
           sink.write(content);
           await sink.flush();
           await sink.close();
           
           print('✅ [JELLYFIN] Legenda salva (UTF-8): ${file.absolute.path} (${bytes.length} bytes)');
           await Future.delayed(const Duration(milliseconds: 100));
           return file.absolute.path;
        } else {
           print('⚠️ [JELLYFIN] Arquivo de legenda está VAZIO! (0 bytes)');
           return null;
        }
      } else {
        print('❌ [JELLYFIN] Erro ao baixar legenda: ${response.statusCode} - URL: $url');
        return null;
      }
    } catch (e) {
      print('❌ [JELLYFIN] Exceção download legenda: $e');
      return null;
    }
  }

  /// Baixa o CONTEÚDO da legenda (Texto) para uso em Data URI
  static Future<String?> getSubtitleContent(String itemId, int streamIndex, String format, {String? mediaSourceId}) async {
    try {
      final apiKey = _accessToken ?? '';
      final targetId = mediaSourceId ?? itemId;
      final url = '$_baseUrl/Videos/$itemId/$targetId/Subtitles/$streamIndex/Stream.$format?api_key=$apiKey';
      print('📥 [JELLYFIN] Buscando conteúdo da legenda: $url');

      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) => true; 

      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('X-Emby-Authorization', getAuthorizationHeader());
      
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final bytes = await response.fold<List<int>>([], (buffer, chunk) => buffer..addAll(chunk));
        String content;
        try {
          content = utf8.decode(bytes);
        } catch (e) {
          content = latin1.decode(bytes);
        }

        if (content.trim().startsWith('<!DOCTYPE') || content.trim().startsWith('<html')) {
           print('❌ [JELLYFIN] Conteúdo é HTML/Erro!');
           return null;
        }
        
        print('✅ [JELLYFIN] Conteúdo da legenda baixado: ${content.length} chars');
        return content;
      } else {
        print('❌ [JELLYFIN] Erro HTTP ao buscar legenda: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ [JELLYFIN] Erro ao buscar conteúdo da legenda: $e');
      return null;
    }
  }

  // Force recompile verify
  
  /// Busca informações de mídia incluindo legendas disponíveis
  static Future<Map<String, dynamic>?> getMediaInfo(String itemId) async {
    if (!isAuthenticated || _accessToken == null) {
      print('❌ JellyfinService: Não autenticado');
      return null;
    }

    try {
      final url = '$_baseUrl/Items/$itemId/PlaybackInfo?UserId=$_userId';
      
      final body = jsonEncode({
        'DeviceProfile': {'Name': 'ClickChannel', 'MaxStreamingBitrate': 120000000},
      });
      
      print('🔍 [JELLYFIN] Buscando PlaybackInfo: $url');
      
      // CRÍTICO: Usar HttpClient com bypass SSL (mesmo padrão de downloadSubtitle)
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) => true;
      
      final request = await client.postUrl(Uri.parse(url));
      request.headers.set('X-MediaBrowser-Token', _accessToken!);
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Accept', 'application/json');
      request.write(body);
      
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      
      print('🔍 [JELLYFIN] PlaybackInfo status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        
        if (data['MediaSources'] != null) {
           final sources = data['MediaSources'] as List;
           print('📦 [JELLYFIN] Fontes encontradas: ${sources.length}');
           for(var s in sources) {
             final streams = s['MediaStreams'] as List? ?? [];
             final subs = streams.where((st) => st['Type'] == 'Subtitle').toList();
             final audios = streams.where((st) => st['Type'] == 'Audio').toList();
             print('   👉 Source ${s['Name']}: ${subs.length} legendas, ${audios.length} áudios');
           }
        }
        
        client.close();
        return data;
      } else {
        print('❌ [JELLYFIN] Erro PlaybackInfo: ${response.statusCode} - $responseBody');
        client.close();
        return null;
      }
    } catch (e) {
      print('❌ [JELLYFIN] Exceção PlaybackInfo: $e');
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
    if (!isAuthenticated) {
      final authenticated = await authenticate();
      if (!authenticated) return [];
    }

    try {
      // FIX: Usar endpoint específico /Shows/{Id}/Episodes em vez de /Items
      // Este endpoint garante que os IDs retornados são de episódios válidos
      final params = <String, String>{
        'SeasonId': seasonId,
        'Fields': 'Overview,PrimaryImageAspectRatio,ProductionYear,CommunityRating,Genres,MediaSources',
      };

      final uri = Uri.parse('$_baseUrl/Shows/$seriesId/Episodes').replace(queryParameters: params);
      
      final headers = {
        'X-MediaBrowser-Token': _accessToken!,
        'Accept-Language': 'pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7',
      };

      print('🐙 JellyfinService: Buscando episódios de $uri');
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = List<Map<String, dynamic>>.from(data['Items'] ?? []);
        print('✅ JellyfinService: ${items.length} episódios encontrados');
        
        // DEBUG: Imprimir IDs dos primeiros 3 episódios da API
        if (items.isNotEmpty) {
          for (int i = 0; i < (items.length < 3 ? items.length : 3); i++) {
            final item = items[i];
            print('   📋 API Episode $i: Id=${item['Id']}, Type=${item['Type']}, Name=${item['Name']}');
          }
        }
        
        return items.map((item) => _mapJellyfinToContentItem(item)).toList();
      } else {
        print('❌ JellyfinService: Erro ao buscar episódios (${response.statusCode})');
        return [];
      }
    } catch (e) {
      print('❌ JellyfinService: Erro ao buscar episódios: $e');
      return [];
    }
  }

  /// Converte um item do Jellyfin para ContentItem
  static ContentItem _mapJellyfinToContentItem(Map<String, dynamic> jellyfinItem) {
    var itemId = jellyfinItem['Id']?.toString() ?? '';
    final type = jellyfinItem['Type']?.toString().toLowerCase() ?? 'movie';
    final name = jellyfinItem['Name'] ?? 'Sem Título';

    // FIX: Priorizar EpisodeId para episódios para evitar colisão com SeriesId
    if (type == 'episode' && jellyfinItem['EpisodeId'] != null) {
       itemId = jellyfinItem['EpisodeId'].toString();
    } else if (itemId.isEmpty) {
       itemId = jellyfinItem['EpisodeId']?.toString() ?? ''; // Tentativa de fallback
    }
    
    // DEBUG: Verificar IDs de episódios COM MAIS DETALHES
    if (type == 'episode') {
      print('🔍 [Mapping] Episode: "$name"');
      print('   └─ FINAL ID USADO: $itemId');
      print('   └─ Raw API Id: ${jellyfinItem['Id']}');
      print('   └─ SeasonId: ${jellyfinItem['SeasonId']}');
      print('   └─ SeriesId: ${jellyfinItem['SeriesId']}');
    }

    final overview = jellyfinItem['Overview'] ?? '';
    final year = jellyfinItem['ProductionYear']?.toString() ?? '';
    final rating = (jellyfinItem['CommunityRating'] ?? 0.0).toDouble();
    final genres = List<String>.from(jellyfinItem['Genres'] ?? []);
    final genreStr = genres.isNotEmpty ? genres.first : '';
    
    
    // Gerar URL de imagem com fallback e OTIMIZADO
    String imageUrl = '';
    
    if (jellyfinItem['ImageTags'] != null) {
      final tags = jellyfinItem['ImageTags'];
      if (tags['Primary'] != null) {
        // Poster: Limitado a 500px de largura (bom para mobile/TV grids)
        imageUrl = getImageUrl(itemId, tags['Primary']!, maxWidth: 500);
      } else if (tags['Backdrop'] != null) {
        // Backdrop: Limitado a 1280px (720p) - suficiente para backgrounds
        imageUrl = getImageUrl(itemId, tags['Backdrop']!, imageType: 'Backdrop', maxWidth: 1280);
      } else if (tags['Thumb'] != null) {
        // Thumb: Limitado a 600px
        imageUrl = getImageUrl(itemId, tags['Thumb']!, imageType: 'Thumb', maxWidth: 600);
      }
    }

    // Gerar URL de streaming
    final streamUrl = getStreamUrl(itemId);

    // Determinar tipo de conteúdo
    // Fix: Video, Recording e TvProgram devem ser tratados como 'movie' (VOD)
    // 'episode' deve ser mantido como 'episode' para não quebrar navegação de séries
    final isVod = ['movie', 'video', 'recording', 'tvprogram'].contains(type);
    
    String contentType;
    if (type == 'series') {
      contentType = 'series';
    } else if (type == 'episode') {
      contentType = 'episode';
    } else if (isVod) {
      contentType = 'movie';
    } else {
      contentType = 'channel';
    }

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
