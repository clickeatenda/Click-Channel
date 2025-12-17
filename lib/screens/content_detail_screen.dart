import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';
import '../models/content_item.dart';
import '../widgets/media_player_screen.dart';
import '../widgets/meta_chips_widget.dart';

/// Tela genérica de detalhes para qualquer tipo de conteúdo (filmes, séries, canais)
class ContentDetailScreen extends StatelessWidget {
  final ContentItem item;
  final String? contentType; // 'movie', 'channel', 'live'

  const ContentDetailScreen({
    super.key,
    required this.item,
    this.contentType,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MetaChipsWidget(item: item),
                  const SizedBox(height: 24),
                  _buildPlayButton(context),
                  const SizedBox(height: 32),
                  _buildInfoSection(),
                  const SizedBox(height: 32),
                  _buildDetailsBox(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 250,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withOpacity(0.7), AppColors.background],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          if (item.image.isNotEmpty)
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: item.image,
                fit: BoxFit.cover,
                errorWidget: (c, u, e) => Container(),
              ),
            ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.4)),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Text(
              item.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => MediaPlayerScreen(url: item.url, item: item)),
          );
        },
        icon: const Icon(Icons.play_arrow),
        label: Text(
          contentType == 'channel' ? 'ASSISTIR AGORA' : 'REPRODUZIR',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    final typeLabel = contentType == 'channel' ? 'Canal' : contentType == 'movie' ? 'Filme' : 'Conteúdo';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sobre',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          '$typeLabel em ${item.quality.toUpperCase()} ${item.audioType.isNotEmpty ? '• ${item.audioType.toUpperCase()}' : ''}',
          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.6),
        ),
      ],
    );
  }

  Widget _buildDetailsBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          _buildDetailRow('Qualidade', item.quality.toUpperCase()),
          if (item.audioType.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildDetailRow('Áudio', item.audioType.toUpperCase()),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _buildDetailRow('Avaliação', '★ 4.8'),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _buildDetailRow('Categoria', item.group),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
