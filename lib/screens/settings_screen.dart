import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';
import '../core/config.dart';
import '../core/prefs.dart';
import '../core/utils/validators.dart';
import '../core/utils/logger.dart';
import '../data/m3u_service.dart';
import '../data/epg_service.dart';
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
  late TextEditingController _epgController;
  final FocusNode _urlFocusNode = FocusNode();
  final FocusNode _buttonFocusNode = FocusNode();
  final FocusNode _epgUrlFocusNode = FocusNode();
  final FocusNode _epgButtonFocusNode = FocusNode();
  bool _urlHasFocus = false;
  bool _buttonHasFocus = false;
  bool _epgUrlHasFocus = false;
  bool _epgButtonHasFocus = false;

  // Subtitle Preferences
  double _subtitleSize = 28.0;
  String _subtitleColor = 'white'; // white, yellow, cyan
  String _subtitleLanguage = 'por'; // por, eng, spa

  @override
  void initState() {
    super.initState();
    _playlistController = TextEditingController(text: Config.playlistRuntime ?? '');
    _epgController = TextEditingController(text: EpgService.epgUrl ?? '');
    _urlFocusNode.addListener(() {
      if (mounted) setState(() => _urlHasFocus = _urlFocusNode.hasFocus);
    });
    _buttonFocusNode.addListener(() {
      if (mounted) setState(() => _buttonHasFocus = _buttonFocusNode.hasFocus);
    });
    _epgUrlFocusNode.addListener(() {
      if (mounted) setState(() => _epgUrlHasFocus = _epgUrlFocusNode.hasFocus);
    });
    _epgButtonFocusNode.addListener(() {
      if (mounted) setState(() => _epgButtonHasFocus = _epgButtonFocusNode.hasFocus);
    });
    _loadSubtitlePrefs();
  }

  Future<void> _loadSubtitlePrefs() async {
    await Prefs.init();
    setState(() {
      _subtitleSize = Prefs.getSubtitleSize();
      _subtitleColor = Prefs.getSubtitleColor();
      _subtitleLanguage = Prefs.getSubtitleLanguage();
    });
  }

  @override
  void dispose() {
    _playlistController.dispose();
    _epgController.dispose();
    _urlFocusNode.dispose();
    _buttonFocusNode.dispose();
    _epgUrlFocusNode.dispose();
    _epgButtonFocusNode.dispose();
    super.dispose();
  }

  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatus = '';
  
  bool _isDownloadingEpg = false;
  String _epgDownloadStatus = '';

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

  Future<void> _applyEpg() async {
    final value = _epgController.text.trim();
    
    if (value.isEmpty) {
      await EpgService.clearCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('EPG removido'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    setState(() {
      _isDownloadingEpg = true;
      _epgDownloadStatus = 'Baixando EPG...';
    });

    try {
      print('🔧 [Settings] Baixando EPG: $value');
      
      await EpgService.loadEpg(value);
      
      setState(() {
        _isDownloadingEpg = false;
        _epgDownloadStatus = '';
      });
      
      final channelCount = EpgService.getAllChannels().length;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ EPG carregado! $channelCount canais'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ [Settings] Erro ao baixar EPG: $e');
      setState(() {
        _isDownloadingEpg = false;
        _epgDownloadStatus = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro ao baixar EPG: $e'),
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
                                        await M3uService.clearAllCache(null);
                                        await EpgService.clearCache();
                                        if (mounted) {
                                          messenger.showSnackBar(const SnackBar(content: Text('Reset realizado: playlist e cache limpos')));
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
                    // EPG (Electronic Program Guide) Input
                    const Text(
                      'Guia de Programação (EPG)',
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
                            Row(
                              children: [
                                const Icon(Icons.calendar_month, color: AppColors.primary, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'URL do EPG (XMLTV)',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  icon: const Icon(Icons.tv_outlined, size: 16),
                                  label: const Text('Ver Guia'),
                                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                                  onPressed: () => Navigator.pushNamed(context, '/epg'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _epgUrlHasFocus ? AppColors.primary : Colors.transparent,
                                  width: 3,
                                ),
                                boxShadow: _epgUrlHasFocus ? [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.4),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ] : [],
                              ),
                              child: TextField(
                                controller: _epgController,
                                focusNode: _epgUrlFocusNode,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'https://exemplo.com/epg.xml',
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
                                onSubmitted: (_) => _epgButtonFocusNode.requestFocus(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_isDownloadingEpg) ...[
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _epgDownloadStatus,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _epgButtonHasFocus ? Colors.white : Colors.transparent,
                                        width: 3,
                                      ),
                                      boxShadow: _epgButtonHasFocus ? [
                                        BoxShadow(
                                          color: AppColors.primary.withOpacity(0.6),
                                          blurRadius: 16,
                                          spreadRadius: 2,
                                        ),
                                      ] : [],
                                    ),
                                    child: ElevatedButton.icon(
                                      focusNode: _epgButtonFocusNode,
                                      onPressed: _applyEpg,
                                      icon: const Icon(Icons.download, size: 20),
                                      label: Text(
                                        _epgButtonHasFocus ? '▶ BAIXAR EPG ◀' : 'Baixar EPG',
                                        style: TextStyle(
                                          fontSize: _epgButtonHasFocus ? 14 : 12,
                                          fontWeight: _epgButtonHasFocus ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _epgButtonHasFocus 
                                            ? Colors.green
                                            : Colors.green.withOpacity(0.8),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  if (EpgService.isLoaded)
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _epgButtonHasFocus ? Colors.amber : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          final epgUrl = EpgService.epgUrl;
                                          if (epgUrl != null && epgUrl.isNotEmpty) {
                                            setState(() {
                                              _isDownloadingEpg = true;
                                              _epgDownloadStatus = 'Atualizando EPG...';
                                            });
                                            try {
                                              await EpgService.loadEpg(epgUrl);
                                              final channelCount = EpgService.getAllChannels().length;
                                              setState(() {
                                                _isDownloadingEpg = false;
                                                _epgDownloadStatus = '';
                                              });
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('✅ EPG atualizado! $channelCount canais'),
                                                    duration: const Duration(seconds: 3),
                                                    backgroundColor: Colors.green,
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              setState(() {
                                                _isDownloadingEpg = false;
                                                _epgDownloadStatus = '';
                                              });
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('❌ Erro ao atualizar EPG: $e'),
                                                    duration: const Duration(seconds: 3),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
                                            }
                                          }
                                        },
                                        icon: const Icon(Icons.refresh, size: 18),
                                        label: const Text('Atualizar EPG'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue.withOpacity(0.8),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        ),
                                      ),
                                    ),
                                  if (EpgService.isLoaded)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${EpgService.getAllChannels().length} canais',
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'O EPG mostra a programação dos canais ao vivo',
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
                          // --- Subtitle Language ---
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Language', style: TextStyle(color: Colors.white)),
                                DropdownButton<String>(
                                  value: _subtitleLanguage,
                                  dropdownColor: Colors.grey[900],
                                  style: const TextStyle(color: Colors.white),
                                  underline: Container(),
                                  items: const [
                                    DropdownMenuItem(value: 'por', child: Text('Português')),
                                    DropdownMenuItem(value: 'eng', child: Text('English')),
                                    DropdownMenuItem(value: 'spa', child: Text('Español')),
                                    DropdownMenuItem(value: 'off', child: Text('Desativado')),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() => _subtitleLanguage = v);
                                      Prefs.setSubtitleLanguage(v);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          Divider(color: Colors.white.withOpacity(0.1)),
                          
                          // --- Subtitle Size ---
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Size', style: TextStyle(color: Colors.white)),
                                    Row(
                                      children: [
                                        _buildSizeBtn(Icons.remove, () {
                                          setState(() {
                                            if (_subtitleSize > 12) _subtitleSize -= 2;
                                            Prefs.setSubtitleSize(_subtitleSize);
                                          });
                                        }),
                                        SizedBox(
                                          width: 60,
                                          child: Center(
                                            child: Text(
                                              '${_subtitleSize.toInt()}px',
                                              style: const TextStyle(color: Colors.white),
                                            ),
                                          ),
                                        ),
                                        _buildSizeBtn(Icons.add, () {
                                          setState(() {
                                            if (_subtitleSize < 64) _subtitleSize += 2;
                                            Prefs.setSubtitleSize(_subtitleSize);
                                          });
                                        }),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Divider(color: Colors.white.withOpacity(0.1)),

                          // --- Subtitle Color ---
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Color', style: TextStyle(color: Colors.white)),
                                Row(
                                  children: [
                                    _buildColorBtn('white', Colors.white),
                                    const SizedBox(width: 8),
                                    _buildColorBtn('yellow', Colors.yellow),
                                    const SizedBox(width: 8),
                                    _buildColorBtn('cyan', Colors.cyanAccent),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // --- Preview ---
                          Container(
                            margin: const EdgeInsets.only(top: 16),
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                              image: const DecorationImage(
                                image: AssetImage('assets/images/logo.png'), // Placeholder bg
                                fit: BoxFit.cover,
                                opacity: 0.3,
                              ),
                            ),
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'Exemplo de Legenda\nSubtitle Preview',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: _subtitleSize,
                                  color: _subtitleColor == 'yellow' 
                                      ? Colors.yellow 
                                      : _subtitleColor == 'cyan' 
                                          ? Colors.cyanAccent 
                                          : Colors.white,
                                  shadows: const [
                                    Shadow(offset: Offset(1, 1), blurRadius: 2, color: Colors.black),
                                  ],
                                ),
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




  Widget _buildSizeBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _buildColorBtn(String colorName, Color color) {
    bool isSelected = _subtitleColor == colorName;
    return GestureDetector(
      onTap: () {
        setState(() => _subtitleColor = colorName);
        Prefs.setSubtitleColor(colorName);
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.white24,
            width: isSelected ? 2 : 1,
          ),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
