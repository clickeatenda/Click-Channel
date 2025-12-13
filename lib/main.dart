import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_colors.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Garante tela cheia e modo paisagem
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft, 
    DeviceOrientation.landscapeRight
  ]);
  runApp(const StreamXApp());
}

class StreamXApp extends StatelessWidget {
  const StreamXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ClickFlix',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(primary: AppColors.primary),
        // Define preto como cor padrão de fundo para evitar clarões
        canvasColor: Colors.black, 
      ),
      home: const SplashScreen(),
    );
  }
}

// --- TELA DE CARREGAMENTO PERSONALIZADA ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Aguarda 3 segundos e vai para a Home
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black, // Fundo Preto
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ícone Pulsando (opcional, aqui estático)
            Icon(Icons.movie_filter, size: 100, color: Colors.blueAccent),
            SizedBox(height: 30),
            
            // Spinner Azul
            SizedBox(
              width: 40, height: 40,
              child: CircularProgressIndicator(
                color: Colors.blueAccent,
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 20),
            
            // Texto Azul
            Text(
              "CARREGANDO...",
              style: TextStyle(
                color: Colors.blueAccent,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
                fontFamily: 'Roboto', // Fonte padrão segura
              ),
            ),
          ],
        ),
      ),
    );
  }
}