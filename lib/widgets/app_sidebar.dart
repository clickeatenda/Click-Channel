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
  bool _isExpanded = false;
  late FocusNode _activeTabFocusNode;

  @override
  void initState() {
    super.initState();
    _activeTabFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _activeTabFocusNode.dispose();
    super.dispose();
  }

  // Called when a sidebar item gets focused
  void _onItemFocused() {
    if (!_isExpanded) {
      setState(() => _isExpanded = true);
    }
  }

  // Called when a sidebar item loses focus (to check if whole sidebar lost focus)
  void _onItemBlurred() {
    // Use post-frame so the next focused widget is known
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Check if focus is still within the sidebar
      final focus = FocusManager.instance.primaryFocus;
      // If focus moved outside the sidebar subtree, collapse
      if (focus != null && !_activeTabFocusNode.context.toString().contains(focus.toString())) {
        // simpler: just check if none of our known items have focus
        if (!_isAnyItemFocused()) {
          setState(() => _isExpanded = false);
        }
      }
    });
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  bool _isAnyItemFocused() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null || focus.context == null) return false;
    
    bool isInsideSidebar = false;
    focus.context!.visitAncestorElements((element) {
      if (element.widget is AppSidebar) {
        isInsideSidebar = true;
        return false; // Stop visiting
      }
      return true; // Continue visiting
    });
    return isInsideSidebar;
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

    return AnimatedContainer(
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
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                  _SidebarItem(
                    label: 'Início',
                    icon: Icons.home_outlined,
                    selected: widget.selectedIndex == 0,
                    isExpanded: _isExpanded,
                    onTap: () => _navigate(0),
                    onFocused: _onItemFocused,
                    onBlurred: _onItemBlurred,
                    autofocus: widget.selectedIndex == 0,
                    focusNode: widget.selectedIndex == 0 ? _activeTabFocusNode : null,
                  ),
                  _SidebarItem(
                    label: 'Filmes',
                    icon: Icons.movie_outlined,
                    selected: widget.selectedIndex == 1,
                    isExpanded: _isExpanded,
                    onTap: () => _navigate(1),
                    onFocused: _onItemFocused,
                    onBlurred: _onItemBlurred,
                    focusNode: widget.selectedIndex == 1 ? _activeTabFocusNode : null,
                  ),
                  _SidebarItem(
                    label: 'Séries',
                    icon: Icons.tv_outlined,
                    selected: widget.selectedIndex == 2,
                    isExpanded: _isExpanded,
                    onTap: () => _navigate(2),
                    onFocused: _onItemFocused,
                    onBlurred: _onItemBlurred,
                    focusNode: widget.selectedIndex == 2 ? _activeTabFocusNode : null,
                  ),
                  _SidebarItem(
                    label: 'Canais',
                    icon: Icons.live_tv_outlined,
                    selected: widget.selectedIndex == 3,
                    isExpanded: _isExpanded,
                    onTap: () => _navigate(3),
                    onFocused: _onItemFocused,
                    onBlurred: _onItemBlurred,
                    focusNode: widget.selectedIndex == 3 ? _activeTabFocusNode : null,
                  ),
                  _SidebarItem(
                    label: 'SharkFlix',
                    icon: Icons.subscriptions_outlined,
                    selected: widget.selectedIndex == 4,
                    isExpanded: _isExpanded,
                    onTap: () => _navigate(4),
                    onFocused: _onItemFocused,
                    onBlurred: _onItemBlurred,
                    focusNode: widget.selectedIndex == 4 ? _activeTabFocusNode : null,
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
                    onFocused: _onItemFocused,
                    onBlurred: _onItemBlurred,
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
                    focusNode: widget.selectedIndex == 10 ? _activeTabFocusNode : null,
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
                    focusNode: widget.selectedIndex == 11 ? _activeTabFocusNode : null,
                  ),
                ],
              ),
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
      );
  }
}

class _SidebarItem extends StatefulWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onFocused;
  final VoidCallback? onBlurred;
  final bool autofocus;
  final bool isExpanded;
  final FocusNode? focusNode;

  const _SidebarItem({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
    this.onFocused,
    this.onBlurred,
    this.autofocus = false,
    this.isExpanded = true,
    this.focusNode,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (f) {
        setState(() => _focused = f);
        if (f) {
          widget.onFocused?.call();
        } else {
          widget.onBlurred?.call();
        }
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.gameButtonA) {
            widget.onTap();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: InkWell(
        onTap: () {
          if (!widget.selected) {
            widget.onTap();
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: widget.selected 
                ? AppColors.primary.withOpacity(0.15) 
                : (_focused ? Colors.white.withOpacity(0.05) : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.selected 
                  ? AppColors.primary.withOpacity(0.5) 
                  : (_focused ? AppColors.primary : Colors.transparent),
              width: widget.selected || _focused ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: widget.isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              if (widget.isExpanded) const SizedBox(width: 16),
              Icon(
                widget.icon,
                color: widget.selected ? AppColors.primary : (_focused ? Colors.white : Colors.white54),
                size: 24,
              ),
              if (widget.isExpanded) ...[
                const SizedBox(width: 16),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.selected ? AppColors.primary : (_focused ? Colors.white : Colors.white70),
                    fontWeight: widget.selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
