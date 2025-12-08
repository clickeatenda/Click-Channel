import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/services.dart';

class PlayerScreen extends StatefulWidget {
  final String url;
  const PlayerScreen({super.key, required this.url});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late VideoPlayerController _vc;
  ChewieController? _cc;
  bool _hasError = false;
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      // Conecta ao nosso PROXY LOCAL (Node.js)
      _vc = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await _vc.initialize();

      _cc = ChewieController(
        videoPlayerController: _vc,
        autoPlay: true,
        aspectRatio: 16 / 9,
        allowedScreenSleep: false,
        fullScreenByDefault: true,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 50),
                const SizedBox(height: 10),
                const Text("Erro ao reproduzir", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          );
        },
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = "Falha ao conectar.\nVerifique se o link da lista está ativo.";
        });
      }
      print("Erro Player: $e");
    }
  }

  @override
  void dispose() {
    _vc.dispose();
    _cc?.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _hasError ? AppBar(backgroundColor: Colors.transparent, leading: const BackButton(color: Colors.white)) : null,
      body: Center(
        child: _hasError
            ? Text(_errorMessage, style: const TextStyle(color: Colors.white))
            : _cc != null && _vc.value.isInitialized
                ? Chewie(controller: _cc!)
                : const CircularProgressIndicator(color: Colors.blueAccent),
      ),
    );
  }
}