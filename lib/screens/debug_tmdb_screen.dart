import 'package:flutter/material.dart';
import '../utils/tmdb_test_helper.dart';

/// Tela de debug para testar enriquecimento TMDB
class DebugTmdbScreen extends StatefulWidget {
  const DebugTmdbScreen({super.key});

  @override
  State<DebugTmdbScreen> createState() => _DebugTmdbScreenState();
}

class _DebugTmdbScreenState extends State<DebugTmdbScreen> {
  final _controller = TextEditingController();
  bool _testing = false;
  String _result = '';

  Future<void> _testTitle() async {
    if (_controller.text.isEmpty) return;
    
    setState(() {
      _testing = true;
      _result = 'Testando "${_controller.text}"...\nVerifique os logs do logcat';
    });
    
    try {
      await TmdbTestHelper.testTitles([_controller.text.trim()]);
      setState(() {
        _result = 'Teste concluído!\nVerifique os logs detalhados no logcat';
        _testing = false;
      });
    } catch (e) {
      setState(() {
        _result = 'Erro: $e';
        _testing = false;
      });
    }
  }

  Future<void> _testProblematicTitles() async {
    setState(() {
      _testing = true;
      _result = 'Testando ${TmdbTestHelper.problematicTitles.length} títulos problemáticos...\nVerifique os logs do logcat';
    });
    
    try {
      await TmdbTestHelper.testProblematicTitles();
      setState(() {
        _result = 'Teste de ${TmdbTestHelper.problematicTitles.length} títulos concluído!\nVerifique os logs detalhados no logcat';
        _testing = false;
      });
    } catch (e) {
      setState(() {
        _result = 'Erro: $e';
        _testing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug TMDB'),
        backgroundColor: Colors.black,
      ),
      body: Container(
        color: Colors.black,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Teste de Enriquecimento TMDB',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Título para testar',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white30),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _testing ? null : _testTitle,
              child: _testing
                  ? const CircularProgressIndicator()
                  : const Text('Testar Título'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _testing ? null : _testProblematicTitles,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              child: _testing
                  ? const CircularProgressIndicator()
                  : Text('Testar ${TmdbTestHelper.problematicTitles.length} Títulos Problemáticos'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _result.isEmpty
                        ? 'Digite um título e clique em "Testar Título"\nou teste os títulos problemáticos encontrados nos logs.\n\nOs resultados detalhados aparecerão no logcat.'
                        : _result,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '💡 Dica: Execute o script verificar_logs_tmdb_firestick.bat ou verificar_logs_tmdb_tablet.bat para ver os logs detalhados',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

