import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../widgets/glass_panel.dart';
import '../widgets/custom_app_header.dart';

class LiveChannelsScreen extends StatefulWidget {
  const LiveChannelsScreen({super.key});

  @override
  State<LiveChannelsScreen> createState() => _LiveChannelsScreenState();
}

class _LiveChannelsScreenState extends State<LiveChannelsScreen> {
  int _selectedNavIndex = 2;
  String _searchQuery = '';

  final List<HeaderNav> _navItems = [
    HeaderNav(label: 'Home'),
    HeaderNav(label: 'Categories'),
    HeaderNav(label: 'Live TV'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Column(
        children: [
          CustomAppHeader(
            title: 'ClickFlix',
            navItems: _navItems,
            selectedNavIndex: _selectedNavIndex,
            onNavSelected: (index) =>
                setState(() => _selectedNavIndex = index),
            userAvatarUrl:
                'https://via.placeholder.com/32x32?text=User',
            userName: 'Sarah J',
            onNotificationTap: () {},
            onProfileTap: () {},
            onSearchChanged: (query) =>
                setState(() => _searchQuery = query),
          ),
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
                    GridView.count(
                      crossAxisCount: 3,
                      mainAxisSpacing: 24,
                      crossAxisSpacing: 24,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.2,
                      children: List.generate(
                        9,
                        (index) => _buildChannelCard('Channel ${index + 1}'),
                      ),
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
    );
  }

  Widget _buildChannelCard(String title) {
    return GlassCard(
      padding: EdgeInsets.zero,
      onTap: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withOpacity(0.3),
                    AppColors.surface,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      Icons.tv,
                      color: AppColors.primary,
                      size: 40,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '2.4K watching',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
