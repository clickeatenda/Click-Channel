import 'package:flutter/material.dart';
import 'dart:async'; // Required for Timer (Watchdog)
import 'dart:io'; // Required for Platform check
import 'package:flutter/services.dart';
import 'dart:convert'; // Required for Base64
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/content_item.dart';
import '../data/watch_history_service.dart';
import '../data/epg_service.dart';
import '../models/epg_program.dart';

import '../data/favorites_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // NOVO import para bypassar erro de build
import '../data/jellyfin_service.dart'; // Garantir import do service
import '../core/prefs.dart'; // Player Settings

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
  bool _showControls = true;
  bool _showInfo = false;
  bool _showAudioOptions = false;
  bool _showSubtitleOptions = false;
  bool _showFitOptions = false;
  bool isFavorite = false; // Novo estado
  String _currentMediaUrl = ''; // Debug URL
  
  // Informações de mídia
  String _videoQuality = 'Carregando...';
  // ... (restante dos campos)
  String _videoCodec = '';
  String _audioCodec = '';
  String _currentAudio = 'Padrão';
  String _currentSubtitle = 'Desativado';
  List<AudioTrack> _audioTracks = [];
  List<SubtitleTrack> _subtitleTracks = [];
  // v25: Lista manual de legendas (Jellyfin API)
  List<Map<String, dynamic>> _jellyfinSubtitles = [];
  bool _isLoadingSubs = false;

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
  
  // FocusNodes
  final FocusNode _playPauseFocusNode = FocusNode();
  final FocusNode _rootFocusNode = FocusNode(); // Root for keyboard listener
  final FocusNode _rewindFocusNode = FocusNode();
  final FocusNode _forwardFocusNode = FocusNode();
  final FocusNode _audioFocusNode = FocusNode();
  final FocusNode _subtitleFocusNode = FocusNode();
  final FocusNode _fitFocusNode = FocusNode();
  final FocusNode _infoFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    
    try {
      if (widget.item != null) {
        isFavorite = FavoritesService.isFavorite(widget.item!);
      }
      _playlist = widget.playlist ?? (widget.item != null ? [widget.item!] : []);
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

  // --- WATCHDOG / KEEP ALIVE SYSTEM ---
  Timer? _watchdogTimer;
  Duration _lastWatchdogPos = Duration.zero;
  int _stallCount = 0;

  void _startWatchdog() {
    _watchdogTimer?.cancel();
    // Verifica a cada 2 segundos se o vídeo está andando
    _watchdogTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      // Só monitora se deveria estar tocando e não está explicitamente em buffer
      if (_isPlaying && !_isBuffering) {
        final currentPos = _position;
        
        // Se a posição não mudou (ou mudou muito pouco) em 2 segundos
        if ((currentPos - _lastWatchdogPos).abs().inMilliseconds < 200) {
           _stallCount++;
        } else {
           _stallCount = 0; // Playback normal, reseta contador
           _lastWatchdogPos = currentPos;
        }

        // Se detectarmos 5 verificações seguidas (10 segundos) sem progresso...
        if (_stallCount >= 5) {
           print('⚠️ Watchdog: DETECTADO TRAVAMENTO (Stall). Reiniciando player...');
           _stallCount = 0;
           _retryPlayback();
        }
      }
    });
  }

  void _stopWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
  }

  Future<void> _retryPlayback() async {
    _stopWatchdog();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sinal instável. Reconectando...'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      )
    );

    // Pequeno delay para liberar recursos
    await Future.delayed(const Duration(milliseconds: 500));
    _initPlayer(); // Re-inicializa tudo
  }

  // ... (dentro de _buildTopBar) ...
  
  /// CAMADA SUPERIOR: Voltar | Favoritos | Info
  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          bottom: 8,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.8), Colors.transparent],
          ),
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
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
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
                  icon: Icons.arrow_back,
                  label: 'Voltar',
                  onPressed: () => Navigator.pop(context),
                  onDownPressed: () => _rewindFocusNode.requestFocus(),
                ),
                const SizedBox(width: 12),
                
                // FAVORITOS
                if (widget.item != null)
                  _buildTopButton(
                    icon: isFavorite ? Icons.favorite : Icons.favorite_border,
                    label: 'Favorito',
                    color: isFavorite ? Colors.red : Colors.white,
                    onPressed: _toggleFavorite,
                    onDownPressed: () => _playPauseFocusNode.requestFocus(),
                  ),
                const SizedBox(width: 12),
                
                // INFORMAÇÃO
                _buildTopButton(
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
    );
  }
  
  Widget _buildTopButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required VoidCallback onDownPressed,
    Color color = Colors.white,
  }) {
    return Focus(
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
              color: hasFocus ? Colors.blueAccent.withOpacity(0.7) : Colors.white.withOpacity(0.1),
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
  
  Future<void> _initPlayer() async {
    try {
      print('🎬 Iniciando player para: ${widget.url}');
      
      // Cleanup anterior se houver (retry)
      await _player?.dispose();
      
      // Criar player com configurações otimizadas (buffer aumentado e Hardware Acceleration)
      _player = Player(
        configuration: PlayerConfiguration(
          // CRÍTICO: Configurações para compatibilidade com Jellyfin Direct Play
          // Docs: https://mpv.io/manual/master/
          title: widget.item?.title ?? 'Click Channel',
          
          // Aumentamos drasticamente o buffer para evitar travamentos em redes instáveis
          bufferSize: 128 * 1024 * 1024, // 128MB
          vo: 'gpu',
        ),
      );

      // Apply mpv-specific options for Jellyfin compatibility
      // TEMPORARIAMENTE DESABILITADO PARA TESTE
      /*
      try {
        final nativePlayer = _player.platform as dynamic;
        
        // Demuxer options - be more permissive with format detection
        await nativePlayer.setProperty('demuxer-lavf-probe-info', 'yes');
        await nativePlayer.setProperty('demuxer-lavf-analyzeduration', '20000000'); // 20 seconds
        await nativePlayer.setProperty('demuxer-lavf-probescore', '25'); // Lower threshold (default 26)
        
        // Try software decoding first for compatibility
        await nativePlayer.setProperty('hwdec', 'no');
        
        // Network/stream options
        await nativePlayer.setProperty('stream-lavf-o', 'reconnect_streamed=1,reconnect_delay_max=5');
        
        print('✅ [Player] Configurações mpv aplicadas para compatibilidade Jellyfin');
      } catch (e) {
        print('⚠️ [Player] Erro ao aplicar configurações mpv: $e');
      }
      */
      
      _controller = VideoController(_player!);
      
      // Listeners
      _player!.stream.playing.listen((playing) {
        if (mounted) setState(() => _isPlaying = playing);
      });
      
      _player!.stream.position.listen((position) {
        if (mounted) {
          setState(() => _position = position);
          _saveProgress();
        }
      });
      
      _player!.stream.duration.listen((duration) {
        if (mounted) setState(() => _duration = duration);
      });
      
      _player!.stream.buffering.listen((buffering) {
        if (mounted) setState(() => _isBuffering = buffering);
      });
      
      _player!.stream.error.listen((error) {
        if (mounted && error.isNotEmpty) {
          // IGNORAR ERROS NÃO 
          if (error.toLowerCase().contains('seek') || 
              error.toLowerCase().contains('force') ||
              error.toLowerCase().contains('codec') || // Ignora erros de codec (pode ser áudio não suportado mas video ok)
              error.toLowerCase().contains('decoder') ||
              error.contains('--')) {
             print('⚠️ Ignorando aviso de player: $error');
             
             // Se o erro for de seek/codec, garantimos que o player pelo menos tente tocar
             if (!_isPlaying) _player!.play();
             return;
          }
           
          print('❌ Player error: $error');
          // Auto-Retry logic for decoding errors
          if (_retryCount < 3 && _position.inSeconds > 1) {
            _retryCount++;
            print('🔄 Tentando recuperar playback (Tentativa $_retryCount/3)...');
            
            ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(
                 content: Text('Erro de reprodução. Reconectando...'),
                 duration: Duration(seconds: 2),
               )
            );
            
            // Reabre o vídeo na posição atual
            final currentPos = _position;
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
           _onVideoCompleted();
        }
      });
      
      // Listener para tracks de áudio
    _player!.stream.tracks.listen((tracks) {
      if (mounted) {
        setState(() {
          // Filtrar tracks vazias (a primeira geralmente é "no" track)
          _audioTracks = tracks.audio.where((t) => t.id != 'no' && t.id != 'auto').toList();
          _subtitleTracks = tracks.subtitle.where((t) => t.id != 'no' && t.id != 'auto').toList();
          
          // Debug
          print('🎵 Audio tracks: ${_audioTracks.length}');
          for (var t in _audioTracks) {
            print('   - ${t.id}: ${t.title ?? t.language ?? "unknown"}');
          }
          print('📝 Subtitle tracks: ${_subtitleTracks.length}');
          for (var t in _subtitleTracks) {
            print('   - ${t.id}: ${t.title ?? t.language ?? "unknown"}');
          }
          
          // AUTO-RECOVERY: Se perdeu todas as tracks de áudio durante reprodução, força play
          if (_audioTracks.isEmpty && _position.inSeconds > 5 && !_isPlaying) {
            print('⚠️ PERDA DE ÁUDIO DETECTADA! Forçando continuação da reprodução...');
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted && _player != null) {
                _player!.play();
              }
            });
          }
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
                _currentAudio = audioTrack.title ?? audioTrack.language ?? 'Faixa ${idx + 1}';
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
            final idx = _subtitleTracks.indexWhere((t) => t.id == subtitleTrack.id);
            if (idx >= 0) {
              setState(() {
                _selectedSubtitleIndex = idx;
                _currentSubtitle = subtitleTrack.title ?? subtitleTrack.language ?? 'Legenda ${idx + 1}';
              });
            }
          }
        }
      });
      
      // Listener para informações de vídeo
      _player!.stream.width.listen((width) => _updateVideoInfo());
      _player!.stream.height.listen((height) => _updateVideoInfo());
      
      // Verificar posição salva
      final savedPosition = await WatchHistoryService.getSavedPosition(widget.url).timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );
      
      // Carregar EPG se for canal
      if (widget.item != null && widget.item!.type == 'channel') {
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
          
          _epgChannel = EpgService.findChannelByName(widget.item!.title);
          if (_epgChannel != null) {
            _currentEpgProgram = _epgChannel!.currentProgram;
            _nextEpgProgram = _epgChannel!.nextProgram;
            print('✅ EPG carregado para canal "${widget.item!.title}": ${_currentEpgProgram?.title ?? "Sem programa"}');
          } else {
            print('⚠️ EPG não encontrado para canal "${widget.item!.title}"');
          }
          if (mounted) setState(() {});
        } catch (e) {
          print('⚠️ Erro ao carregar EPG no player: $e');
        }
      }
      
      // Abrir mídia com timeout
      // Configs v18 (Player Settings)
      final decoderMode = Prefs.getDecoderMode();
      final bufferSize = Prefs.getBufferSize();
      final hlsForced = Prefs.getHlsForced();

      // HLS Override Logic moved to end of function
      var mediaUrl = _playlist[_currentIndex].url;

      // Decoder Mapping
      String hwdecValue = 'auto'; // Default safer
      
      if (Platform.isAndroid) {
        hwdecValue = 'mediacodec-copy'; // Tenta copy para melhor compatibilidade
      } else if (Platform.isWindows) {
        hwdecValue = 'd3d11va'; // Windows Explicit (Melhor que auto)
      }

      if (decoderMode == 'sw') hwdecValue = 'no'; // Software
      if (decoderMode == 'auto') hwdecValue = 'auto'; // Automatic
      if (decoderMode == 'hw') hwdecValue = Platform.isAndroid ? 'mediacodec' : 'auto';

      // Buffer Mapping
      String demuxerMaxBytes = '100M'; // Default Medium
      String demuxerMaxBackBytes = '20M';
      
      if (bufferSize == 'low') {
        demuxerMaxBytes = '32M';
        demuxerMaxBackBytes = '5M';
      } else if (bufferSize == 'high') {
         demuxerMaxBytes = '300M';
         demuxerMaxBackBytes = '50M';
      }

      print('⚙️ Player Config: Decoder=$decoderMode ($hwdecValue), Buffer=$bufferSize ($demuxerMaxBytes), HLS=$hlsForced');
      
      print('🎬 [Player] Iniciando setup para item: ${widget.item?.title ?? "Desconhecido"}');

       // CRÍTICO: Buscar PlaybackInfo ANTES de abrir a mídia
      // Relaxando checagem de grupo para teste (se tiver ID, tenta buscar)
      if (widget.item != null && (widget.item!.group == 'Jellyfin' || widget.item!.id.isNotEmpty)) {
        try {
           final mediaInfo = await JellyfinService.getMediaInfo(widget.item!.id);
           if (mediaInfo != null && mediaInfo['MediaSources'] != null) {
             final sources = mediaInfo['MediaSources'] as List;
             
             if (sources.isNotEmpty) {
               final source = sources[0];
               final sourceId = source['Id'];
               final directPlay = source['SupportsDirectPlay'] == true;
               final directStream = source['SupportsDirectStream'] == true;
               final container = source['Container'] ?? 'unknown';
               
               print('📦 [Player] Source: container=$container, DirectPlay=$directPlay, DirectStream=$directStream');
               
               if (directPlay || directStream) {
                 // Direct Play/Stream - usa URL de stream normal
                 final newUrl = JellyfinService.getStreamUrl(widget.item!.id) + '&MediaSourceId=$sourceId';
                 mediaUrl = newUrl;
                 print('🎬 [Player] Usando Direct Play/Stream');
               } else {
                 // CRÍTICO: Precisa de transcoding HLS do servidor
                 // Usa endpoint /master.m3u8 que pede ao Jellyfin para transcodificar
                 mediaUrl = JellyfinService.getHlsTranscodingUrl(widget.item!.id, mediaSourceId: sourceId);
                 print('🔄 [Player] DirectPlay=false → Usando HLS Transcoding do Jellyfin');
                 print('   └─ URL: $mediaUrl');
               }
               
               // Carregar Legendas
               if (source['MediaStreams'] != null) {
                 final streams = source['MediaStreams'] as List;
                     final subtitles = streams.where((s) => s['Type'] == 'Subtitle').toList();
                 
                     // ignore: avoid_print
                     print('📝 [Player] Legendas encontradas na API: ${subtitles.length}');
                 
                     if (mounted) {
                       setState(() {
                         _jellyfinSubtitles = subtitles.map((s) {
                           // Adiciona ID do source para garantir download correto
                           final map = Map<String, dynamic>.from(s);
                           map['MediaSourceId'] = sourceId; 
                           return map;
                         }).toList();
                       });
                   
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Jellyfin (Force): ${subtitles.length} legendas!'),
                        backgroundColor: subtitles.isNotEmpty ? Colors.green : Colors.orange,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                 }
               }
             }
           } else {
             // ignore: avoid_print
             print('⚠️ [Player] PlaybackInfo retornou NULL ou sem Sources');
           }
        } catch (e) {
           // ignore: avoid_print
           print('⚠️ [Player] Erro PlaybackInfo: $e');
        }
      }



      // CRÍTICO: Aplicar lógica de HLS Forced POR ÚLTIMO, para garantir que params sejam adicionados
      // mesmo após a atualização da URL pelo PlaybackInfo
      if (hlsForced) {
        if (mediaUrl.contains('.ts')) {
           mediaUrl = mediaUrl.replaceAll('.ts', '.m3u8');
           print('🔄 Player: HLS Forced -> Convertendo .ts para .m3u8');
         // FIX: Desabilitar TranscodingContainer forçado para Jellyfin
         // Causa erro "partial file" pois player tenta abrir antes da transcodificação terminar
         // Jellyfin já decide automaticamente se precisa transcodificar via PlaybackInfo
         /*
         } else if (widget.item?.group == 'Jellyfin' && !mediaUrl.contains('.m3u8') && !mediaUrl.contains('TranscodingContainer')) {
            // Jellyfin brute force
            if (mediaUrl.contains('/stream')) {
              mediaUrl += '&TranscodingContainer=m3u8';
              print('🔄 Player: HLS Forced (Jellyfin) -> Adicionando container m3u8 (Final)');
            }
         */
         } else if (widget.item?.group == 'Jellyfin') {
           print('🎬 Direct Play habilitado para Jellyfin (sem transcodificação forçada)');
         }
       }

      print('🎬 Abrindo mídia final: $mediaUrl');
      _currentMediaUrl = mediaUrl; // Salva para debug na UI de erro
      
      // Mídia Principal
      final media = Media(
        mediaUrl,
        httpHeaders: {
          'User-Agent': 'ClickChannel/1.0 VLC/3.0.18',
          if (widget.item?.group == 'Jellyfin' && JellyfinService.accessToken.isNotEmpty) ...{
            'X-Emby-Authorization': JellyfinService.getAuthorizationHeader(),
            // Mantendo token legacy apenas por segurança
            'X-MediaBrowser-Token': JellyfinService.accessToken,
          } 
        },
        extras: {
          'network-timeout': '30',
          'reconnect': 'yes',
          'reconnect-delay': '1',
          'tls-verify': 'no', // Fix SSL Self-Signed
          // Buffer Dinâmico
          'stream-buffer-size': '2M',
          'demuxer-max-bytes': demuxerMaxBytes,
          'demuxer-max-back-bytes': demuxerMaxBackBytes,
          'hls-bitrate': 'max',
          'sub-codepage': 'utf-8', // CRÍTICO: Forçar codificação UTF-8
          'cache': 'yes',
          'keep-open': 'yes',
          'user-agent': 'VLC/3.0.18 LibVLC/3.0.18',
          'audio-fallback-to-null': 'yes',
          'video-sync': 'audio',
          'hwdec': hwdecValue,     // Codec Dinâmico
          'framedrop': 'vo',
          'vd-lavc-threads': '16', // CRÍTICO: Multithread decoding para 4K
        },
      );
      
      // CRÍTICO: Abre sem dar play imediatamente para configurar buffer e seek com segurança
      await _player!.open(media, play: false).timeout(
        const Duration(seconds: 45), // Aumentado timeout para conexões lentas
        onTimeout: () {
          print('⏱️ Timeout ao abrir mídia');
          throw Exception('Timeout ao carregar vídeo. Verifique sua conexão.');
        },
      );
      
      // Logica de legendas movida para antes do player.open
      
      // Seek seguro antes de tocar (evita que o player toque do início e pule depois)
      if (savedPosition != null && savedPosition.inSeconds > 5) { // Só resume se > 5s
        print('⏩ Retomando de ${_formatDuration(savedPosition)}');
        try {
           await _player!.seek(savedPosition).timeout(
             const Duration(seconds: 5),
             onTimeout: () => print('⏱️ Timeout ao fazer seek inicial'),
           );
        } catch(e) {
           print('⚠️ Erro não-fatal no seek: $e');
        }
      }
      
      print('✅ Mídia pronta. Iniciando playback...');
      await _player!.play();
      
      if (mounted) {
        setState(() => _isInitialized = true);
        print('✅ Player inicializado');
      }
      
      // Auto-hide controls após 5 segundos
      _startControlsTimer();
      
      // Inicia monitoramento de travamentos
      _startWatchdog();
      
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

  void _markAsWatched() {
     if (_currentIndex < _playlist.length) {
       final item = _playlist[_currentIndex];
       WatchHistoryService.addToWatched(item);
     }
  }

  void _playNext() {
      if (!mounted) return;
      setState(() {
         _currentIndex++;
         _hasError = false;
         _errorMessage = '';
         _position = Duration.zero;
      });
      
      final nextItem = _playlist[_currentIndex];
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
           content: Text('Reproduzindo: ${nextItem.title} - ${nextItem.group}'), 
           duration: const Duration(seconds: 3),
           behavior: SnackBarBehavior.floating,
        )
      );
      
      _player?.open(Media(nextItem.url, httpHeaders: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      }));
  }
  
  void _updateVideoInfo() {
    final width = _player?.state.width;
    final height = _player?.state.height;
    
    if (width != null && height != null && width > 0 && height > 0) {
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
    if (widget.item != null && _position.inSeconds % 10 == 0 && _duration.inSeconds > 0) {
      WatchHistoryService.saveProgress(widget.item!, _position, _duration);
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
    final newPosition = _position + const Duration(seconds: 10);
    _player?.seek(newPosition);
  }
  
  void _seekBackward() {
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
      print('🎵 Selecionando áudio: ${track.id} - ${track.title ?? track.language}');
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
      print('📝 Selecionando legenda: ${track.id} - ${track.title ?? track.language}');
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
    // Salvar progresso final
    if (widget.item != null && _duration.inSeconds > 0) {
      WatchHistoryService.saveProgress(widget.item!, _position, _duration);
    }
    _player?.dispose();
    _player = null; // CRÍTICO: Evita erro "player has been disposed" em callbacks async
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
    _stopWatchdog();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _hasError ? _buildErrorView() : _buildPlayerView(),
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
            child: const Text('Voltar', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoError(BuildContext context, String error) {
    // Tradução amigável de erros comuns
    String displayError = error;
    if (error.contains('Failed to open')) {
      displayError = 'Falha ao abrir o vídeo.\n\nVerifique:\n1. Se o servidor Jellyfin está online.\n2. Se o formato do arquivo é suportado.\n3. Se sua conexão de internet está estável.';
    } else if (error.contains('404')) {
      displayError = 'Arquivo não encontrado (Erro 404).\nO vídeo pode ter sido movido ou deletado do servidor.';
    } else if (error.contains('401') || error.contains('403')) {
      displayError = 'Acesso negado (Erro de Autenticação).\nVerifique seu login no Jellyfin.';
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        color: Colors.black87,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.orange, size: 48),
              const SizedBox(height: 16),
              const Text('Erro de Reprodução', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text(displayError, style: const TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              if (displayError != error) // Mostra erro original menor se foi traduzido
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text('Detalhe técnico: $error', style: const TextStyle(color: Colors.grey, fontSize: 10), textAlign: TextAlign.center),
                ),
              const SizedBox(height: 16),
              if (_currentMediaUrl.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('URL de Origem:', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      SelectableText(
                        _currentMediaUrl,
                        style: const TextStyle(color: Colors.blueGrey, fontSize: 10, fontFamily: 'monospace'),
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                   // Força reset do player
                   _initPlayer();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar Novamente'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              ),
              const SizedBox(height: 12),
              TextButton(
                 onPressed: () => Navigator.pop(context),
                 child: const Text('Voltar', style: TextStyle(color: Colors.white54)),
              )
            ],
          ),
        ),
      ),
    );
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
        if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.backspace) {
          Navigator.pop(context);
          return KeyEventResult.handled;
        }

        // Se controles ocultos
        if (!_showControls) {
          // Qualquer tecla acorda a UI
          setState(() => _showControls = true);
          _startControlsTimer();
          
          // Solicita foco para o botão principal (Play/Pause)
          // Isso permite que a navegação comece imediatamente
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_playPauseFocusNode.canRequestFocus) {
              _playPauseFocusNode.requestFocus();
            }
          });
          
          // Se for setas, executamos a ação E mostramos a UI?
          // Padrão TV: Setas enquanto oculto = Seek direto (sem mostrar UI focável, talvez info overlay)
          // Mas aqui decidimos mostrar a UI.
          // Vamos permitir que o primeiro clique apenas mostre a UI para não causar ação acidental.
          // EXCETO setas, que usuário espera seek imediato.
          if (key == LogicalKeyboardKey.arrowLeft) {
            _seekBackward();
            return KeyEventResult.handled;
          } 
          if (key == LogicalKeyboardKey.arrowRight) {
             _seekForward();
             return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
             // Apenas mostra controles, não pausa ainda.
             return KeyEventResult.handled;
          }
          
          // Outras teclas: apenas mostrou UI
          return KeyEventResult.handled;
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
            // RETROCEDER 10s
            _buildCenterButton(
              focusNode: _rewindFocusNode,
              icon: Icons.replay_10,
              size: 44,
              onPressed: _seekBackward,
              // Navegação vertical
              onUpPressed: () {}, // Vai para TopBar - deixar vazio por enquanto, navegação natural
              onDownPressed: () => _audioFocusNode.requestFocus(),
            ),
            const SizedBox(width: 48),
            // PLAY/PAUSE (principal)
            _buildCenterButton(
              focusNode: _playPauseFocusNode,
              icon: _isPlaying ? Icons.pause : Icons.play_arrow,
              size: 64,
              onPressed: _togglePlayPause,
              isPrimary: true,
              onUpPressed: () {}, // Navegação natural para cima
              onDownPressed: () => _subtitleFocusNode.requestFocus(),
            ),
            const SizedBox(width: 48),
            // AVANÇAR 10s
            _buildCenterButton(
              focusNode: _forwardFocusNode,
              icon: Icons.forward_10,
              size: 44,
              onPressed: _seekForward,
              onUpPressed: () {}, // Navegação natural para cima
              onDownPressed: () => _fitFocusNode.requestFocus(),
            ),
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
          // Seta para cima - volta para camada superior (natural focus traversal)
          // Deixamos o sistema lidar com isso
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
                  : (isPrimary ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.1)),
              shape: BoxShape.circle,
              border: Border.all(
                color: hasFocus ? Colors.blueAccent : Colors.white.withOpacity(isPrimary ? 0.5 : 0.3), 
                width: hasFocus ? 3 : (isPrimary ? 2 : 1),
              ),
              boxShadow: hasFocus ? [
                const BoxShadow(color: Colors.blueAccent, blurRadius: 20, spreadRadius: 3)
              ] : null,
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
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.8), Colors.transparent],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar
            Row(
              children: [
                Text(
                  _formatDuration(_position),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                Expanded(
                  child: Slider(
                    value: _duration.inSeconds > 0
                        ? _position.inSeconds.toDouble().clamp(0, _duration.inSeconds.toDouble())
                        : 0,
                    max: _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1,
                    activeColor: Colors.blueAccent,
                    inactiveColor: Colors.white30,
                    onChanged: (value) {
                      _player?.seek(Duration(seconds: value.toInt()));
                    },
                  ),
                ),
                Text(
                  _formatDuration(_duration),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
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
                  onTap: () => setState(() {
                    _showAudioOptions = !_showAudioOptions;
                    _showSubtitleOptions = false;
                    _showFitOptions = false;
                    _showInfo = false;
                  }),
                  isActive: _showAudioOptions,
                  onUpPressed: () => _rewindFocusNode.requestFocus(),
                  onRightPressed: () => _subtitleFocusNode.requestFocus(),
                ),
                // LEGENDA
                _buildBottomButton(
                  focusNode: _subtitleFocusNode,
                  icon: Icons.subtitles,
                  label: _currentSubtitle,
                  onTap: () => setState(() {
                    _showSubtitleOptions = !_showSubtitleOptions;
                    _showAudioOptions = false;
                    _showFitOptions = false;
                    _showInfo = false;
                  }),
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
                  onTap: () => setState(() {
                    _showFitOptions = !_showFitOptions;
                    _showAudioOptions = false;
                    _showSubtitleOptions = false;
                    _showInfo = false;
                  }),
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
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft && onLeftPressed != null) {
            onLeftPressed();
            return KeyEventResult.handled;
          }
          // Seta para direita - navega para próximo botão
          if (event.logicalKey == LogicalKeyboardKey.arrowRight && onRightPressed != null) {
            onRightPressed();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: hasFocus 
                    ? Colors.blueAccent.withOpacity(0.7) 
                    : (isActive ? Colors.blueAccent.withOpacity(0.3) : Colors.white.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasFocus 
                      ? Colors.blueAccent 
                      : (isActive ? Colors.blueAccent : Colors.white24),
                  width: hasFocus ? 3 : 1,
                ),
                boxShadow: hasFocus ? [
                   const BoxShadow(color: Colors.blueAccent, blurRadius: 10, spreadRadius: 2)
                ] : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: hasFocus ? Colors.white : (isActive ? Colors.blueAccent : Colors.white70), size: 24),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: TextStyle(
                      color: hasFocus ? Colors.white : (isActive ? Colors.blueAccent : Colors.white70),
                      fontSize: 14,
                      fontWeight: hasFocus ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }
  
  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.space || 
             event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: hasFocus 
                    ? Colors.white.withOpacity(0.3) 
                    : (isActive ? Colors.blueAccent.withOpacity(0.3) : Colors.white.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasFocus 
                      ? Colors.white 
                      : (isActive ? Colors.blueAccent : Colors.transparent),
                  width: hasFocus ? 2 : 2,
                ),
                boxShadow: hasFocus ? [
                   BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 4, spreadRadius: 1)
                ] : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: hasFocus ? Colors.white : (isActive ? Colors.blueAccent : Colors.white), size: 20),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: hasFocus ? Colors.white : (isActive ? Colors.blueAccent : Colors.white),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      ),
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
                    icon: const Icon(Icons.refresh, color: Colors.white70, size: 18),
                    onPressed: () async {
                      // Recarregar EPG
                      if (widget.item != null) {
                        final epgUrl = EpgService.epgUrl;
                        if (epgUrl != null) {
                          try {
                            await EpgService.loadEpg(epgUrl);
                            _epgChannel = EpgService.findChannelByName(widget.item!.title);
                            if (_epgChannel != null) {
                              setState(() {
                                _currentEpgProgram = _epgChannel!.currentProgram;
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
              if (_currentEpgProgram?.description != null && _currentEpgProgram!.description!.isNotEmpty) ...[
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
              _buildInfoRow('Faixas de Áudio', '${_audioTracks.length} disponíveis'),
            if (_subtitleTracks.isNotEmpty)
              _buildInfoRow('Legendas', '${_subtitleTracks.length} disponíveis'),
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
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
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
  
  Widget _buildAudioOptionsPanel() {
    return Positioned(
      bottom: 120,
      left: 16,
      right: 16,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
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
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () => setState(() => _showAudioOptions = false),
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 8),
            Flexible(
              child: _audioTracks.isEmpty
                  ? const Center(
                      child: Text('Nenhuma faixa de áudio disponível', style: TextStyle(color: Colors.white70)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _audioTracks.length,
                      itemBuilder: (context, index) {
                        final track = _audioTracks[index];
                        final title = track.title ?? track.language ?? 'Faixa ${index + 1}';
                        final isSelected = index == _selectedAudioIndex;
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            isSelected ? Icons.check_circle : Icons.circle_outlined,
                            color: isSelected ? Colors.blueAccent : Colors.white54,
                            size: 20,
                          ),
                          title: Text(
                            title,
                            style: TextStyle(
                              color: isSelected ? Colors.blueAccent : Colors.white,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: track.language != null
                              ? Text(track.language!, style: const TextStyle(color: Colors.white54, fontSize: 11))
                              : null,
                          onTap: () => _setAudioTrack(index),
                        );
                      },
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
        constraints: const BoxConstraints(maxHeight: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
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
                  'Opções de Legenda',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () => setState(() => _showSubtitleOptions = false),
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 8),
            // Opção para desativar legenda
            ListTile(
              dense: true,
              leading: Icon(
                _selectedSubtitleIndex == -1 ? Icons.check_circle : Icons.circle_outlined,
                color: _selectedSubtitleIndex == -1 ? Colors.blueAccent : Colors.white54,
                size: 20,
              ),
              title: Text(
                'Desativado',
                style: TextStyle(
                  color: _selectedSubtitleIndex == -1 ? Colors.blueAccent : Colors.white,
                  fontSize: 13,
                ),
              ),
              onTap: () => _setSubtitleTrack(-1),
            ),
            if (_isLoadingSubs)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator(color: Colors.white)),
              ),

             if (!_isLoadingSubs && _subtitleTracks.isEmpty && _jellyfinSubtitles.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Nenhuma legenda disponível', style: TextStyle(color: Colors.white70)),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    // Legendas Nativas (Player)
                    if (_subtitleTracks.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.only(left: 12, top: 4, bottom: 4),
                        child: Text('Internas', style: TextStyle(color: Colors.white54, fontSize: 11)),
                      ),
                      ..._subtitleTracks.asMap().entries.map((entry) {
                         final index = entry.key;
                         final track = entry.value;
                         final title = track.title ?? track.language ?? 'Legenda ${index + 1}';
                         final isSelected = index == _selectedSubtitleIndex && _selectedSubtitleIndex < _subtitleTracks.length;
                         
                         return ListTile(
                          dense: true,
                          leading: Icon(
                            isSelected ? Icons.check_circle : Icons.circle_outlined,
                            color: isSelected ? Colors.blueAccent : Colors.white54,
                            size: 20,
                          ),
                          title: Text(title, style: TextStyle(color: isSelected ? Colors.blueAccent : Colors.white, fontSize: 13)),
                          subtitle: track.language != null ? Text(track.language!, style: const TextStyle(color: Colors.white54, fontSize: 11)) : null,
                          onTap: () => _setSubtitleTrack(index),
                        );
                      }),
                    ],

                    // Legendas Externas (Jellyfin API)
                    if (_jellyfinSubtitles.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.only(left: 12, top: 8, bottom: 4),
                        child: Text('Externas (Jellyfin)', style: TextStyle(color: Colors.white54, fontSize: 11)),
                      ),
                      ..._jellyfinSubtitles.asMap().entries.map((entry) {
                         final idx = entry.key;
                         final sub = entry.value;
                         final title = sub['Title'] ?? sub['Language'] ?? 'Externo ${idx + 1}';
                         
                         // Verifica se já está selecionado (hacky check via nome)
                         final isSelected = _currentSubtitle == title;
                         
                         return ListTile(
                          dense: true,
                          leading: Icon(
                            isSelected ? Icons.check_circle : Icons.download, // Ícone de download
                            color: isSelected ? Colors.blueAccent : Colors.white70,
                            size: 20,
                          ),
                          title: Text(title, style: TextStyle(color: isSelected ? Colors.blueAccent : Colors.white, fontSize: 13)),
                          subtitle: Text('Toque para baixar e ativar', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                          onTap: () async {
                             setState(() => _isLoadingSubs = true);
                             try {
                               final index = (sub['Index'] as num?)?.toInt() ?? 0;
                               final codec = sub['Codec'] ?? 'vtt';
                               String format = (codec == 'srt' || codec == 'subrip') ? 'srt' : 'vtt';
                               final mediaSourceId = sub['MediaSourceId'];

                               print('📥 [UI] Solicitando download da legenda: "$title" (Index: $index, Format: $format, Source: $mediaSourceId)');
                               String? finalUri;
                               
                               // Tenta baixar primeiro
                               final path = await JellyfinService.downloadSubtitle(widget.item!.id, index, format, mediaSourceId: mediaSourceId);
                               if (path != null) {
                                  // CRÍTICO: No Windows, MPV prefere caminhos absolutos com barras normais ou invertidas
                                  // Uri.file() pode causar problemas com encoding de espaços/caracteres
                                  if (Platform.isWindows) {
                                     finalUri = path.replaceAll('\\', '/'); // Normaliza para forward slashes
                                     print('✅ [UI] Windows Path Normalizado: "$finalUri"');
                                  } else {
                                     finalUri = Uri.file(path).toString();
                                     print('✅ [UI] URI padrão: "$finalUri"');
                                  }
                               } else {
                                  // Fallback: URL direta (usando sourceId se tiver)
                                  print('⚠️ [UI] Download falhou. Tentando URL direta...');
                                  
                                  // TODO: Atualizar getSubtitleUrl para aceitar sourceId também se necessário, 
                                  // mas por enquanto vamos manter simples ou construir manual
                                  // O ideal seria que getSubtitleUrl também recebesse mediaSourceId
                                  var directUrl = JellyfinService.getSubtitleUrl(widget.item!.id, index, format, mediaSourceId: mediaSourceId);
                                  if (mediaSourceId != null) {
                                     // Hack rápido para injetar o ID correto na URL se getSubtitleUrl não suportar ainda e usar baseUrl padrão
                                     // Mas como getSubtitleUrl é simples, melhor não mexer. Se download falhou (404), URL direta tbm vai falhar se usar ID errado.
                                     // Vamos confiar no downloadSubtitle que já corrigimos.
                                  }
                                  
                                  if (directUrl.isNotEmpty) {
                                     finalUri = directUrl;
                                     print('✅ [UI] Usando URL direta de legenda: $finalUri');
                                  }
                               }

                               if (finalUri != null && mounted) {
                                  // CRÍTICO: Verificar se player ainda existe e não foi descartado
                                  if (_player != null) {
                                    try {
                                      // Se for arquivo local no Windows, não usa esquema URI file://
                                      // Se for URL remota ou Data URI, usa URI normal

                                      final isLocalWindows = Platform.isWindows && !finalUri.startsWith('http');
                                      
                                      SubtitleTrack track;
                                      
                                      if (isLocalWindows) {
                                        // CRÍTICO: Windows prefere path cru com barras normais (C:/...) ao invés de file:///
                                        // Removemos o scheme file:// se estiver presente (embora aqui finalUri já deva ser path cru vindo do download)
                                        var winPath = finalUri.replaceAll('\\', '/');
                                        if (winPath.startsWith('file:///')) winPath = winPath.substring(8);
                                        track = SubtitleTrack.uri(winPath, title: title, language: sub['Language']);
                                      } else {
                                        track = SubtitleTrack.uri(finalUri, title: title, language: sub['Language']);
                                      }

                                      print('🎬 [UI] Setando legenda no player: "${track.uri}" (LocalWin=$isLocalWindows)');
                                      await _player!.setSubtitleTrack(track);
                                        
                                        if (mounted) {
                                          setState(() {
                                            _currentSubtitle = title;
                                            _selectedSubtitleIndex = 999; 
                                            _isLoadingSubs = false;
                                          });
                                          
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Legenda ativada: $title'), 
                                              backgroundColor: Colors.green,
                                              duration: const Duration(seconds: 2)
                                            )
                                          );
                                        }

                                    } catch (e) {
                                      // Captura AssertionError (player disposed) e outras exceções
                                      print('❌ [UI] Erro ao setar legenda (Player pode ter sido descartado): $e');
                                      if (mounted) {
                                         setState(() => _isLoadingSubs = false);
                                      }
                                    }
                                  }
                               } else {
                                  print('❌ [UI] Falha fatal: Não foi possível obter URI da legenda');
                                  throw Exception('Falha ao carregar legenda (Download e URL direta falharam)');
                               }
                             } catch (e) {
                               print('❌ [UI] Erro ao ativar legenda externa: $e');
                               if (mounted) {
                                 setState(() => _isLoadingSubs = false);
                                 ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Erro ao carregar legenda: $e'), 
                                      backgroundColor: Colors.red,
                                    )
                                  );
                               }
                             }
                          },
                        );
                      }),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
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
          color: Colors.black.withOpacity(0.9),
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
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () => setState(() => _showFitOptions = false),
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
                return GestureDetector(
                  onTap: () => _setFit(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blueAccent : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected ? null : Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          option['icon'] as IconData,
                          color: isSelected ? Colors.white : Colors.white70,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          option['label'] as String,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
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
