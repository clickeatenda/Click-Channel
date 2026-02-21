import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';
import '../screens/search_screen.dart';

class AppSidebar extends StatefulWidget {
  final int selectedIndex;
  final Function(int)? onNavSelected;

  const AppSidebar({
    super.key,
    this.selectedIndex = -1,
    this.onNavSelected,
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  bool _isExpanded = false; // Start compact by default on larger screens or let focus handle it
  bool _hasFocus = false;

  void _onFocusChange(bool focused) {
    setState(() {
      _hasFocus = focused;
      // Auto-expand when a child gets focus
      _isExpanded = focused;
    });
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  void _navigate(int index) {
    setState(() => _isExpanded = false);
    if (widget.onNavSelected != null) {
      widget.onNavSelected!(index);
    } else {
      Navigator.pushNamed(context, '/home', arguments: index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = _isExpanded ? 250.0 : 80.0;

    return Focus( // Wrap in Focus to detect when ANY element inside gets focus
      onFocusChange: _onFocusChange,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: width,
        decoration: BoxDecoration(
          color: const Color(0xFF161b22).withOpacity(0.8),
          border: Border(
            right: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 32),
            // Logo + título
            GestureDetector(
              onTap: () {
                setState(() => _isExpanded = false);
                if (widget.onNavSelected != null) {
                  widget.onNavSelected!(0);
                } else {
                  Navigator.pushNamed(context, '/home');
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: _isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.primary, 
                                  AppColors.primaryLight,
                                ],
                              ),
                            ),
                            child: const Icon(Icons.live_tv, color: Colors.white, size: 24),
                          );
                        },
                      ),
                    ),
                    if (_isExpanded) ...[
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Click Channel',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
  
            // NAV
            Expanded(
              child: ListView(
                children: [
                  _SidebarItem(
                    label: 'Início',
                    icon: Icons.home_outlined,
                    selected: widget.selectedIndex == 0,
                    isExpanded: _isExpanded,
                    onTap: () => _navigate(0),
                    autofocus: widget.selectedIndex == 0,
                  ),
                  _SidebarItem(
                    label: 'Filmes',
                    icon: Icons.movie_outlined,
                    selected: widget.selectedIndex == 1,
                    isExpanded: _isExpanded,
                    onTap: () => _navigate(1),
                  ),
                  _SidebarItem(
                    label: 'Séries',
                    icon: Icons.tv_outlined,
                    selected: widget.selectedIndex == 2,
                    isExpanded: _isExpanded,
                    onTap: () => _navigate(2),
                  ),
                  _SidebarItem(
                    label: 'Canais',
                    icon: Icons.live_tv_outlined,
                    selected: widget.selectedIndex == 3,
                    isExpanded: _isExpanded,
                    onTap: () => _navigate(3),
                  ),
                  _SidebarItem(
                    label: 'SharkFlix',
                    icon: Icons.subscriptions_outlined,
                    selected: widget.selectedIndex == 4,
                    isExpanded: _isExpanded,
                    onTap: () => _navigate(4),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(color: Colors.white.withOpacity(0.05)),
                  ),
                  const SizedBox(height: 16),
                  _SidebarItem(
                    label: 'Buscar',
                    icon: Icons.search_outlined,
                    selected: false,
                    isExpanded: _isExpanded,
                    onTap: () {
                      setState(() => _isExpanded = false);
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const SearchScreen(),
                      ));
                    },
                  ),
                  _SidebarItem(
                    label: 'Config.',
                    icon: Icons.settings_outlined,
                    selected: widget.selectedIndex == 10,
                    isExpanded: _isExpanded,
                    onTap: () {
                      setState(() => _isExpanded = false);
                      if (widget.selectedIndex != 10) {
                        Navigator.pushNamed(context, '/settings');
                      }
                    },
                  ),
                  _SidebarItem(
                    label: 'Perfil',
                    icon: Icons.person_outline,
                    selected: widget.selectedIndex == 11,
                    isExpanded: _isExpanded,
                    onTap: () {
                      setState(() => _isExpanded = false);
                      if (widget.selectedIndex != 11) {
                        Navigator.pushNamed(context, '/profile');
                      }
                    },
                  ),
                ],
              ),
            ),
            
            // Expand/Collapse Toggle Button (Useful for Mouse/Touch)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: IconButton(
                icon: Icon(
                  _isExpanded ? Icons.keyboard_double_arrow_left : Icons.keyboard_double_arrow_right,
                  color: Colors.white54,
                ),
                onPressed: _toggleExpanded,
                hoverColor: Colors.white10,
                splashRadius: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final bool autofocus;
  final bool isExpanded;

  const _SidebarItem({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
    this.autofocus = false,
    this.isExpanded = true,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    const primary = AppColors.primary; // Muted glowing blue
    final active = widget.selected || _focused;

    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (f) {
        setState(() => _focused = f);
      },
      onKey: (node, event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.gameButtonA) {
            widget.onTap();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            // Explicitly force focus to the right content area
            FocusScope.of(context).focusInDirection(TraversalDirection.right);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: InkWell(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: EdgeInsets.symmetric(
            horizontal: widget.isExpanded ? 16 : 8, 
            vertical: 4
          ),
          padding: EdgeInsets.symmetric(
            vertical: 12, 
            horizontal: widget.isExpanded ? 16 : 0
          ),
          decoration: BoxDecoration(
            color: active ? primary.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(10), // Fully rounded pills
            border: Border.all(
              color: active ? primary.withOpacity(0.5) : Colors.transparent,
              width: 1,
            ),
            boxShadow: _focused ? [
              BoxShadow(
                color: primary.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 1,
              )
            ] : null,
          ),
          child: Row(
            mainAxisAlignment: widget.isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  color: active ? primary : Colors.white54,
                  size: 24, // slightly larger icon for collapsed view
                ),
                if (widget.isExpanded) const SizedBox(width: 12),
              ],
              if (widget.isExpanded)
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: active ? primary : Colors.white70,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
