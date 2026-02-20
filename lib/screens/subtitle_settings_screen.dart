import 'package:flutter/material.dart';
import '../core/subtitle_preferences.dart';

/// Tela de configurações de legendas
class SubtitleSettingsScreen extends StatefulWidget {
  const SubtitleSettingsScreen({super.key});

  @override
  State<SubtitleSettingsScreen> createState() => _SubtitleSettingsScreenState();
}

class _SubtitleSettingsScreenState extends State<SubtitleSettingsScreen> {
  Color _subtitleColor = Colors.white;
  double _backgroundOpacity = 0.7;
  double _fontSize = 18.0;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final color = await SubtitlePreferences.getSubtitleColor();
    final opacity = await SubtitlePreferences.getBackgroundOpacity();
    final size = await SubtitlePreferences.getFontSize();

    setState(() {
      _subtitleColor = color;
      _backgroundOpacity = opacity;
      _fontSize = size;
    });
  }

  Future<void> _savePreferences() async {
    await SubtitlePreferences.setSubtitleColor(_subtitleColor);
    await SubtitlePreferences.setBackgroundOpacity(_backgroundOpacity);
    await SubtitlePreferences.setFontSize(_fontSize);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferências salvas!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Configurações de Legendas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            onPressed: () async {
              await SubtitlePreferences.resetToDefaults();
              _loadPreferences();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Preview da legenda
          Card(
            color: Colors.black54,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(_backgroundOpacity),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Exemplo de Legenda',
                    style: TextStyle(
                      color: _subtitleColor,
                      fontSize: _fontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Cor da legenda
          _buildSection(
            'Cor da Legenda',
            Icons.palette,
            Column(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildColorOption(Colors.white, 'Branco'),
                    _buildColorOption(Colors.yellow, 'Amarelo'),
                    _buildColorOption(Colors.cyan, 'Ciano'),
                    _buildColorOption(Colors.green, 'Verde'),
                    _buildColorOption(Colors.red, 'Vermelho'),
                    _buildColorOption(Colors.blue, 'Azul'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Opacidade do fundo
          _buildSection(
            'Opacidade do Fundo',
            Icons.opacity,
            Column(
              children: [
                Slider(
                  value: _backgroundOpacity,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  label: '${(_backgroundOpacity * 100).toInt()}%',
                  onChanged: (value) {
                    setState(() {
                      _backgroundOpacity = value;
                    });
                  },
                ),
                Text(
                  'Opacidade: ${(_backgroundOpacity * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tamanho da fonte
          _buildSection(
            'Tamanho da Fonte',
            Icons.text_fields,
            Column(
              children: [
                Slider(
                  value: _fontSize,
                  min: 12.0,
                  max: 32.0,
                  divisions: 20,
                  label: '${_fontSize.toInt()}pt',
                  onChanged: (value) {
                    setState(() {
                      _fontSize = value;
                    });
                  },
                ),
                Text(
                  'Tamanho: ${_fontSize.toInt()}pt',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Botão Salvar
          ElevatedButton.icon(
            onPressed: _savePreferences,
            icon: const Icon(Icons.save),
            label: const Text('Salvar Preferências'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Widget child) {
    return Card(
      color: const Color(0xFF1A1A1A),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildColorOption(Color color, String label) {
    final isSelected = _subtitleColor.value == color.value;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _subtitleColor = color;
        });
      },
      child: Container(
        width: 80,
        height: 60,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(
            color: isSelected ? Colors.red : Colors.white24,
            width: isSelected ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSelected)
              const Icon(Icons.check, color: Colors.black),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
