import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

// --- CONFIGURAÇÃO ---
// Confirme se este IP é o do seu PC/NUC na rede local
const String SERVER_IP = "192.168.3.251"; 
const String BACKEND_URL = "http://$SERVER_IP:4000"; 

enum MediaType { movie, series, liveTv }

class MediaItem {
  final String id;
  final String title;
  final String url;
  final String group;
  final String logo;
  final MediaType type;

  MediaItem({
    required this.id, required this.title, required this.url,
    required this.group, required this.logo, required this.type,
  });
}

class ApiService {
  static Future<List<MediaItem>> fetchPlaylist() async {
    try {
      print("Tentando conectar em: $BACKEND_URL/api/playlist/check");
      final check = await http.get(Uri.parse('$BACKEND_URL/api/playlist/check')).timeout(const Duration(seconds: 5));
      
      if (check.statusCode != 200) {
        print("Erro Check: ${check.statusCode}");
        return [];
      }
      
      var body = jsonDecode(check.body);
      if (body['exists'] != true) return [];

      print("Baixando lista...");
      final response = await http.get(Uri.parse('$BACKEND_URL/api/playlist/content'));
      if (response.statusCode == 200) {
        return _parseM3U(response.body);
      }
    } catch (e) {
      print("ERRO FATAL DE CONEXÃO: $e");
    }
    return [];
  }

  static List<MediaItem> _parseM3U(String content) {
    final List<MediaItem> items = [];
    final lines = LineSplitter.split(content).toList();
    
    String currentName = "";
    String currentGroup = "Geral";
    String currentLogo = "";

    final regexLogo = RegExp(r'tvg-logo="([^"]*)"', caseSensitive: false);
    final regexGroup = RegExp(r'group-title="([^"]*)"', caseSensitive: false);
    final regexName = RegExp(r',([^\n\r]*)$');

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        var matchName = regexName.firstMatch(line);
        if (matchName != null) currentName = matchName.group(1)?.trim() ?? "";
        
        var matchLogo = regexLogo.firstMatch(line);
        if (matchLogo != null) currentLogo = matchLogo.group(1) ?? "";
        
        var matchGroup = regexGroup.firstMatch(line);
        if (matchGroup != null) currentGroup = matchGroup.group(1) ?? "Geral";
      } else if (!line.startsWith('#')) {
        MediaType type = MediaType.movie;
        String upperGroup = currentGroup.toUpperCase();
        
        if (upperGroup.contains('TV') || upperGroup.contains('CANAIS')) type = MediaType.liveTv;
        if (upperGroup.contains('SERIE') || upperGroup.contains('SEASON')) type = MediaType.series;

        String proxyUrl = '$BACKEND_URL/stream?url=${Uri.encodeComponent(line)}';

        items.add(MediaItem(
          id: items.length.toString(),
          title: currentName.isEmpty ? "Sem Nome" : currentName,
          url: proxyUrl,
          group: currentGroup,
          logo: currentLogo.isNotEmpty ? currentLogo : '',
          type: type,
        ));
      }
    }
    return items;
  }
}

void main() {
  runApp(const StreamFlowApp());
}

