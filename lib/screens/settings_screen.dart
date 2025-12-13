import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("Configurações", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionTitle("Interface"),
          _buildSwitchTile("Modo Escuro Profundo", true),
          _buildSwitchTile("Autoplay no Destaque", true),
          
          const SizedBox(height: 30),
          _buildSectionTitle("Player"),
          _buildSwitchTile("Usar Player Nativo (ExoPlayer)", true),
          _buildSwitchTile("Aceleração de Hardware", true),

          const SizedBox(height: 30),
          _buildSectionTitle("Dados"),
          ListTile(
            title: const Text("Limpar Cache de Imagens", style: TextStyle(color: Colors.white)),
            leading: const Icon(Icons.delete_outline, color: Colors.white),
            onTap: () {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cache limpo!")));
            },
          ),
          const ListTile(
            title: Text("Sobre o StreamX", style: TextStyle(color: Colors.white)),
            subtitle: Text("Versão 1.0.2 - Beta", style: TextStyle(color: Colors.grey)),
            leading: Icon(Icons.info_outline, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: AppTypography.headlineMedium.copyWith(color: AppColors.primary)),
    );
  }

  Widget _buildSwitchTile(String title, bool value) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      value: value,
      activeThumbColor: AppColors.primary,
      onChanged: (val) {},
    );
  }
}