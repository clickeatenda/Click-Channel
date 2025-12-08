import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../models/content_item.dart';
import '../models/series_details.dart';
import '../data/api_service.dart';
import '../widgets/player_screen.dart';

class SeriesDetailScreen extends StatefulWidget {
  final ContentItem item;
  const SeriesDetailScreen({super.key, required this.item});

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  SeriesDetails? details;
  bool loading = true;
  String? selectedSeason;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final d = await ApiService.fetchSeriesDetails(widget.item.id);
    if (mounted) {
      setState(() {
        details = d;
        if (d != null && d.seasons.isNotEmpty) {
          var keys = d.seasons.keys.toList();
          // Ordenação numérica inteligente das temporadas
          keys.sort((a, b) {
            int na = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            int nb = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            return na.compareTo(nb);
          });
          selectedSeason = keys.first;
        }
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(backgroundColor: AppColors.background, body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    if (details == null) return const Scaffold(backgroundColor: AppColors.background, body: Center(child: Text("Série indisponível", style: TextStyle(color: Colors.white))));

    // Ordenação da lista para exibição
    final sortedSeasons = details!.seasons.keys.toList();
    sortedSeasons.sort((a, b) {
      int na = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      int nb = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return na.compareTo(nb);
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // === COLUNA ESQUERDA (30% da tela) ===
          Container(
            width: 320,
            color: const Color(0xFF121212), // Fundo levemente mais claro
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Botão Voltar
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                    focusColor: AppColors.primary,
                  ),
                ),
                
                // Capa
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 20),
                  height: 250,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: widget.item.image.isNotEmpty
                        ? CachedNetworkImage(imageUrl: widget.item.image, fit: BoxFit.cover)
                        : Container(color: Colors.grey[800], child: const Icon(Icons.tv, size: 50, color: Colors.white)),
                  ),
                ),
                
                Text(widget.item.title, textAlign: TextAlign.center, style: AppTypography.headlineMedium.copyWith(fontSize: 20)),
                const SizedBox(height: 20),
                
                // Lista de Temporadas (COM EXPANDED PARA EVITAR OVERFLOW)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: sortedSeasons.length,
                      itemBuilder: (ctx, i) {
                        final season = sortedSeasons[i];
                        final isActive = season == selectedSeason;
                        
                        return _SeasonButton(
                          title: season, 
                          isActive: isActive, 
                          onTap: () => setState(() => selectedSeason = season)
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // === COLUNA DIREITA (70% da tela - Episódios) ===
          Expanded(
            child: Container(
              color: Colors.black,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título da Temporada
                  Padding(
                    padding: const EdgeInsets.fromLTRB(40, 40, 40, 20),
                    child: Text(
                      selectedSeason ?? "Selecione uma temporada", 
                      style: AppTypography.displayMedium.copyWith(fontSize: 32, color: AppColors.primary)
                    ),
                  ),
                  
                  // Grade de Episódios
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                      itemCount: details!.seasons[selectedSeason]?.length ?? 0,
                      separatorBuilder: (_,__) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) {
                        final ep = details!.seasons[selectedSeason]![i];
                        return _EpisodeCard(
                          episode: ep,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(url: ep.url))),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

// --- WIDGET DE BOTÃO DE TEMPORADA (Alto Contraste) ---
class _SeasonButton extends StatefulWidget {
  final String title;
  final bool isActive;
  final VoidCallback onTap;
  const _SeasonButton({required this.title, required this.isActive, required this.onTap});
  @override
  State<_SeasonButton> createState() => _SeasonButtonState();
}

class _SeasonButtonState extends State<_SeasonButton> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: widget.onTap,
        onFocusChange: (val) => setState(() => _focused = val),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            // Fundo: Se focado = Branco. Se ativo = Vermelho. Senão = Transparente
            color: _focused ? Colors.white : (widget.isActive ? AppColors.primary : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _focused ? AppColors.primary : (widget.isActive ? AppColors.primary : Colors.white24),
              width: _focused ? 3 : 1
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    // Texto: Se focado = Preto. Senão = Branco
                    color: _focused ? Colors.black : Colors.white,
                  ),
                ),
              ),
              if (widget.isActive && !_focused) 
                const Icon(Icons.check_circle, color: Colors.white, size: 18)
            ],
          ),
        ),
      ),
    );
  }
}

// --- WIDGET DE CARD DE EPISÓDIO (Alto Contraste) ---
class _EpisodeCard extends StatefulWidget {
  final ContentItem episode;
  final VoidCallback onTap;
  const _EpisodeCard({required this.episode, required this.onTap});
  @override
  State<_EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<_EpisodeCard> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      onFocusChange: (val) => setState(() => _focused = val),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        transform: _focused ? Matrix4.identity().scaled(1.02) : Matrix4.identity(),
        decoration: BoxDecoration(
          color: _focused ? const Color(0xFF333333) : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(8),
          // Borda grossa branca quando focado
          border: _focused ? Border.all(color: Colors.white, width: 3) : Border.all(color: Colors.white10),
          boxShadow: _focused ? [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)] : [],
        ),
        child: Row(
          children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: _focused ? AppColors.primary : Colors.white12,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.play_arrow, color: _focused ? Colors.white : Colors.white70),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.episode.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _focused ? AppColors.primary : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text("Toque para reproduzir", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}