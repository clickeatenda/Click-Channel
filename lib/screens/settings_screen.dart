import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';
import '../core/config.dart';
import '../core/prefs.dart';
import '../core/utils/validators.dart';
import '../core/utils/logger.dart';
import '../data/m3u_service.dart';
import '../data/epg_service.dart';
import '../data/tmdb_service.dart';
import '../data/jellyfin_service.dart';
import '../widgets/glass_panel.dart';
import '../widgets/app_sidebar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // -1 para nenhum selecionado (fora da Home)
  int _selectedNavIndex = -1;
  bool _darkMode = true;
  bool _autoplay = true;
  bool _notifications = true;
  late TextEditingController _playlistController;
  final FocusNode _urlFocusNode = FocusNode();
  final FocusNode _buttonFocusNode = FocusNode();
  bool _urlHasFocus = false;
  bool _buttonHasFocus = false;

  @override
  void initState() {
    super.initState();
    _playlistController = TextEditingController(text: Config.playlistRuntime ?? '');
    _urlFocusNode.addListener(() {
      if (mounted) setState(() => _urlHasFocus = _urlFocusNode.hasFocus);
    });
    _buttonFocusNode.addListener(() {
      if (mounted) setState(() => _buttonHasFocus = _buttonFocusNode.hasFocus);
    });
    // TMDB key controller (load from Prefs if set)
    _tmdbController = TextEditingController(text: Prefs.getTmdbApiKey() ?? '');
    _tmdbFocusNode.addListener(() {
      if (mounted) setState(() => _tmdbHasFocus = _tmdbFocusNode.hasFocus);
    });
    // Focus nodes para botões TMDB (TV / Firestick navigation)
    _tmdbSaveFocusNode = FocusNode();
    _tmdbTestFocusNode = FocusNode();
    _tmdbClearFocusNode = FocusNode();
    
    // Listeners para atualizar borda de foco Jellyfin
    void update() { if(mounted) setState((){}); }
    _jfUrlFocusNode.addListener(update);
    _jfUserFocusNode.addListener(update);
    _jfPassFocusNode.addListener(update);
    _jfSaveFocusNode.addListener(update);
    _jfTestFocusNode.addListener(update);

    _loadJellyfinConfig();
  }

  // Jellyfin Controllers & FocusNodes
  final _jfUrlController = TextEditingController();
  final _jfUserController = TextEditingController();
  final _jfPassController = TextEditingController();
  
  final _jfUrlFocusNode = FocusNode();
  final _jfUserFocusNode = FocusNode();
  final _jfPassFocusNode = FocusNode();
  final _jfSaveFocusNode = FocusNode();
  final _jfTestFocusNode = FocusNode();
  
  Future<void> _loadJellyfinConfig() async {
    final creds = await JellyfinService.getCredentials();
    if (mounted) {
      setState(() {
        String urlLoad = creds['url'] ?? '';
        if (urlLoad.startsWith('http://')) {
          urlLoad = urlLoad.substring(7); // Remove HTTP:// default
        }
        _jfUrlController.text = urlLoad;
        _jfUserController.text = creds['username'] ?? '';
        _jfPassController.text = creds['password'] ?? '';
      });
    }
  }

  Future<void> _saveJellyfinConfig() async {
    var url = _jfUrlController.text.trim();
    final user = _jfUserController.text.trim();
    final pass = _jfPassController.text.trim();
    
    if (!context.mounted) return;
    if (url.isEmpty) {
      await JellyfinService.clearConfig();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuração Jellyfin removida')));
      return;
    }

    // Normalização de URL
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url'; // Assume HTTP por padrão (comum em LAN)
    }
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    // _jfUrlController.text = url; // Removido: Não re-preencher a UI com o 'http://' para facilitar tv

    await JellyfinService.saveConfig(url: url, username: user, password: pass);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuração Jellyfin salva!')));
  }

  Future<void> _testJellyfinConfig() async {
    // Salva temporariamente para testar (já com a URL normalizada pelo _saveJellyfinConfig)
    await _saveJellyfinConfig();
    
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⏳ Testando conexão...')));

    try {
      // Tenta conectar
      final connected = await JellyfinService.testConnection();
      if (!context.mounted) return;
      if (!connected) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('❌ Falha ao conectar. Verifique URL e se o servidor está online.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ));
        return;
      }

      // Tenta autenticar
      final auth = await JellyfinService.authenticate();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth ? '✅ Conexão e Login OK!' : '⚠️ Servidor achado, mas senha incorreta.'),
          backgroundColor: auth ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 3),
        )
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ Erro: $e'),
        backgroundColor: Colors.red,
      )); 
    }
  }

  Future<void> _saveTmdbKey() async {
    final key = _tmdbController.text.trim();
    try {
      await Prefs.setTmdbApiKey(key.isEmpty ? null : key);
      // Re-init service so it picks up runtime key
      TmdbService.init();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chave TMDB salva')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar chave TMDB: $e')),
      );
    }
  }

  Future<void> _testTmdbKey() async {
    final key = _tmdbController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insira a chave TMDB antes de testar')));
      return;
    }
    try {
      // Persiste temporariamente to ensure TmdbService reads the updated key
      await Prefs.setTmdbApiKey(key);
      // Force reload
      TmdbService.init();
      final ok = await TmdbService.testApiKeyNow();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? '✅ Chave TMDB válida' : '❌ Chave inválida ou erro (veja logs)')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao testar chave: $e')));
    }
  }

  @override
  void dispose() {
    _playlistController.dispose();
    _urlFocusNode.dispose();
    _buttonFocusNode.dispose();
    _tmdbController.dispose();
    _tmdbFocusNode.dispose();
    _tmdbSaveFocusNode.dispose();
    _tmdbTestFocusNode.dispose();
    _tmdbClearFocusNode.dispose();
    _jfUrlController.dispose();
    _jfUserController.dispose();
    _jfPassController.dispose();
    _jfUrlFocusNode.dispose();
    _jfUserFocusNode.dispose();
    _jfPassFocusNode.dispose();
    _jfSaveFocusNode.dispose();
    _jfTestFocusNode.dispose();
    super.dispose();
  }

  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatus = '';
  
  late TextEditingController _tmdbController;
  final FocusNode _tmdbFocusNode = FocusNode();
  bool _tmdbHasFocus = false;
  // Focus nodes para botões TMDB (suporte Fire TV / DPAD)
  late FocusNode _tmdbSaveFocusNode;
  late FocusNode _tmdbTestFocusNode;
  late FocusNode _tmdbClearFocusNode;
  bool _tmdbSaveHasFocus = false;
  bool _tmdbTestHasFocus = false;
  bool _tmdbClearHasFocus = false;

  Future<void> _applyPlaylist() async {
    final value = _playlistController.text.trim();
    
    if (value.isEmpty) {
      Config.setPlaylistOverride(null);
      await Prefs.setPlaylistOverride(null);
      await Prefs.setPlaylistReady(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Playlist removida'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // ✅ VALIDAÇÃO DE URL ADICIONADA (Issue #133)
    final sanitizedUrl = Validators.sanitizeUrl(value);
    
    if (!Validators.isValidUrl(sanitizedUrl)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Validators.getUrlErrorMessage(sanitizedUrl)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      AppLogger.warning('URL de playlist inválida', data: sanitizedUrl);
      return;
    }
    
    // Validação específica para M3U
    if (!Validators.isValidM3UUrl(sanitizedUrl)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ URL não parece ser uma playlist M3U válida. Deseja continuar?'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
      AppLogger.warning('URL não parece ser M3U', data: sanitizedUrl);
    }

    // Inicia download com progresso
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadStatus = 'Conectando...';
    });

    try {
      AppLogger.info('Baixando playlist', data: sanitizedUrl);
      
      // CRÍTICO: Limpa TODOS os caches antigos ANTES de salvar nova URL
      // Isso garante que não haverá cache de lista antiga sendo carregado
      print('🧹 Settings: Limpando TODOS os caches antigos antes de salvar nova URL...');
      print('   Nova URL: ${value.substring(0, value.length > 50 ? 50 : value.length)}...');
      
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
      await Prefs.setPlaylistOverride(value);
      Config.setPlaylistOverride(value);
      
      // Aguarda um pouco mais para garantir que a URL foi salva
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Garante que a URL foi salva corretamente
      final verifyUrl = Prefs.getPlaylistOverride();
      if (verifyUrl != value) {
        print('⚠️ Settings: Erro ao salvar URL! Tentando novamente...');
        await Prefs.setPlaylistOverride(value);
      }
      print('✅ Settings: URL salva em Prefs: ${value.substring(0, value.length > 50 ? 50 : value.length)}...');
      
      await M3uService.downloadAndCachePlaylist(
        value,
        onProgress: (progress, status) {
          if (mounted) {
            setState(() {
              _downloadProgress = progress;
              _downloadStatus = status;
            });
          }
        },
      );

      setState(() {
        _downloadStatus = 'Processando categorias...';
        _downloadProgress = 0.9;
      });

      await M3uService.preloadCategories(value);
      
      // Carrega EPG automaticamente após configurar playlist M3U
      setState(() {
        _downloadStatus = 'Carregando EPG...';
        _downloadProgress = 0.95;
      });
      
      try {
        final epgUrl = EpgService.epgUrl;
        if (epgUrl != null && epgUrl.isNotEmpty) {
          print('📺 Settings: Carregando EPG automaticamente: $epgUrl');
          await EpgService.loadEpg(epgUrl);
          print('✅ Settings: EPG carregado: ${EpgService.getAllChannels().length} canais');
        } else {
          print('ℹ️ Settings: Nenhuma URL de EPG configurada');
        }
      } catch (e) {
        print('⚠️ Settings: Erro ao carregar EPG automaticamente: $e');
        // Não bloqueia o fluxo se EPG falhar
      }
      
      await Prefs.setPlaylistReady(true);

      setState(() {
        _isDownloading = false;
        _downloadProgress = 1.0;
        _downloadStatus = '';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Playlist baixada! Redirecionando...'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
        
        // Redireciona para Home após 1.5s
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        }
      }
    } catch (e) {
      print('❌ [Settings] Erro ao baixar: $e');
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0.0;
        _downloadStatus = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro ao baixar: $e'),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Row(
        children: [
          const AppSidebar(selectedIndex: 10),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // TMDB API Key (runtime) - moved to top for visibility
                    const Text(
                      'TMDB (enriquecimento de metadados)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassPanel(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TMDB API Key',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              decoration: BoxDecoration(
                                color: const Color(0xFF161b22),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _tmdbHasFocus ? AppColors.primary : Colors.white.withOpacity(0.05),
                                  width: 1,
                                ),
                                boxShadow: _tmdbHasFocus ? [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.5),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ] : [],
                              ),
                              child: RawKeyboardListener(
                                focusNode: FocusNode(),
                                onKey: (event) {
                                  if (event is RawKeyDownEvent) {
                                    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                                      FocusScope.of(context).previousFocus();
                                    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                      // Move focus to the Save button for TV remotes
                                      _tmdbSaveFocusNode.requestFocus();
                                    }
                                  }
                                },
                                child: TextField(
                                  controller: _tmdbController,
                                  focusNode: _tmdbFocusNode,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'Insira a TMDB API key (opcional)',
                                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.03),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  onSubmitted: (_) => _tmdbSaveFocusNode.requestFocus(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                ElevatedButton(
                                  focusNode: _tmdbSaveFocusNode,
                                  onPressed: _saveTmdbKey,
                                  child: const Text('Salvar chave'),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  focusNode: _tmdbTestFocusNode,
                                  onPressed: _testTmdbKey,
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                  child: const Text('Testar chave'),
                                ),
                                const SizedBox(width: 12),
                                TextButton(
                                  focusNode: _tmdbClearFocusNode,
                                  onPressed: () async {
                                    _tmdbController.text = '';
                                    await Prefs.setTmdbApiKey(null);
                                    TmdbService.init();
                                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chave TMDB removida')));
                                  },
                                  child: const Text('Limpar'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'A chave permite enriquecer capas e descrições. Se não configurada, o app não mostrará metadados TMDB.',
                              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Playlist (M3U) Input
                    const Text(
                      'Playlist IPTV (M3U)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassPanel(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'URL da Playlist',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              decoration: BoxDecoration(
                                color: const Color(0xFF161b22),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _urlHasFocus ? AppColors.primary : Colors.white.withOpacity(0.05),
                                  width: 1,
                                ),
                                boxShadow: _urlHasFocus ? [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.5),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ] : [],
                              ),
                              child: RawKeyboardListener(
                                focusNode: FocusNode(),
                                onKey: (event) {
                                  // Seta para cima sai do campo e volta ao menu
                                  if (event is RawKeyDownEvent && 
                                      event.logicalKey == LogicalKeyboardKey.arrowUp) {
                                    FocusScope.of(context).previousFocus();
                                  }
                                },
                                child: TextField(
                                  controller: _playlistController,
                                  focusNode: _urlFocusNode,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'https://exemplo.com/minha_playlist.m3u',
                                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.05),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  onSubmitted: (_) => _buttonFocusNode.requestFocus(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),                              Row(
                                children: [
                                  Expanded(child: Container()),
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      if (!mounted) return;
                                      final messenger = ScaffoldMessenger.of(context);
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Confirmar reset'),
                                          content: const Text('Deseja remover a playlist atual e limpar todos os caches?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
                                            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Confirmar')),
                                          ],
                                        ),
                                      );
                                      if (confirm == true && context.mounted) {
                                        // Reset
                                        await Prefs.setPlaylistOverride(null);
                                        await Prefs.setPlaylistReady(false);
                                        // Clear both memory and disk caches to ensure no stale data
                                        M3uService.clearMemoryCache();
                                        await M3uService.clearAllCache(null);
                                        await EpgService.clearCache();
                                        Config.setPlaylistOverride(null);
                                        // Recreate install marker to leave the app in a clean configured state
                                        await M3uService.writeInstallMarker();
                                        if (context.mounted) {
                                          messenger.showSnackBar(const SnackBar(content: Text('Reset realizado: playlist e cache limpos')));
                                          // Restart initialization to ensure UI reflects cleared state
                                          Navigator.pushReplacementNamed(context, '/splash', arguments: {'nextRoute': '/settings'});
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.restore),
                                    label: const Text('Reset playlist & cache'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                  ),
                                ],
                              ),                            if (_isDownloading) ...[
                              // Progress bar durante download
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: _downloadProgress,
                                  backgroundColor: Colors.white.withOpacity(0.1),
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                                  minHeight: 6,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _downloadStatus,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ] else ...[
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _buttonHasFocus ? Colors.white : Colors.transparent,
                                    width: 1,
                                  ),
                                  boxShadow: _buttonHasFocus ? [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.6),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ] : [],
                                ),
                                child: ElevatedButton.icon(
                                  focusNode: _buttonFocusNode,
                                  onPressed: _applyPlaylist,
                                  icon: Icon(
                                    Icons.download,
                                    size: _buttonHasFocus ? 28 : 24,
                                  ),
                                  label: Text(
                                    _buttonHasFocus ? '▶ BAIXAR E SALVAR ◀' : 'Baixar e Salvar',
                                    style: TextStyle(
                                      fontSize: _buttonHasFocus ? 16 : 14,
                                      fontWeight: _buttonHasFocus ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _buttonHasFocus 
                                        ? AppColors.primary
                                        : AppColors.primary.withOpacity(0.8),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'A lista será salva localmente',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Jellyfin Integration
                    const Text(
                      'Jellyfin Integration',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassPanel(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Manual Focus Chain for TV Remote
                            // URL -> User -> Pass -> Save Button -> Test Button
                            Column(
                              children: [
                                // URL
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF161b22),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _jfUrlFocusNode.hasFocus ? AppColors.primary : Colors.white.withOpacity(0.05), 
                                      width: 1
                                    ),
                                    boxShadow: _jfUrlFocusNode.hasFocus ? [
                                      BoxShadow(
                                        color: AppColors.primary.withOpacity(0.5),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      ),
                                    ] : [],
                                  ),
                                  child: Focus(
                                    canRequestFocus: false,
                                    onKeyEvent: (node, event) {
                                      if (event is KeyDownEvent) {
                                        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                          _jfUserFocusNode.requestFocus();
                                          return KeyEventResult.handled;
                                        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                                          _buttonFocusNode.requestFocus();
                                          return KeyEventResult.handled;
                                        }
                                      }
                                      return KeyEventResult.ignored;
                                    },
                                    child: TextField(
                                      controller: _jfUrlController,
                                      focusNode: _jfUrlFocusNode,
                                      style: const TextStyle(color: Colors.white),
                                      textInputAction: TextInputAction.next,
                                      onSubmitted: (_) => _jfUserFocusNode.requestFocus(),
                                      decoration: InputDecoration(
                                        labelText: 'Server URL',
                                        labelStyle: const TextStyle(color: Colors.white70),
                                        hintText: '192.168.1.100:8096',
                                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                                        filled: true,
                                        fillColor: Colors.white.withOpacity(0.05),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                
                                // User
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF161b22),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _jfUserFocusNode.hasFocus ? AppColors.primary : Colors.white.withOpacity(0.05), 
                                      width: 1
                                    ),
                                    boxShadow: _jfUserFocusNode.hasFocus ? [
                                      BoxShadow(
                                        color: AppColors.primary.withOpacity(0.5),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      ),
                                    ] : [],
                                  ),
                                  child: Focus(
                                    canRequestFocus: false,
                                    onKeyEvent: (node, event) {
                                      if (event is KeyDownEvent) {
                                        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                          _jfPassFocusNode.requestFocus();
                                          return KeyEventResult.handled;
                                        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                                          _jfUrlFocusNode.requestFocus();
                                          return KeyEventResult.handled;
                                        }
                                      }
                                      return KeyEventResult.ignored;
                                    },
                                    child: TextField(
                                      controller: _jfUserController,
                                      focusNode: _jfUserFocusNode,
                                      style: const TextStyle(color: Colors.white),
                                      textInputAction: TextInputAction.next,
                                      onSubmitted: (_) => _jfPassFocusNode.requestFocus(),
                                      decoration: InputDecoration(
                                        labelText: 'Username',
                                        labelStyle: const TextStyle(color: Colors.white70),
                                        filled: true,
                                        fillColor: Colors.white.withOpacity(0.05),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                
                                // Pass
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF161b22),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _jfPassFocusNode.hasFocus ? AppColors.primary : Colors.white.withOpacity(0.05), 
                                      width: 1
                                    ),
                                    boxShadow: _jfPassFocusNode.hasFocus ? [
                                      BoxShadow(
                                        color: AppColors.primary.withOpacity(0.5),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      ),
                                    ] : [],
                                  ),
                                  child: Focus(
                                    canRequestFocus: false,
                                    onKeyEvent: (node, event) {
                                      if (event is KeyDownEvent) {
                                        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                          _jfSaveFocusNode.requestFocus();
                                          return KeyEventResult.handled;
                                        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                                          _jfUserFocusNode.requestFocus();
                                          return KeyEventResult.handled;
                                        }
                                      }
                                      return KeyEventResult.ignored;
                                    },
                                    child: TextField(
                                      controller: _jfPassController,
                                      focusNode: _jfPassFocusNode,
                                      obscureText: true,
                                      style: const TextStyle(color: Colors.white),
                                      textInputAction: TextInputAction.done,
                                      onSubmitted: (_) => _jfSaveFocusNode.requestFocus(),
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        labelStyle: const TextStyle(color: Colors.white70),
                                        filled: true,
                                        fillColor: Colors.white.withOpacity(0.05),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    ElevatedButton(
                                      focusNode: _jfSaveFocusNode,
                                      onPressed: _saveJellyfinConfig,
                                      style: ElevatedButton.styleFrom(
                                        side: _jfSaveFocusNode.hasFocus ? const BorderSide(color: Colors.white, width: 2) : null
                                      ),
                                      child: const Text('Salvar'),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton(
                                      focusNode: _jfTestFocusNode,
                                      onPressed: _testJellyfinConfig,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        side: _jfTestFocusNode.hasFocus ? const BorderSide(color: Colors.white, width: 2) : null
                                      ),
                                      child: const Text('Testar Conexão'),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Appearance Settings
                    const Text(
                      'Appearance',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassPanel(
                      child: Column(
                        children: [
                          _buildSettingRow(
                            'Dark Mode',
                            'Use dark theme',
                            _darkMode,
                            (value) =>
                                setState(() => _darkMode = value),
                          ),
                          Divider(
                            color: Colors.white.withOpacity(0.1),
                          ),
                          _buildSettingRow(
                            'Autoplay',
                            'Automatically play next content',
                            _autoplay,
                            (value) =>
                                setState(() => _autoplay = value),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Playback Settings
                    const Text(
                      'Playback',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassPanel(
                      child: Column(
                        children: [
                          _buildSettingRow(
                            'Quality',
                            'Adaptive (4K when available)',
                            false,
                            null,
                            trailing: const Text(
                              'Adaptive',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Divider(
                            color: Colors.white.withOpacity(0.1),
                          ),
                          _buildSettingRow(
                            'Subtitle Size',
                            'Large',
                            false,
                            null,
                            trailing: const Text(
                              'Large',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Notifications
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassPanel(
                      child: _buildSettingRow(
                        'Push Notifications',
                        'Receive updates about new content',
                        _notifications,
                        (value) =>
                            setState(() => _notifications = value),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // About
                    const Text(
                      'About',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassPanel(
                      child: Column(
                        children: [
                          _buildSettingRow(
                            'App Version',
                            '1.0.0',
                            false,
                            null,
                            trailing: const Text(
                              '1.0.0',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Divider(
                            color: Colors.white.withOpacity(0.1),
                          ),
                          GestureDetector(
                            onTap: () {},
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.privacy_tip_outlined,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Privacy Policy',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          'View our privacy terms',
                                          style: TextStyle(
                                            color: Colors.white
                                                .withOpacity(0.6),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Divider(
                            color: Colors.white.withOpacity(0.1),
                          ),
                          GestureDetector(
                            onTap: () {},
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.help_outline,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Help & Support',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          'Get help with your account',
                                          style: TextStyle(
                                            color: Colors.white
                                                .withOpacity(0.6),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow(
    String title,
    String subtitle,
    bool value,
    Function(bool)? onChanged, {
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null)
            trailing
          else if (onChanged != null)
            Switch(
              value: value,
              activeThumbColor: AppColors.primary,
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }
}
