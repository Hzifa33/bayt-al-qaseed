import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/animations/bayt_transitions.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import 'eras/eras_screen.dart';
import 'home/home_screen.dart';
import 'library/library_screen.dart';
import 'search/search_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _index = 0;

  void _goToTab(int tabIndex) {
    if (tabIndex == _index) return;
    BaytNav.unfocus();
    HapticFeedback.selectionClick();
    setState(() => _index = tabIndex);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        onOpenErasTab: () => _goToTab(1),
        onOpenSearchTab: () => _goToTab(2),
      ),
      const ErasScreen(),
      const SearchScreen(),
      const LibraryScreen(),
    ];

    // Requirement #5: Back on any non-Home tab returns cleanly to Home first.
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) {
          _goToTab(0);
        }
      },
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(index: _index, children: pages),
        bottomNavigationBar: _FloatingHeritageNavBar(
          selectedIndex: _index,
          onSelect: _goToTab,
        ),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

const _navItems = [
  _NavItemData(
    label: 'الرئيسية',
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
  ),
  _NavItemData(
    label: 'الدواوين',
    icon: Icons.auto_stories_outlined,
    activeIcon: Icons.auto_stories_rounded,
  ),
  _NavItemData(
    label: 'البحث',
    icon: Icons.search_rounded,
    activeIcon: Icons.manage_search_rounded,
  ),
  _NavItemData(
    label: 'مكتبتي',
    icon: Icons.bookmarks_outlined,
    activeIcon: Icons.bookmarks_rounded,
  ),
];

/// Floating Neo-Heritage Pill Bottom Bar with double hairline frame and smooth
/// animated sliding highlight pill.
class _FloatingHeritageNavBar extends StatelessWidget {
  const _FloatingHeritageNavBar({
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
        child: Container(
          height: 66,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: p.surfaceElevated.withValues(alpha: isDark ? 0.94 : 0.96),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: p.ornament.withValues(alpha: 0.48),
              width: 1.05,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.10),
                blurRadius: 24,
                spreadRadius: -4,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: p.accent.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(21),
              border: Border.all(
                color: p.hairline.withValues(alpha: 0.65),
                width: 0.65,
              ),
            ),
            child: Row(
              children: List.generate(_navItems.length, (i) {
                final item = _navItems[i];
                final active = i == selectedIndex;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelect(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: active ? p.accentSoft : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: active
                              ? p.accent.withValues(alpha: 0.32)
                              : Colors.transparent,
                          width: 0.9,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedScale(
                            scale: active ? 1.08 : 0.95,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutBack,
                            child: Icon(
                              active ? item.activeIcon : item.icon,
                              size: 21,
                              color: active ? p.accent : p.inkMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.label,
                            maxLines: 1,
                            style: TextStyle(
                              fontFamily: AppFonts.ui,
                              fontSize: 11,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: active ? p.accent : p.inkMuted,
                              height: 1.15,
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 240),
                            margin: const EdgeInsets.only(top: 2),
                            width: active ? 12 : 0,
                            height: 2,
                            decoration: BoxDecoration(
                              color: p.accent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
