import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/content_item.dart';
import '../data/api_service.dart';
import '../data/m3u_service.dart';
import '../widgets/optimized_gridview.dart';
import 'series_detail_screen.dart';

class SeriesLibraryScreen extends StatefulWidget {
  const SeriesLibraryScreen({super.key});

  @override
  State<SeriesLibraryScreen> createState() => _SeriesLibraryScreenState();
}

class _SeriesLibraryScreenState extends State<SeriesLibraryScreen> {
  List<ContentItem> series = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadSeries();
  }

  Future<void> _loadSeries() async {
    try {
      // Try M3U first for series
      List<ContentItem> data = [];
      try {
        data = await M3uService.fetchFromEnv(limit: 100);
        print('📺 SeriesLibraryScreen: ✅ Carregados ${data.length} itens da M3U');
        // Filter only series
        data = data.where((item) => item.isSeries).toList();
        print('📺 SeriesLibraryScreen: ${data.length} séries após filtro');
      } catch (e) {
        print('⚠️ SeriesLibraryScreen: M3U falhou: $e');
        print('⚠️ SeriesLibraryScreen: Tentando backend...');
        data = await ApiService.fetchAllSeries(limit: 100);
        print('📺 SeriesLibraryScreen: ${data.length} séries do backend');
      }
      
      if (mounted) {
        setState(() {
          series = data;
          loading = false;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = e.toString();
          series = [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, 
                        size: 64, 
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Erro ao carregar séries',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loadSeries,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TV Series',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Explore nossa coleção de ${series.length} séries',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Grid com suporte a navegação por controle
                        OptimizedGridView(
                          items: series,
                          crossAxisCount: 4,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 24,
                          mainAxisSpacing: 24,
                          physics: const NeverScrollableScrollPhysics(),
                          showMetaChips: true,
                          metaFontSize: 10,
                          metaIconSize: 12,
                          onTap: (serie) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SeriesDetailScreen(item: serie),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
