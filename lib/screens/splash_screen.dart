import 'package:flutter/material.dart';
import 'dart:async';
import '../core/theme/app_colors.dart';

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
  String _statusMessage = 'Inicializando...';
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    
    // Configurar animações
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
    
    _controller.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // CRÍTICO: Reduz delays artificiais para melhorar tempo de abertura
      // Total: ~500ms vs. ~1400ms anterior
      _updateProgress(0.2, 'Carregando configurações...');
      await Future.delayed(const Duration(milliseconds: 100));
      
      _updateProgress(0.4, 'Verificando playlist...');
      await Future.delayed(const Duration(milliseconds: 100));
      
      _updateProgress(0.6, 'Carregando dados...');
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Executa inicialização real se fornecida
      if (widget.onInit != null) {
        _updateProgress(0.8, 'Preparando conteúdo...');
        await widget.onInit!();
      }
      
      _updateProgress(1.0, 'Pronto!');
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Navega para próxima tela
      if (mounted && widget.nextRoute != null) {
        Navigator.of(context).pushReplacementNamed(widget.nextRoute!);
      } else if (mounted) {
        // Se não tem rota específica, apenas remove a splash
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        _updateProgress(1.0, 'Erro ao inicializar');
        await Future.delayed(const Duration(milliseconds: 500));
        // Mesmo com erro, tenta navegar
        if (widget.nextRoute != null) {
          Navigator.of(context).pushReplacementNamed(widget.nextRoute!);
        } else {
          Navigator.of(context).pop();
        }
      }
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Container(
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
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback se logo não existir
                          return Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Icon(
                              Icons.play_circle_filled,
                              size: 80,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Nome do app
                  const Text(
                    'Click Channel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Streaming IPTV',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 60),
                  
                  // Barra de progresso
                  Container(
                    width: 300,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _progress,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primary.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Mensagem de status
                  Text(
                    _statusMessage,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Indicador de carregamento animado
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      strokeWidth: 3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

