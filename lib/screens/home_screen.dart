import 'package:flutter/material.dart';
import 'detail_screens.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF111318);  // --bg-dark
    const bg2 = Color(0xFF0F1620); // --bg-darker

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: const BoxDecoration(
                color: bg2,
                border: Border(
                  bottom: BorderSide(color: Color(0x334B5563)),
                ),
              ),
              child: Row(
                children: [
                  // Logo + título
                  GestureDetector(
                    onTap: () => setState(() => _selectedIndex = 0),
                    child: const Row(
                      children: [
                        _AppLogo(),
                        SizedBox(width: 8),
                        Text(
                          'ClickFlix',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),

                  // NAV
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _NavItem(
                            label: 'Início',
                            selected: _selectedIndex == 0,
                            onTap: () => setState(() => _selectedIndex = 0),
                          ),
                          _NavItem(
                            label: 'Filmes',
                            selected: _selectedIndex == 1,
                            onTap: () => setState(() => _selectedIndex = 1),
                          ),
                          _NavItem(
                            label: 'Séries',
                            selected: _selectedIndex == 2,
                            onTap: () => setState(() => _selectedIndex = 2),
                          ),
                          _NavItem(
                            label: 'Canais',
                            selected: _selectedIndex == 3,
                            onTap: () => setState(() => _selectedIndex = 3),
                          ),
                          _NavItem(
                            label: 'SharkFlix',
                            selected: _selectedIndex == 4,
                            onTap: () => setState(() => _selectedIndex = 4),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),
                  // Search
                  SizedBox(
                    width: 200,
                    child: TextField(
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Buscar filmes, séries...',
                        hintStyle: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0x334B5563),
                          ),
                        ),
                        prefixIcon: const Icon(Icons.search,
                            color: Colors.white70, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.notifications_none,
                        color: Colors.white),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 8),
                  const _ProfileMenu(),
                ],
              ),
            ),

            // CONTEÚDO POR ABA
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: const [
                  _HomeBody(),
                  MoviesLibraryBody(),
                  SeriesLibraryBody(),
                  LiveChannelsBody(),
                  PremiumBody(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFE11D48);

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      offset: const Offset(0, 40),
      color: const Color(0xFF111827),
      onSelected: (value) {
        if (value == 1) {
          // Ir para tela de favoritos
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MyFavoritesScreen(),
            ),
          );
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 0, child: Text('Meu Perfil')),
        const PopupMenuItem(
          value: 1,
          child: Row(
            children: [
              Icon(Icons.favorite, color: Color(0xFFE11D48)),
              SizedBox(width: 8),
              Text('Favoritos'),
            ],
          ),
        ),
        const PopupMenuItem(value: 2, child: Text('Histórico')),
        const PopupMenuItem(value: 3, child: Text('Configurações')),
        const PopupMenuItem(value: 4, child: Text('Sair')),
      ],
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white10,
              border: Border.all(color: Colors.white24),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.person, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          const Text(
            'Sarah',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
          const Icon(Icons.keyboard_arrow_down,
              color: Colors.white70, size: 18),
        ],
      ),
    );
  }
}

/// =====================
///  ABA INÍCIO
/// =====================

class _HomeBody extends StatelessWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeroInception(),
              SizedBox(height: 32),
              _ContinueWatchingSection(),
              SizedBox(height: 32),
              _CategoriesSection(),
              SizedBox(height: 32),
              _TrendingSection(),
            ],
          ),
        ),
        // Painel de teste flutuante
        Positioned(
          bottom: 24,
          right: 24,
          child: _TestPanel(),
        ),
      ],
    );
  }
}

