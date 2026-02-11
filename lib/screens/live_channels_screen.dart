import 'package:flutter/material.dart';
import '../models/content_item.dart';
import '../data/m3u_service.dart';
import '../widgets/optimized_gridview.dart';
import '../data/epg_service.dart';
import '../models/epg_program.dart';
import '../core/theme/app_colors.dart';
import '../widgets/glass_panel.dart';
import '../widgets/custom_app_header.dart';

class LiveChannelsScreen extends StatefulWidget {
  const LiveChannelsScreen({super.key});

  @override
  State<LiveChannelsScreen> createState() => _LiveChannelsScreenState();
}

class _LiveChannelsScreenState extends State<LiveChannelsScreen> {
  int _selectedNavIndex = 3; // 'Canais' selecionado
  List<ContentItem> _channels = [];
  Map<String, EpgChannel> _epgChannelsMap = {};
  bool _loading = true;
  String _selectedFilter = 'All';

  final List<HeaderNav> _navItems = [
    HeaderNav(label: 'Início'),
    HeaderNav(label: 'Filmes'),
    HeaderNav(label: 'Séries'),
    HeaderNav(label: 'Canais'),
    HeaderNav(label: 'SharkFlix'),
  ];

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    try {
      // 1. Carrega canais do M3U
      final allChannels = await M3uService.fetchCategoryItemsFromEnv(
        category: 'ALL', // Busca todos ou usa logica de 'Live'
        typeFilter: 'channel',
        maxItems: 300, // Limita visualização inicial
      );

      // 2. Prepara EPG
      if (!EpgService.isLoaded) {
        await EpgService.loadFromCache();
      }
      final epgMap = EpgService.isLoaded
          ? {for (final c in EpgService.getAllChannels()) c.displayName.trim().toLowerCase(): c}
          : <String, EpgChannel>{};

      if (mounted) {
        setState(() {
          _channels = allChannels;
          _epgChannelsMap = epgMap;
          _loading = false;
        });
      }
    } catch (e) {
      print('❌ Erro ao carregar canais ao vivo: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  List<ContentItem> get _filteredChannels {
    if (_selectedFilter == 'All') return _channels;
    // Filtro simples por nome/grupo (exemplo básico)
    return _channels.where((c) => 
      c.group.toLowerCase().contains(_selectedFilter.toLowerCase()) || 
      c.title.toLowerCase().contains(_selectedFilter.toLowerCase())
    ).toList();
  }

  void _navigateByIndex(int index) {
    if (index == 3) return; // Já estamos aqui
    if (index >= 0 && index <= 4) {
      Navigator.pushNamed(context, '/home', arguments: index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Column(
        children: [
          CustomAppHeader(
            title: 'Click Channel',
            navItems: _navItems,
            selectedNavIndex: _selectedNavIndex,
            onNavSelected: (index) => _navigateByIndex(index),
            userAvatarUrl: 'https://via.placeholder.com/32x32?text=User',
            userName: 'Usuário',
            onNotificationTap: () {},
            onProfileTap: () => Navigator.pushNamed(context, '/profile'),
            onSettingsTap: () => Navigator.pushNamed(context, '/settings'),
          ),
          Expanded(
            child: _loading 
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Canais ao Vivo',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Assista seus canais favoritos ao vivo agora',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Filter tabs
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip('All'),
                              _buildFilterChip('News'),
                              _buildFilterChip('Sports'),
                              _buildFilterChip('Globo'),
                              _buildFilterChip('SBT'),
                              _buildFilterChip('Record'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Channels Grid
                        if (_channels.isEmpty)
                          const Center(child: Text('Nenhum canal encontrado.', style: TextStyle(color: Colors.white54)))
                        else
                          OptimizedGridView(
                            items: _filteredChannels,
                            epgChannels: _epgChannelsMap,
                            crossAxisCount: 6, // Mais colunas para tela grande
                            childAspectRatio: 1.1,
                            physics: const NeverScrollableScrollPhysics(),
                            onTap: (item) {
                              // Navega para player direto
                              Navigator.pushNamed(
                                context, 
                                '/player', 
                                arguments: {'url': item.url, 'item': item}
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = label),
        child: GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          borderRadius: BorderRadius.circular(20),
          backgroundColor: isSelected ? AppColors.primary.withOpacity(0.6) : null,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
