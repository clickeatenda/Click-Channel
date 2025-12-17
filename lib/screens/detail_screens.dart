import 'package:flutter/material.dart';
import '../models/content_item.dart';
import '../widgets/optimized_gridview.dart';

// =====================
// SERIES DETAIL SCREEN
// =====================

class SeriesDetailScreen extends StatelessWidget {
  const SeriesDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero image
              Container(
                width: double.infinity,
                height: 300,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE11D48), Color(0xFF111318)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Stack(
                  children: [
                    const Center(
                      child: Icon(Icons.tv, size: 80, color: Colors.white30),
                    ),
                    Positioned(
                      top: 16,
                      left: 16,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.arrow_back,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Breaking Bad',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Drama • Suspense • 5 Temporadas • 62 Episódios',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE11D48),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              const PlayerDashboardScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Assistir Série Completa'),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Sinopse',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Um professor de química diagnosticado com câncer entra no negócio de metanfetamina para garantir a segurança financeira de sua família.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Elenco',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: 4,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          return Container(
                            width: 80,
                            decoration: BoxDecoration(
                              color: const Color(0x33111B2B),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0x334B5563)),
                            ),
                            child: const Center(
                              child: Icon(Icons.person,
                                  size: 32, color: Colors.white30),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================
// MY FAVORITES SCREEN
// =====================

class MyFavoritesScreen extends StatelessWidget {
  const MyFavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final favMovies = List.generate(6, (i) => ContentItem(
      title: 'Favorito ${i + 1}',
      url: 'https://example.com/movie/${i + 1}',
      image: '',
      group: 'Favoritos',
      type: 'movie',
    ));

    final favSeries = List.generate(6, (i) => ContentItem(
      title: 'Série Favorita ${i + 1}',
      url: 'https://example.com/series/${i + 1}',
      image: '',
      group: 'Favoritos',
      type: 'series',
      isSeries: true,
    ));

    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1620),
        title: const Text('Meus Favoritos'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filmes Favoritos',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            OptimizedGridView(
              items: favMovies,
              crossAxisCount: 3,
              childAspectRatio: 0.8,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              physics: const NeverScrollableScrollPhysics(),
              onTap: (item) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const PlayerDashboardScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            const Text(
              'Séries Favoritas',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            OptimizedGridView(
              items: favSeries,
              crossAxisCount: 3,
              childAspectRatio: 0.8,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              physics: const NeverScrollableScrollPhysics(),
              onTap: (serie) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SeriesDetailScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// =====================
// PLAYER DASHBOARD SCREEN
// =====================

class PlayerDashboardScreen extends StatefulWidget {
  const PlayerDashboardScreen({super.key});

  @override
  State<PlayerDashboardScreen> createState() =>
      _PlayerDashboardScreenState();
}

class _PlayerDashboardScreenState extends State<PlayerDashboardScreen> {
  bool _isPlaying = true;
  double _progress = 0.35;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      body: SafeArea(
        child: Column(
          children: [
            // Player area
            Container(
              width: double.infinity,
              height: 300,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE11D48), Color(0xFF111318)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.play_circle_filled,
                      size: 80, color: Colors.white30),
                  Positioned(
                    top: 16,
                    left: 16,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.arrow_back,
                            color: Colors.white),
                      ),
                    ),
                  ),
                  Center(
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _isPlaying = !_isPlaying),
                      child: Icon(
                        _isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Progress bar
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF0F1620),
              child: Column(
                children: [
                  SliderTheme(
                    data: const SliderThemeData(
                      trackHeight: 6,
                      thumbShape: RoundSliderThumbShape(
                          enabledThumbRadius: 8),
                      activeTrackColor: Color(0xFFE11D48),
                      inactiveTrackColor: Colors.white24,
                    ),
                    child: Slider(
                      value: _progress,
                      onChanged: (val) =>
                          setState(() => _progress = val),
                      min: 0,
                      max: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text('52:30',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 12)),
                      Text('2:28:00',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            // Info section
            const Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inception',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Ficção Científica • Suspense • 2010',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 24),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceEvenly,
                      children: [
                        _PlayerButton(
                          icon: Icons.add,
                          label: 'Adicionar',
                        ),
                        _PlayerButton(
                          icon: Icons.favorite_border,
                          label: 'Favoritar',
                        ),
                        _PlayerButton(
                          icon: Icons.share,
                          label: 'Compartilhar',
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Sinopse',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Um ladrão que rouba segredos corporativos através da tecnologia de compartilhamento de sonhos recebe uma tarefa inversa: implantar uma ideia',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerButton extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PlayerButton({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0x33111B2B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x334B5563)),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
