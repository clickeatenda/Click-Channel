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
import 'routes/app_routes.dart';
import 'core/config.dart';
import 'data/epg_service.dart';
import 'data/m3u_service.dart';
import 'data/tmdb_service.dart';
import 'screens/splash_screen.dart';

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
  
  print('🔍 main: Verificando estado inicial...');
  print('   - Playlist salva: ${hasPlaylist ? "SIM" : "NÃO"}');
  if (hasPlaylist) {
    print('   - URL: ${savedPlaylistUrl!.substring(0, savedPlaylistUrl.length > 60 ? 60 : savedPlaylistUrl.length)}...');
  }
  
  // CRÍTICO: Verifica install marker ANTES de decidir se limpa dados
  final hasMarker = await M3uService.hasInstallMarker();
  print('   - Install marker: ${hasMarker ? "SIM" : "NÃO"}');
  
  // CRÍTICO: Verifica se há cache de disco
  final hasAnyCache = await M3uService.hasAnyCache();
  print('   - Cache de disco: ${hasAnyCache ? "SIM" : "NÃO"}');
  
  // CRÍTICO: SITUAÇÃO ANÔMALA - Tem cache mas não tem playlist
  // Isso indica cache antigo/corrupto que deve ser limpo
  if (hasAnyCache && !hasPlaylist) {
    print('🚨 main: SITUAÇÃO ANÔMALA detectada: Cache existe mas não há playlist salva!');
    print('   Isso indica cache antigo/corrupto. Limpando TUDO...');
    
    // Limpa TUDO para garantir estado limpo
    M3uService.clearMemoryCache();
    await M3uService.clearAllCache(null);
    await EpgService.clearCache();
    await Prefs.setPlaylistOverride(null);
    await Prefs.setPlaylistReady(false);
    Config.setPlaylistOverride(null);
    
    // Recria marker para não cair nessa situação novamente
    await M3uService.writeInstallMarker();
    
    print('✅ main: Cache anômalo limpo. App pronto para configuração limpa.');
  }
  
  // CRÍTICO: Se tem playlist salva, GARANTE que está marcada como pronta
  // Isso evita que o app solicite novamente a lista
  if (hasPlaylist) {
    final isReady = Prefs.isPlaylistReady();
    print('   - Playlist pronta: ${isReady ? "SIM" : "NÃO"}');
    if (!isReady) {
      print('⚠️ main: Playlist salva mas não marcada como pronta. Marcando como pronta...');
      await Prefs.setPlaylistReady(true);
    }
  }
  
  // CRÍTICO: Só considera primeira execução se NÃO houver playlist salva E NÃO houver marker
  // Se tem playlist salva OU marker, significa que já foi configurado antes
  final isFirstRun = !hasMarker && !hasPlaylist && !hasAnyCache;
  print('   - Primeira execução: ${isFirstRun ? "SIM (vai limpar tudo)" : "NÃO (mantém dados)"}');
  
  if (isFirstRun) {
    print('🚨 main: PRIMEIRA EXECUÇÃO detectada (sem marker, sem playlist, sem cache) - Limpando TODOS os dados...');
    
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
    print('✅ main: Install marker criado');
    
    print('✅ main: Primeira execução - App limpo e pronto para configuração');
  } else if (hasPlaylist) {
    // Tem playlist salva - cria marker se não existir
    if (!hasMarker) {
      print('ℹ️ main: Playlist encontrada mas sem marker - criando marker...');
      await M3uService.writeInstallMarker();
    }
  } else if (hasMarker && !hasPlaylist && !hasAnyCache) {
    // Tem marker mas não tem playlist nem cache - app foi usado mas playlist foi removida
    print('ℹ️ main: Marker existe mas não há playlist - usuário removeu configuração');
  }
  
  if (hasPlaylist) {
    print('✅ main: Playlist encontrada em Prefs: ${savedPlaylistUrl.substring(0, savedPlaylistUrl.length > 50 ? 50 : savedPlaylistUrl.length)}...');
    
    // SEMPRE define o override para garantir que seja usado
    Config.setPlaylistOverride(savedPlaylistUrl);
    
    // CRÍTICO: Sempre tenta (re)construir o cache em memória para garantir que
    // a lista de séries e categorias esteja disponível — mesmo que o cache
    // local não exista ou esteja desatualizado. preloadCategories possui
    // validações internas e não bloqueará a inicialização do app.
    print('📦 main: Iniciando (re)construção de categorias em background (preloadCategories)...');
    M3uService.preloadCategories(savedPlaylistUrl).then((_) {
      print('✅ main: Categorias pré-carregadas/reconstruídas com sucesso');
    }).catchError((e) {
      print('⚠️ main: Erro ao (re)pré-carregar categorias: $e');
      // Continua mesmo se preload falhar (não bloqueia app)
    });
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
  // Verifica se TMDB está configurado e loga status
  if (TmdbService.isConfigured) {
    print('✅ main: TMDB Service inicializado e configurado');
  } else {
    print('⚠️ main: TMDB Service NÃO está configurado - ratings não serão carregados');
  }
  
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
    // CRÍTICO: Se tem playlist E está marcada como pronta, vai direto para Home
    String initialRoute;
    final isReady = Prefs.isPlaylistReady();
    if (!hasPlaylist) {
        // Temporariamente pulamos a tela de setup inicial.
        // Ao invés de exigir a URL na primeira execução, abrimos as Configurações
        // para o usuário inserir a playlist manualmente via Settings.
        initialRoute = AppRoutes.settings;
    } else if (hasPlaylist && isReady) {
      // CRÍTICO: Se tem playlist e está pronta, vai direto para Home (não passa pelo Setup)
      initialRoute = AppRoutes.home;
    } else if (authProvider.isAuthenticated) {
      initialRoute = AppRoutes.home;
    } else {
      // Como temos playlist mas não está marcada como pronta, vai para Setup verificar cache
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
          // CRÍTICO: Usa SplashScreen como tela inicial, que depois navega para a rota correta
          home: SplashScreen(
            nextRoute: initialRoute,
            onInit: () async {
              // Se estamos abrindo Settings inicialmente (pular Setup),
              // garante que não haja caches antigos sendo usados.
              if (initialRoute == AppRoutes.settings) {
                try {
                  print('🧹 Splash onInit: Inicializando em modo Settings — limpando caches e resets...');
                  M3uService.clearMemoryCache();
                  await M3uService.clearAllCache(null);
                  await EpgService.clearCache();
                  await Prefs.setPlaylistOverride(null);
                  await Prefs.setPlaylistReady(false);
                  Config.setPlaylistOverride(null);
                  await M3uService.writeInstallMarker();
                  print('✅ Splash onInit: Limpeza concluída');
                } catch (e) {
                  print('⚠️ Splash onInit: Erro ao limpar caches para Settings: $e');
                }
              }

              // Pequeno delay para suavizar a transição
              await Future.delayed(const Duration(milliseconds: 500));
            },
          ),
          onGenerateRoute: AppRoutes.generateRoute,
        ),
      ),
    );
  }
}