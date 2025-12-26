import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/content_item.dart';
import '../data/watch_history_service.dart';
import '../data/epg_service.dart';
import '../models/epg_program.dart';

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
  });

  @override
  State<MediaPlayerScreen> createState() => _MediaPlayerScreenState();
}

class _MediaPlayerScreenState extends State<MediaPlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showControls = true;
  bool _showInfo = false;
  bool _showAudioOptions = false;
  bool _showSubtitleOptions = false;
  bool _showFitOptions = false;
  
  // Informações de mídia
  String _videoQuality = 'Carregando...';
  String _videoCodec = '';
  String _audioCodec = '';
  String _currentAudio = 'Padrão';
  String _currentSubtitle = 'Desativado';
  List<AudioTrack> _audioTracks = [];
  List<SubtitleTrack> _subtitleTracks = [];
  int _selectedAudioIndex = 0;
  int _selectedSubtitleIndex = -1;
  
  // EPG (para canais)
  EpgChannel? _epgChannel;
  EpgProgram? _currentEpgProgram;
  EpgProgram? _nextEpgProgram;
  
  // Opções de ajuste de tela
  BoxFit _videoFit = BoxFit.contain;
  int _fitIndex = 0;
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
  
  @override
  void initState() {
    super.initState();
    _initPlayer();
  }
  
  Future<void> _initPlayer() async {
    try {
      // Criar player com configurações otimizadas para 4K/HDR
      _player = Player(
        configuration: const PlayerConfiguration(
          bufferSize: 64 * 1024 * 1024, // 64MB buffer para 4K
        ),
      );
      
      _controller = VideoController(_player);
      
      // Listeners
      _player.stream.playing.listen((playing) {
        if (mounted) setState(() => _isPlaying = playing);
      });
      
      _player.stream.position.listen((position) {
        if (mounted) {
          setState(() => _position = position);
          _saveProgress();
        }
      });
      
      _player.stream.duration.listen((duration) {
        if (mounted) setState(() => _duration = duration);
      });
      
      _player.stream.buffering.listen((buffering) {
        if (mounted) setState(() => _isBuffering = buffering);
      });
      
      _player.stream.error.listen((error) {
        if (mounted && error.isNotEmpty) {
          setState(() {
            _hasError = true;
            _errorMessage = error;
          });
        }
      });
      
      // Listener para tracks de áudio
      _player.stream.tracks.listen((tracks) {
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
          });
        }
      });
      
      // Listener para track de áudio atual
      _player.stream.track.listen((track) {
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
      _player.stream.width.listen((width) => _updateVideoInfo());
      _player.stream.height.listen((height) => _updateVideoInfo());
      
      // Verificar posição salva
      final savedPosition = await WatchHistoryService.getSavedPosition(widget.url);
      
      // Carregar EPG se for canal
      if (widget.item != null && widget.item!.type == 'channel') {
        // CRÍTICO: Garante que EPG está carregado antes de buscar
        final epgUrl = EpgService.epgUrl;
        if (epgUrl != null && !EpgService.isLoaded) {
          try {
            await EpgService.loadEpg(epgUrl);
          } catch (e) {
            print('⚠️ Erro ao carregar EPG no player: $e');
          }
        }
        
        _epgChannel = EpgService.findChannelByName(widget.item!.title);
        if (_epgChannel != null) {
          _currentEpgProgram = _epgChannel!.currentProgram;
          _nextEpgProgram = _epgChannel!.nextProgram;
          print('✅ EPG carregado para canal "${widget.item!.title}": ${_currentEpgProgram?.title ?? "Sem programa"}');
          // CRÍTICO: Mostra painel de informações automaticamente para canais
          if (mounted) {
            setState(() {
              _showInfo = true; // Mostra painel automaticamente para canais
            });
          }
        } else {
          print('⚠️ EPG não encontrado para canal "${widget.item!.title}"');
          // Mesmo sem EPG, mostra painel para canais
          if (mounted) {
            setState(() {
              _showInfo = true;
            });
          }
        }
        if (mounted) setState(() {});
      }
      
      // Abrir mídia
      await _player.open(
        Media(
          widget.url,
          httpHeaders: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
        ),
      );
      
      // Seek para posição salva
      if (savedPosition != null && savedPosition.inSeconds > 0) {
        await _player.seek(savedPosition);
      }
      
      if (mounted) {
        setState(() => _isInitialized = true);
      }
      
      // Auto-hide controls após 5 segundos
      _startControlsTimer();
      
    } catch (e) {
      print('Erro ao inicializar player: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Falha ao carregar o vídeo: $e';
        });
      }
    }
  }
  
  void _updateVideoInfo() {
    final width = _player.state.width;
    final height = _player.state.height;
    
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
    _player.playOrPause();
  }
  
  void _seekForward() {
    final newPosition = _position + const Duration(seconds: 10);
    _player.seek(newPosition);
  }
  
  void _seekBackward() {
    final newPosition = _position - const Duration(seconds: 10);
    _player.seek(newPosition.isNegative ? Duration.zero : newPosition);
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
      _player.setAudioTrack(track);
      setState(() => _showAudioOptions = false);
      // O listener de track vai atualizar o estado
    }
  }
  
  void _setSubtitleTrack(int index) {
    if (index == -1) {
      print('📝 Desativando legendas');
      _player.setSubtitleTrack(SubtitleTrack.no());
      setState(() {
        _selectedSubtitleIndex = -1;
        _currentSubtitle = 'Desativado';
        _showSubtitleOptions = false;
      });
    } else if (index >= 0 && index < _subtitleTracks.length) {
      final track = _subtitleTracks[index];
      print('📝 Selecionando legenda: ${track.id} - ${track.title ?? track.language}');
      _player.setSubtitleTrack(track);
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
    _player.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
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
  
  Widget _buildPlayerView() {
    return GestureDetector(
      onTap: _toggleControls,
      child: Stack(
        children: [
          // Vídeo
          Center(
            child: _isInitialized
                ? Video(
                    controller: _controller,
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
    );
  }
  
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
            colors: [Colors.black.withOpacity(0.7), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
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
            // Botão de informações
            IconButton(
              icon: Icon(
                Icons.info_outline,
                color: _showInfo ? Colors.blueAccent : Colors.white,
              ),
              onPressed: () => setState(() {
                _showInfo = !_showInfo;
                _showAudioOptions = false;
                _showSubtitleOptions = false;
              }),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCenterControls() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Retroceder 10s
          IconButton(
            icon: const Icon(Icons.replay_10, color: Colors.white, size: 40),
            onPressed: _seekBackward,
          ),
          const SizedBox(width: 32),
          // Play/Pause
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 56,
              ),
              onPressed: _togglePlayPause,
            ),
          ),
          const SizedBox(width: 32),
          // Avançar 10s
          IconButton(
            icon: const Icon(Icons.forward_10, color: Colors.white, size: 40),
            onPressed: _seekForward,
          ),
        ],
      ),
    );
  }
  
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
            colors: [Colors.black.withOpacity(0.7), Colors.transparent],
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
                      _player.seek(Duration(seconds: value.toInt()));
                    },
                  ),
                ),
                Text(
                  _formatDuration(_duration),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Botões de opções
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Áudio
                _buildOptionButton(
                  icon: Icons.audiotrack,
                  label: _currentAudio,
                  onTap: () => setState(() {
                    _showAudioOptions = !_showAudioOptions;
                    _showSubtitleOptions = false;
                    _showFitOptions = false;
                    _showInfo = false;
                  }),
                  isActive: _showAudioOptions,
                ),
                // Legenda
                _buildOptionButton(
                  icon: Icons.subtitles,
                  label: _currentSubtitle,
                  onTap: () => setState(() {
                    _showSubtitleOptions = !_showSubtitleOptions;
                    _showAudioOptions = false;
                    _showFitOptions = false;
                    _showInfo = false;
                  }),
                  isActive: _showSubtitleOptions,
                ),
                // Ajuste de tela
                _buildOptionButton(
                  icon: _fitOptions[_fitIndex]['icon'] as IconData,
                  label: _fitOptions[_fitIndex]['label'] as String,
                  onTap: () => setState(() {
                    _showFitOptions = !_showFitOptions;
                    _showAudioOptions = false;
                    _showSubtitleOptions = false;
                    _showInfo = false;
                  }),
                  isActive: _showFitOptions,
                ),
                // Qualidade (info)
                _buildOptionButton(
                  icon: Icons.high_quality,
                  label: _videoQuality.split(' ').first,
                  onTap: () => setState(() {
                    _showInfo = !_showInfo;
                    _showAudioOptions = false;
                    _showSubtitleOptions = false;
                    _showFitOptions = false;
                  }),
                  isActive: _showInfo,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.blueAccent.withOpacity(0.3) : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? Colors.blueAccent : Colors.white, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.blueAccent : Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ),
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
            if (_subtitleTracks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Nenhuma legenda disponível', style: TextStyle(color: Colors.white70)),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _subtitleTracks.length,
                  itemBuilder: (context, index) {
                    final track = _subtitleTracks[index];
                    final title = track.title ?? track.language ?? 'Legenda ${index + 1}';
                    final isSelected = index == _selectedSubtitleIndex;
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
                      onTap: () => _setSubtitleTrack(index),
                    );
                  },
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
