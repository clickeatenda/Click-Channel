import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/services.dart';
import '../models/content_item.dart';
import '../data/watch_history_service.dart';

class PlayerScreen extends StatefulWidget {
  final String url;
  final ContentItem? item; // Opcional para rastrear histórico
  const PlayerScreen({super.key, required this.url, this.item});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late VideoPlayerController _vc;
  ChewieController? _cc;
  bool _hasError = false;
  String _errorMessage = "";
  Duration? _savedPosition;
  bool _isInitializing = true;
  bool _is4kContent = false;
  bool _showQualityWarning = false;

  @override
  void initState() {
    super.initState();
    // Detectar se é conteúdo 4K pelo item ou URL
    final itemQuality = widget.item?.quality;
    final quality = itemQuality?.toLowerCase() ?? '';
    _is4kContent = quality.contains('4k') || quality.contains('uhd') ||
                   widget.url.toLowerCase().contains('4k') ||
                   widget.url.toLowerCase().contains('uhd');
    _init();
  }

  Future<void> _init() async {
    try {
      setState(() {
        _isInitializing = true;
        _hasError = false;
      });
      
      // Verificar se há posição salva
      _savedPosition = await WatchHistoryService.getSavedPosition(widget.url);
      
      // Configurar o controller com opções otimizadas
      _vc = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
        httpHeaders: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );
      
      await _vc.initialize();
      
      // Seek para posição salva se existir
      if (_savedPosition != null && _savedPosition!.inSeconds > 0) {
        await _vc.seekTo(_savedPosition!);
      }

      _cc = ChewieController(
        videoPlayerController: _vc,
        autoPlay: true,
        aspectRatio: 16 / 9,
        allowedScreenSleep: false,
        fullScreenByDefault: true,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 50),
                const SizedBox(height: 10),
                const Text("Erro ao reproduzir", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          );
        },
      );
      
      // Listener para salvar progresso periodicamente
      _vc.addListener(_onVideoProgress);
      
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitializing = false;
          _errorMessage = "Falha ao conectar.\nVerifique se o link da lista está ativo.";
        });
      }
      print("Erro Player: $e");
    }
  }
  
  Future<void> _restart() async {
    // Reiniciar o player (pode ajudar com problemas de decodificação)
    _cc?.dispose();
    _vc.removeListener(_onVideoProgress);
    await _vc.dispose();
    _cc = null;
    await _init();
  }
  
  void _onVideoProgress() {
    // Salvar progresso a cada 10 segundos
    if (_vc.value.isPlaying && widget.item != null) {
      final position = _vc.value.position;
      final duration = _vc.value.duration;
      
      // Só salva se a duração é conhecida e a cada 10 segundos
      if (duration.inSeconds > 0 && position.inSeconds % 10 == 0) {
        WatchHistoryService.saveProgress(widget.item!, position, duration);
      }
    }
  }

  @override
  void dispose() {
    // Salvar progresso final ao sair
    if (widget.item != null && _vc.value.isInitialized) {
      final position = _vc.value.position;
      final duration = _vc.value.duration;
      if (duration.inSeconds > 0) {
        WatchHistoryService.saveProgress(widget.item!, position, duration);
      }
    }
    
    _vc.removeListener(_onVideoProgress);
    _vc.dispose();
    _cc?.dispose();
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
      appBar: _hasError 
          ? AppBar(backgroundColor: Colors.transparent, leading: const BackButton(color: Colors.white)) 
          : null,
      body: Stack(
        children: [
          Center(
            child: _hasError
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage, style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _restart,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  )
                : _cc != null && _vc.value.isInitialized
                    ? Chewie(controller: _cc!)
                    : const CircularProgressIndicator(color: Colors.blueAccent),
          ),
          // Aviso de qualidade 4K
          if (_is4kContent && _showQualityWarning)
            Positioned(
              bottom: 80,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.white),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Conteúdo 4K/HDR pode apresentar distorções em alguns dispositivos. Tente um conteúdo FHD se houver problemas.',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 18),
                      onPressed: () => setState(() => _showQualityWarning = false),
                    ),
                  ],
                ),
              ),
            ),
          // Botões de controle
          if (!_hasError && !_isInitializing && _cc != null)
            Positioned(
              top: 8,
              right: 8,
              child: SafeArea(
                child: Row(
                  children: [
                    if (_is4kContent)
                      IconButton(
                        icon: Icon(
                          _showQualityWarning ? Icons.warning : Icons.warning_amber_outlined,
                          color: _showQualityWarning ? Colors.orange : Colors.white70,
                          size: 24,
                        ),
                        tooltip: 'Aviso de qualidade',
                        onPressed: () => setState(() => _showQualityWarning = !_showQualityWarning),
                      ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white70, size: 24),
                      tooltip: 'Reiniciar reprodução',
                      onPressed: _restart,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}