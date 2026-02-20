import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';

/// Splash Screen com vídeo de abertura
/// IMPORTANTE: Esta splash é exibida pelo main.dart durante a inicialização.
/// O vídeo toca enquanto o app carrega. Quando o main.dart termina de carregar,
/// ele reconstrói e vai para a rota correta automaticamente.
class SplashScreen extends StatefulWidget {
  final Future<void> Function()? onInit;
  final String? nextRoute;
  
  const SplashScreen({super.key, this.onInit, this.nextRoute});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _controller;
  bool _videoReady = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
    
    // Executa onInit em background (não bloqueia o vídeo)
    if (widget.onInit != null) {
      widget.onInit!().catchError((_) {});
    }
  }
  
  Future<void> _initVideo() async {
    try {
      _controller = VideoPlayerController.asset('assets/videos/intro.mp4');
      
      await _controller!.initialize();
      
      if (mounted && _controller!.value.isInitialized) {
        _controller!.setVolume(0.5);
        _controller!.setLooping(true); // Loop enquanto carrega
        _controller!.play();
        
        setState(() => _videoReady = true);
      }
    } catch (e) {
      debugPrint('Erro no vídeo: $e');
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildContent(),
    );
  }
  
  Widget _buildContent() {
    // Se vídeo está pronto, mostra ele
    if (_videoReady && _controller != null && _controller!.value.isInitialized) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller!.value.size.width,
            height: _controller!.value.size.height,
            child: VideoPlayer(_controller!),
          ),
        ),
      );
    }
    
    // Fallback premium animado (ao invés de apenas um spinner)
    return Container(
      color: const Color(0xFF111318), // Deep Space Navy
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF135bec),
                    Color(0xFF38bdf8),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF135bec).withOpacity(0.6),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 60,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Click Channel',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.0,
              ),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                color: Color(0xFF38bdf8),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'STARTING ENGINE',
              style: TextStyle(
                color: Color(0xFF38bdf8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 4.0, 
              ),
            ),
          ],
        ),
      ),
    );
  }
}
