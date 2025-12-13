import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_colors.dart';
import 'core/api/api_client.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'routes/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Inicializar autenticação
  final apiClient = ApiClient();
  final authProvider = AuthProvider(apiClient);
  await authProvider.initialize();
  
  runApp(ClickFlixApp(authProvider: authProvider, apiClient: apiClient));
}

class ClickFlixApp extends StatelessWidget {
  final AuthProvider authProvider;
  final ApiClient apiClient;
  
  const ClickFlixApp({
    required this.authProvider,
    required this.apiClient,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: apiClient),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'ClickFlix',
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
        initialRoute: authProvider.isAuthenticated ? AppRoutes.home : AppRoutes.login,
        onGenerateRoute: AppRoutes.generateRoute,
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
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 30,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.movie,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                );
              },
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