import 'package:flutter/material.dart';
import '../models/content_item.dart';
import '../widgets/optimized_gridview.dart';
import '../data/epg_service.dart';
import '../models/epg_program.dart';
import '../core/theme/app_colors.dart';
import '../widgets/glass_panel.dart';
import '../widgets/app_sidebar.dart';

class LiveChannelsScreen extends StatefulWidget {
  const LiveChannelsScreen({super.key});

  @override
  State<LiveChannelsScreen> createState() => _LiveChannelsScreenState();
}

class _LiveChannelsScreenState extends State<LiveChannelsScreen> {
  @override
  Widget build(BuildContext context) {
    final epgChannelsMap = EpgService.isLoaded
        ? {for (final c in EpgService.getAllChannels()) c.displayName.trim().toLowerCase(): c}
        : <String, EpgChannel>{};
    print('🔍 LiveChannels: EPG channels passed: ${epgChannelsMap.length}');

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Row(
        children: [
          const AppSidebar(selectedIndex: 3),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Live TV Channels',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Watch your favorite channels live right now',
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
                          _buildFilterChip('Entertainment'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Channels Grid
                    OptimizedGridView(
                      items: List.generate(9, (i) => ContentItem(
                        title: 'Channel ${i + 1}',
                        url: 'https://example.com/channel/${i + 1}',
                        image: '',
                        group: 'Live',
                        type: 'channel',
                      )),
                      epgChannels: epgChannelsMap,
                      crossAxisCount: 3,
                      mainAxisSpacing: 24,
                      crossAxisSpacing: 24,
                      childAspectRatio: 1.2,
                      physics: const NeverScrollableScrollPhysics(),
                      onTap: (item) {
                        // TODO: integrar player de canal ao vivo
                        debugPrint('Selecionado canal: ${item.title}');
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
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Placeholder: Future filter function
          },
          borderRadius: BorderRadius.circular(20),
          focusColor: Colors.white.withOpacity(0.15),
          hoverColor: Colors.white.withOpacity(0.05),
          child: GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            borderRadius: BorderRadius.circular(20),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

}
