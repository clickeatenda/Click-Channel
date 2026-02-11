import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:io'; // Moved here
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:media_kit/media_kit.dart';
import 'core/theme/app_colors.dart';
import 'core/api/api_client.dart';
import 'core/prefs.dart';
import 'core/http_overrides.dart'; // Moved here
import 'providers/auth_provider.dart';
import 'routes/app_routes.dart';
import 'core/config.dart';
import 'data/epg_service.dart';
import 'data/m3u_service.dart';
import 'data/tmdb_service.dart';
import 'data/favorites_service.dart';
import 'screens/splash_screen.dart';

/// Variáveis globais para compartilhar estado entre main e app
bool _hasPlaylist = false;
String? _savedPlaylistUrl;

void main() {
  // CRÍTICO: Inicializa o binding PRIMEIRO e chama runApp() IMEDIATAMENTE
  // Isso garante que a splash screen nativa seja substituída pelo Flutter o mais rápido possível
  WidgetsFlutterBinding.ensureInitialized();
  
  // FIX: Ignora erros de SSL globalmente
  HttpOverrides.global = MyHttpOverrides();
  
  // Inicializar MediaKit (síncrono, rápido)
  MediaKit.ensureInitialized();
  
  // Configurar UI mode (síncrono, rápido)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  // CRÍTICO: Inicia o app IMEDIATAMENTE com a splash screen
  // Todas as inicializações pesadas acontecem DENTRO da splash screen
  runApp(const ClickChannelBootstrap());
}

/// Widget de bootstrap que mostra splash e depois carrega o app principal
class ClickChannelBootstrap extends StatefulWidget {
  const ClickChannelBootstrap({super.key});

  @override
  State<ClickChannelBootstrap> createState() => _ClickChannelBootstrapState();
}

class _ClickChannelBootstrapState extends State<ClickChannelBootstrap> {
  bool _initialized = false;
  late ApiClient _apiClient;
  late AuthProvider _authProvider;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Load .env
      if (!kIsWeb) {
        try {
          await dotenv.load(fileName: '.env');
        } catch (_) {}
      }
      
      // Init API client and auth
      _apiClient = ApiClient();
      _authProvider = AuthProvider(_apiClient);
      
      // Init preferences
      await Prefs.init();
      
      // Init favorites
      await FavoritesService.init();
      
      // Load playlist from prefs
      _savedPlaylistUrl = await Config.loadPlaylistFromPrefs();
      _hasPlaylist = _savedPlaylistUrl != null && _savedPlaylistUrl!.isNotEmpty;
      
      if (_hasPlaylist) {
        final isReady = Prefs.isPlaylistReady();
        if (!isReady) {
          await Prefs.setPlaylistReady(true);
        }
      }
      
      // Verificação de primeira execução
      final isFirstRun = !await M3uService.hasInstallMarker() && !_hasPlaylist;
      
      if (isFirstRun) {
        for (int i = 0; i < 3; i++) {
          await Prefs.setPlaylistOverride(null);
          await Prefs.setPlaylistReady(false);
          Config.setPlaylistOverride(null);
        }
        M3uService.clearMemoryCache();
        await M3uService.clearAllCache(null);
        await EpgService.clearCache();
        await M3uService.writeInstallMarker();
      }
      
      if (!_hasPlaylist) {
        M3uService.clearMemoryCache();
        await M3uService.clearAllCache(null);
        await EpgService.clearCache();
      }
      
      if (_hasPlaylist && _savedPlaylistUrl != null) {
        Config.setPlaylistOverride(_savedPlaylistUrl);
      }
        
      // Inicializar TMDB Service
      TmdbService.init();
      
      // Iniciar carregamento em background (não bloqueia a splash screen por muito tempo)
      if (_hasPlaylist && _savedPlaylistUrl != null) {
        // 1. Tenta carregar meta-cache do disco primeiro (MUITO RÁPIDO) 
        // para que a Home tenha categorias imediatamente
        await M3uService.loadMetaCache(_savedPlaylistUrl!);
        
        // 2. Inicia o preload pesado (parse do arquivo) em background
        M3uService.preloadCategories(_savedPlaylistUrl!).catchError((_) {});
        EpgService.loadFromCache().catchError((_) {});
      }
      
      await _authProvider.initialize();
      
      // CRÍTICO: Espera no mínimo 5 segundos na splash para o vídeo de abertura
      // O vídeo tem 8 segundos, então 5 segundos é um bom mínimo
      await Future.delayed(const Duration(seconds: 5));
      
      if (mounted) {
        setState(() => _initialized = true);
      }
    } catch (e) {
      print('❌ Erro na inicialização: $e');
      if (mounted) {
        setState(() => _initialized = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      // Mostra nossa splash screen com vídeo enquanto inicializa
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: SplashScreen(
          onInit: () async {
            // Espera a inicialização terminar
            while (!_initialized && mounted) {
              await Future.delayed(const Duration(milliseconds: 100));
            }
          },
        ),
      );
    }

    // Determina rota inicial
    String initialRoute;
    final isReady = Prefs.isPlaylistReady();
    if (!_hasPlaylist) {
      initialRoute = AppRoutes.setup;
    } else if (_hasPlaylist && isReady) {
      initialRoute = AppRoutes.home;
    } else if (_authProvider.isAuthenticated) {
      initialRoute = AppRoutes.home;
    } else {
      initialRoute = AppRoutes.setup;
    }

    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: _apiClient),
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
      ],
      child: Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowUp): const DirectionalFocusIntent(TraversalDirection.up),
          LogicalKeySet(LogicalKeyboardKey.arrowDown): const DirectionalFocusIntent(TraversalDirection.down),
          LogicalKeySet(LogicalKeyboardKey.arrowLeft): const DirectionalFocusIntent(TraversalDirection.left),
          LogicalKeySet(LogicalKeyboardKey.arrowRight): const DirectionalFocusIntent(TraversalDirection.right),
        },
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Click Channel',
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: AppColors.backgroundDark,
            canvasColor: AppColors.backgroundDarker,
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              secondary: AppColors.accent,
              surface: AppColors.surface,
              error: AppColors.error,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.backgroundDark,
              elevation: 0,
              centerTitle: true,
            ),
          textTheme: const TextTheme(
            displayLarge: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.015,
            ),
            displayMedium: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.015,
            ),
            headlineSmall: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            titleLarge: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            bodyLarge: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
            bodyMedium: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
            labelSmall: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
          initialRoute: initialRoute,
          onGenerateRoute: AppRoutes.generateRoute,
        ),
      ),
    );
  }
}

/// Splash screen simples para o bootstrap
class _BootstrapSplash extends StatelessWidget {
  const _BootstrapSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
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
            const Text(
              'Streaming IPTV',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 60),
            
            // Loading indicator
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Inicializando...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}