import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/theme/app_colors.dart';
import '../core/config.dart';
import '../core/prefs.dart';
import '../data/m3u_service.dart';
import '../data/epg_service.dart';
import '../widgets/glass_input.dart';
import '../widgets/glass_button.dart';

class XtreamLoginScreen extends StatefulWidget {
  const XtreamLoginScreen({super.key});

  @override
  State<XtreamLoginScreen> createState() => _XtreamLoginScreenState();
}

class _XtreamLoginScreenState extends State<XtreamLoginScreen> {
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // Focus nodes para TV
  final _serverFocus = FocusNode();
  final _userFocus = FocusNode();
  final _passFocus = FocusNode();
  final _buttonFocus = FocusNode();
  
  bool _isLoading = false;
  String? _errorMessage;
  String _statusMessage = '';
  bool _obscurePassword = true;

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _serverFocus.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    _buttonFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // 1. Validação básica
    if (_serverController.text.isEmpty || 
        _usernameController.text.isEmpty || 
        _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Preencha todos os campos');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = 'Autenticando...';
    });

    try {
      // 2. Normalizar URL
      String baseUrl = _serverController.text.trim();
      if (!baseUrl.startsWith('http')) {
        baseUrl = 'http://$baseUrl';
      }
      if (baseUrl.endsWith('/')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      }

      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();

      // 3. Testar credenciais na API
      final checkUrl = '$baseUrl/player_api.php?username=$username&password=$password';
      print('🔐 Xtream Auth: Verificando em $checkUrl');

      final response = await http.get(Uri.parse(checkUrl)).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Erro no servidor: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      
      // Validação da resposta do Xtream Codes
      if (data['user_info'] == null || data['user_info']['auth'] == 0) {
        throw Exception('Usuário ou senha inválidos');
      }

      final status = data['user_info']['status'];
      if (status != 'Active' && status != 'Experiment') {
         // Alguns servidores retornam Active ou Experiment
         // Se for diferente, pode estar expirado, mas vamos deixar passar com aviso
         print('⚠️ Xtream: Status da conta: $status');
      }

      // 4. Construir URLs finais
      final m3uUrl = '$baseUrl/get.php?username=$username&password=$password&type=m3u_plus&output=ts';
      final epgUrl = '$baseUrl/xmltv.php?username=$username&password=$password';

      print('✅ Xtream Auth: Sucesso! Gerando playlist...');
      
      // 5. Iniciar processo de download (Lógica do SetupScreen)
      await _processPlaylist(m3uUrl, epgUrl);

    } catch (e) {
      print('❌ Xtream Error: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erro ao conectar: ${_cleanError(e)}';
      });
    }
  }

  // Helper para limpar msg de erro
  String _cleanError(dynamic e) {
    String msg = e.toString();
    if (msg.contains('SocketException')) return 'Não foi possível conectar ao servidor';
    if (msg.contains('TimeoutException')) return 'Tempo limite excedido';
    if (msg.contains('Exception:')) return msg.replaceAll('Exception:', '').trim();
    return msg;
  }

  Future<void> _processPlaylist(String m3uUrl, String epgUrl) async {
    try {
      setState(() => _statusMessage = 'Salvando configurações...');

      // Limpeza de caches anteriores
      M3uService.clearMemoryCache();
      await M3uService.clearAllCache(null);
      await Prefs.setPlaylistOverride(null);
      Config.setPlaylistOverride(null);

      // Salvar nova URL
      await Prefs.setPlaylistOverride(m3uUrl);
      Config.setPlaylistOverride(m3uUrl);
      
      // Salvar URL do EPG (se tiver suporte no EpgService, caso contrário fica pro futuro)
      // TODO: Adicionar suporte a salvar EPG URL no Prefs se necessário
      // Por enquanto, o EpgService tenta carregar do link xmltv se a playlist tiver a tag url-tvg,
      // mas como estamos via Xtream, podemos forçar o carregamento depois.
      
      setState(() => _statusMessage = 'Baixando lista de canais...');

      // Download da Playlist
      await M3uService.downloadAndCachePlaylist(
        m3uUrl,
        onProgress: (progress, status) {
          if (mounted) {
            setState(() => _statusMessage = status);
          }
        },
      );

      setState(() => _statusMessage = 'Processando categorias...');
      
      // Preload
      try {
        await M3uService.preloadCategories(m3uUrl);
      } catch (e) {
        print('⚠️ Xtream: Erro preload: $e');
      }

      setState(() => _statusMessage = 'Carregando Guia de Programação...');
      
      // Tentar carregar EPG explicitamente
      try {
        await EpgService.loadEpg(epgUrl, onProgress: (p, s) {
           if (mounted) setState(() => _statusMessage = s);
        });
      } catch (e) {
        print('⚠️ Xtream: Erro EPG: $e');
      }

      setState(() => _statusMessage = 'Concluído!');
      await Future.delayed(const Duration(milliseconds: 500));

      // Marcar como pronto
      await Prefs.setPlaylistReady(true);
      await M3uService.writeInstallMarker();

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }

    } catch (e) {
      print('❌ Xtream Process Error: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erro ao baixar lista: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400), // Limite de largura para TV
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.dns, size: 50, color: AppColors.primary),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Xtream Codes',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'Conecte-se ao seu servidor',
                  style: TextStyle(color: Colors.white54),
                ),
                const SizedBox(height: 40),

                if (_isLoading) ...[
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(_statusMessage, style: const TextStyle(color: Colors.white70)),
                ] else ...[
                  GlassInput(
                    controller: _serverController,
                    hintText: 'http://url-do-servidor:porta',
                    prefixIcon: Icons.link,
                    focusNode: _serverFocus,
                    onSubmitted: (_) => _userFocus.requestFocus(),
                  ),
                  const SizedBox(height: 16),
                  GlassInput(
                    controller: _usernameController,
                    hintText: 'Nome de usuário',
                    prefixIcon: Icons.person,
                    focusNode: _userFocus,
                    onSubmitted: (_) => _passFocus.requestFocus(),
                  ),
                  const SizedBox(height: 16),
                  GlassInput(
                    controller: _passwordController,
                    hintText: 'Senha',
                    prefixIcon: Icons.lock,
                    obscureText: _obscurePassword,
                    focusNode: _passFocus,
                    onSubmitted: (_) => _buttonFocus.requestFocus(),
                    suffixIcon: _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    onSuffixTap: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  const SizedBox(height: 32),
                  
                  SolidButton(
                    label: 'CONECTAR',
                    icon: Icons.login,
                    width: double.infinity,
                    height: 56,
                    onPressed: _login,
                    // Passando focusNode se o widget suportasse, 
                    // mas o SolidButton do glass_button.dart não recebe focusNode.
                    // Vamos envelopar em um Focus widget se necessário ou confiar no auto-focus do flutter
                  ),
                ],

                if (_errorMessage != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
