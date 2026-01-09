import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';
import '../core/config.dart';
import '../models/content_item.dart';
import '../models/series_details.dart';
import '../data/api_service.dart';
import '../data/m3u_service.dart';
import '../widgets/media_player_screen.dart';
import '../utils/content_enricher.dart';

/// Tela de detalhes completa de série com todas as informações
/// Layout similar ao MovieDetailScreen
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
  ContentItem? enrichedItem;
  bool loadingMetadata = true;
  List<ContentItem> similarItems = [];
  bool loadingSimilar = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
    _loadMetadata();
    _loadSimilarItems();
  }

  Future<void> _loadMetadata() async {
    // Enriquece o item com dados do TMDB
    try {
      final enriched = await ContentEnricher.enrichItem(widget.item);
      if (mounted) {
        setState(() {
          enrichedItem = enriched;
          loadingMetadata = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          enrichedItem = widget.item;
          loadingMetadata = false;
        });
      }
    }
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

  Future<void> _loadSimilarItems() async {
    try {
      List<ContentItem> items = [];
      if (Config.playlistRuntime != null && Config.playlistRuntime!.isNotEmpty) {
        items = await M3uService.fetchCategoryItemsFromEnv(
          category: _displayItem.group,
          typeFilter: 'series',
        );
        // Remove o item atual
        items.removeWhere((i) => i.title == _displayItem.title);
        
        // Enriquece itens similares
        final enriched = await ContentEnricher.enrichItems(items.take(10).toList());
        items = enriched;
      }
      if (mounted) {
        setState(() {
          similarItems = items.take(5).toList();
          loadingSimilar = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => loadingSimilar = false);
      }
    }
  }

  ContentItem get _displayItem => enrichedItem ?? widget.item;

  @override
  Widget build(BuildContext context) {
    if (loadingMetadata || loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary))
      );
    }
    if (details == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Text("Série indisponível", style: TextStyle(color: Colors.white))
        )
      );
    }

    // Ordenação da lista para exibição
    final sortedSeasons = details!.seasons.keys.toList();
    sortedSeasons.sort((a, b) {
      int na = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      int nb = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return na.compareTo(nb);
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background blur com poster
          if (_displayItem.image.isNotEmpty)
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: _displayItem.image,
                fit: BoxFit.cover,
                color: Colors.black.withOpacity(0.7),
                colorBlendMode: BlendMode.darken,
              ),
            ),
          // Overlay escuro
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.black.withOpacity(0.95),
                  ],
                ),
              ),
            ),
          ),
          // Conteúdo com CustomScrollView para performance
          SafeArea(
            child: CustomScrollView(
              slivers: [
                // Top Section: Metadata + Poster
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // COLUNA ESQUERDA - Informações
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Botão voltar
                              IconButton(
                                icon: const Icon(Icons.arrow_back, color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                              const SizedBox(height: 16),
                              
                              // Tags de gênero
                              Wrap(
                                spacing: 8,
                                children: [
                                  if (_displayItem.genre.isNotEmpty)
                                    ..._displayItem.genre.split(',').take(3).map((g) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            g.trim().toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )),
                                ],
                              ),
                              const SizedBox(height: 12),
                              
                              // Ano e informações
                              Row(
                                children: [
                                  Text(
                                    _displayItem.year,
                                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                                  ),
                                  if (sortedSeasons.isNotEmpty) ...[
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[800],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${sortedSeasons.length} Temporada${sortedSeasons.length > 1 ? 's' : ''}',
                                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 16),
                              
                              // Título
                              Text(
                                _displayItem.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Rating e Match Score
                              Row(
                                children: [
                                  // Rating com estrela (do TMDB)
                                  if (_displayItem.rating > 0)
                                    Row(
                                      children: [
                                        const Icon(Icons.star, color: Colors.amber, size: 24),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${_displayItem.rating.toStringAsFixed(1)} / 10',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (_displayItem.rating > 0) const SizedBox(width: 24),
                                  // Match Score (baseado em popularidade)
                                  if (_displayItem.popularity > 0)
                                    Row(
                                      children: [
                                        const Icon(Icons.trending_up, color: Colors.green, size: 20),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${(_displayItem.popularity.clamp(0, 100)).toInt()}% Match',
                                          style: const TextStyle(
                                            color: Colors.green,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              const SizedBox(height: 32),
                              
                              // Audio Type Selector (DUB/LEG)
                              if (availableAudioTypes.isNotEmpty) ...[
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
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
                                      backgroundColor: isSelected ? AppColors.primary : Colors.transparent,
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
                                const SizedBox(height: 24),
                              ],
                              
                              // Botões de ação
                              Row(
                                children: [
                                  // Watch Now (primeiro episódio da primeira temporada)
                                  if (selectedSeason != null && details!.seasons[selectedSeason]!.isNotEmpty)
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        final firstEpisode = details!.seasons[selectedSeason]!.first;
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => MediaPlayerScreen(
                                              url: firstEpisode.url,
                                              item: firstEpisode,
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.play_arrow, size: 24),
                                      label: const Text('Assistir Agora', style: TextStyle(fontSize: 16)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 12),
                                  // My List
                                  OutlinedButton.icon(
                                    onPressed: () {},
                                    icon: const Icon(Icons.add, size: 20),
                                    label: const Text('Minha Lista'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(color: Colors.white38),
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Share
                                  IconButton(
                                    onPressed: () {},
                                    icon: const Icon(Icons.share, color: Colors.white70),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white10,
                                      padding: const EdgeInsets.all(12),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 40),
                              
                              // Synopsis
                              const Text(
                                'Sinopse',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _displayItem.description.isNotEmpty
                                    ? _displayItem.description
                                    : 'Sinopse não disponível.',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 15,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 48),
                        
                        // COLUNA DIREITA - Poster e Info Panel
                        SizedBox(
                          width: 320,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 80),
                              // Poster grande
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: _displayItem.image,
                                  width: double.infinity,
                                  height: 480,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    color: Colors.grey[900]!,
                                    height: 480,
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    color: Colors.grey[900]!,
                                    height: 480,
                                    child: const Icon(
                                      Icons.image_not_supported,
                                      color: Colors.white24,
                                      size: 64,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              
                              // Info Panel
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.grey[900]!.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInfoRow('Temporadas', '${sortedSeasons.length}'),
                                    const SizedBox(height: 12),
                                    if (selectedSeason != null && details!.seasons[selectedSeason] != null)
                                      _buildInfoRow('Episódios (${selectedSeason})', '${details!.seasons[selectedSeason]!.length}'),
                                    if (widget.item.quality.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      _buildInfoRow('Qualidade', widget.item.quality.toUpperCase()),
                                    ],
                                    if (availableAudioTypes.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      _buildInfoRow('Áudio', availableAudioTypes.join(', ').toUpperCase()),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Header: Temporadas e Episódios
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 40),
                        const Text(
                          'TEMPORADAS E EPISÓDIOS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Seletor de Temporada
                        SizedBox(
                          height: 50,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: sortedSeasons.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (ctx, i) {
                              final season = sortedSeasons[i];
                              final isActive = season == selectedSeason;
                              final episodeCount = details!.seasons[season]?.length ?? 0;
                              return FilterChip(
                                label: Text('$season (${episodeCount} eps)'),
                                selected: isActive,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() => selectedSeason = season);
                                  }
                                },
                                backgroundColor: isActive ? AppColors.primary : Colors.transparent,
                                side: BorderSide(
                                  color: isActive ? AppColors.primary : Colors.white24,
                                ),
                                labelStyle: TextStyle(
                                  color: isActive ? Colors.white : Colors.white70,
                                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // Lista de Episódios (SliverList para performance)
                if (selectedSeason != null && details != null && details!.seasons.containsKey(selectedSeason))
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final episode = details!.seasons[selectedSeason]![index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 6),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[900]!.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: ListTile(
                              leading: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                episode.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'Episódio ${index + 1}',
                                style: const TextStyle(color: Colors.white54),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.play_circle_outline, color: AppColors.primary),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MediaPlayerScreen(
                                        url: episode.url,
                                        item: episode,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MediaPlayerScreen(
                                      url: episode.url,
                                      item: episode,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                      childCount: details!.seasons[selectedSeason]!.length,
                    ),
                  ),

                // Similares
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 40),
                        const Text(
                          'Séries Similares',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (loadingSimilar)
                          const Center(child: CircularProgressIndicator())
                        else if (similarItems.isEmpty)
                          const Text(
                            'Nenhuma série similar encontrada',
                            style: TextStyle(color: Colors.white54),
                          )
                        else
                          SizedBox(
                            height: 280,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: similarItems.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final item = similarItems[index];
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SeriesDetailScreen(item: item),
                                      ),
                                    );
                                  },
                                  child: SizedBox(
                                    width: 160,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: CachedNetworkImage(
                                              imageUrl: item.image,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              placeholder: (_, __) => Container(
                                                color: Colors.grey[900],
                                                child: const Center(
                                                  child: CircularProgressIndicator(),
                                                ),
                                              ),
                                              errorWidget: (_, __, ___) => Container(
                                                color: Colors.grey[900]!,
                                                child: const Icon(
                                                  Icons.image_not_supported,
                                                  color: Colors.white24,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          item.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
