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
import '../widgets/glass_panel.dart';
import '../widgets/custom_app_header.dart';

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
  }

  Future<void> _saveTmdbKey() async {
    final key = _tmdbController.text.trim();
    try {
      await Prefs.setTmdbApiKey(key.isEmpty ? null : key);
      // Re-init service so it picks up runtime key
      TmdbService.init();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chave TMDB salva')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar chave TMDB: $e')),
        );
      }
    }
  }

  Future<void> _testTmdbKey() async {
    final key = _tmdbController.text.trim();
    if (key.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insira a chave TMDB antes de testar')));
      return;
    }
    try {
      // Persiste temporariamente to ensure TmdbService reads the updated key
      await Prefs.setTmdbApiKey(key);
      // Force reload
      TmdbService.init();
      final ok = await TmdbService.testApiKeyNow();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? '✅ Chave TMDB válida' : '❌ Chave inválida ou erro (veja logs)')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao testar chave: $e')));
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
  final List<HeaderNav> _navItems = [
    HeaderNav(label: 'Início'),
    HeaderNav(label: 'Filmes'),
    HeaderNav(label: 'Séries'),
    HeaderNav(label: 'Canais'),
    HeaderNav(label: 'SharkFlix'),
  ];

  void _navigateByIndex(int index) {
    // Mapeia para abas da Home
    if (index >= 0 && index <= 4) {
      Navigator.pushNamed(context, '/home', arguments: index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Column(
        children: [
          CustomAppHeader(
            title: 'Click Channel',
            navItems: _navItems,
            selectedNavIndex: _selectedNavIndex,
            onNavSelected: (index) => _navigateByIndex(index),
            showSearch: false,
            onNotificationTap: () {},
            onProfileTap: () {
              Navigator.pushNamed(context, '/profile');
            },
            onSettingsTap: () {
              // Já estamos em Settings, fechar ou fazer nada
              print('🔧 Já em Settings');
            },
          ),
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
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _tmdbHasFocus ? AppColors.primary : Colors.transparent,
                                  width: 3,
                                ),
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
                                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chave TMDB removida')));
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
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _urlHasFocus ? AppColors.primary : Colors.transparent,
                                  width: 3,
                                ),
                                boxShadow: _urlHasFocus ? [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.4),
                                    blurRadius: 12,
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
                                      if (confirm == true && mounted) {
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
                                        if (mounted) {
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
                                    width: 3,
                                  ),
                                  boxShadow: _buttonHasFocus ? [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.6),
                                      blurRadius: 16,
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
