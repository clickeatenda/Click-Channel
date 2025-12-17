import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/config.dart';
import '../models/content_item.dart';
import '../models/series_details.dart';
import '../data/api_service.dart';
import '../data/m3u_service.dart';
import '../widgets/media_player_screen.dart';
import '../widgets/meta_chips_widget.dart';


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
  String? selectedAudioType;
  List<String> availableAudioTypes = [];

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    // Preferir M3U quando disponível
    SeriesDetails? d;
    if (Config.playlistRuntime != null && Config.playlistRuntime!.isNotEmpty) {
      // Carregar tipos de áudio disponíveis
      availableAudioTypes = await M3uService.getAvailableAudioTypesForSeries(widget.item.title, widget.item.group);
      d = await M3uService.fetchSeriesDetailsFromM3u(widget.item.title, widget.item.group);
    } else {
      d = await ApiService.fetchSeriesDetails(widget.item.id);
    }
    
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
                        ? CachedNetworkImage(
                            imageUrl: widget.item.image, 
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[800],
                              child: const Center(child: CircularProgressIndicator()),
                            ),
                            errorWidget: (c, u, e) => Container(
                              color: Colors.grey[800],
                              child: const Icon(Icons.video_library, size: 60, color: Colors.white54),
                            ),
                          )
                        : Container(
                            color: Colors.grey[800], 
                            child: const Icon(Icons.video_library, size: 60, color: Colors.white54),
                          ),
                  ),
                ),
                
                Text(widget.item.title, textAlign: TextAlign.center, style: AppTypography.headlineMedium.copyWith(fontSize: 20)),
                const SizedBox(height: 8),
                // Audio Type Selector (DUB/LEG)
                if (availableAudioTypes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      children: availableAudioTypes.map((audioType) {
                        final isSelected = selectedAudioType == audioType;
                        return FilterChip(
                          label: Text(audioType.toUpperCase()),
                          selected: isSelected,
                          onSelected: (selected) async {
                            setState(() => selectedAudioType = selected ? audioType : null);
                            // Recarregar detalhes com novo audioType
                            SeriesDetails? d;
                            if (Config.playlistRuntime != null && Config.playlistRuntime!.isNotEmpty) {
                              d = await M3uService.fetchSeriesDetailsFromM3u(
                                widget.item.title,
                                widget.item.group,
                                audioType: selected ? audioType : null,
                              );
                            }
                            if (d != null && mounted) {
                              setState(() {
                                details = d;
                                if (d != null && d.seasons.isNotEmpty) {
                                  final keys = d.seasons.keys.toList();
                                  keys.sort((a, b) {
                                    int na = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                                    int nb = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                                    return na.compareTo(nb);
                                  });
                                  selectedSeason = keys.first;
                                }
                              });
                            }
                          },
                          backgroundColor: Colors.transparent,
                          side: BorderSide(
                            color: isSelected ? AppColors.primary : Colors.white24,
                          ),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 8),
                // Metadados: origem do stream, tipo de áudio, qualidade e avaliação
                MetaChipsWidget(item: widget.item),
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
                          onTap: () => setState(() => selectedSeason = season),
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
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MediaPlayerScreen(url: ep.url, item: ep))),
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