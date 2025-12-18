import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';
import '../core/config.dart';
import '../core/prefs.dart';
import '../data/m3u_service.dart';

/// Tela de configuração inicial.
/// Se não houver playlist configurada, exibe campo para inserir URL.
/// Se houver, inicia download com loading visual.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  final FocusNode _buttonFocusNode = FocusNode();
  
  bool _isLoading = false;
  String _statusMessage = '';
  double _progress = 0.0;
  String? _errorMessage;
  
  // Para foco visual claro na TV
  bool _urlHasFocus = false;
  bool _buttonHasFocus = false;

  @override
  void initState() {
    super.initState();
    
    // Listeners para atualizar visual de foco
    _urlFocusNode.addListener(_onUrlFocusChange);
    _buttonFocusNode.addListener(_onButtonFocusChange);
    
    _checkExistingPlaylist();
  }

  void _onUrlFocusChange() {
    if (mounted) setState(() => _urlHasFocus = _urlFocusNode.hasFocus);
  }

  void _onButtonFocusChange() {
    if (mounted) setState(() => _buttonHasFocus = _buttonFocusNode.hasFocus);
  }

  @override
  void dispose() {
    _urlFocusNode.removeListener(_onUrlFocusChange);
    _buttonFocusNode.removeListener(_onButtonFocusChange);
    _urlController.dispose();
    _urlFocusNode.dispose();
    _buttonFocusNode.dispose();
    super.dispose();
  }

  /// Verifica se já existe playlist salva e válida
  Future<void> _checkExistingPlaylist() async {
    final savedUrl = Prefs.getPlaylistOverride();
    final isReady = Prefs.isPlaylistReady();
    
    // Se não tem URL salva, limpa qualquer cache antigo
    if (savedUrl == null || savedUrl.isEmpty) {
      print('🧹 Setup: Sem URL configurada, limpando caches antigos...');
      await M3uService.clearAllCache(null);
      await Prefs.setPlaylistReady(false);
      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });
      return;
    }
    
    _urlController.text = savedUrl;
    
    // Se já foi baixada anteriormente, tenta usar cache
    if (isReady) {
      setState(() {
        _statusMessage = 'Verificando lista salva...';
        _isLoading = true;
      });
      
      // Verifica se o cache local ainda existe
      final hasCache = await M3uService.hasCachedPlaylist(savedUrl);
      if (hasCache) {
        setState(() {
          _statusMessage = 'Lista encontrada! Carregando...';
          _progress = 1.0;
        });
        
        // Pequeno delay para mostrar a mensagem
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
        return;
      }
      
      // Se não tem cache, precisa baixar novamente
      setState(() {
        _statusMessage = 'Cache expirado, baixando novamente...';
      });
      await _downloadPlaylist(savedUrl);
      return;
    }
    
    // Foco automático é tratado pelo autofocus: true no botão
  }

  /// Inicia download da playlist com feedback visual
  Future<void> _downloadPlaylist(String url) async {
    if (url.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Por favor, insira a URL da playlist';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _progress = 0.0;
      _statusMessage = 'Conectando ao servidor...';
    });

    try {
      // Salva URL nas preferências
      Config.setPlaylistOverride(url.trim());
      await Prefs.setPlaylistOverride(url.trim());

      setState(() {
        _progress = 0.1;
        _statusMessage = 'Baixando playlist...';
      });

      // Faz download com callback de progresso
      await M3uService.downloadAndCachePlaylist(
        url.trim(),
        onProgress: (progress, status) {
          if (mounted) {
            setState(() {
              _progress = 0.1 + (progress * 0.7); // 10% a 80%
              _statusMessage = status;
            });
          }
        },
      );

      setState(() {
        _progress = 0.85;
        _statusMessage = 'Processando categorias...';
      });

      // Pré-carrega categorias para otimizar primeira abertura
      await M3uService.preloadCategories(url.trim());

      setState(() {
        _progress = 1.0;
        _statusMessage = 'Pronto! Entrando no app...';
      });

      // Marca como pronta
      await Prefs.setPlaylistReady(true);

      // Pequeno delay para mostrar conclusão
      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      print('❌ SetupScreen: Erro ao baixar playlist: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erro ao baixar: $e';
        _statusMessage = '';
        _progress = 0.0;
      });
      // Volta o foco para o botão
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _buttonFocusNode.requestFocus();
      });
    }
  }

  void _onSubmit() {
    _downloadPlaylist(_urlController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(Icons.live_tv, color: Colors.white, size: 56),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Título
              const Text(
                'Click Channel',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'Configure sua playlist IPTV',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
              
              const SizedBox(height: 48),
              
              if (_isLoading) ...[
                // Loading com progresso
                _buildLoadingState(),
              ] else ...[
                // Campo de URL
                _buildUrlInput(),
              ],
              
              // Mensagem de erro
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
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
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        // Barra de progresso
        Container(
          width: 300,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Texto de status
        Text(
          _statusMessage,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 8),
        
        // Porcentagem
        Text(
          '${(_progress * 100).toInt()}%',
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Spinner
        const SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 3,
          ),
        ),
      ],
    );
  }

  Widget _buildUrlInput() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Column(
        children: [
          // Campo de URL com navegação TV e foco visual
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _urlHasFocus ? AppColors.primary : Colors.transparent,
                width: 3,
              ),
              boxShadow: _urlHasFocus ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ] : [],
            ),
            child: TextField(
              controller: _urlController,
                focusNode: _urlFocusNode,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'URL da Playlist M3U',
                  labelStyle: TextStyle(
                    color: _urlHasFocus ? AppColors.primary : Colors.white.withOpacity(0.7),
                    fontWeight: _urlHasFocus ? FontWeight.bold : FontWeight.normal,
                  ),
                  hintText: 'https://exemplo.com/playlist.m3u',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  prefixIcon: Icon(
                    Icons.link,
                    color: _urlHasFocus ? AppColors.primary : Colors.white54,
                    size: 28,
                  ),
                  filled: true,
                  fillColor: _urlHasFocus 
                      ? Colors.white.withOpacity(0.1)
                      : Colors.white.withOpacity(0.05),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _onSubmit(),
              ),
            ),
          
          const SizedBox(height: 24),
          
          // Botão Carregar com FOCO VISUAL CLARO para TV
          AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _buttonHasFocus ? Colors.white : Colors.transparent,
                  width: 4,
                ),
                boxShadow: _buttonHasFocus ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.6),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                  const BoxShadow(
                    color: Colors.white24,
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ] : [],
              ),
            child: ElevatedButton.icon(
              focusNode: _buttonFocusNode,
              autofocus: true, // Foco automático inicial
              onPressed: _onSubmit,
              icon: Icon(
                Icons.download,
                size: _buttonHasFocus ? 32 : 26,
              ),
              label: Text(
                _buttonHasFocus ? '▶ CARREGAR PLAYLIST ◀' : 'CARREGAR PLAYLIST',
                style: TextStyle(
                  fontSize: _buttonHasFocus ? 20 : 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: _buttonHasFocus ? 2 : 1,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _buttonHasFocus 
                    ? AppColors.primary
                    : AppColors.primary.withOpacity(0.8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: _buttonHasFocus ? 12 : 4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
