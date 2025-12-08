import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../models/content_item.dart';
import '../widgets/content_card.dart';
import '../widgets/player_screen.dart';
import '../data/api_service.dart';
import 'series_detail_screen.dart'; // Importação correta

class CategoryScreen extends StatefulWidget {
  final String categoryName;
  final String type;

  const CategoryScreen({super.key, required this.categoryName, required this.type});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  List<ContentItem> items = [];
  bool loading = true;
  ContentItem? bannerItem;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    // Busca até 100 itens para preencher a tela
    final data = await ApiService.fetchCategoryItems(widget.categoryName, widget.type, limit: 100);
    
    if (mounted) {
      setState(() {
        items = data;
        if (items.isNotEmpty) {
          final withImage = items.where((i) => i.image.isNotEmpty).toList();
          bannerItem = withImage.isNotEmpty ? withImage[Random().nextInt(withImage.length)] : items.first;
        }
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 250,
                  pinned: true,
                  backgroundColor: AppColors.background,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(widget.categoryName, style: AppTypography.headlineMedium),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (bannerItem != null)
                          CachedNetworkImage(imageUrl: bannerItem!.image, fit: BoxFit.cover, alignment: Alignment.topCenter)
                        else
                          Container(color: const Color(0xFF222222)),
                        Container(decoration: BoxDecoration(gradient: heroGradient)),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 160,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return ContentCard(
                          item: items[index],
                          onTap: (_) {
                             if (items[index].isSeries) {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => SeriesDetailScreen(item: items[index])));
                             } else {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(url: items[index].url)));
                             }
                          },
                        );
                      },
                      childCount: items.length,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}