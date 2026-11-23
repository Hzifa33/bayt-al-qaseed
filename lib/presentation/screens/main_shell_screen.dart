import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/animations/bayt_motion.dart';
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

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) {
          _goToTab(0);
        }
      },
      child: Scaffold(
        extendBody: false,
        body: Stack(
          fit: StackFit.expand,
          children: List.generate(pages.length, (i) {
            final active = i == _index;
            return IgnorePointer(
              ignoring: !active,
              child: AnimatedOpacity(
                opacity: active ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 210),
                curve: active ? BaytMotion.easeOut : BaytMotion.exit,
                child: AnimatedScale(
                  scale: active ? 1.0 : 0.985,
                  duration: const Duration(milliseconds: 240),
                  curve: BaytMotion.easeOut,
                  child: TickerMode(enabled: active, child: pages[i]),
                ),
              ),
            );
          }),
        ),
        bottomNavigationBar: _SculptedFloatingNavBar(
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
    activeIcon: Icons.search_rounded,
  ),
  _NavItemData(
    label: 'مكتبتي',
    icon: Icons.bookmarks_outlined,
    activeIcon: Icons.bookmarks_rounded,
  ),
];

/// Ultra-clean, sculpted floating capsule navigation bar.
///
/// The active destination smoothly expands horizontally into a warm antique-gold
/// pill displaying `[Icon + Label]`, while inactive tabs remain light, minimalist
/// icons — delivering modern refinement with quiet Neo-Heritage poise.
class _SculptedFloatingNavBar extends StatelessWidget {
  const _SculptedFloatingNavBar({
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: p.canvas,
        border: Border(
          top: BorderSide(
            color: p.hairline.withValues(alpha: 0.55),
            width: 0.7,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(
              color: p.surfaceElevated.withValues(alpha: isDark ? 0.95 : 0.97),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: p.ornament.withValues(alpha: isDark ? 0.42 : 0.36),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.09),
                  blurRadius: 22,
                  spreadRadius: -4,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_navItems.length, (i) {
                final item = _navItems[i];
                final active = i == selectedIndex;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelect(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.symmetric(
                      horizontal: active ? 16 : 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: active ? p.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          active ? item.activeIcon : item.icon,
                          size: 21,
                          color: active
                              ? Theme.of(context).colorScheme.onPrimary
                              : p.inkMuted,
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          child: active
                              ? Padding(
                                  padding: const EdgeInsets.only(right: 7),
                                  child: Text(
                                    item.label,
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontFamily: AppFonts.ui,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
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
