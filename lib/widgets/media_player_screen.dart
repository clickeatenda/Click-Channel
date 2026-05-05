import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/content_item.dart';
import '../data/m3u_service.dart';
import '../data/watch_history_service.dart';
import '../data/epg_service.dart';
import '../models/epg_program.dart';

import '../core/config.dart';
import '../core/click_channel_web_proxy.dart';
import '../core/device_awake_guard.dart';
import '../core/managed_access_storage.dart';
import '../core/prefs.dart';
import '../data/favorites_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/jellyfin_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:ui';

class _JellyfinPlaybackPlan {
  final String url;
  final bool usesServerSideSubtitles;
  final String? subtitleLabel;

  const _JellyfinPlaybackPlan({
    required this.url,
    this.usesServerSideSubtitles = false,
    this.subtitleLabel,
  });
}

/// Player avançado usando media_kit (libmpv) com suporte completo a 4K/HDR
class MediaPlayerScreen extends StatefulWidget {
  final String url;
  final ContentItem? item;
  final String? title;

  const MediaPlayerScreen({
    super.key,
    required this.url,
    this.item,
    this.title,
    this.playlist,
    this.playlistIndex = 0,
  });

  final List<ContentItem>? playlist;
  final int playlistIndex;

  @override
  State<MediaPlayerScreen> createState() => _MediaPlayerScreenState();
}

class _MediaPlayerScreenState extends State<MediaPlayerScreen> {
  // ... (campos existentes)
  Player? _player;
  VideoController? _controller;

  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  int _retryCount = 0; // Contador para tentativas de recuperação de erro
  Timer? _stallTimer; // Timer para detectar congelamento de buffering
  Timer? _videoPresenceTimer;
  bool _useFireTvLiveMode = false;
  bool _usingDirectWebFallback = false;
  bool _directWebFallbackAttempted = false;
  bool _usingLiveHlsPreference = false;
  bool _channelVariantFallbackAttempted = false;
  bool _webChannelSameSourceRetryAttempted = false;
  final Set<String> _webChannelAttemptedUrls = <String>{};
  int _playerInitSeq = 0;
  bool _showControls = true;
  bool _showInfo = false;
  bool _showAudioOptions = false;
  bool _showSubtitleOptions = false;
  bool _showFitOptions = false;
  bool isFavorite = false; // Novo estado

  // Informações de mídia
  String _videoQuality = 'Carregando...';
  // ... (restante dos campos)
  String _videoCodec = '';
  String _audioCodec = '';
  String _currentAudio = 'Padrão';
  String _currentSubtitle = 'Desativado';
  List<AudioTrack> _audioTracks = [];
  List<SubtitleTrack> _subtitleTracks = [];
  List<SubtitleTrack> _externalSubtitles =
      []; // NOVO: Armazena legendas externas (Jellyfin)
  int _selectedAudioIndex = 0;
  int _selectedSubtitleIndex = -1;

  // EPG (para canais)
  EpgChannel? _epgChannel;
  EpgProgram? _currentEpgProgram;
  EpgProgram? _nextEpgProgram;

  // Playlist Autoplay
  List<ContentItem> _playlist = [];
  int _currentIndex = 0;

  // Opções de ajuste de tela
  BoxFit _videoFit = BoxFit.contain;
  int _fitIndex = 0;
  // ... (resto dos campos)

  final List<Map<String, dynamic>> _fitOptions = [
    {'fit': BoxFit.contain, 'label': 'Ajustar', 'icon': Icons.fit_screen},
    {'fit': BoxFit.cover, 'label': 'Preencher', 'icon': Icons.crop_free},
    {'fit': BoxFit.fill, 'label': 'Esticar', 'icon': Icons.aspect_ratio},
    {'fit': BoxFit.fitWidth, 'label': 'Largura', 'icon': Icons.swap_horiz},
    {'fit': BoxFit.fitHeight, 'label': 'Altura', 'icon': Icons.swap_vert},
  ];

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isBuffering = false;

  ContentItem? get _activeItem {
    if (_playlist.isNotEmpty &&
        _currentIndex >= 0 &&
        _currentIndex < _playlist.length) {
      return _playlist[_currentIndex];
    }
    return widget.item;
  }

  bool get _isActiveChannel => _activeItem?.type == 'channel';

  // Controle de gravação
  int _lastSavedSeconds = -1;
  bool _autoSubtitleSelected = false;
  bool _completionHandled = false;

  // FocusNodes
  final FocusNode _playPauseFocusNode = FocusNode();
  final FocusNode _rootFocusNode = FocusNode(); // Root for keyboard listener
  final FocusNode _rewindFocusNode = FocusNode();
  final FocusNode _forwardFocusNode = FocusNode();
  final FocusNode _backFocusNode = FocusNode();
  final FocusNode _favoriteFocusNode = FocusNode();
  final FocusNode _infoTopFocusNode = FocusNode();
  final FocusNode _audioFocusNode = FocusNode();
  final FocusNode _subtitleFocusNode = FocusNode();
  final FocusNode _fitFocusNode = FocusNode();
  final FocusNode _infoFocusNode = FocusNode();

  // Customização de Legendas
  bool _showSubtitleCustomizer = false;
  final FocusNode _subToggleCustomizerNode = FocusNode();
  final FocusNode _subSizeNode = FocusNode();
  final FocusNode _subColorNode = FocusNode();
  final FocusNode _subBgToggleNode = FocusNode();

  // Panel Focus Nodes
  List<FocusNode> _audioNodes = [];
  List<FocusNode> _subtitleNodes = [];
  final FocusNode _firstFitOptionNode = FocusNode();

