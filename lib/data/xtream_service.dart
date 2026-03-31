import 'dart:convert';
import 'package:http/http.dart' as http;

class XtreamService {
  /// Valida as credenciais Xtream Codes chamando player_api.php
  /// Retorna um Map com user_info e server_info se sucesso, ou null/throw se falha
  static Future<Map<String, dynamic>> validateCredentials({
    required String host,
    required String username,
    required String password,
  }) async {
    // Normaliza host (garante http/https e remove barra final)
    var cleanHost = host.trim();
    if (cleanHost.endsWith('/')) {
      cleanHost = cleanHost.substring(0, cleanHost.length - 1);
    }
    if (!cleanHost.startsWith('http')) {
      cleanHost = 'http://$cleanHost';
    }

    final encodedUser = Uri.encodeComponent(username);
    final encodedPass = Uri.encodeComponent(password);
    final url = '$cleanHost/player_api.php?username=$encodedUser&password=$encodedPass';
    print('🔑 XtreamService: Validando credenciais em $cleanHost...');

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Verifica se login falhou (API retorna JSON mesmo no erro, mas user_info.auth pode ser 0)
        if (data['user_info'] != null) {
          final auth = data['user_info']['auth'];
          final isAuthenticated = auth == 1 || auth == '1';
          if (isAuthenticated) {
            print('✅ XtreamService: Login realizado com sucesso! (Status: ${data['user_info']['status']})');
            return data;
          }
        }
        
        print('❌ XtreamService: Login falhou (Credenciais inválidas ou expiradas)');
        throw Exception('Login falhou. Verifique usuário e senha.');
      } else {
        print('❌ XtreamService: Erro HTTP ${response.statusCode}');
        throw Exception('Erro ao conectar no servidor (${response.statusCode})');
      }
    } catch (e) {
      print('❌ XtreamService: Erro de conexão: $e');
      rethrow;
    }
  }

  static String generateM3uUrl({
    required String host,
    required String username,
    required String password,
    String output = 'ts', // 'ts' ou 'm3u8'
  }) {
    var cleanHost = host.trim();
    if (cleanHost.endsWith('/')) {
      cleanHost = cleanHost.substring(0, cleanHost.length - 1);
    }
    if (!cleanHost.startsWith('http')) {
      cleanHost = 'http://$cleanHost';
    }

    final encodedUser = Uri.encodeComponent(username);
    final encodedPass = Uri.encodeComponent(password);
    return '$cleanHost/get.php?username=$encodedUser&password=$encodedPass&type=m3u_plus&output=$output';
  }
}
