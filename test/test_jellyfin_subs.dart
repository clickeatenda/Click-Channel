import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  print('🔍 Diagnóstico de Legendas Jellyfin (v23)');
  
  // 1. Carregar .env
  final env = loadEnv();
  
  String? baseUrl = env['JELLYFIN_URL'];
  String? username = env['JELLYFIN_USERNAME'];
  String? password = env['JELLYFIN_PASSWORD'];

  if (baseUrl == null) {
      print('⚠️ .env não encontrado. Modo Interativo Iniciado.');
      print('Digite a URL do Jellyfin:');
      baseUrl = stdin.readLineSync()?.trim();
      print('Digite o Usuário:');
      username = stdin.readLineSync()?.trim();
      print('Digite a Senha:');
      password = stdin.readLineSync()?.trim();
  }

  if (baseUrl == null || username == null || password == null) {
     print('❌ Credenciais inválidas. Abortando.');
     return;
  }
  
  // 2. Autenticar
  final authResult = await authenticate(baseUrl, username, password);
  if (authResult == null) return;
  
  final token = authResult['Token']!;
  final userId = authResult['UserId']!;

  // 3. Buscar Item
  final item = await fetchFirstItemWithSubtitles(baseUrl, userId, token);
  if (item == null) {
      print('❌ Nenhum item com legendas encontrado para teste.');
      return;
  }

  final itemId = item['Id'];
  print('✅ Item selecionado: ${item['Name']} (ID: $itemId)');

  // 4. Listar Legendas
  final subtitles = await listSubtitles(item);
  if (subtitles.isEmpty) {
      print('❌ Item não possui streams de legenda (Type=Subtitle).');
      return;
  }

  // 5. Testar Download da Primeira Legenda
  final firstSub = subtitles[0];
  await testSubtitleDownload(baseUrl, itemId, firstSub, token);
}

// ... Helpers ...

Map<String, String> loadEnv() {
  final absFile = File('d:\\ClickeAtenda-DEV\\Vs\\Click-Channel\\.env');
  if (absFile.existsSync()) return _parseEnv(absFile);
  return {};
}

Map<String, String> _parseEnv(File file) {
    final lines = file.readAsLinesSync();
    final map = <String, String>{};
    for (var line in lines) {
        if (line.trim().isEmpty || line.startsWith('#')) continue;
        final parts = line.split('=');
        if (parts.length >= 2) {
          map[parts[0].trim()] = parts.sublist(1).join('=').trim();
        }
    }
    return map;
}

Future<Map<String, String>?> authenticate(String currBaseUrl, String username, String password) async {
  var baseUrl = currBaseUrl;
  while (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);

  final url = '$baseUrl/Users/AuthenticateByName';
  final deviceId = 'diagnostic_script_subs';
  final authHeader = 'MediaBrowser Client="ClickChannel Diag", Device="Script", DeviceId="$deviceId", Version="1.0.0"';

  print('🔄 Autenticando...');
  try {
    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) => true; 
    
    final request = await client.postUrl(Uri.parse(url));
    request.headers.add('Content-Type', 'application/json');
    request.headers.add('X-Emby-Authorization', authHeader);
    
    request.write(jsonEncode({'Username': username, 'Pw': password}));
    
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      return {'Token': data['AccessToken'], 'UserId': data['User']['Id']};
    } else {
      print('❌ Erro Auth: ${response.statusCode}');
      return null;
    }
  } catch (e) {
    print('❌ Exceção Auth: $e');
    return null;
  }
}

Future<Map<String, dynamic>?> fetchFirstItemWithSubtitles(String baseUrl, String userId, String token) async {
    // Buscar filmes/episodios recentes
    final url = '$baseUrl/Users/$userId/Items?Recursive=true&IncludeItemTypes=Movie,Episode&Limit=5&Fields=MediaSources';
    print('🔍 Buscando itens...');
    
    try {
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) => true;
        final request = await client.getUrl(Uri.parse(url));
        request.headers.add('X-MediaBrowser-Token', token);
        
        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();
        
        if (response.statusCode == 200) {
            final data = jsonDecode(body);
            final items = data['Items'] as List;
            
            for (var item in items) {
                if (item['MediaSources'] != null) {
                    final source = item['MediaSources'][0];
                    if (source['MediaStreams'] != null) {
                        final streams = source['MediaStreams'] as List;
                        final hasSubs = streams.any((s) => s['Type'] == 'Subtitle');
                        if (hasSubs) return item;
                    }
                }
            }
        }
        return null;
    } catch (e) {
        print('❌ Erro busca: $e');
        return null;
    }
}

Future<List<Map<String, dynamic>>> listSubtitles(Map<String, dynamic> item) async {
    final subs = <Map<String, dynamic>>[];
    final source = item['MediaSources'][0];
    final streams = source['MediaStreams'] as List;
    
    print('📝 Verificando streams...');
    for (var stream in streams) {
        if (stream['Type'] == 'Subtitle') {
            print('   - Encontrada: ${stream['Title'] ?? stream['Language']} (Codec: ${stream['Codec']}, Index: ${stream['Index']})');
            subs.add(stream);
        }
    }
    return subs;
}

Future<void> testSubtitleDownload(String baseUrl, String itemId, Map<String, dynamic> sub, String token) async {
    final index = sub['Index'];
    final codec = sub['Codec'] ?? 'vtt';
    String format = 'vtt';
    if (codec == 'srt' || codec == 'subrip') format = 'srt';
    
    final url = '$baseUrl/Videos/$itemId/$index/Subtitles.$format';
    
    print('--------------------------------------------------');
    print('📥 Testando Download: $url');
    
    final deviceId = 'diagnostic_script_subs';
    final authHeader = 'MediaBrowser Client="ClickChannel Diag", Device="Script", DeviceId="$deviceId", Version="1.0.0"';
    
    try {
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) => true;
        
        final request = await client.getUrl(Uri.parse(url));
        request.headers.add('X-Emby-Authorization', authHeader);
        
        final response = await request.close();
        
        print('STATUS: ${response.statusCode}');
        if (response.statusCode == 200) {
            final bytes = await response.length;
            print('✅ Download OK! Tamanho: $bytes bytes');
            
            // Preview do conteúdo
            final content = await response.transform(utf8.decoder).join();
            print('📄 Preview (primeiros 100 chars):');
            print(content.substring(0, content.length > 100 ? 100 : content.length));
        } else {
            print('❌ Falha Download: ${response.statusCode}');
        }
    } catch (e) {
        print('❌ Exceção Download: $e');
    }
}