  bool _shouldForceHlsForUrl(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('.m3u8')) return false;
    if (lower.contains('/api/auth/stream/media')) return false;
    if (lower.contains('format=direct')) return false;
    if (lower.endsWith('.mp4') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mp3') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.ogg') ||
        lower.endsWith('.ogv')) {
      return false;
    }

    return lower.contains('/live/') ||
        lower.endsWith('.ts') ||
        lower.endsWith('.m2ts') ||
        lower.endsWith('.mpegts') ||
        !lower.contains('.');
  }

  void _updateListFocusNodes() {
    for (var node in _audioNodes) {
      node.dispose();
    }
    for (var node in _subtitleNodes) {
      node.dispose();
    }
    _audioNodes = List.generate(
        _audioTracks.isNotEmpty ? _audioTracks.length : 1, (i) => FocusNode());
    _subtitleNodes =
        List.generate(_subtitleTracks.length + 1, (i) => FocusNode());
  }

  @override
  void initState() {
    super.initState();
    DeviceAwakeGuard.instance.ensureEnabled();

    try {
      if (widget.item != null) {
        isFavorite = FavoritesService.isFavorite(widget.item!);
        final title = widget.item!.title.toLowerCase();
        if (widget.item!.type == 'channel' &&
            (title.contains('fhd') ||
                title.contains('full hd') ||
                title.contains('1080'))) {
          _useFireTvLiveMode = true;
        }
      }
      _playlist = List<ContentItem>.from(
          widget.playlist ?? (widget.item != null ? [widget.item!] : []));
      _currentIndex = widget.playlistIndex;

      // Delay init para dar tempo ao widget tree estabilizar (importante no Firestick)
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _initPlayer().catchError((e) {
            print('❌ Erro crítico ao inicializar player: $e');
            if (mounted) {
              setState(() {
                _hasError = true;
                _errorMessage = 'Falha ao inicializar player: $e';
              });
            }
          });
        }
      });
    } catch (e) {
      print('❌ Erro no initState: $e');
      _hasError = true;
      _errorMessage = 'Erro ao inicializar tela: $e';
    }
  }

  Future<void> _toggleFavorite() async {
    if (widget.item == null) return;
    await FavoritesService.toggleFavorite(widget.item!);
    setState(() {
      isFavorite = !isFavorite;
    });
    // Feedback é mostrado via ícone preenchido
  }

  // ... (método _initPlayer original inalterado) ...

  // ... (dentro de _buildTopBar) ...

  /// CAMADA SUPERIOR: Voltar | Favoritos | Info
  Widget _buildTopBar() {
    return Positioned(
      top: MediaQuery.of(context).padding.top > 0
          ? MediaQuery.of(context).padding.top
          : 24,
      left: 32,
      right: 32,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                // Título
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title ?? widget.item?.title ?? 'Reproduzindo',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _videoQuality,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Botões da camada superior
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // VOLTAR
                    _buildTopButton(
                      focusNode: _backFocusNode,
                      icon: Icons.arrow_back,
                      label: 'Voltar',
                      onPressed: _exitPlayer,
                      onDownPressed: () => _rewindFocusNode.requestFocus(),
                    ),
                    const SizedBox(width: 12),

                    // FAVORITOS
                    if (widget.item != null)
                      _buildTopButton(
                        focusNode: _favoriteFocusNode,
                        icon:
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                        label: 'Favorito',
                        color: isFavorite ? Colors.red : Colors.white,
                        onPressed: _toggleFavorite,
                        onDownPressed: () => _playPauseFocusNode.requestFocus(),
                      ),
                    const SizedBox(width: 12),

                    // INFORMAÇÃO
                    _buildTopButton(
                      focusNode: _infoTopFocusNode,
                      icon: Icons.info_outline,
                      label: 'Info',
                      color: _showInfo ? Colors.blueAccent : Colors.white,
                      onPressed: () => setState(() {
                        _showInfo = !_showInfo;
                        _showAudioOptions = false;
                        _showSubtitleOptions = false;
                        _showFitOptions = false;
                      }),
                      onDownPressed: () => _forwardFocusNode.requestFocus(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopButton({
    required FocusNode focusNode,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required VoidCallback onDownPressed,
    Color color = Colors.white,
  }) {
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          // Enter/Select - ativa o botão
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.gameButtonA) {
            onPressed();
            return KeyEventResult.handled;
          }
          // Seta para baixo - vai para camada do meio
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            onDownPressed();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(builder: (ctx) {
        final hasFocus = Focus.of(ctx).hasFocus;
        return GestureDetector(
          onTap: onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: hasFocus
                  ? Colors.blueAccent.withOpacity(0.7)
                  : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasFocus ? Colors.blueAccent : Colors.transparent,
                width: hasFocus ? 2 : 0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: hasFocus ? Colors.white : color, size: 22),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: hasFocus ? Colors.white : color,
                    fontSize: 12,
                    fontWeight: hasFocus ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  void _applySubtitleStyles() {
    if (_player == null) return;
    try {
      final dynamic nativePlayer = _player!.platform;
      final size = Prefs.getSubtitleSize();
      final color = Prefs.getSubtitleColor();
      final hasBg = Prefs.getSubtitleBackground();
      final bgColor = Prefs.getSubtitleBackgroundColor();

      // Converte nome de cor para Hex Argb/Rgb esperado pelo mpv
      String colorHex = '#FFFFFF';
      switch (color.toLowerCase()) {
        case 'yellow':
          colorHex = '#FFFF00';
          break;
        case 'cyan':
          colorHex = '#00FFFF';
          break;
        case 'green':
          colorHex = '#00FF00';
          break;
      }

      nativePlayer.setProperty('sub-font-size', size.toInt().toString());
      nativePlayer.setProperty('sub-color', colorHex);
      nativePlayer.setProperty('sub-border-size', '2');
      nativePlayer.setProperty('sub-shadow-offset', '1');

      if (hasBg) {
        nativePlayer.setProperty('sub-back-color', bgColor);
      } else {
        nativePlayer.setProperty('sub-back-color', '#00000000');
      }

      print(
          '📝 Estilos de legenda aplicados: Tam=$size, Cor=$color, Fundo=$hasBg');
    } catch (e) {
      print('⚠️ Erro ao aplicar estilos de legenda: $e');
    }
  }

  Future<String> _resolveManagedWebPlaybackUrl(
    String sourceUrl, {
    bool forceDirect = false,
    bool preferLiveHls = false,
  }) async {
    if (!kIsWeb || !Config.useManagedAccess || Config.backendUrl.isEmpty) {
      return sourceUrl;
    }
    if (ClickChannelWebProxy.isBackendPlaybackProxy(sourceUrl)) {
      return sourceUrl;
    }

    try {
      const storage = FlutterSecureStorage();
      String? authToken = (await storage.read(key: 'auth_token')) ??
          ClickChannelWebProxy.managedAccessToken();
      if (authToken == null || authToken.isEmpty) {
        final managed = await ManagedAccessStorage.read();
        authToken = ClickChannelWebProxy.accessTokenFromUrl(managed['url']);
      }
      if (authToken == null || authToken.isEmpty) {
        return sourceUrl;
      }

      final uri =
          Uri.parse('${Config.backendUrl}/api/auth/stream/ticket').replace(
        queryParameters: {
          'access_token': authToken,
          'upstream_url': sourceUrl,
          if (preferLiveHls) 'format': 'hls',
          if (forceDirect) 'format': 'direct',
        },
      );

      final response = await http.get(uri, headers: const {
        'Accept': 'application/json',
      });

      if (response.statusCode != 200) {
        print(
            '⚠️ Falha ao resolver proxy web do Click SaaS: ${response.statusCode} ${response.body}');
        return sourceUrl;
      }

      final data = jsonDecode(response.body);
      final resolved = data is Map ? data['url']?.toString() : null;
      if (resolved == null || resolved.isEmpty) {
        return sourceUrl;
      }

      print('🌐 Proxy web do Click SaaS resolvido para playback');
      return resolved;
    } catch (e) {
      print('⚠️ Erro ao resolver proxy web do Click SaaS: $e');
      return sourceUrl;
    }
  }

  bool _isRecoverableWebSourceError(String error) {
    final lower = error.toLowerCase();
    return lower.contains('supported source') ||
        lower.contains('src_not_supported') ||
        lower.contains('media_err_src_not_supported') ||
        lower.contains('hls') ||
        lower.contains('manifest') ||
        lower.contains('failed to load');
  }

  bool _shouldRetryWithDirectWebFallback(String error) {
    if (!kIsWeb ||
        !Config.useManagedAccess ||
        Config.backendUrl.isEmpty ||
        _usingDirectWebFallback ||
        _directWebFallbackAttempted ||
        widget.item?.type == 'channel') {
      return false;
    }

    return _isRecoverableWebSourceError(error);
  }

  void _retryManagedWebDirectFallback(String reason) {
    if (_directWebFallbackAttempted || !mounted) return;
    _directWebFallbackAttempted = true;
    print(
        '🌐 Web: manifesto recusado pelo player, tentando mídia direta. Motivo: $reason');
    Future.microtask(() {
      if (mounted) _initPlayer(forceDirectWebPlayback: true);
    });
  }

  void _scheduleWebChannelVideoPresenceCheck() {
    _videoPresenceTimer?.cancel();
    if (!kIsWeb || !_isActiveChannel || _channelVariantFallbackAttempted) {
      return;
    }

    _videoPresenceTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted ||
          !_isActiveChannel ||
          _channelVariantFallbackAttempted ||
          !_isPlaying) {
        return;
      }

      final width = _player?.state.width ?? 0;
      final height = _player?.state.height ?? 0;
      if (width > 0 && height > 0) return;

      _recoverWebChannelPlayback(
          'o áudio iniciou, mas o navegador não recebeu vídeo decodificável');
    });
  }

  Future<bool> _recoverWebChannelPlayback(String reason) async {
    if (!kIsWeb || !_isActiveChannel || !mounted) return false;

    if (!_webChannelSameSourceRetryAttempted) {
      _webChannelSameSourceRetryAttempted = true;
      _videoPresenceTimer?.cancel();
      print(
          '🔄 Web: reabrindo o mesmo canal antes de trocar variante. Motivo: $reason');
      Future.microtask(() {
        if (mounted) _initPlayer();
      });
      return true;
    }

    return _retryWebChannelVariant(reason);
  }

  Future<bool> _retryWebChannelVariant(String reason) async {
    if (!kIsWeb || _channelVariantFallbackAttempted || !mounted) return false;
    final currentItem = _activeItem;
    if (currentItem == null || currentItem.type != 'channel') return false;

    _channelVariantFallbackAttempted = true;
    final alternatives =
        await M3uService.getChannelPlaybackAlternatives(currentItem);
    if (!mounted) return false;

    ContentItem? nextItem;
    for (final item in alternatives) {
      if (!_webChannelAttemptedUrls.contains(item.url)) {
        nextItem = item;
        break;
      }
    }

    if (nextItem == null) {
      print('⚠️ Sem variante alternativa para ${currentItem.title}: $reason');
      return false;
    }
    final selectedItem = nextItem;

    _webChannelAttemptedUrls.add(currentItem.url);
    _webChannelAttemptedUrls.add(selectedItem.url);
    _webChannelSameSourceRetryAttempted = false;
    _videoPresenceTimer?.cancel();

    print(
        '🔄 Web: canal sem vídeo, trocando variante "${currentItem.title}" -> "${selectedItem.title}". Motivo: $reason');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Trocando para ${selectedItem.title}...'),
        duration: const Duration(seconds: 2),
      ),
    );

    setState(() {
      _playlist[_currentIndex] = selectedItem;
      _hasError = false;
      _errorMessage = '';
      _isInitialized = false;
      _isBuffering = true;
      _position = Duration.zero;
      _videoQuality = 'Carregando...';
    });

    Future.microtask(() {
      if (mounted) _initPlayer();
    });

    return true;
  }

  String? _findJellyfinSubtitleLabel(
      Map<String, dynamic>? mediaInfo, int? subtitleStreamIndex) {
    if (mediaInfo == null || subtitleStreamIndex == null) {
      return null;
    }

    final mediaSources = mediaInfo['MediaSources'];
    if (mediaSources is! List || mediaSources.isEmpty) {
      return null;
    }

    final source = mediaSources.first;
    final mediaStreams = source['MediaStreams'];
    if (mediaStreams is! List) {
      return null;
    }

    for (final dynamic stream in mediaStreams) {
      if (stream is! Map) {
        continue;
      }

      final type = stream['Type']?.toString().toLowerCase();
      final index = int.tryParse(stream['Index']?.toString() ?? '');
      if (type == 'subtitle' && index == subtitleStreamIndex) {
        return stream['Title']?.toString() ??
            stream['DisplayTitle']?.toString() ??
            stream['Language']?.toString();
      }
    }

    return null;
  }

  Future<_JellyfinPlaybackPlan> _buildJellyfinPlaybackPlan(
      ContentItem item) async {
    try {
      final playbackInfo = await JellyfinService.getPlaybackInfo(item.id);
      final mediaInfo =
          await JellyfinService.getMediaInfo(item.id) ?? playbackInfo;
      final mediaSources =
          (playbackInfo?['MediaSources'] ?? mediaInfo?['MediaSources']);

      String? sourceId;
      if (mediaSources is List && mediaSources.isNotEmpty) {
        sourceId = mediaSources.first['Id']?.toString();
      }

      if (kIsWeb) {
        final preferredSubtitleIndex =
            JellyfinService.getPreferredSubtitleStreamIndex(mediaInfo);
        final subtitleLabel =
            _findJellyfinSubtitleLabel(mediaInfo, preferredSubtitleIndex);
        final hlsUrl = JellyfinService.getHlsTranscodingUrlWithOptions(
          item.id,
          mediaSourceId: sourceId,
          subtitleStreamIndex: preferredSubtitleIndex,
        );

        if (hlsUrl.isNotEmpty) {
          print(
              '🌐 Jellyfin web: usando HLS transcoding para compatibilidade de áudio/legenda');
          return _JellyfinPlaybackPlan(
            url: hlsUrl,
            usesServerSideSubtitles: preferredSubtitleIndex != null,
            subtitleLabel: subtitleLabel,
          );
        }
      }

      if (sourceId != null && sourceId.isNotEmpty) {
        return _JellyfinPlaybackPlan(
          url: JellyfinService.getStreamUrl(item.id, mediaSourceId: sourceId),
        );
      }
    } catch (e) {
      print('⚠️ Jellyfin: falha ao preparar playback: $e');
    }

    return _JellyfinPlaybackPlan(url: item.url);
  }

  Future<void> _initPlayer({bool forceDirectWebPlayback = false}) async {
    final initSeq = ++_playerInitSeq;
    try {
      print('🎬 Iniciando player para: ${widget.url}');
      _completionHandled = false;
      _usingDirectWebFallback = forceDirectWebPlayback;
      _usingLiveHlsPreference = kIsWeb &&
          Config.useManagedAccess &&
          Config.backendUrl.isNotEmpty &&
          _isActiveChannel;
      _channelVariantFallbackAttempted = false;
      if (!kIsWeb || !_isActiveChannel) {
        _webChannelAttemptedUrls.clear();
        _webChannelSameSourceRetryAttempted = false;
      } else {
        final activeUrl = _activeItem?.url;
        if (activeUrl != null && activeUrl.isNotEmpty) {
          _webChannelAttemptedUrls.add(activeUrl);
        }
      }

      // Cancelar timers anteriores
      _stallTimer?.cancel();

      // Cleanup anterior se houver (retry)
      final oldPlayer = _player;
      _player = null;
      if (oldPlayer != null) {
        try {
          await oldPlayer.dispose();
        } catch (e) {
          print('⚠️ Player anterior já estava encerrado: $e');
        }
      }
      if (!mounted || initSeq != _playerInitSeq) return;

      // Apply Buffer Size Preference
      final prefsBuffer = Prefs.getBufferSize();
      int bufferBytes = 32 * 1024 * 1024; // Default medium
      if (_isActiveChannel) {
        // Live precisa de um buffer curto. Buffer grande no Fire TV faz o player
        // tentar reaproveitar trechos antigos e pode parecer um loop de replay.
        bufferBytes = _useFireTvLiveMode ? 12 * 1024 * 1024 : 8 * 1024 * 1024;
      } else if (prefsBuffer == 'low') {
        bufferBytes = 8 * 1024 * 1024;
      } else if (prefsBuffer == 'high') {
        bufferBytes = 64 * 1024 * 1024;
      }

      _player = Player(
        configuration: PlayerConfiguration(
          bufferSize: bufferBytes,
        ),
      );

      // Ajustes de Performance — aplicados para TODOS os tipos de mídia:
      try {
        dynamic nativePlayer = _player!.platform;
        final decoder = Prefs.getDecoder();

        if (_isActiveChannel) {
          // ─── CANAIS AO VIVO ───────────────────────────────────────────────
          // Projetores e TVs Android com MediaCodec bugado produzem artefatos
          // verdes quando o decodificador acessa a GPU diretamente (surface mode).
          // `mediacodec-copy` usa hardware mas copia os frames de volta à RAM,
          // eliminando o problema de renderização e os riscos verdes.
          if (decoder == 'sw') {
            print('⚙️ [Canal] Decodificador de Software forçado pelo usuário');
            nativePlayer.setProperty('hwdec', 'no');
          } else if (_useFireTvLiveMode) {
            print(
                '⚙️ [Canal] Modo Fire TV live: MediaCodec direto + buffer curto');
            nativePlayer.setProperty('hwdec', 'mediacodec');
            nativePlayer.setProperty('video-sync', 'audio');
            nativePlayer.setProperty('audio-channels', 'stereo');
            nativePlayer.setProperty('audio-samplerate', '48000');
            nativePlayer.setProperty('cache', 'yes');
            nativePlayer.setProperty('cache-pause', 'no');
            nativePlayer.setProperty('demuxer-readahead-secs', '4');
            nativePlayer.setProperty('demuxer-max-bytes', '12MiB');
          } else {
            print(
                '⚙️ [Canal] Usando mediacodec-copy (HW seguro para projetores)');
            nativePlayer.setProperty('hwdec', 'mediacodec-copy');
            nativePlayer.setProperty('cache', 'yes');
            nativePlayer.setProperty('cache-pause', 'no');
            nativePlayer.setProperty('demuxer-readahead-secs', '3');
            nativePlayer.setProperty('demuxer-max-bytes', '8MiB');
          }
          // Live streams têm quadros inter-dependentes — framedrop agressivo
          // pode corrompê-los. Usamos 'decoder' que só descarta se o decoder atrasar.
          nativePlayer.setProperty(
              'framedrop', _useFireTvLiveMode ? 'vo' : 'decoder');
          // Sem passthrough de áudio em live (pode causar crashes em alguns projetores)
          nativePlayer.setProperty('audio-spdif', '');
          // Aumenta tolerância de jitter em live streams
          nativePlayer.setProperty('demuxer-max-back-bytes', '1MiB');
          nativePlayer.setProperty('force-seekable', 'no');
        } else {
          // ─── VOD (Filmes / Séries) ────────────────────────────────────────
          if (decoder == 'sw') {
            print('⚙️ [VOD] Decodificador de Software forçado pelo usuário');
            nativePlayer.setProperty('hwdec', 'no');
          } else {
            print('⚙️ [VOD] Usando decodificador padrão (hardware)');
            // Padrão do media_kit já usa hardware quando disponível
          }
          // Passthrough de áudio premium para VOD (Dolby/DTS via HDMI)
          nativePlayer.setProperty('audio-spdif', 'ac3,eac3,dts,dts-hd,truehd');
          // VOD: skip de frame na saída de vídeo se a GPU atrasar
          nativePlayer.setProperty('framedrop', 'vo');
        }
      } catch (e) {
        print('Aviso: Não foi possível aplicar libmpv properties: $e');
      }

      _controller = VideoController(_player!);

      // Listeners
      _player!.stream.playing.listen((playing) {
        if (mounted) setState(() => _isPlaying = playing);
      });

      _player!.stream.position.listen((position) {
        if (mounted) {
          // Sem setState global para evitar FPS insano na Engine do Flutter que rouba CPU do decodificador!
          _position = position;
          _saveProgress();
          _checkVodCompletionByPosition();
        }
      });

      _player!.stream.duration.listen((duration) {
        if (mounted) setState(() => _duration = duration);
      });

      _player!.stream.buffering.listen((buffering) {
        if (mounted) {
          setState(() => _isBuffering = buffering);

          // Auto-reconnect para Live Channels travados em Buffering
          if (_isActiveChannel) {
            if (buffering) {
              // Iniciar timer de stall
              _stallTimer?.cancel();
              _stallTimer = Timer(const Duration(seconds: 10), () {
                // Reduzido timeout de 15s para 10s
                if (mounted && _isBuffering) {
                  if (kIsWeb && _isActiveChannel) {
                    _recoverWebChannelPlayback('canal ficou carregando no web');
                    return;
                  }
                  if (!_useFireTvLiveMode) {
                    _useFireTvLiveMode = true;
                    _retryCount = 0;
                    print(
                        '🔄 Canal travado em buffering. Ativando modo Fire TV FHD...');
                  } else {
                    print(
                        '🔄 Canal travado em buffering há 10s. Forçando reconexão imediata...');
                  }
                  _initPlayer();
                }
              });
            } else {
              // Parou de carregar, limpar timer
              _stallTimer?.cancel();
            }
          }
        }
      });

      _player!.stream.error.listen((error) {
        if (mounted && error.isNotEmpty) {
          final lowerError = error.toLowerCase();
          final isChannel = _isActiveChannel;
          final isDecodeOrAudioError = lowerError.contains('audio') ||
              lowerError.contains('decod') ||
              lowerError.contains('codec');
          final isFormatProbeError =
              lowerError.contains('failed to recognize file format') ||
                  lowerError.contains('unrecognized file format');

          if (isChannel && kIsWeb && _isRecoverableWebSourceError(lowerError)) {
            _recoverWebChannelPlayback(error).then((didRetry) {
              if (!didRetry && mounted) {
                setState(() {
                  _hasError = true;
                  _errorMessage = error;
                });
              }
            });
            return;
          }

          if (isChannel && isDecodeOrAudioError && !_useFireTvLiveMode) {
            if (kIsWeb) {
              _recoverWebChannelPlayback(error);
              return;
            }
            print(
                '🔄 Erro de codec/áudio em canal FHD. Ativando modo Fire TV FHD: $error');
            _useFireTvLiveMode = true;
            _retryCount = 0;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Otimizando reprodução para Fire TV...'),
                duration: Duration(seconds: 2),
              ),
            );
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) _initPlayer();
            });
            return;
          }

          if (isChannel && isFormatProbeError) {
            print(
                '⚠️ Stream do canal retornou formato inválido momentâneo. Rechecando em 6s: $error');
            _stallTimer?.cancel();
            _stallTimer = Timer(const Duration(seconds: 6), () {
              if (mounted) _initPlayer();
            });
            return;
          }

          // IGNORAR ERROS NÃO
          if (lowerError.contains('seek') ||
              lowerError.contains('force') ||
              lowerError.contains(
                  'codec') || // Ignora erros de codec (pode ser áudio não suportado mas video ok)
              lowerError.contains('decoder') ||
              error.contains('--')) {
            print('⚠️ Ignorando aviso de player: $error');

            // Se o erro for de seek/codec, garantimos que o player pelo menos tente tocar
            if (!_isPlaying) _player!.play();
            return;
          }

          print('❌ Player error: $error');
          if (_shouldRetryWithDirectWebFallback(lowerError)) {
            _retryManagedWebDirectFallback(error);
            return;
          }

          // Auto-Retry logic for decoding errors
          if (_retryCount < 3 && _position.inSeconds > 1) {
            _retryCount++;
            print(
                '🔄 Tentando recuperar playback (Tentativa $_retryCount/3)...');

            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Erro de reprodução. Reconectando...'),
              duration: Duration(seconds: 2),
            ));

            // Reabre o vídeo na posição atual
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) _initPlayer(); // Re-inicia o fluxo completo
            });
          } else {
            setState(() {
              _hasError = true;
              _errorMessage = error;
            });
          }
        }
      });

      // Auto-Play Listener
      _player!.stream.completed.listen((completed) {
        if (completed && mounted) {
          // Auto-reconnect se o fluxo do canal cair (streaming "encerra")
          if (_isActiveChannel) {
            print('🔄 Canal "encerrou". Tentando reconectar imediatamente...');
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) _initPlayer();
            });
          } else {
            _handleVideoCompletedOnce();
          }
        }
      });

      // Listener para tracks de áudio
      _player!.stream.tracks.listen((tracks) {
        if (mounted) {
          setState(() {
            // Filtrar tracks vazias (a primeira geralmente é "no" track)
            _audioTracks = tracks.audio
                .where((t) => t.id != 'no' && t.id != 'auto')
                .toList();
            _subtitleTracks = [
              ...tracks.subtitle.where((t) => t.id != 'no' && t.id != 'auto'),
              ..._externalSubtitles,
            ];

            // Debug
            print('🎵 Audio tracks: ${_audioTracks.length}');
            for (var t in _audioTracks) {
              print('   - ${t.id}: ${t.title ?? t.language ?? "unknown"}');
            }
            print('📝 Subtitle tracks: ${_subtitleTracks.length}');
            for (var t in _subtitleTracks) {
              print('   - ${t.id}: ${t.title ?? t.language ?? "unknown"}');
            }

            // Auto seleção de legenda em português quando as faixas carregam
            if (!_autoSubtitleSelected && _subtitleTracks.isNotEmpty) {
              _autoSubtitleSelected = true;
              try {
                final ptTrack = _subtitleTracks.firstWhere((t) =>
                    (t.language?.toLowerCase().contains('pt') == true ||
                        t.language?.toLowerCase().contains('por') == true ||
                        t.title?.toLowerCase().contains('portugu') == true ||
                        t.title?.toLowerCase().contains('pt-br') == true));
                _player!.setSubtitleTrack(ptTrack);
              } catch (_) {
                // Se não achar português mas tiver externas, pega a primeira externa, senão deixa o default do mpv
                if (_externalSubtitles.isNotEmpty) {
                  _player!.setSubtitleTrack(_externalSubtitles.first);
                }
              }
            }

            _updateListFocusNodes();
          });
        }
      });

      // Listener para track de áudio atual
      _player!.stream.track.listen((track) {
        if (mounted) {
          final audioTrack = track.audio;
          if (audioTrack.id != 'no' && audioTrack.id != 'auto') {
            final idx = _audioTracks.indexWhere((t) => t.id == audioTrack.id);
            if (idx >= 0) {
              setState(() {
                _selectedAudioIndex = idx;
                _currentAudio = audioTrack.title ??
                    audioTrack.language ??
                    'Faixa ${idx + 1}';
              });
            }
          }

          final subtitleTrack = track.subtitle;
          if (subtitleTrack.id == 'no' || subtitleTrack.id == 'auto') {
            setState(() {
              _selectedSubtitleIndex = -1;
              _currentSubtitle = 'Desativado';
            });
          } else {
            final idx =
                _subtitleTracks.indexWhere((t) => t.id == subtitleTrack.id);
            if (idx >= 0) {
              setState(() {
                _selectedSubtitleIndex = idx;
                _currentSubtitle = subtitleTrack.title ??
                    subtitleTrack.language ??
                    'Legenda ${idx + 1}';
              });
            }
          }
        }
      });

      // Listener para informações de vídeo
      _player!.stream.width.listen((width) => _updateVideoInfo());
      _player!.stream.height.listen((height) => _updateVideoInfo());

      // Verificar posição salva
      final savedPosition =
          await WatchHistoryService.getSavedPosition(widget.url).timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );

      // Carregar EPG se for canal
      final activeItem = _activeItem;
      if (activeItem != null && activeItem.type == 'channel') {
        try {
          // CRÍTICO: Garante que EPG está carregado antes de buscar
          final epgUrl = EpgService.epgUrl;
          if (epgUrl != null && !EpgService.isLoaded) {
            await EpgService.loadEpg(epgUrl).timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                print('⏱️ Timeout ao carregar EPG');
              },
            );
          }

          _epgChannel = EpgService.findChannelByName(activeItem.title);
          if (_epgChannel != null) {
            _currentEpgProgram = _epgChannel!.currentProgram;
            _nextEpgProgram = _epgChannel!.nextProgram;
            print(
                '✅ EPG carregado para canal "${activeItem.title}": ${_currentEpgProgram?.title ?? "Sem programa"}');
          } else {
            print('⚠️ EPG não encontrado para canal "${activeItem.title}"');
          }
          if (mounted) setState(() {});
        } catch (e) {
          print('⚠️ Erro ao carregar EPG no player: $e');
        }
      }

      // Abrir mídia com timeout
      print('🎬 Abrindo mídia: ${_playlist[_currentIndex].url}');

      // Use empty headers for Jellyfin (avoid User-Agent issues), IPTV sources get VLC mask
      final isJellyfin =
          widget.item != null && widget.item!.group == 'Jellyfin';
      final Map<String, String> mediaHeaders = (isJellyfin || kIsWeb)
          ? const {}
          : const {'User-Agent': 'VLC/3.0.18 LibVLC/3.0.18'};

      // Aplica Preferência: Forçar HLS
      String finalUrl = _playlist[_currentIndex].url;
      _externalSubtitles.clear();
      _autoSubtitleSelected = false;
      String? serverSideSubtitleLabel;
      if (isJellyfin && widget.item != null) {
        try {
          final playbackPlan = await _buildJellyfinPlaybackPlan(widget.item!);
          finalUrl = playbackPlan.url;
          serverSideSubtitleLabel = playbackPlan.subtitleLabel;
        } catch (e) {
          print(
              '⚠️ Jellyfin: falha ao preparar PlaybackInfo, seguindo com URL padrão: $e');
        }
      }

      final isManagedWebPlayback =
          kIsWeb && Config.useManagedAccess && Config.backendUrl.isNotEmpty;
      final shouldForceHls = !isManagedWebPlayback &&
          (Prefs.getForceHls() || (kIsWeb && _shouldForceHlsForUrl(finalUrl)));
      if (isManagedWebPlayback && _shouldForceHlsForUrl(finalUrl)) {
        print(
            '🌐 Web gerenciado: deixando o Click SaaS decidir entre manifesto e mídia direta');
      }
      if (shouldForceHls && !finalUrl.toLowerCase().contains('.m3u8')) {
        if (kIsWeb) {
          print(
              '🌐 Web: forçando fluxo HLS (.m3u8) para compatibilidade do navegador');
        } else {
          print('⚙️ Forçando fluxo HLS (adicionando .m3u8 na URL)');
        }
        // Na maioria dos servidores Xtream, basta adicionar .m3u8 no final do link ts/mp4
        finalUrl = '$finalUrl.m3u8';
      }

      finalUrl = await _resolveManagedWebPlaybackUrl(
        finalUrl,
        forceDirect: forceDirectWebPlayback,
        preferLiveHls: _usingLiveHlsPreference && !forceDirectWebPlayback,
      );

      // Mídia Principal
      final media = Media(
        finalUrl,
        httpHeaders: mediaHeaders,
      );

      // CRÍTICO: Abre sem dar play imediatamente para configurar buffer e seek com segurança
      try {
        await _player!.open(media, play: false).timeout(
          const Duration(
              seconds: 25), // Reduzido de 45s para 25s para falhar rápido na TV
          onTimeout: () {
            print('⏱️ Timeout ao abrir mídia');
            throw Exception(
                'Timeout ao carregar vídeo. Verifique sua conexão.');
          },
        );
      } catch (e) {
        if (kIsWeb &&
            _isActiveChannel &&
            _isRecoverableWebSourceError(e.toString())) {
          final didRetry = await _recoverWebChannelPlayback(e.toString());
          if (didRetry) return;
        }
        if (_shouldRetryWithDirectWebFallback(e.toString().toLowerCase())) {
          _retryManagedWebDirectFallback(e.toString());
          return;
        }
        rethrow;
      }

      // Carregar Legendas do Jellyfin (se for item do Jellyfin)
      if (widget.item != null && widget.item!.group == 'Jellyfin' && !kIsWeb) {
        try {
          final mediaInfo = await JellyfinService.getMediaInfo(widget.item!.id);
          if (mediaInfo != null && mediaInfo['MediaSources'] != null) {
            final source =
                mediaInfo['MediaSources'][0]; // Assume primeira fonte
            if (source['MediaStreams'] != null) {
              final streams = source['MediaStreams'] as List;
              // Apenas legendas externas! Legendas embutidas (IsExternal == false)
              // já são reproduzidas nativamente pelo libmpv na URL principal do vídeo.
              final subtitles = streams
                  .where((s) =>
                      s['Type'] == 'Subtitle' &&
                      (s['IsExternal'] == true || s['DeliveryUrl'] != null))
                  .toList();

              print(
                  '📝 Encontradas ${subtitles.length} legendas externas no Jellyfin');
              _externalSubtitles.clear(); // Limpa legendas anteriores

              for (var sub in subtitles) {
                final index = (sub['Index'] as num?)?.toInt() ?? 0;
                final title =
                    sub['Title'] ?? sub['Language'] ?? 'Legenda $index';
                final codec = sub['Codec'] ?? 'vtt';

                // Prioriza o formato original se suportado, senão converte
                String format = codec.toLowerCase();
                if (format == 'subrip') format = 'srt';
                if (format == 'vtt' ||
                    format == 'srt' ||
                    format == 'ass' ||
                    format == 'ssa') {
                  // OK
                } else {
                  format = 'srt'; // Fallback default suportado pelo MPV
                }

                // BYPASS: Ler credenciais direto do storage para evitar erro de build
                const storage = FlutterSecureStorage();
                final baseUrl = await storage.read(key: 'jellyfin_url') ?? '';
                final token =
                    await storage.read(key: 'jellyfin_access_token') ?? '';

                if (baseUrl.isNotEmpty && token.isNotEmpty) {
                  final sourceId = source['Id'] ?? widget.item!.id;
                  final deliveryUrl = sub['DeliveryUrl'];

                  String subUrl;
                  if (deliveryUrl != null &&
                      deliveryUrl.toString().isNotEmpty) {
                    String dUrl = deliveryUrl.toString();
                    if (!dUrl.startsWith('http')) {
                      if (!dUrl.startsWith('/')) dUrl = '/$dUrl';
                      subUrl = '$baseUrl$dUrl';
                    } else {
                      subUrl = dUrl;
                    }
                    if (!subUrl.contains('?')) {
                      subUrl += '?api_key=$token';
                    } else {
                      subUrl += '&api_key=$token';
                    }
                  } else {
                    subUrl =
                        '$baseUrl/Videos/${widget.item!.id}/$sourceId/Subtitles/$index/0/Stream.$format?api_key=$token';
                  }

                  // O media_kit/mpv gerencia falhas de carregamento silenciosamente.
                  // Adiciona a legenda diretamente sem bloquear a UI com http.head
                  print(
                      '➕ Legenda adicionada via Jellyfin API: $title ($format) -> $subUrl');
                  _externalSubtitles.add(SubtitleTrack.uri(subUrl,
                      title: title, language: sub['Language']));
                }
              }

              if (mounted && _externalSubtitles.isNotEmpty) {
                setState(() {
                  _subtitleTracks = [
                    ..._player!.state.tracks.subtitle
                        .where((t) => t.id != 'no' && t.id != 'auto'),
                    ..._externalSubtitles
                  ];
                });

                // Se a API trouxe legendas depois da flag pular, ou se nunca pegou PT, iteramos novamente
                if (!_autoSubtitleSelected || _selectedSubtitleIndex <= 0) {
                  _autoSubtitleSelected = true;
                  try {
                    final ptTrack = _subtitleTracks.firstWhere((t) =>
                        (t.language?.toLowerCase().contains('pt') == true ||
                            t.language?.toLowerCase().contains('por') == true ||
                            t.title?.toLowerCase().contains('portugu') ==
                                true ||
                            t.title?.toLowerCase().contains('pt-br') == true));
                    _player!.setSubtitleTrack(ptTrack);
                  } catch (_) {
                    _player!.setSubtitleTrack(_externalSubtitles.first);
                  }
                }
              }
            }
          }
        } catch (e) {
          print('⚠️ Erro ao carregar legendas do Jellyfin: $e');
        }
      }

      if (kIsWeb && isJellyfin && serverSideSubtitleLabel != null && mounted) {
        setState(() {
          _currentSubtitle = '$serverSideSubtitleLabel (Jellyfin)';
          _selectedSubtitleIndex = -1;
        });
      }

      // Seek seguro antes de tocar (evita que o player toque do início e pule depois)
      if (!_isActiveChannel &&
          savedPosition != null &&
          savedPosition.inSeconds > 5) {
        // Só resume se > 5s
        print('⏩ Retomando de ${_formatDuration(savedPosition)}');
        try {
          await _player!.seek(savedPosition).timeout(
                const Duration(seconds: 5),
                onTimeout: () => print('⏱️ Timeout ao fazer seek inicial'),
              );
        } catch (e) {
          print('⚠️ Erro não-fatal no seek: $e');
        }
      }

      print('✅ Mídia pronta. Iniciando playback...');
      await _player!.play();
      _scheduleWebChannelVideoPresenceCheck();

      // Aplicar estilos de legenda após o play para garantir que o renderer está pronto
      _applySubtitleStyles();

      if (mounted) {
        setState(() => _isInitialized = true);
        print('✅ Player inicializado');
      }

      // Auto-hide controls após 5 segundos
      _startControlsTimer();
    } catch (e, stackTrace) {
      print('❌ Erro ao inicializar player: $e');
      print('Stack: $stackTrace');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Falha ao carregar o vídeo: ${e.toString()}';
        });
      }
    }
  }

  void _onVideoCompleted() {
    _markAsWatched();
    if (_playlist.isNotEmpty && _currentIndex < _playlist.length - 1) {
      _playNext();
    } else {
      if (widget.item != null && widget.item!.isSeries) {
        Navigator.pop(context);
      }
    }
  }

  void _handleVideoCompletedOnce() {
    if (_completionHandled) return;
    _completionHandled = true;
    _onVideoCompleted();
  }

  void _checkVodCompletionByPosition() {
    if (_completionHandled || _isActiveChannel || _duration.inSeconds <= 0) {
      return;
    }

    final remaining = _duration - _position;
    if (_position.inSeconds > 0 &&
        !remaining.isNegative &&
        remaining <= const Duration(milliseconds: 900)) {
      _handleVideoCompletedOnce();
    }
  }

  void _markAsWatched() {
    if (_currentIndex < _playlist.length) {
      final item = _playlist[_currentIndex];
      WatchHistoryService.addToWatched(item);
    }
  }

  void _playNext() async {
    if (!mounted) return;
    setState(() {
      _currentIndex++;
      _hasError = false;
      _errorMessage = '';
      _position = Duration.zero;
      _duration = Duration.zero;
      _completionHandled = false;
      _lastSavedSeconds = -1;
    });

    final nextItem = _playlist[_currentIndex];
    final isJellyfin = nextItem.group == 'Jellyfin';
    String nextUrl = nextItem.url;
    if (isJellyfin) {
      try {
        final playbackPlan = await _buildJellyfinPlaybackPlan(nextItem);
        nextUrl = playbackPlan.url;
      } catch (e) {
        print('⚠️ Jellyfin: falha ao preparar próximo item: $e');
      }
    }
    final isManagedWebPlayback =
        kIsWeb && Config.useManagedAccess && Config.backendUrl.isNotEmpty;
    final shouldForceHls = !isManagedWebPlayback &&
        (Prefs.getForceHls() || (kIsWeb && _shouldForceHlsForUrl(nextUrl)));

    if (shouldForceHls && !nextUrl.toLowerCase().contains('.m3u8')) {
      nextUrl = '$nextUrl.m3u8';
    }

    nextUrl = await _resolveManagedWebPlaybackUrl(nextUrl);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Reproduzindo: ${nextItem.title} - ${nextItem.group}'),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
    ));

    await _player?.open(
      Media(
        nextUrl,
        httpHeaders: (isJellyfin || kIsWeb)
            ? const {}
            : const {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              },
      ),
      play: true,
    );
  }

  void _updateVideoInfo() {
    final width = _player?.state.width;
    final height = _player?.state.height;

    if (width != null && height != null && width > 0 && height > 0) {
      _videoPresenceTimer?.cancel();
      String quality;
      if (height >= 2160) {
        quality = '4K UHD ($width×$height)';
      } else if (height >= 1080) {
        quality = 'Full HD ($width×$height)';
      } else if (height >= 720) {
        quality = 'HD ($width×$height)';
      } else {
        quality = 'SD ($width×$height)';
      }

      if (mounted) {
        setState(() => _videoQuality = quality);
      }
    }
  }

  void _saveProgress() {
    final activeItem = _activeItem;
    if (activeItem != null &&
        activeItem.type != 'channel' &&
        _duration.inSeconds > 0) {
      final currentSeconds = _position.inSeconds;

      // Salva a cada 30 segundos para evitar eventuais engasgos de gravação em disco durante o vídeo
      if (currentSeconds > 0 &&
          currentSeconds % 30 == 0 &&
          currentSeconds != _lastSavedSeconds) {
        _lastSavedSeconds = currentSeconds;
        WatchHistoryService.saveProgress(activeItem, _position, _duration);
      }
    }
  }

  void _startControlsTimer() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _isPlaying && _showControls) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _startControlsTimer();
    }
  }

  void _togglePlayPause() {
    _player?.playOrPause();
  }

  void _seekForward() {
    if (_isActiveChannel) return;
    final newPosition = _position + const Duration(seconds: 10);
    _player?.seek(newPosition);
  }

  void _seekBackward() {
    if (_isActiveChannel) return;
    final newPosition = _position - const Duration(seconds: 10);
    _player?.seek(newPosition.isNegative ? Duration.zero : newPosition);
  }

  void _setFit(int index) {
    setState(() {
      _fitIndex = index;
      _videoFit = _fitOptions[index]['fit'] as BoxFit;
      _showFitOptions = false;
    });
  }

  void _setAudioTrack(int index) {
    if (index >= 0 && index < _audioTracks.length) {
      final track = _audioTracks[index];
      print(
          '🎵 Selecionando áudio: ${track.id} - ${track.title ?? track.language}');
      _player?.setAudioTrack(track);
      setState(() => _showAudioOptions = false);
      // O listener de track vai atualizar o estado
    }
  }

  void _setSubtitleTrack(int index) {
    if (index == -1) {
      print('📝 Desativando legendas');
      _player?.setSubtitleTrack(SubtitleTrack.no());
      setState(() {
        _selectedSubtitleIndex = -1;
        _currentSubtitle = 'Desativado';
        _showSubtitleOptions = false;
      });
    } else if (index >= 0 && index < _subtitleTracks.length) {
      final track = _subtitleTracks[index];
      print(
          '📝 Selecionando legenda: ${track.id} - ${track.title ?? track.language}');
      _player?.setSubtitleTrack(track);
      // O listener de track vai atualizar o estado
      setState(() => _showSubtitleOptions = false);
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  void dispose() {
    _stallTimer?.cancel();
    _videoPresenceTimer?.cancel();
    // Salvar progresso final
    final activeItem = _activeItem;
    if (activeItem != null &&
        activeItem.type != 'channel' &&
        _duration.inSeconds > 0) {
      WatchHistoryService.saveProgress(activeItem, _position, _duration);
    }
    _player?.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _playPauseFocusNode.dispose();
    _rootFocusNode.dispose();
    _rewindFocusNode.dispose();
    _forwardFocusNode.dispose();
    _audioFocusNode.dispose();
    _subtitleFocusNode.dispose();
    _fitFocusNode.dispose();
    _infoFocusNode.dispose();
    super.dispose();
  }

  bool _forceExit = false;

  void _exitPlayer() {
    setState(() {
      _forceExit = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool trapBack = !_forceExit && (_isAnyPanelOpen() || _showControls);
    return PopScope(
      canPop: !trapBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBackAction();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _hasError ? _buildErrorView() : _buildPlayerView(),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          Text(
            _errorMessage,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _hasError = false;
                _errorMessage = '';
              });
              _initPlayer();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Voltar', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  bool _isAnyPanelOpen() {
    return _showInfo ||
        _showAudioOptions ||
        _showSubtitleOptions ||
        _showFitOptions;
  }

  void _handleBackAction() {
    print(
        '🔙 _handleBackAction: panels=${_isAnyPanelOpen()}, controls=$_showControls');

    // Se algum painel extra estiver aberto, fecha esse painel primeiro
    if (_isAnyPanelOpen()) {
      setState(() {
        _showInfo = false;
        _showAudioOptions = false;
        _showSubtitleOptions = false;
        _showFitOptions = false;
      });
      return;
    }

    if (_showControls) {
      setState(() => _showControls = false);
      return;
    }
  }

  Widget _buildPlayerView() {
    return Focus(
      focusNode: _rootFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        // Mapeia teclas
        final key = event.logicalKey;

        // Atalho global: Voltar
        if (key == LogicalKeyboardKey.escape ||
            key == LogicalKeyboardKey.backspace ||
            key == LogicalKeyboardKey.gameButtonB) {
          final bool trapBack =
              !_forceExit && (_isAnyPanelOpen() || _showControls);
          if (trapBack) {
            _handleBackAction();
          } else {
            _exitPlayer();
          }
          return KeyEventResult.handled;
        }

        // Se controles ocultos
        if (!_showControls) {
          // Apenas agir para setas e teclas de ação
          if (key == LogicalKeyboardKey.arrowLeft ||
              key == LogicalKeyboardKey.arrowRight ||
              key == LogicalKeyboardKey.arrowUp ||
              key == LogicalKeyboardKey.arrowDown ||
              key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.space ||
              key == LogicalKeyboardKey.mediaPlayPause) {
            setState(() => _showControls = true);
            _startControlsTimer();

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_playPauseFocusNode.canRequestFocus) {
                _playPauseFocusNode.requestFocus();
              }
            });

            if (key == LogicalKeyboardKey.arrowLeft) {
              _seekBackward();
            } else if (key == LogicalKeyboardKey.arrowRight) {
              _seekForward();
            }
            return KeyEventResult.handled;
          }
          // Para outras teclas (incluindo System Back), deixa o Flutter lidar
          return KeyEventResult.ignored;
        }

        // Se controles VISÍVEIS:
        // Deixamos o sistema de Foco nativo lidar com navegação (Setas) e ativação (Enter)
        // A menos que sejam atalhos específicos

        if (key == LogicalKeyboardKey.keyI) {
          setState(() {
            _showInfo = !_showInfo;
            _showAudioOptions = false;
            _showSubtitleOptions = false;
            _showFitOptions = false;
          });
          return KeyEventResult.handled;
        }

        // Ignora setas e enter para que os botões focados os recebam
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Vídeo
            Center(
              child: _isInitialized
                  ? Video(
                      controller: _controller!,
                      controls: NoVideoControls,
                      fit: _videoFit,
                      filterQuality: FilterQuality
                          .none, // Otimização extrema de FPS para Android TV
                    )
                  : const CircularProgressIndicator(color: Colors.blueAccent),
            ),

            // Buffering indicator
            if (_isBuffering)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            // Controles customizados
            if (_showControls) ...[
              _buildTopBar(),
              _buildCenterControls(),
              _buildBottomBar(),
            ],

            // Painel de informações
            if (_showInfo) _buildInfoPanel(),

            // Opções de áudio
            if (_showAudioOptions) _buildAudioOptionsPanel(),

            // Opções de legenda
            if (_showSubtitleOptions) _buildSubtitleOptionsPanel(),

            // Opções de ajuste de tela
            if (_showFitOptions) _buildFitOptionsPanel(),
          ],
        ),
      ),
    );
  }

  /// CAMADA DO MEIO: Retroceder | Play/Pause | Avançar
  Widget _buildCenterControls() {
    return Positioned(
      top: 100,
      left: 0,
      right: 0,
      bottom: 140,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isActiveChannel) ...[
              _buildCenterButton(
                focusNode: _rewindFocusNode,
                icon: Icons.replay_10,
                size: 44,
                onPressed: _seekBackward,
                onUpPressed: () => _backFocusNode.requestFocus(),
                onDownPressed: () => _audioFocusNode.requestFocus(),
              ),
              const SizedBox(width: 48),
            ],
            // PLAY/PAUSE (principal)
            _buildCenterButton(
              focusNode: _playPauseFocusNode,
              icon: _isPlaying ? Icons.pause : Icons.play_arrow,
              size: 64,
              onPressed: _togglePlayPause,
              isPrimary: true,
              onUpPressed: () => widget.item != null
                  ? _favoriteFocusNode.requestFocus()
                  : _backFocusNode.requestFocus(),
              onDownPressed: () => _subtitleFocusNode.requestFocus(),
            ),
            if (!_isActiveChannel) ...[
              const SizedBox(width: 48),
              _buildCenterButton(
                focusNode: _forwardFocusNode,
                icon: Icons.forward_10,
                size: 44,
                onPressed: _seekForward,
                onUpPressed: () => _infoTopFocusNode.requestFocus(),
                onDownPressed: () => _fitFocusNode.requestFocus(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCenterButton({
    required FocusNode focusNode,
    required IconData icon,
    required double size,
    required VoidCallback onPressed,
    required VoidCallback onUpPressed,
    required VoidCallback onDownPressed,
    bool isPrimary = false,
  }) {
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          // Enter/Select - ativa o botão
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.gameButtonA) {
            onPressed();
            return KeyEventResult.handled;
          }
          // Seta para cima - volta para camada superior (TopBar)
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            onUpPressed();
            return KeyEventResult.handled;
          }
          // Seta para baixo - vai para camada inferior (BottomBar)
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            onDownPressed();
            return KeyEventResult.handled;
          }
          // Setas esquerda/direita fazem seek
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _seekBackward();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _seekForward();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(builder: (ctx) {
        final hasFocus = Focus.of(ctx).hasFocus;
        return GestureDetector(
          onTap: onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.all(isPrimary ? 20 : 14),
            decoration: BoxDecoration(
              color: hasFocus
                  ? Colors.blueAccent.withOpacity(0.7)
                  : (isPrimary
                      ? Colors.white.withOpacity(0.2)
                      : Colors.white.withOpacity(0.1)),
              shape: BoxShape.circle,
              border: Border.all(
                color: hasFocus
                    ? Colors.blueAccent
                    : Colors.white.withOpacity(isPrimary ? 0.5 : 0.3),
                width: hasFocus ? 3 : (isPrimary ? 2 : 1),
              ),
              boxShadow: hasFocus
                  ? [
                      const BoxShadow(
                          color: Colors.blueAccent,
                          blurRadius: 20,
                          spreadRadius: 3)
                    ]
                  : null,
            ),
            child: Icon(icon, color: Colors.white, size: size),
          ),
        );
      }),
    );
  }

  /// CAMADA INFERIOR: Áudio | Legenda | Ajuste | Info
  Widget _buildBottomBar() {
    return Positioned(
      bottom: 32,
      left: 32,
      right: 32,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isActiveChannel)
                  Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'AO VIVO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  StreamBuilder<Duration>(
                      stream: _player?.stream.position,
                      builder: (context, snapshot) {
                        final currentPosition = snapshot.data ?? _position;
                        return Row(
                          children: [
                            Text(
                              _formatDuration(currentPosition),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ),
                            Expanded(
                              child: Slider(
                                value: _duration.inSeconds > 0
                                    ? currentPosition.inSeconds
                                        .toDouble()
                                        .clamp(
                                            0, _duration.inSeconds.toDouble())
                                    : 0,
                                max: _duration.inSeconds > 0
                                    ? _duration.inSeconds.toDouble()
                                    : 1,
                                activeColor: Colors.blueAccent,
                                inactiveColor: Colors.white30,
                                onChanged: (value) {
                                  _player
                                      ?.seek(Duration(seconds: value.toInt()));
                                },
                              ),
                            ),
                            Text(
                              _formatDuration(_duration),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ),
                          ],
                        );
                      }),
                const SizedBox(height: 12),
                // Botões de opções
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // ÁUDIO (primeiro - não tem esquerda)
                    _buildBottomButton(
                      focusNode: _audioFocusNode,
                      icon: Icons.audiotrack,
                      label: _currentAudio,
                      onTap: () {
                        setState(() {
                          _showAudioOptions = !_showAudioOptions;
                          _showSubtitleOptions = false;
                          _showFitOptions = false;
                          _showInfo = false;
                        });
                        if (_showAudioOptions) {
                          Future.delayed(const Duration(milliseconds: 50), () {
                            if (mounted && _audioNodes.isNotEmpty)
                              _audioNodes[0].requestFocus();
                          });
                        }
                      },
                      isActive: _showAudioOptions,
                      onUpPressed: () => _rewindFocusNode.requestFocus(),
                      onRightPressed: () => _subtitleFocusNode.requestFocus(),
                    ),
                    // LEGENDA
                    _buildBottomButton(
                      focusNode: _subtitleFocusNode,
                      icon: Icons.subtitles,
                      label: _currentSubtitle,
                      onTap: () {
                        setState(() {
                          _showSubtitleOptions = !_showSubtitleOptions;
                          _showAudioOptions = false;
                          _showFitOptions = false;
                          _showInfo = false;
                        });
                        if (_showSubtitleOptions) {
                          Future.delayed(const Duration(milliseconds: 50), () {
                            if (mounted && _subtitleNodes.isNotEmpty)
                              _subtitleNodes[0].requestFocus();
                          });
                        }
                      },
                      isActive: _showSubtitleOptions,
                      onUpPressed: () => _playPauseFocusNode.requestFocus(),
                      onLeftPressed: () => _audioFocusNode.requestFocus(),
                      onRightPressed: () => _fitFocusNode.requestFocus(),
                    ),
                    // AJUSTE DE TELA
                    _buildBottomButton(
                      focusNode: _fitFocusNode,
                      icon: _fitOptions[_fitIndex]['icon'] as IconData,
                      label: _fitOptions[_fitIndex]['label'] as String,
                      onTap: () {
                        setState(() {
                          _showFitOptions = !_showFitOptions;
                          _showAudioOptions = false;
                          _showSubtitleOptions = false;
                          _showInfo = false;
                        });
                        if (_showFitOptions) {
                          Future.delayed(const Duration(milliseconds: 50), () {
                            if (mounted) _firstFitOptionNode.requestFocus();
                          });
                        }
                      },
                      isActive: _showFitOptions,
                      onUpPressed: () => _forwardFocusNode.requestFocus(),
                      onLeftPressed: () => _subtitleFocusNode.requestFocus(),
                      onRightPressed: () => _infoFocusNode.requestFocus(),
                    ),
                    // QUALIDADE/INFO (último - não tem direita)
                    _buildBottomButton(
                      focusNode: _infoFocusNode,
                      icon: Icons.high_quality,
                      label: _videoQuality.split(' ').first,
                      onTap: () => setState(() {
                        _showInfo = !_showInfo;
                        _showAudioOptions = false;
                        _showSubtitleOptions = false;
                        _showFitOptions = false;
                      }),
                      isActive: _showInfo,
                      onUpPressed: () => _forwardFocusNode.requestFocus(),
                      onLeftPressed: () => _fitFocusNode.requestFocus(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Botão da camada inferior com navegação vertical e horizontal
  Widget _buildBottomButton({
    required FocusNode focusNode,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required VoidCallback onUpPressed,
    VoidCallback? onLeftPressed,
    VoidCallback? onRightPressed,
    bool isActive = false,
  }) {
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          // Enter/Select - ativa o botão
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space ||
              event.logicalKey == LogicalKeyboardKey.gameButtonA) {
            onTap();
            return KeyEventResult.handled;
          }
          // Seta para cima - volta para camada do meio
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            onUpPressed();
            return KeyEventResult.handled;
          }
          // Seta para esquerda - navega para botão anterior
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
              onLeftPressed != null) {
            onLeftPressed();
            return KeyEventResult.handled;
          }
          // Seta para direita - navega para próximo botão
          if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
              onRightPressed != null) {
            onRightPressed();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(builder: (context) {
        final hasFocus = Focus.of(context).hasFocus;
        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: hasFocus
                  ? Colors.blueAccent.withOpacity(0.7)
                  : (isActive
                      ? Colors.blueAccent.withOpacity(0.3)
                      : Colors.white.withOpacity(0.1)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasFocus
                    ? Colors.blueAccent
                    : (isActive ? Colors.blueAccent : Colors.white24),
                width: hasFocus ? 3 : 1,
              ),
              boxShadow: hasFocus
                  ? [
                      const BoxShadow(
                          color: Colors.blueAccent,
                          blurRadius: 10,
                          spreadRadius: 2)
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    color: hasFocus
                        ? Colors.white
                        : (isActive ? Colors.blueAccent : Colors.white70),
                    size: 24),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    color: hasFocus
                        ? Colors.white
                        : (isActive ? Colors.blueAccent : Colors.white70),
                    fontSize: 14,
                    fontWeight: hasFocus ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildInfoPanel() {
    final isChannel = widget.item != null && widget.item!.type == 'channel';
    return Positioned(
      right: 16,
      top: 100,
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isChannel ? 'EPG e Informações' : 'Informações de Mídia',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isChannel)
                  IconButton(
                    icon: const Icon(Icons.refresh,
                        color: Colors.white70, size: 18),
                    onPressed: () async {
                      // Recarregar EPG
                      if (widget.item != null) {
                        final epgUrl = EpgService.epgUrl;
                        if (epgUrl != null) {
                          try {
                            await EpgService.loadEpg(epgUrl);
                            _epgChannel = EpgService.findChannelByName(
                                widget.item!.title);
                            if (_epgChannel != null) {
                              setState(() {
                                _currentEpgProgram =
                                    _epgChannel!.currentProgram;
                                _nextEpgProgram = _epgChannel!.nextProgram;
                              });
                            }
                          } catch (e) {
                            print('⚠️ Erro ao atualizar EPG: $e');
                          }
                        }
                      }
                    },
                    tooltip: 'Atualizar EPG',
                  ),
              ],
            ),
            const Divider(color: Colors.white24),
            // EPG (apenas para canais) - CRÍTICO: Mostra sempre para canais
            if (isChannel) ...[
              if (_currentEpgProgram != null) ...[
                const Text(
                  'Agora',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentEpgProgram?.title ?? 'Sem informação',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_currentEpgProgram?.description != null &&
                    _currentEpgProgram!.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _currentEpgProgram!.description!,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '${_formatTime(_currentEpgProgram!.start)} - ${_formatTime(_currentEpgProgram!.end)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
                if (_nextEpgProgram != null) ...[
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white12),
                  const Text(
                    'Próximo',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _nextEpgProgram!.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(_nextEpgProgram!.start),
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ] else ...[
                // Se não tem programa atual, mostra mensagem
                const Text(
                  'EPG não disponível',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Divider(color: Colors.white24),
            ],
            // Informações técnicas
            _buildInfoRow('Qualidade', _videoQuality),
            _buildInfoRow('Áudio', _currentAudio),
            _buildInfoRow('Legenda', _currentSubtitle),
            if (_audioTracks.isNotEmpty)
              _buildInfoRow(
                  'Faixas de Áudio', '${_audioTracks.length} disponíveis'),
            if (_subtitleTracks.isNotEmpty)
              _buildInfoRow(
                  'Legendas', '${_subtitleTracks.length} disponíveis'),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusableOptionItem({
    required FocusNode focusNode,
    required String title,
    String? subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    VoidCallback? onUp,
    VoidCallback? onDown,
    bool autofocus = false,
  }) {
    return Focus(
      focusNode: focusNode,
      autofocus: autofocus,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.gameButtonA) {
            onTap();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
              onDown != null) {
            onDown();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp && onUp != null) {
            onUp();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(builder: (ctx) {
        final hasFocus = Focus.of(ctx).hasFocus;
        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: hasFocus
                  ? Colors.blueAccent.withOpacity(0.6)
                  : (isSelected
                      ? Colors.white.withOpacity(0.1)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasFocus ? Colors.white : Colors.transparent,
                width: hasFocus ? 2 : 0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: hasFocus
                      ? Colors.white
                      : (isSelected ? Colors.blueAccent : Colors.white54),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: hasFocus || isSelected
                              ? Colors.white
                              : Colors.white70,
                          fontWeight: hasFocus || isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: hasFocus ? Colors.white : Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildAudioOptionsPanel() {
    return Positioned(
      bottom: 120,
      left: 16,
      right: 16,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 250),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.95),
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Opções de Áudio',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
                Focus(
                  canRequestFocus:
                      false, // Prevents stealing TV focus naturally
                  child: IconButton(
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => setState(() => _showAudioOptions = false),
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 8),
            Flexible(
              child: _audioTracks.isEmpty
                  ? const Center(
                      child: Text('Nenhuma faixa de áudio disponível',
                          style: TextStyle(color: Colors.white70)),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: _audioTracks.asMap().entries.map((entry) {
                          final index = entry.key;
                          final track = entry.value;
                          final title = track.title ??
                              track.language ??
                              'Faixa ${index + 1}';
                          final isSelected = index == _selectedAudioIndex;
                          return _buildFocusableOptionItem(
                              focusNode: _audioNodes[index],
                              autofocus: index == 0,
                              title: title,
                              subtitle: track.language,
                              isSelected: isSelected,
                              onTap: () => _setAudioTrack(index),
                              onDown: () {
                                if (index < _audioTracks.length - 1) {
                                  _audioNodes[index + 1].requestFocus();
                                }
                              },
                              onUp: () {
                                if (index > 0) {
                                  _audioNodes[index - 1].requestFocus();
                                } else {
                                  _audioFocusNode.requestFocus();
                                  setState(() => _showAudioOptions = false);
                                }
                              });
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitleOptionsPanel() {
    return Positioned(
      bottom: 120,
      left: 16,
      right: 16,
      child: Container(
        constraints:
            BoxConstraints(maxHeight: _showSubtitleCustomizer ? 350 : 250),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.95),
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Legendas',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 16),
                    // Botão para alternar entre Faixas e Estilo
                    _buildSubPanelToggleButton(),
                  ],
                ),
                Focus(
                  canRequestFocus: false, // Prevents stealing TV focus
                  child: IconButton(
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () =>
                        setState(() => _showSubtitleOptions = false),
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 8),
            if (!_showSubtitleCustomizer)
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Opção para desativar legenda
                      _buildFocusableOptionItem(
                          focusNode: _subtitleNodes.isNotEmpty
                              ? _subtitleNodes[0]
                              : FocusNode(),
                          autofocus: true,
                          title: 'Desativado',
                          isSelected: _selectedSubtitleIndex == -1,
                          onTap: () => _setSubtitleTrack(-1),
                          onUp: () {
                            _subtitleFocusNode.requestFocus();
                            setState(() => _showSubtitleOptions = false);
                          },
                          onDown: () {
                            if (_subtitleTracks.isNotEmpty &&
                                _subtitleNodes.length > 1) {
                              _subtitleNodes[1].requestFocus();
                            }
                          }),
                      if (_subtitleTracks.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        ..._subtitleTracks.asMap().entries.map((entry) {
                          final index = entry.key;
                          final mapIndex = index + 1;
                          final track = entry.value;
                          final title = track.title ??
                              track.language ??
                              'Legenda ${index + 1}';
                          final isSelected = index == _selectedSubtitleIndex;
                          return _buildFocusableOptionItem(
                              focusNode: _subtitleNodes[mapIndex],
                              title: title,
                              subtitle: track.language,
                              isSelected: isSelected,
                              onTap: () => _setSubtitleTrack(index),
                              onUp: () {
                                if (mapIndex > 0)
                                  _subtitleNodes[mapIndex - 1].requestFocus();
                              },
                              onDown: () {
                                if (mapIndex < _subtitleNodes.length - 1) {
                                  _subtitleNodes[mapIndex + 1].requestFocus();
                                }
                              });
                        }),
                      ],
                    ],
                  ),
                ),
              )
            else
              // UI de Customização de Estilo
              _buildSubtitleStyleCustomizer(),
          ],
        ),
      ),
    );
  }

  Widget _buildSubPanelToggleButton() {
    return Focus(
      focusNode: _subToggleCustomizerNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          setState(() => _showSubtitleCustomizer = !_showSubtitleCustomizer);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(builder: (ctx) {
        final hasFocus = Focus.of(ctx).hasFocus;
        return GestureDetector(
          onTap: () => setState(
              () => _showSubtitleCustomizer = !_showSubtitleCustomizer),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: hasFocus ? Colors.blueAccent : Colors.white10,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_showSubtitleCustomizer ? Icons.list : Icons.style,
                    color: Colors.white, size: 14),
                const SizedBox(width: 6),
                Text(
                  _showSubtitleCustomizer ? 'Ver Faixas' : 'Ajustar Estilo',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSubtitleStyleCustomizer() {
    final curSize = Prefs.getSubtitleSize();
    final curColor = Prefs.getSubtitleColor();
    final curBg = Prefs.getSubtitleBackground();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          // Controle de Tamanho
          _buildStyleControl(
            focusNode: _subSizeNode,
            label: 'Tamanho da Fonte',
            value: curSize.toInt().toString(),
            onLeft: () {
              if (curSize > 16) {
                Prefs.setSubtitleSize(curSize - 4);
                setState(() {});
                _applySubtitleStyles();
              }
            },
            onRight: () {
              if (curSize < 64) {
                Prefs.setSubtitleSize(curSize + 4);
                setState(() {});
                _applySubtitleStyles();
              }
            },
            onUp: () => _subToggleCustomizerNode.requestFocus(),
            onDown: () => _subColorNode.requestFocus(),
          ),

          // Controle de Cor
          _buildStyleControl(
            focusNode: _subColorNode,
            label: 'Cor do Texto',
            value: curColor.toUpperCase(),
            onLeft: () {
              final colors = ['white', 'yellow', 'cyan', 'green'];
              final idx = colors.indexOf(curColor);
              final next = colors[(idx - 1 + colors.length) % colors.length];
              Prefs.setSubtitleColor(next);
              setState(() {});
              _applySubtitleStyles();
            },
            onRight: () {
              final colors = ['white', 'yellow', 'cyan', 'green'];
              final idx = colors.indexOf(curColor);
              final next = colors[(idx + 1) % colors.length];
              Prefs.setSubtitleColor(next);
              setState(() {});
              _applySubtitleStyles();
            },
            onUp: () => _subSizeNode.requestFocus(),
            onDown: () => _subBgToggleNode.requestFocus(),
          ),

          // Controle de Fundo
          _buildStyleControl(
            focusNode: _subBgToggleNode,
            label: 'Fundo (Box)',
            value: curBg ? 'ATIVADO' : 'DESATIVADO',
            onLeft: () {
              Prefs.setSubtitleBackground(!curBg);
              setState(() {});
              _applySubtitleStyles();
            },
            onRight: () {
              Prefs.setSubtitleBackground(!curBg);
              setState(() {});
              _applySubtitleStyles();
            },
            onUp: () => _subColorNode.requestFocus(),
          ),

          const SizedBox(height: 16),
          const Text(
            'Use as setas Esquerda/Direita para ajustar',
            style: TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleControl({
    required FocusNode focusNode,
    required String label,
    required String value,
    required VoidCallback onLeft,
    required VoidCallback onRight,
    required VoidCallback onUp,
    VoidCallback? onDown,
  }) {
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            onLeft();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            onRight();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            onUp();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
              onDown != null) {
            onDown();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(builder: (ctx) {
        final hasFocus = Focus.of(ctx).hasFocus;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: hasFocus
                ? Colors.blueAccent.withOpacity(0.2)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: hasFocus ? Colors.blueAccent : Colors.transparent),
          ),
          child: Row(
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const Spacer(),
              const Icon(Icons.arrow_left, color: Colors.white24, size: 18),
              const SizedBox(width: 8),
              Text(
                value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_right, color: Colors.white24, size: 18),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildFitOptionsPanel() {
    return Positioned(
      bottom: 120,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.95),
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ajuste de Tela',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
                Focus(
                  canRequestFocus: false, // Prevents stealing TV focus
                  child: IconButton(
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => setState(() => _showFitOptions = false),
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_fitOptions.length, (index) {
                final option = _fitOptions[index];
                final isSelected = index == _fitIndex;

                return Focus(
                  focusNode: index == 0 ? _firstFitOptionNode : null,
                  autofocus: index == 0,
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent &&
                        (event.logicalKey == LogicalKeyboardKey.select ||
                            event.logicalKey == LogicalKeyboardKey.enter ||
                            event.logicalKey ==
                                LogicalKeyboardKey.gameButtonA)) {
                      _setFit(index);
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Builder(builder: (ctx) {
                    final hasFocus = Focus.of(ctx).hasFocus;
                    return GestureDetector(
                      onTap: () => _setFit(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: hasFocus
                              ? Colors.blueAccent.withOpacity(0.8)
                              : (isSelected
                                  ? Colors.blueAccent
                                  : Colors.white.withOpacity(0.1)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: hasFocus
                                ? Colors.white
                                : (isSelected
                                    ? Colors.transparent
                                    : Colors.white24),
                            width: hasFocus ? 2 : (isSelected ? 0 : 1),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              option['icon'] as IconData,
                              color: hasFocus || isSelected
                                  ? Colors.white
                                  : Colors.white70,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              option['label'] as String,
                              style: TextStyle(
                                color: hasFocus || isSelected
                                    ? Colors.white
                                    : Colors.white70,
                                fontSize: 13,
                                fontWeight: hasFocus || isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                );
              }),
            ),
            const SizedBox(height: 12),
            const Text(
              'Ajustar: Mantém proporção • Preencher: Corta bordas • Esticar: Distorce',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
