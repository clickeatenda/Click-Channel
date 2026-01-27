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
    
    // Enquanto carrega ou se deu erro, mostra tela preta com loading
    return const Center(
      child: CircularProgressIndicator(
        color: Colors.white,
        strokeWidth: 2,
      ),
    );
  }
}