class _HeroInception extends StatelessWidget {
  const _HeroInception();

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFE11D48);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x33E11D48), Color(0x330F1620)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: const Border.fromBorderSide(
          BorderSide(color: Color(0x334B5563)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x33E11D48),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: primary),
            ),
            child: const Text(
              'AO VIVO AGORA',
              style: TextStyle(
                color: primary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Inception',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ficção Científica • 2h 28m • 8.8/10',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {},
                icon: const Icon(Icons.play_arrow),
                label: const Text('Reproduzir'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white30),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {},
                child: const Text('Mais Info'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContinueWatchingSection extends StatelessWidget {
  const _ContinueWatchingSection();

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> items = [
      {'title': 'The Crown', 'subtitle': 'Série • 5 temp'},
      {'title': 'Stranger Things', 'subtitle': 'Série • 4 temp'},
      {'title': 'Inception', 'subtitle': 'Filme • 2023'},
      {'title': 'The Last Kingdom', 'subtitle': 'Série • 5 temp'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Continuar Assistindo'),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final item = items[index];
              return _MediaCard(
                title: item['title'] ?? '',
                subtitle: item['subtitle'] ?? '',
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoriesSection extends StatelessWidget {
  const _CategoriesSection();

  @override
  Widget build(BuildContext context) {
    final cats = [
      {'name': 'Ação', 'emoji': '🔥'},
      {'name': 'Comédia', 'emoji': '😂'},
      {'name': 'Drama', 'emoji': '💔'},
      {'name': 'Terror', 'emoji': '😱'},
      {'name': 'Ficção Científica', 'emoji': '🚀'},
      {'name': 'Romance', 'emoji': '💕'},
      {'name': 'Suspense', 'emoji': '🎬'},
      {'name': 'Animação', 'emoji': '📚'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Categorias Populares'),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cats.length,
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.4,
          ),
          itemBuilder: (context, index) {
            return _CategoryCard(
              label: cats[index]['name'] ?? '',
              emoji: cats[index]['emoji'] ?? '🎬',
            );
          },
        ),
      ],
    );
  }
}

class _TrendingSection extends StatelessWidget {
  const _TrendingSection();

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> items = [
      {'title': 'Inception', 'subtitle': 'Filme • 2010'},
      {'title': 'Interstellar', 'subtitle': 'Filme • 2014'},
      {'title': 'Breaking Bad', 'subtitle': 'Série • 2008'},
      {'title': 'The Crown', 'subtitle': 'Série • 2016'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Tendências'),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final item = items[index];
              return _MediaCard(
                title: item['title'] ?? '',
                subtitle: item['subtitle'] ?? '',
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
    );
  }
}

class _MediaCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _MediaCard({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: const Color(0x33111B2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x334B5563)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 120,
            decoration: const BoxDecoration(
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(12)),
              gradient: LinearGradient(
                colors: [Color(0xFFE11D48), Color(0xFF1E293B)],
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.play_circle_fill,
                color: Colors.white, size: 40),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================
// SERIES CARD
// =====================

class _SeriesCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SeriesCard({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x33111B2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x334B5563)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(12)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE11D48), Color(0xFF111827)],
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.tv,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Série Exemplo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  '5 temporadas • 2024',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================
// CHANNEL CARD
// =====================

class _ChannelCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _ChannelCard({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x33111B2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x334B5563)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(12)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE11D48), Color(0xFF111827)],
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.live_tv,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Canal ao Vivo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  '● AO VIVO',
                  style: TextStyle(
                    color: Color(0xFFE11D48),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================
// PREMIUM CARD
// =====================

class _PremiumCard extends StatelessWidget {
  const _PremiumCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x33111B2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x334B5563)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(12)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE11D48), Color(0xFF111827)],
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.star,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conteúdo Exclusivo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  'Apenas para premium',
                  style: TextStyle(
                    color: Color(0xFFE11D48),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================
// APP LOGO WIDGET
// =====================

class _AppLogo extends StatelessWidget {
  const _AppLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE11D48), Color(0xFFEC4C63)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE11D48).withOpacity(0.4),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Robô estilizado (cabeça)
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          // Olhos
          Positioned(
            left: 8,
            top: 8,
            child: Container(
              width: 3,
              height: 3,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF0F1620),
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 3,
              height: 3,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF0F1620),
              ),
            ),
          ),
          // Antena superior direita
          Positioned(
            top: -2,
            right: 6,
            child: Container(
              width: 2,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          // Antena superior esquerda
          Positioned(
            top: -2,
            left: 6,
            child: Container(
              width: 2,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          // Play icon no centro
          const Center(
            child: Icon(
              Icons.play_arrow,
              color: Color(0xFFE11D48),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================
// HERO BANNER (Reutilizável)
// =====================

class _HeroBanner extends StatelessWidget {
  final String badge;
  final String title;
  final String subtitle;
  final String description;
  final String buttonLabel;
  final IconData icon;

  const _HeroBanner({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.buttonLabel,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x33E11D48), Color(0x330F1620)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x334B5563)),
      ),
      child: Row(
        children: [
          // Conteúdo
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0x33E11D48),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: const Color(0xFFE11D48)),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Color(0xFFE11D48),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
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
                  onPressed: () {},
                  icon: Icon(icon),
                  label: Text(buttonLabel),
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          // Ícone
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFE11D48), Color(0xFFEC4C63)],
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 60,
            ),
          ),
        ],
      ),
    );
  }
}
// =====================
// TEST PANEL
// =====================

class _TestPanel extends StatefulWidget {
  @override
  State<_TestPanel> createState() => _TestPanelState();
}

