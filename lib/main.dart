import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:media_kit/media_kit.dart';
import 'core/theme/app_colors.dart';
import 'core/api/api_client.dart';
import 'core/prefs.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'routes/app_routes.dart';
import 'core/config.dart';
import 'data/epg_service.dart';
import 'data/m3u_service.dart';
import 'data/tmdb_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar MediaKit para player de vídeo avançado
  MediaKit.ensureInitialized();
  
  // Only load .env for non-web platforms
  if (!kIsWeb) {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // ignore - will use fallback values from Config
    }
  }
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  // Permitir todas as orientações (portrait e landscape)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  // Inicializar autenticação
  final apiClient = ApiClient();
  final authProvider = AuthProvider(apiClient);
  // Init preferences and handle saved playlist override
  await Prefs.init();

  // VERIFICAÇÃO: Verifica se há playlist salva PRIMEIRO
  // Se houver playlist salva, NÃO é primeira execução (mesmo sem marker)
  final savedPlaylistUrl = await Config.loadPlaylistFromPrefs();
  final hasPlaylist = savedPlaylistUrl != null && savedPlaylistUrl.isNotEmpty;
  
  // CRÍTICO: Só considera primeira execução se NÃO houver playlist salva
  // Se tem playlist salva, significa que já foi configurado antes
  final isFirstRun = !await M3uService.hasInstallMarker() && !hasPlaylist;
  
  if (isFirstRun) {
    print('🚨 main: PRIMEIRA EXECUÇÃO detectada (sem marker e sem playlist) - Limpando TODOS os dados e caches...');
    
    // CRÍTICO: Limpa TODOS os dados persistentes (múltiplas vezes para garantir)
    for (int i = 0; i < 3; i++) {
      await Prefs.setPlaylistOverride(null);
      await Prefs.setPlaylistReady(false);
      Config.setPlaylistOverride(null);
    }
    
    // Limpa TODOS os caches (memória e disco) - SEMPRE na primeira execução
    M3uService.clearMemoryCache();
    await M3uService.clearAllCache(null);
    await EpgService.clearCache();
    
    // Cria install marker para marcar que não é mais primeira execução
    await M3uService.writeInstallMarker();
    
    // CRÍTICO: Verifica e limpa qualquer dado restaurado do backup do Android (múltiplas vezes)
    for (int i = 0; i < 3; i++) {
      final verifyNoUrl = Prefs.getPlaylistOverride();
      if (verifyNoUrl != null && verifyNoUrl.isNotEmpty) {
        print('⚠️ main: Dados restaurados detectados (tentativa ${i + 1})! Limpando...');
        await Prefs.setPlaylistOverride(null);
        await Prefs.setPlaylistReady(false);
        Config.setPlaylistOverride(null);
        // Pequeno delay para garantir que a escrita foi persistida
        await Future.delayed(const Duration(milliseconds: 100));
      } else {
        break; // Se já está limpo, para o loop
      }
    }
    
    // Verificação final
    final finalCheck = Prefs.getPlaylistOverride();
    if (finalCheck != null && finalCheck.isNotEmpty) {
      print('❌ main: ERRO CRÍTICO: Não foi possível limpar playlist restaurada!');
      print('   URL restaurada: ${finalCheck.substring(0, finalCheck.length > 50 ? 50 : finalCheck.length)}');
    } else {
      print('✅ main: Primeira execução - App limpo e pronto para configuração');
    }
  } else if (hasPlaylist) {
    // Tem playlist salva mas não tem marker - cria marker para manter consistência
    final hasMarker = await M3uService.hasInstallMarker();
    if (!hasMarker) {
      print('ℹ️ main: Playlist encontrada mas sem marker - criando marker...');
      await M3uService.writeInstallMarker();
    }
  }
  
  if (!hasPlaylist) {
    // SEM PLAYLIST CONFIGURADA - LIMPA TUDO SEMPRE
    print('🚨 main: SEM PLAYLIST CONFIGURADA - Limpando TODOS os dados e caches...');
    
    // Limpa TODOS os caches (memória e disco) - SEMPRE
    M3uService.clearMemoryCache();
    await M3uService.clearAllCache(null);
    await EpgService.clearCache();
    
    print('✅ main: App limpo - SEM playlist configurada');
  }
  
  if (hasPlaylist) {
    print('✅ main: Playlist encontrada em Prefs: ${savedPlaylistUrl.substring(0, savedPlaylistUrl.length > 50 ? 50 : savedPlaylistUrl.length)}...');
    
    // SEMPRE define o override para garantir que seja usado
    Config.setPlaylistOverride(savedPlaylistUrl);
    
    // CRÍTICO: Verifica se cache existe E corresponde à URL salva
    final hasCache = await M3uService.hasCachedPlaylist(savedPlaylistUrl);
    if (hasCache) {
      print('✅ main: Cache encontrado para playlist salva. Usando cache permanente.');
    } else {
      print('⚠️ main: Cache não encontrado para playlist salva. Cache será recriado quando necessário.');
      // Limpa qualquer cache antigo que possa estar causando confusão
      print('🧹 main: Limpando caches antigos para evitar conflitos...');
      await M3uService.clearAllCache(savedPlaylistUrl);
    }
    
    // GARANTE que a URL está salva corretamente (tripla verificação)
    final verifyUrl1 = Prefs.getPlaylistOverride();
    if (verifyUrl1 != savedPlaylistUrl) {
      print('⚠️ main: Inconsistência detectada! Re-salvando URL...');
      await Prefs.setPlaylistOverride(savedPlaylistUrl);
      Config.setPlaylistOverride(savedPlaylistUrl);
      // Verifica novamente
      final verifyUrl2 = Prefs.getPlaylistOverride();
      if (verifyUrl2 != savedPlaylistUrl) {
        print('❌ main: ERRO CRÍTICO: Não foi possível salvar URL em Prefs!');
      } else {
        print('✅ main: URL re-salva com sucesso!');
      }
    }
  } else {
    print('ℹ️ main: Nenhuma playlist salva encontrada. Usuário precisa configurar via Setup.');
    // Se não tem playlist mas tem cache, limpa cache antigo
    final hasAnyCache = await M3uService.hasAnyCache();
    if (hasAnyCache) {
      print('🧹 main: Cache antigo detectado sem playlist salva. Limpando...');
      await M3uService.clearAllCache(null);
    }
  }
  
  // Carregar EPG do cache em background (APENAS se houver playlist configurada)
  // SEM playlist, EPG não deve ser carregado
  if (hasPlaylist) {
    EpgService.loadFromCache().then((loaded) {
      if (loaded && EpgService.isLoaded) {
        print('📺 EPG carregado do cache: ${EpgService.getAllChannels().length} canais');
      } else {
        // Se não tem cache, verifica se há URL salva para carregar
        final epgUrl = EpgService.epgUrl;
        if (epgUrl != null && epgUrl.isNotEmpty) {
          print('📺 EPG: URL encontrada, carregando automaticamente...');
          EpgService.loadEpg(epgUrl).then((_) {
            if (EpgService.isLoaded) {
              print('✅ EPG carregado automaticamente: ${EpgService.getAllChannels().length} canais');
            }
          }).catchError((e) {
            print('⚠️ EPG: Erro ao carregar automaticamente: $e');
          });
        } else {
          print('ℹ️ EPG: Nenhuma URL configurada. Configure via Settings.');
        }
      }
    });
  } else {
    print('ℹ️ EPG: Sem playlist configurada - EPG não será carregado');
    // Limpa cache de EPG também
    await EpgService.clearCache();
  }

  // Inicializar TMDB Service
  TmdbService.init();
  
  await authProvider.initialize();
  
  runApp(ClickChannelApp(
    authProvider: authProvider,
    apiClient: apiClient,
    hasPlaylist: hasPlaylist,
  ));
}

class ClickChannelApp extends StatelessWidget {
  final AuthProvider authProvider;
  final ApiClient apiClient;
  final bool hasPlaylist;
  
  const ClickChannelApp({
    required this.authProvider,
    required this.apiClient,
    required this.hasPlaylist,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Determina rota inicial: Setup se não tem playlist, senão Home/Login
    String initialRoute;
    if (!hasPlaylist) {
      initialRoute = AppRoutes.setup;
    } else if (authProvider.isAuthenticated) {
      initialRoute = AppRoutes.home;
    } else {
      // Como temos playlist mas FRONT_ONLY é true, vai direto para Setup verificar cache
      initialRoute = AppRoutes.setup;
    }

    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: apiClient),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
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

// --- SPLASH SCREEN ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 800),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 0.8 + (value * 0.2),
                  child: Opacity(
                    opacity: value,
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
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.primary,
                                  AppColors.primary.withOpacity(0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Icon(Icons.live_tv, color: Colors.white, size: 64),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Click Channel',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'CARREGANDO...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}