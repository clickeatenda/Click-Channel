import 'package:flutter/material.dart';
import 'dart:async';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../core/theme/app_colors.dart';
import '../data/m3u_service.dart';
import '../core/prefs.dart';
import '../core/config.dart';
import '../routes/app_routes.dart';

/// Tela de carregamento inicial do aplicativo
/// Exibida durante a inicialização para evitar tela em branco
class SplashScreen extends StatefulWidget {
  final Future<void> Function()? onInit;
  final String? nextRoute;
  
  const SplashScreen({
    super.key,
    this.onInit,
    this.nextRoute,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  // MediaKit Players
  late final Player _player;
  late final VideoController _videoController;
  
  bool _isVideoInitialized = false;
  bool _hasVideoError = false;
  
  String _statusMessage = 'Inicializando...';
  double _progress = 0.0;
  
  // Controle de conclusão
  bool _appInitDone = false;
  bool _videoDone = false;

  Future<void> _handleReset() async {
    setState(() => _statusMessage = "Resetando aplicativo...");
    
    // Limpar caches
    await M3uService.clearAllCache(null);
    await Prefs.setPlaylistOverride(null);
    Config.setPlaylistOverride(null);
    await Prefs.setPlaylistReady(false);
    
    // Matar player se estiver rodando
    try {
      if (_isVideoInitialized) {
        await _player.dispose();
      }
    } catch (_) {}
    
    if (mounted) {
       Navigator.of(context).pushReplacementNamed(AppRoutes.setup);
    }
  }

  @override
  void initState() {
    super.initState();
    
    // Configurar animações (Fallback)
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    
    _initializeVideo();
    _initializeApp();
  }

  Future<void> _initializeVideo() async {
    try {
      // Cria player do MediaKit
      _player = Player();
      _videoController = VideoController(_player);

      // Tenta carregar o vídeo de assets
      await _player.open(Media('asset:///assets/videos/intro.mp4'));
      await _player.setVolume(100.0);

      // Listener para erro e conclusão
      _player.stream.error.listen((error) {
         print('⚠️ SplashScreen: Erro no player: $error');
         if (mounted) {
            setState(() {
              _hasVideoError = true;
              _controller.forward();
            });
         }
      });
      
      _player.stream.completed.listen((completed) {
        if (completed && mounted) {
           _onVideoFinished();
        }
      });
      
      // Se carregou ok
       if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }

    } catch (e) {
      print('⚠️ SplashScreen: Erro ao carregar vídeo de intro (catch): $e');
      if (mounted) {
        setState(() {
          _hasVideoError = true;
          _controller.forward();
          try { _player.dispose(); } catch (_) {}
        });
      }
    }
  }

  void _onVideoFinished() {
    if (_videoDone) return;
    print('🎥 Video Intro finalizado.');
    _videoDone = true;
    _checkNavigation();
  }

  Future<void> _initializeApp() async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      _updateProgress(0.2, 'Carregando configurações...');
      
      if (widget.onInit != null) {
        await widget.onInit!();
      } else {
        await Future.delayed(const Duration(milliseconds: 800));
      }
      
      _updateProgress(1.0, 'Pronto!');
      
      _appInitDone = true;
      _checkNavigation();
      
    } catch (e) {
      print('Erro na inicialização: $e');
      _appInitDone = true; 
      _checkNavigation();
    }
  }

  void _checkNavigation() {
    bool videoReady = false;
    
    if (_hasVideoError) {
      videoReady = true;
    } else if (_isVideoInitialized) {
      videoReady = _videoDone;
    } else {
      // Still loading or waiting
    }
    
    if (_appInitDone && videoReady) {
       _navigateToNext();
    }
  }

  void _navigateToNext() {
      if (!mounted) return;
      
      if (widget.nextRoute != null) {
        Navigator.of(context).pushReplacementNamed(widget.nextRoute!);
      } else {
        Navigator.of(context).pop();
      }
  }

  void _updateProgress(double progress, String message) {
    if (mounted) {
      setState(() {
        _progress = progress;
        _statusMessage = message;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    try {
      if (_isVideoInitialized || _hasVideoError) {
        _player.dispose();
      }
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Se temos vídeo rodando, mostramos ele em tela cheia
    if (_isVideoInitialized && !_hasVideoError && !_videoDone) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Video(
            controller: _videoController,
            fit: BoxFit.contain, // Garante visibilidade em qualquer orientação
            controls: NoVideoControls,
          ),
        ),
      );
    }

    // Fallback UI (Logo) com botão Reset
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // Conteúdo Principal
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.backgroundDark,
                    AppColors.backgroundDark.withOpacity(0.8),
                    AppColors.background,
                  ],
                ),
              ),
              child: Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo do app
                        Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.5),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(32),
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: 250,
                              height: 250,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 250,
                                  height: 250,
                                  color: AppColors.primary,
                                  child: const Icon(Icons.play_circle_filled, size: 120, color: Colors.white),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        const Text(
                          'Click Channel',
                          style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 60),
                        SizedBox(
                          width: 40, 
                          height: 40,
                          child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.primary)),
                        ),
                        const SizedBox(height: 20),
                        Text(_statusMessage, style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Botão de Reset (Bypass) - Discreto e Seguro
          Positioned(
             bottom: 20,
             right: 20,
             child: SafeArea(
               child: TextButton.icon(
                 onPressed: _handleReset,
                 icon: const Icon(Icons.restore, color: Colors.white30, size: 16),
                 label: const Text("RESETAR APP", style: TextStyle(color: Colors.white30, fontSize: 10)),
                 style: TextButton.styleFrom(
                   backgroundColor: Colors.black26, 
                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                 ),
               ),
             ),
          ),
        ],
      ),
    );
  }
}

