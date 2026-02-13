import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  print('🔍 Diagnóstico de Autenticação Jellyfin (v23 - package:http)');
  
  // 1. Carregar .env
  final env = loadEnv();
  
  String? baseUrl = env['JELLYFIN_URL'];
  String? username = env['JELLYFIN_USERNAME'];
  String? password = env['JELLYFIN_PASSWORD'];

  if (baseUrl == null) {
      print('⚠️ .env não encontrado. Modo Interativo Iniciado.');
      print('Digite a URL do Jellyfin (ex: http://jellyfin.server):');
      baseUrl = stdin.readLineSync()?.trim();
      
      print('Digite o Usuário:');
      username = stdin.readLineSync()?.trim();
      
      print('Digite a Senha:');
      password = stdin.readLineSync()?.trim();
  }

  if (baseUrl == null || baseUrl.isEmpty || username == null || username.isEmpty || password == null) {
     print('❌ Credenciais inválidas (vazias). Abortando.');
     return;
  }
  
  // Sanitize URL
  if (baseUrl.endsWith('/')) {
    baseUrl = baseUrl.substring(0, baseUrl.length - 1);
  }
  
  // 2. Autenticar
  final authResult = await authenticate(baseUrl, username, password);
  
  if (authResult != null) {
      final token = authResult['Token']!;
      final userId = authResult['UserId']!;
      
      // 3. Buscar Item para teste
      final itemId = await fetchFirstItem(baseUrl, userId, token);
      
      if (itemId != null) {
          // 4. Testar GetMediaInfo (Legendas)
          await testGetMediaInfo(baseUrl, itemId, userId, token);
      }
  }
}

Future<Map<String, String>?> authenticate(String baseUrl, String username, String password) async {
    final url = '$baseUrl/Users/AuthenticateByName';
    print('� Tentando autenticar (Package:http) em $url...');

    try {
        final body = jsonEncode({
            'Username': username,
            'Pw': password,
        });
        
        // Header idêntico ao App
        final authHeader = 'MediaBrowser Client="ClickChannel", Device="App", DeviceId="clickchannel_windows", Version="1.0.0"';
        
        final headers = {
            'Content-Type': 'application/json',
            'X-Emby-Authorization': authHeader,
            // 'Accept': 'application/json', // REMOVED: App isn't sending this on Auth
        };

        // HttpClient do package:http cuida de Content-Length e Encoding
        final response = await http.post(
            Uri.parse(url),
            headers: headers,
            body: body
        );

        if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final token = data['AccessToken'];
            final userId = data['User']['Id'];
            print('✅ Autenticado! Token: ${token.substring(0, 5)}... UserId: $userId');
            return {'Token': token, 'UserId': userId};
        } else {
            print('❌ Erro Auth: ${response.statusCode} - ${response.body}');
            return null;
        }
    } catch (e) {
        print('❌ Exceção Auth: $e');
        return null;
    }
}

Future<String?> fetchFirstItem(String baseUrl, String userId, String token) async {
    final url = '$baseUrl/Users/$userId/Items?Recursive=true&IncludeItemTypes=Movie,Episode&Limit=1';
    print('🔍 Buscando item válido...');
    
    try {
        final headers = {
            'X-MediaBrowser-Token': token,
            'Accept': 'application/json',
        };
        
        final response = await http.get(Uri.parse(url), headers: headers);
        
        if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['Items'] != null && data['Items'].isNotEmpty) {
                final item = data['Items'][0];
                print('✅ Item encontrado: ${item['Name']} (ID: ${item['Id']})');
                return item['Id'];
            }
        }
        print('❌ Falha ao buscar itens: ${response.statusCode}');
        return null;
    } catch (e) {
        print('❌ Erro busca: $e');
        return null;
    }
}

Future<void> testGetMediaInfo(String baseUrl, String itemId, String userId, String token) async {
    // CRITICAL: Using PlaybackInfo endpoint logic
    final url = '$baseUrl/Items/$itemId/PlaybackInfo?UserId=$userId';
    
    print('--------------------------------------------------');
    print('🔍 Testando PlaybackInfo (v28 - Native)...');
    print('URL: $url');
    
    try {
        final headers = {
            'X-MediaBrowser-Token': token,
            'Content-Type': 'application/json',
            'Accept': 'application/json',
        };
        
        final body = jsonEncode({
            'DeviceProfile': {'Name': 'ClickChannel Diagnostic', 'MaxStreamingBitrate': 120000000},
        });
        
        final response = await http.post(
            Uri.parse(url), 
            headers: headers, 
            body: body
        );
        
        print('STATUS: ${response.statusCode}');
        if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            
            // Check Subtitles
            if (data['MediaSources'] != null) {
                final sources = data['MediaSources'] as List;
                print('📦 MediaSources: ${sources.length}');
                
                for (var source in sources) {
                   print('   👉 Source [${source['Name']}] (Container: ${source['Container']})');
                   
                   if (source['MediaStreams'] != null) {
                       final streams = source['MediaStreams'] as List;
                       final subs = streams.where((s) => s['Type'] == 'Subtitle').toList();
                       final audio = streams.where((s) => s['Type'] == 'Audio').toList();
                       
                       print('      🔊 Áudio Tracks: ${audio.length}');
                       print('      📝 Legendas Encontradas: ${subs.length}');
                       
                       for (var sub in subs) {
                           print('         - [Index ${sub['Index']}] ${sub['Title'] ?? sub['Language'] ?? 'Unknown'} (Codec: ${sub['Codec']}) (Ext: ${sub['IsExternal']})');
                       }
                   } else {
                       print('⚠️ Sem MediaStreams no Source!');
                   }
                }
            } else {
                print('⚠️ Campo "MediaSources" vazio na resposta.');
            }
        } else {
            print('❌ Falha PlaybackInfo: ${response.statusCode} - ${response.body}');
        }
    } catch (e) {
        print('❌ Exceção PlaybackInfo: $e');
    }
}

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