class StreamFlowApp extends StatelessWidget {
  const StreamFlowApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClickFlix',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF141414),
        primaryColor: Colors.red,
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme).apply(bodyColor: Colors.white),
      ),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<MediaItem> liveTv = [];
  List<MediaItem> movies = [];
  List<MediaItem> series = [];
  MediaItem? featuredItem;
  bool loading = true;
  String? errorMsg;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final items = await ApiService.fetchPlaylist();
    
    if (mounted) {
      setState(() {
        if (items.isEmpty) {
          errorMsg = "Não foi possível conectar ao servidor ou lista vazia.\nVerifique se o backend está rodando.";
          loading = false;
          return;
        }

        liveTv = items.where((i) => i.type == MediaType.liveTv).take(20).toList();
        movies = items.where((i) => i.type == MediaType.movie).take(20).toList();
        series = items.where((i) => i.type == MediaType.series).take(20).toList();
        
        if (movies.isNotEmpty) featuredItem = movies.first;
        else if (liveTv.isNotEmpty) featuredItem = liveTv.first;
        
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.red)));
    
    if (errorMsg != null) return Scaffold(
      body: Center(child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 50, color: Colors.red),
            const SizedBox(height: 20),
            Text(errorMsg!, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () { setState(() { loading = true; errorMsg = null; }); _loadData(); }, child: const Text("Tentar Novamente"))
          ],
        ),
      ))
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 400.0, // Altura fixa segura
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(featuredItem?.title ?? "ClickFlix", 
                  style: const TextStyle(shadows: [Shadow(color: Colors.black, blurRadius: 10)])),
              background: _buildHeroBackground(),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 10),
                if (featuredItem != null)
                  ElevatedButton.icon(
                    onPressed: () => _playVideo(context, featuredItem!),
                    icon: const Icon(Icons.play_arrow, color: Colors.black),
                    label: const Text("ASSISTIR AGORA", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12)),
                  ),
                if (liveTv.isNotEmpty) _buildCategoryRow(context, "Canais Ao Vivo", liveTv, isLive: true),
                if (movies.isNotEmpty) _buildCategoryRow(context, "Filmes em Alta", movies),
                if (series.isNotEmpty) _buildCategoryRow(context, "Séries", series),
                const SizedBox(height: 50),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHeroBackground() {
    if (featuredItem == null) return Container(color: Colors.black);
    return Stack(
      fit: StackFit.expand,
      children: [
        featuredItem!.logo.isNotEmpty 
          ? CachedNetworkImage(imageUrl: featuredItem!.logo, fit: BoxFit.cover)
          : Container(color: Colors.grey[900]),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0xFF141414)],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryRow(BuildContext context, String title, List<MediaItem> items, {bool isLive = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: isLive ? 100 : 160,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_,__) => const SizedBox(width: 10),
            itemBuilder: (ctx, i) {
              final item = items[i];
              return GestureDetector(
                onTap: () => _playVideo(context, item),
                child: AspectRatio(
                  aspectRatio: isLive ? 16/9 : 2/3, // Canais wide, Filmes poster
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[800],
                      image: item.logo.isNotEmpty ? DecorationImage(
                        image: CachedNetworkImageProvider(item.logo),
                        fit: BoxFit.cover,
                      ) : null,
                    ),
                    child: item.logo.isEmpty ? const Center(child: Icon(Icons.tv)) : null,
                  ),
                ),
              );
            },
          ),
        )
      ],
    );
  }

  void _playVideo(BuildContext context, MediaItem item) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(url: item.url, title: item.title)));
  }
}

// --- PLAYER COM LOGS DETALHADOS ---
class PlayerScreen extends StatefulWidget {
  final String url;
  final String title;
  const PlayerScreen({super.key, required this.url, required this.title});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late VideoPlayerController _vc;
  ChewieController? _cc;
  String? error;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    _init();
  }

  Future<void> _init() async {
    print("PLAYER: Tentando abrir: ${widget.url}");
    
    _vc = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      // User-Agent igual ao que funcionou no Backend
      httpHeaders: {'User-Agent': 'okhttp/4.9.0'}, 
    );

    try {
      await _vc.initialize();
      print("PLAYER: Inicializado com sucesso!");
      
      _cc = ChewieController(
        videoPlayerController: _vc,
        autoPlay: true,
        looping: false,
        aspectRatio: 16/9,
        errorBuilder: (context, errorMessage) {
            print("PLAYER ERRO INTERNO: $errorMessage");
            return Center(child: Text("Erro: $errorMessage", style: const TextStyle(color: Colors.white)));
        }
      );
      if (mounted) setState(() {});
    } catch (e) {
      print("PLAYER ERRO FATAL: $e");
      if (mounted) setState(() { error = e.toString(); });
    }
  }

  @override
  void dispose() {
    _vc.dispose();
    _cc?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: error != null 
          ? Text("Falha ao carregar: $error", style: const TextStyle(color: Colors.red))
          : _cc != null && _cc!.videoPlayerController.value.isInitialized
              ? Chewie(controller: _cc!)
              : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.red),
                    SizedBox(height: 10),
                    Text("Carregando Stream...", style: TextStyle(color: Colors.white54))
                  ],
                ),
      ),
    );
  }
}