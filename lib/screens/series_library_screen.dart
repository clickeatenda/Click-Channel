import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/content_item.dart';
import '../data/api_service.dart';
import '../widgets/content_card.dart';
import 'series_detail_screen.dart';

class SeriesLibraryScreen extends StatefulWidget {
  const SeriesLibraryScreen({super.key});

  @override
  State<SeriesLibraryScreen> createState() => _SeriesLibraryScreenState();
}

class _SeriesLibraryScreenState extends State<SeriesLibraryScreen> {
  List<ContentItem> series = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadSeries();
  }

  Future<void> _loadSeries() async {
    final data = await ApiService.fetchAllSeries(limit: 100);
    if (mounted) {
      setState(() {
        series = data;
        loading = false;
      });
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

                    // Grid de séries do backend
                    GridView.count(
                      crossAxisCount: 4,
                      mainAxisSpacing: 24,
                      crossAxisSpacing: 24,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: series.map((serie) {
                        return ContentCard(
                          item: serie,
                          onTap: (_) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    SeriesDetailScreen(item: serie),
                              ),
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
