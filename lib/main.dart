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
  
  // CRÍTICO: Se tem playlist salva, GARANTE que está marcada como pronta
  // Isso evita que o app solicite novamente a lista
  if (hasPlaylist) {
    final isReady = Prefs.isPlaylistReady();
    if (!isReady) {
      print('⚠️ main: Playlist salva mas não marcada como pronta. Marcando como pronta...');
      await Prefs.setPlaylistReady(true);
    }
  }
  
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
      
      // CRÍTICO: Pré-carrega categorias ANTES de continuar (não em background)
      // Isso garante que a lista M3U esteja disponível imediatamente quando o app abrir
      print('📦 main: Pré-carregando categorias do cache (aguardando conclusão)...');
      try {
        await M3uService.preloadCategories(savedPlaylistUrl);
        print('✅ main: Categorias pré-carregadas com sucesso do cache');
      } catch (e) {
        print('⚠️ main: Erro ao pré-carregar categorias: $e');
        // Continua mesmo se preload falhar (não bloqueia app)
      }
    } else {
      print('⚠️ main: Cache não encontrado ou inválido para playlist salva. Cache será recriado quando necessário.');
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
  
  // Inicializar TMDB Service (carrega de Prefs/Settings ou .env)
  TmdbService.init();
  if (TmdbService.isConfigured) {
    print('✅ main: TMDB Service inicializado e configurado');
  } else {
    print('⚠️ main: TMDB Service NÃO está configurado - ratings não serão carregados');
  }

  // CRÍTICO: Sempre tenta (re)construir o cache em memória para garantir que
  // a lista de séries e categorias esteja disponível — mesmo que o cache
  // local não exista ou esteja desatualizado. preloadCategories possui
  // validações internas e não bloqueará a inicialização do app.
  if (hasPlaylist) {
    print('📦 main: Iniciando (re)construção de categorias em background (preloadCategories)...');
    M3uService.preloadCategories(savedPlaylistUrl).then((_) {
      print('✅ main: Categorias pré-carregadas/reconstruídas com sucesso');
    }).catchError((e) {
      print('⚠️ main: Erro ao (re)pré-carregar categorias: $e');
      // Continua mesmo se preload falhar (não bloqueia app)
    });
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
      initialRoute = AppRoutes.setup;
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
              // Aqui pode adicionar qualquer inicialização adicional se necessário
              await Future.delayed(const Duration(milliseconds: 500));
            },
          ),
          onGenerateRoute: AppRoutes.generateRoute,
        ),
      ),
    );
  }
}