import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/config.dart';
import '../core/prefs.dart';
import '../core/managed_access_storage.dart';
import '../data/m3u_service.dart';
import '../data/epg_service.dart';
import '../data/xtream_service.dart';
import '../widgets/blinking_cursor_placeholder.dart';
import 'package:flutter/services.dart';

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
  final TextEditingController _xtreamHostController = TextEditingController();
  final TextEditingController _xtreamUserController = TextEditingController();
  final TextEditingController _xtreamPassController = TextEditingController();
  
  final FocusNode _urlFocusNode = FocusNode();
  final FocusNode _xtreamHostFocusNode = FocusNode();
  final FocusNode _xtreamUserFocusNode = FocusNode();
  final FocusNode _xtreamPassFocusNode = FocusNode();
  final FocusNode _buttonFocusNode = FocusNode();
  
  // Nodes para o placeholder (navegação)
  final FocusNode _urlPlaceholderFocus = FocusNode();
  final FocusNode _xtreamHostPlaceholderFocus = FocusNode();
  final FocusNode _xtreamUserPlaceholderFocus = FocusNode();
  final FocusNode _xtreamPassPlaceholderFocus = FocusNode();
  final FocusNode _tab1Focus = FocusNode();
  final FocusNode _tab2Focus = FocusNode();
  
  int _selectedTab = 0; // 0 = URL, 1 = Xtream
  
  bool _isLoading = false;
  String _statusMessage = '';
  double _progress = 0.0;
  String? _errorMessage;
  
  // Controle de ativação do teclado
  bool _urlActive = false;
  bool _xtreamHostActive = false;
  bool _xtreamUserActive = false;
  bool _xtreamPassActive = false;
  
  // Para foco visual claro na TV
  bool _urlHasFocus = false;
  bool _buttonHasFocus = false;
  bool _managedAccessBootstrapTried = false;

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
    _xtreamHostController.dispose();
    _xtreamUserController.dispose();
    _xtreamPassController.dispose();
    _urlFocusNode.dispose();
    _buttonFocusNode.dispose();
    _urlPlaceholderFocus.dispose();
    _xtreamHostPlaceholderFocus.dispose();
    _xtreamUserPlaceholderFocus.dispose();
    _xtreamPassPlaceholderFocus.dispose();
    _tab1Focus.dispose();
    _tab2Focus.dispose();
    super.dispose();
  }

  /// Verifica se já existe playlist salva e válida
  /// CRÍTICO: Na primeira execução, NUNCA usa cache - sempre limpa tudo
  Future<void> _checkExistingPlaylist() async {
    // Verifica se há playlist salva PRIMEIRO
    final savedUrl = Prefs.getPlaylistOverride();
    
    // CRÍTICO: Só considera primeira execução se NÃO houver playlist salva
    // Se tem playlist salva, significa que já foi configurado antes
    final isFirstRun = !await M3uService.hasInstallMarker() && (savedUrl == null || savedUrl.isEmpty);
    
    if (isFirstRun) {
      print('🚨 Setup: PRIMEIRA EXECUÇÃO detectada (sem marker e sem playlist) - Limpando TODOS os caches...');
      // Limpa TUDO na primeira execução
      M3uService.clearMemoryCache();
      await M3uService.clearAllCache(null);
      await Prefs.setPlaylistOverride(null);
      await Prefs.setPlaylistReady(false);
      Config.setPlaylistOverride(null);
      // Cria o install marker para marcar que não é mais primeira execução
      await M3uService.writeInstallMarker();
      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });
      return; // Primeira execução - não carrega nada
    }
    
    // Se tem playlist salva mas não tem marker, cria marker para manter consistência
    if (savedUrl != null && savedUrl.isNotEmpty) {
      final hasMarker = await M3uService.hasInstallMarker();
      if (!hasMarker) {
        print('ℹ️ Setup: Playlist encontrada mas sem marker - criando marker...');
        await M3uService.writeInstallMarker();
      }
    }
    
    final isReady = Prefs.isPlaylistReady();
    
    // Se não tem URL salva, limpa qualquer cache antigo
    if (savedUrl == null || savedUrl.isEmpty) {
      print('🧹 Setup: Sem URL configurada, limpando caches antigos...');
      M3uService.clearMemoryCache();
      await M3uService.clearAllCache(null);
      await Prefs.setPlaylistReady(false);
      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });
      await _tryBootstrapManagedAccess();
      return;
    }
    
    _urlController.text = savedUrl;
    
    // CRÍTICO: Valida que o cache corresponde à URL salva ANTES de usar
    // Se não corresponder, limpa e força novo download
    final hasCache = await M3uService.hasCachedPlaylist(savedUrl);
    
    // CRÍTICO: Se tem cache válido, SEMPRE marca como pronto e vai direto para Home
    // Não solicita novamente a lista se já tem cache válido
    if (hasCache) {
      // Garante que está marcado como pronto
      if (!isReady) {
        print('⚠️ Setup: Cache válido mas não marcado como pronto. Marcando...');
        await Prefs.setPlaylistReady(true);
      }
      
      // Verifica se a URL salva corresponde à URL atual (validação extra)
      final currentUrl = Config.playlistRuntime;
      if (currentUrl == null || currentUrl.trim() != savedUrl.trim()) {
        print('⚠️ Setup: URL não sincronizada. Sincronizando...');
        Config.setPlaylistOverride(savedUrl);
      }
      
      print('✅ Setup: Cache válido encontrado para URL salva - Navegando para Home');
        setState(() {
          _statusMessage = 'Lista encontrada! Carregando...';
          _progress = 1.0;
          _isLoading = true;
        });
      
      // CRÍTICO: Pré-carrega categorias ANTES de navegar para Home
      // Isso garante que a lista M3U esteja disponível imediatamente
      print('📦 Setup: Pré-carregando categorias do cache...');
      try {
        await M3uService.preloadCategories(savedUrl);
        print('✅ Setup: Categorias pré-carregadas com sucesso');
      } catch (e) {
        print('⚠️ Setup: Erro ao pré-carregar categorias: $e');
        // Continua mesmo se preload falhar
      }
        
        // Pequeno delay para mostrar a mensagem
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
        return;
    }
    
    // Se não tem cache válido, precisa baixar
    if (isReady) {
      print('⚠️ Setup: Cache não encontrado mas marcado como pronto. Re-baixando...');
      await Prefs.setPlaylistReady(false);
      setState(() {
        _statusMessage = 'Cache não encontrado, baixando novamente...';
      });
    }
    // Se não está pronto, o usuário precisa configurar
    setState(() {
      _isLoading = false;
      _statusMessage = '';
    });
    await _tryBootstrapManagedAccess();
    
    // Pequeno delay para garantir que a UI foi construída antes de solicitar foco
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && !_isLoading) {
        FocusScope.of(context).unfocus(); // Limpa focos fantasmagóricos
        FocusScope.of(context).nextFocus(); // Vai para o primeiro elemento (Geralmente a Tab 1)
      }
    });
  }

  Future<void> _tryBootstrapManagedAccess() async {
    if (_managedAccessBootstrapTried || !Config.useManagedAccess) return;
    _managedAccessBootstrapTried = true;

    final managed = await ManagedAccessStorage.read();
    final mode = managed['mode'];
    final url = managed['url'];

    if (mode == null || url == null || url.isEmpty) return;

    if (mode == 'playlist_url') {
      _urlController.text = url;
      await _downloadPlaylist(url);
      return;
    }

    _xtreamHostController.text = url;
    _xtreamUserController.text = managed['username'] ?? '';
    _xtreamPassController.text = managed['password'] ?? '';
    setState(() {
      _selectedTab = 1;
    });
    await _loginWithXtream();
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
      // CRÍTICO: Salva URL nas preferências ANTES de baixar (garante persistência)
      final trimmedUrl = url.trim();
      
      // CRÍTICO: Limpa TODOS os caches antigos ANTES de salvar nova URL
      // Isso garante que não haverá conflito com cache de lista anterior
      print('🧹 Setup: Limpando TODOS os caches antigos antes de configurar nova playlist...');
      print('   Nova URL: ${trimmedUrl.substring(0, trimmedUrl.length > 50 ? 50 : trimmedUrl.length)}...');
      
      // CRÍTICO: Remove a URL antiga PRIMEIRO para evitar que cache seja usado
      await Prefs.setPlaylistOverride(null);
      Config.setPlaylistOverride(null);
      
      // Limpa memória primeiro
      M3uService.clearMemoryCache();
      
      // Limpa TODOS os caches de disco (não mantém nenhum)
      await M3uService.clearAllCache(null);
      
      // Aguarda um pouco para garantir que os arquivos foram deletados
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Agora salva a nova URL
      Config.setPlaylistOverride(trimmedUrl);
      await Prefs.setPlaylistOverride(trimmedUrl);
      
      // Aguarda um pouco mais para garantir que a URL foi salva
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Verifica se foi salva corretamente (tripla verificação)
      final verifyUrl = Prefs.getPlaylistOverride();
      if (verifyUrl != trimmedUrl) {
        print('⚠️ Setup: Erro ao salvar URL! Tentando novamente...');
        await Prefs.setPlaylistOverride(trimmedUrl);
        Config.setPlaylistOverride(trimmedUrl);
        // Verifica novamente
        final verifyUrl2 = Prefs.getPlaylistOverride();
        if (verifyUrl2 != trimmedUrl) {
          print('❌ Setup: ERRO CRÍTICO: Não foi possível salvar URL em Prefs!');
          setState(() {
            _errorMessage = 'Erro ao salvar configuração. Tente novamente.';
            _isLoading = false;
          });
          return;
        }
      }
      print('✅ Setup: URL salva com sucesso em Prefs: ${trimmedUrl.substring(0, trimmedUrl.length > 50 ? 50 : trimmedUrl.length)}...');

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
      // CRÍTICO: Aguarda o download completar e valida URL antes de preload
      setState(() {
        _progress = 0.85;
        _statusMessage = 'Processando categorias...';
      });
      
      // CRÍTICO: Aguarda o preload completar para garantir que cache está correto
      // Não faz em background - precisa garantir que está usando a URL correta
      try {
        await M3uService.preloadCategories(url.trim());
        print('✅ Setup: Categorias pré-carregadas com sucesso');
      } catch (e) {
        print('⚠️ Setup: Erro ao pré-carregar categorias: $e');
        // Não bloqueia o fluxo, mas loga o erro
      }

      // Carrega EPG automaticamente após configurar playlist M3U
      setState(() {
        _progress = 0.9;
        _statusMessage = 'Carregando EPG...';
      });
      
      try {
        final epgUrl = EpgService.epgUrl;
        if (epgUrl != null && epgUrl.isNotEmpty) {
          print('📺 Setup: Carregando EPG automaticamente: $epgUrl');
          await EpgService.loadEpg(epgUrl, onProgress: (progress, status) {
            if (mounted) {
              setState(() {
                _statusMessage = status;
              });
            }
          });
          if (EpgService.isLoaded) {
            print('✅ Setup: EPG carregado: ${EpgService.getAllChannels().length} canais');
          } else {
            print('⚠️ Setup: EPG não foi carregado completamente');
          }
        } else {
          print('ℹ️ Setup: Nenhuma URL de EPG configurada');
        }
      } catch (e) {
        print('⚠️ Setup: Erro ao carregar EPG automaticamente: $e');
        // Não bloqueia o fluxo se EPG falhar
      }

      setState(() {
        _progress = 1.0;
        _statusMessage = 'Pronto! Entrando no app...';
      });

      // Marca como pronta
      await Prefs.setPlaylistReady(true);
      
      // CRÍTICO: Cria install marker se não existir (marca que não é mais primeira execução)
      final hasMarker = await M3uService.hasInstallMarker();
      if (!hasMarker) {
        print('✅ Setup: Criando install marker (primeira configuração concluída)');
        await M3uService.writeInstallMarker();
      }

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
    print('DEBUG: _onSubmit called. Tab: $_selectedTab');
    // Clear active states
    setState(() {
      _urlActive = false;
      _xtreamHostActive = false;
      _xtreamUserActive = false;
      _xtreamPassActive = false;
    });

    if (_selectedTab == 0) {
      print('DEBUG: Submitting URL: ${_urlController.text}');
      _downloadPlaylist(_urlController.text);
    } else {
      print('DEBUG: Submitting Xtream Login');
      _loginWithXtream();
    }
  }

  Future<void> _loginWithXtream() async {
    final host = _xtreamHostController.text.trim();
    final username = _xtreamUserController.text.trim();
    final password = _xtreamPassController.text.trim();
    
    print('DEBUG: _loginWithXtream - Host: $host, User: $username');

    if (host.isEmpty || username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor, preencha todos os campos';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _progress = 0.0;
      _statusMessage = 'Conectando ao servidor Xtream...';
    });

    try {
      setState(() {
        _progress = 0.3;
        _statusMessage = 'Validando credenciais...';
      });

      await XtreamService.validateCredentials(
        host: host,
        username: username,
        password: password,
      );

      setState(() {
        _progress = 0.6;
        _statusMessage = 'Login realizado! Gerando URL da playlist...';
      });

      final playlistUrl = XtreamService.generateM3uUrl(
        host: host,
        username: username,
        password: password,
      );

      print('✅ Setup: URL Xtream gerada: $playlistUrl');

      await _downloadPlaylist(playlistUrl);
    } catch (e) {
      print('❌ Setup: Erro no login Xtream: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Falha no login: $e';
        _statusMessage = '';
        _progress = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // Background blobs (RadialGradient for performance)
          Positioned(
            top: -200,
            right: -200,
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -200,
            left: -200,
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryLight.withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          
          // Conteúdo Central
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo Principal
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.25),
                            blurRadius: 30,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 140,
                          height: 140,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [AppColors.primary, AppColors.primaryLight],
                                ),
                                borderRadius: BorderRadius.circular(32),
                              ),
                              child: const Icon(Icons.live_tv, color: Colors.white, size: 70),
                            );
                          },
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    const Text(
                      'Click Channel',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Text(
                      'Configure sua playlist IPTV',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 16,
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    if (_isLoading) ...[
                      _buildLoadingState(),
                    ] else ...[
                      _buildTabSwitcher(),
                      const SizedBox(height: 24),
                      _selectedTab == 0 ? _buildUrlInput() : _buildXtreamForm(),
                    ],
                    
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],

                    // Espaçador extra no fundo para garantir visibilidade da parte de baixo
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        ],
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
    if (_urlActive) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Focus(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
              setState(() => _urlActive = false);
              _urlPlaceholderFocus.requestFocus();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: TextField(
            controller: _urlController,
            focusNode: _urlFocusNode,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: _inputDecoration('URL da Playlist M3U', Icons.link),
            onSubmitted: (_) => _onSubmit(),
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Column(
        children: [
          Focus(
            focusNode: _urlPlaceholderFocus,
            onFocusChange: (f) {
              if (mounted) setState(() => _urlHasFocus = f);
              if (f) SystemChannels.textInput.invokeMethod('TextInput.hide');
            },
            onKeyEvent: (node, event) => _handleNavigation(event, () {
              setState(() => _urlActive = true);
              Future.delayed(const Duration(milliseconds: 50), () => _urlFocusNode.requestFocus());
            }, _urlFocusNode),
            child: GestureDetector(
              onTap: () {
                setState(() => _urlActive = true);
                Future.delayed(const Duration(milliseconds: 50), () => _urlFocusNode.requestFocus());
              },
              child: BlinkingCursorPlaceholder(
                text: _urlController.text,
                hintText: 'https://exemplo.com/playlist.m3u',
                isFocused: _urlHasFocus,
                onActivate: () => setState(() => _urlActive = true),
                prefixIcon: Icons.link,
              ),
            ),
          ),
          const SizedBox(height: 32),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildTabItem(0, 'URL Direta', _tab1Focus),
          _buildTabItem(1, 'Login Xtream', _tab2Focus),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String label, FocusNode focusNode) {
    bool isSelected = _selectedTab == index;
    
    return Expanded(
      child: Focus(
        focusNode: focusNode,
        onFocusChange: (hasKeyboardFocus) {
          if (mounted) setState(() {});
          if (hasKeyboardFocus) SystemChannels.textInput.invokeMethod('TextInput.hide');
        },
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.enter || 
                event.logicalKey == LogicalKeyboardKey.select) {
              setState(() => _selectedTab = index);
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Builder(
          builder: (context) {
            bool hasFocus = Focus.of(context).hasFocus;
            return GestureDetector(
              onTap: () => setState(() => _selectedTab = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : (hasFocus ? Colors.white.withOpacity(0.1) : Colors.transparent),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasFocus ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: (isSelected || hasFocus) ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildXtreamForm() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Column(
        children: [
          _buildXtreamField(_xtreamHostController, _xtreamHostPlaceholderFocus, _xtreamHostFocusNode, 'URL do Servidor', Icons.dns, _xtreamHostActive, (v) => setState(() => _xtreamHostActive = v), action: TextInputAction.next),
          const SizedBox(height: 16),
          _buildXtreamField(_xtreamUserController, _xtreamUserPlaceholderFocus, _xtreamUserFocusNode, 'Usuário', Icons.person, _xtreamUserActive, (v) => setState(() => _xtreamUserActive = v), action: TextInputAction.next),
          const SizedBox(height: 16),
          _buildXtreamField(_xtreamPassController, _xtreamPassPlaceholderFocus, _xtreamPassFocusNode, 'Senha', Icons.lock, _xtreamPassActive, (v) => setState(() => _xtreamPassActive = v), obscure: true, action: TextInputAction.done),
          const SizedBox(height: 24),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildXtreamField(TextEditingController controller, FocusNode pFocus, FocusNode fFocus, String label, IconData icon, bool isActive, Function(bool) setActive, {bool obscure = false, TextInputAction action = TextInputAction.next}) {
    if (isActive) {
      return Focus(
        onFocusChange: (f) {
          print('DEBUG: Field Active Focus Change: $f (label: $label)');
          // REMOVIDO: Desativação agressiva que cancelava o clique no botão
          // setActive(false); 
        },
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && 
              (event.logicalKey == LogicalKeyboardKey.escape || 
               event.logicalKey == LogicalKeyboardKey.goBack)) {
            setActive(false);
            pFocus.requestFocus();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: controller,
          focusNode: fFocus,
          autofocus: true,
          obscureText: obscure,
          textInputAction: action,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: _inputDecoration(label, icon),
          onSubmitted: (_) {
            if (action == TextInputAction.done) {
              _onSubmit();
            } else {
              // Próximo campo
              FocusScope.of(context).nextFocus();
            }
          },
        ),
      );
    }

    return Focus(
      focusNode: pFocus,
      onFocusChange: (f) {
        if (mounted) setState(() {});
        if (f) SystemChannels.textInput.invokeMethod('TextInput.hide');
      },
      onKeyEvent: (node, event) => _handleNavigation(event, () {
        setActive(true);
        Future.delayed(const Duration(milliseconds: 50), () => fFocus.requestFocus());
      }, fFocus),
      child: GestureDetector(
        onTap: () {
          setActive(true);
          Future.delayed(const Duration(milliseconds: 50), () => fFocus.requestFocus());
        },
        child: BlinkingCursorPlaceholder(
          text: obscure && controller.text.isNotEmpty ? '********' : controller.text,
          hintText: label,
          isFocused: pFocus.hasFocus,
          onActivate: () => setActive(true),
          prefixIcon: icon,
          focusedColor: AppColors.primary,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
      filled: true,
      fillColor: Colors.white.withOpacity(0.1),
      prefixIcon: Icon(icon, color: AppColors.primary),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
    );
  }

  KeyEventResult _handleNavigation(KeyEvent event, VoidCallback onActive, FocusNode next) {
    if (event is KeyDownEvent) {
      final isChar = event.logicalKey.keyLabel.length == 1 && RegExp(r'^[a-zA-Z0-9]$').hasMatch(event.logicalKey.keyLabel);
      if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.select || isChar) {
        onActive();
        return isChar ? KeyEventResult.ignored : KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Widget _buildSubmitButton() {
    return Focus(
      focusNode: _buttonFocusNode,
      onFocusChange: (f) => setState(() => _buttonHasFocus = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _buttonHasFocus ? Colors.white : Colors.transparent, width: 3),
          boxShadow: _buttonHasFocus ? [BoxShadow(color: AppColors.primary.withOpacity(0.5), blurRadius: 20)] : [],
        ),
        child: ElevatedButton(
          onPressed: _onSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            _selectedTab == 0 ? 'CARREGAR PLAYLIST' : 'FAZER LOGIN',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