class _TestPanelState extends State<_TestPanel> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isExpanded)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1620),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE11D48)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '🧪 Telas de Teste',
                      style: TextStyle(
                        color: Color(0xFFE11D48),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _isExpanded = false),
                      child: const Icon(Icons.close,
                          color: Colors.white70, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 180,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const SeriesDetailScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.tv, size: 18),
                    label: const Text(
                      'Série Detail',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 180,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const MyFavoritesScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.favorite, size: 18),
                    label: const Text(
                      'Meus Favoritos',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 180,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const PlayerDashboardScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_circle, size: 18),
                    label: const Text(
                      'Reprodutor',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE11D48),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE11D48).withOpacity(0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              _isExpanded ? Icons.close : Icons.apps,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryCard extends StatefulWidget {
  final String label;
  final String emoji;

  const _CategoryCard({required this.label, required this.emoji});

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {},
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: _isHovered 
              ? const Color(0x55111B2B)
              : const Color(0x33111B2B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered 
                ? const Color(0xFFE11D48)
                : const Color(0x334B5563),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.emoji,
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(height: 8),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// =====================
///  ABAS FILMES / SÉRIES / CANAIS / SHARKFLIX
/// =====================

class MoviesLibraryBody extends StatelessWidget {
  const MoviesLibraryBody({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Banner - Filmes
          const _HeroBanner(
            badge: 'FILME EM DESTAQUE',
            title: 'Inception',
            subtitle: 'Ficção Científica • Suspense • 2h 28m',
            description: 'Um ladrão que rouba segredos corporativos através do compartilhamento de sonhos',
            buttonLabel: 'Assistir Agora',
            icon: Icons.play_arrow,
          ),
          const SizedBox(height: 32),
          const Text(
            'Movies Library',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          const Wrap(
            spacing: 12,
            children: [
              _FilterChip(label: 'Todos'),
              _FilterChip(label: 'Ação'),
              _FilterChip(label: 'Comédia'),
              _FilterChip(label: 'Drama'),
              _FilterChip(label: 'Terror'),
            ],
          ),
          const SizedBox(height: 32),
          GridView.count(
            crossAxisCount: 4,
            mainAxisSpacing: 24,
            crossAxisSpacing: 24,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(
              12,
              (index) => const _MovieCard(),
            ),
          ),
        ],
      ),
    );
  }
}

class SeriesLibraryBody extends StatelessWidget {
  const SeriesLibraryBody({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Banner
          const _HeroBanner(
            badge: 'DESTAQUE DA SEMANA',
            title: 'Breaking Bad',
            subtitle: 'Drama • 5 Temporadas • 2008-2013',
            description: 'Um professor de química cria uma rede de tráfico de drogas',
            buttonLabel: 'Assistir Agora',
            icon: Icons.play_arrow,
          ),
          const SizedBox(height: 32),
          const Text(
            'TV Series',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          // Filter tabs
          const SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(label: 'Todas'),
                _FilterChip(label: 'Drama'),
                _FilterChip(label: 'Comédia'),
                _FilterChip(label: 'Ficção Científica'),
                _FilterChip(label: 'Suspense'),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Series Grid
          GridView.count(
            crossAxisCount: 4,
            mainAxisSpacing: 24,
            crossAxisSpacing: 24,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(
              12,
              (index) => const _SeriesCard(
                title: 'Série Exemplo',
                subtitle: '5 temporadas • 2024',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LiveChannelsBody extends StatelessWidget {
  const LiveChannelsBody({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Banner
          const _HeroBanner(
            badge: 'AO VIVO AGORA',
            title: 'Jogo Ao Vivo',
            subtitle: 'Esportes • 20:00 • HD',
            description: 'Acompanhe os melhores eventos esportivos ao vivo',
            buttonLabel: 'Assistir Transmissão',
            icon: Icons.live_tv,
          ),
          const SizedBox(height: 32),
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
            'Acompanhe seus canais favoritos agora',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),
          // Filter tabs
          const SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(label: 'Todos'),
                _FilterChip(label: 'Notícias'),
                _FilterChip(label: 'Esportes'),
                _FilterChip(label: 'Entretenimento'),
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
            childAspectRatio: 1.3,
            children: List.generate(
              9,
              (index) => const _ChannelCard(
                title: 'Canal',
                subtitle: 'Ao vivo',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PremiumBody extends StatelessWidget {
  const PremiumBody({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SharkFlix Premium',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Conteúdo exclusivo para assinantes premium',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),
          // Premium Hero Banner
          const _HeroBanner(
            badge: 'EXCLUSIVO',
            title: 'Desfrute de Conteúdo Premium',
            subtitle: 'Sem anúncios • Qualidade 4K • Download',
            description: 'Acesso ilimitado a todo conteúdo exclusivo',
            buttonLabel: 'Assinar Agora',
            icon: Icons.star,
          ),
          const SizedBox(height: 32),
          // Featured Premium Content
          const _SectionTitle(title: 'Conteúdo em Destaque'),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 24,
            crossAxisSpacing: 24,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.2,
            children: List.generate(
              6,
              (index) => const _PremiumCard(),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;

  const _FilterChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x33111B2B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x334B5563)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _MovieCard extends StatelessWidget {
  const _MovieCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x33111B2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x334B5563)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(12)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE11D48), Color(0xFF111827)],
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.movie,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Movie',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  '2024 • 2h 28m',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
