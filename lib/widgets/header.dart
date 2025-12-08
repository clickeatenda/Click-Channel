import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'search_bar.dart' as search_widgets;

class Header extends StatelessWidget {
  final VoidCallback onRefresh;
  final Function(String) onFilterChanged;
  final String currentFilter;
  final VoidCallback onSettings;
  final Function(String)? onSearch;
  final VoidCallback? onClearSearch;

  const Header({
    super.key,
    required this.onRefresh,
    required this.onFilterChanged,
    required this.currentFilter,
    required this.onSettings,
    this.onSearch,
    this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black.withOpacity(0.95), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.movie_filter, color: AppColors.primary, size: 40),
              const SizedBox(width: 20),
              
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _navBtn(context, "Início", "all"),
                    _navBtn(context, "Filmes", "movie"),
                    _navBtn(context, "Séries", "series"),
                    _navBtn(context, "Canais", "channel"),
                  ],
                ),
              ),

              _iconBtn(Icons.refresh, onRefresh),
              const SizedBox(width: 10),
              _iconBtn(Icons.settings, onSettings),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: search_widgets.CustomSearchBar(
              onSearch: onSearch ?? (_) {},
              onClear: onClearSearch,
              placeholder: 'Buscar conteúdo...',
            ),
          ),
        ],
      ),
    );
  }

  Widget _navBtn(BuildContext context, String label, String filterKey) {
    final bool isActive = currentFilter == filterKey;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: TextButton(
        onPressed: () => onFilterChanged(filterKey),
        style: TextButton.styleFrom(
          backgroundColor: isActive ? AppColors.primary : Colors.transparent,
          foregroundColor: isActive ? Colors.white : Colors.white70,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
        child: Text(label, style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal, fontSize: 16)),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(shape: const CircleBorder(), padding: const EdgeInsets.all(12), foregroundColor: Colors.white),
      child: Icon(icon, size: 24),
    );
  }
}