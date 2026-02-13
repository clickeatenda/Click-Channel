import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

// Configuração Manual (preenchida pelo script ao ler .env se possível)
String baseUrl = '';
String username = '';
String password = '';

Future<void> main() async {
  print('🔍 Diagnóstico de URL Jellyfin');
  
  // Tentar ler .env
  try {
    final envFile = File('.env');
    if (await envFile.exists()) {
      final content = await envFile.readAsString();
      final lines = content.split(RegExp(r'\r\n|\r|\n'));
      
      print('📄 .env size: ${content.length}');
      print('📄 .env lines: ${lines.length}');

      for (var line in lines) {
        if (line.trim().isEmpty || line.startsWith('#')) continue;
        
        var parts = line.split('=');
        if (parts.length < 2) continue;
        
        var key = parts[0].trim();
        print('🔑 Found key: "$key"'); // Debug
        
        var value = parts.sublist(1).join('=').trim(); // Rejoin if value has =
        
        // Remove quotes
        if (value.startsWith('"') && value.endsWith('"')) value = value.substring(1, value.length - 1);
        if (value.startsWith("'") && value.endsWith("'")) value = value.substring(1, value.length - 1);

        if (key == 'JELLYFIN_URL') baseUrl = value;
        if (key == 'JELLYFIN_USERNAME') username = value;
        if (key == 'JELLYFIN_PASSWORD') password = value;
      }
      print('✅ .env lido com sucesso.');
    } else {
      print('⚠️ .env não encontrado. Usando variáveis de ambiente ou falhará.');
    }
  } catch (e) {
    print('❌ Erro ao ler .env: $e');
  }

  // Sanitizar URL (Lógica v19)
  if (baseUrl.endsWith('/')) {
    print('⚠️ URL terminava com /. Corrigindo...');
    while (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }
  }
  print('🌐 URL Base: $baseUrl');

  if (baseUrl.isEmpty || username.isEmpty) {
    print('❌ Credenciais não encontradas. Configure no .env ou hardcode no script.');
    return;
  }

  // 1. Autenticar
  String? accessToken;
  String? userId;
  
  try {
    // AuthenticateByName
    // Nota: Endpoint pode variar, mas este é o padrão Emby/Jellyfin
    var authUrl = '$baseUrl/Users/AuthenticateByName';
    var headers = {
      'Content-Type': 'application/json',
      'X-Emby-Authorization': 'MediaBrowser Client="ClickChannel-Debug", Device="Script", DeviceId="debug-script", Version="1.0"',
    };
    var body = jsonEncode({'Username': username, 'Pw': password});

    print('🔑 Autenticando...');
    var response = await http.post(Uri.parse(authUrl), headers: headers, body: body);
    
    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      accessToken = data['AccessToken'];
      userId = data['User']['Id'];
      print('✅ Autenticado! Token: ${accessToken!.substring(0, 5)}...');
    } else {
      print('❌ Falha na autenticação: ${response.statusCode} - ${response.body}');
      return;
    }
  } catch (e) {
    print('❌ Erro de conexão Auth: $e');
    return;
  }

  // 2. Buscar um item de vídeo
  String? itemId;
  try {
    var url = '$baseUrl/Users/$userId/Items/Latest?Limit=1&IncludeItemTypes=Movie,Episode';
    var headers = {'X-MediaBrowser-Token': accessToken!};
    
    var response = await http.get(Uri.parse(url), headers: headers);
    if (response.statusCode == 200) {
      var items = jsonDecode(response.body) as List;
      if (items.isNotEmpty) {
        itemId = items[0]['Id'];
        print('✅ Item encontrado: ${items[0]['Name']} (ID: $itemId)');
      } else {
        print('⚠️ Nenhum item de vídeo encontrado.');
        return;
      }
    } else {
       print('❌ Erro ao buscar itens: ${response.statusCode}');
       return;
    }
  } catch (e) {
    print('❌ Erro na busca: $e');
    return;
  }

  // 3. Gerar e Testar URLs
  // Raw URL
  var rawUrl = '$baseUrl/Videos/$itemId/stream?api_key=$accessToken';
  await testUrl('Raw Stream', rawUrl);

  // HLS URL
  var hlsUrl = '$rawUrl&TranscodingContainer=m3u8';
  await testUrl('HLS Stream', hlsUrl);

  // Static File?
  var staticUrl = '$baseUrl/Videos/$itemId/stream?static=true&api_key=$accessToken';
  await testUrl('Static Stream', staticUrl);
}

Future<void> testUrl(String label, String url) async {
  print('\n🧪 Testando $label: $url');
  try {
    // Usar HEAD para não baixar o vídeo todo, mas alguns servidores rejeitam HEAD em stream
    // Vamos usar GET com Range
    var request = http.Request('GET', Uri.parse(url));
    request.headers['Range'] = 'bytes=0-1024'; // Primeiros bytes
    
    var response = await request.send();
    print('   Status: ${response.statusCode}');
    print('   Content-Type: ${response.headers['content-type']}');
    
    if (response.statusCode == 200 || response.statusCode == 206) {
      print('   ✅ SUCESSO! O servidor entregou bytes.');
    } else {
      print('   ❌ FALHA! O servidor rejeitou.');
    }
  } catch (e) {
    print('   ❌ ERRO DE CONEXÃO: $e');
  }
}
