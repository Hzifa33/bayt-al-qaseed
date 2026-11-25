import 'dart:ui' as ui;

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
  final Set<int> _mountedTabs = {0};

  void _goToTab(int tabIndex) {
    if (tabIndex == _index) return;
    BaytNav.unfocus();
    HapticFeedback.selectionClick();
    setState(() {
      _mountedTabs.add(tabIndex);
      _index = tabIndex;
    });
  }

  Widget _buildTab(int i) {
    return switch (i) {
      0 => HomeScreen(
        onOpenErasTab: () => _goToTab(1),
        onOpenSearchTab: () => _goToTab(2),
      ),
      1 => const ErasScreen(),
      2 => const SearchScreen(),
      3 => const LibraryScreen(),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) {
          _goToTab(0);
        }
      },
      child: Scaffold(
        extendBody: true,
        body: Stack(
          fit: StackFit.expand,
          children: List.generate(4, (i) {
            final active = i == _index;
            final mounted = _mountedTabs.contains(i);
            return IgnorePointer(
              ignoring: !active,
              child: AnimatedOpacity(
                opacity: active ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 220),
                curve: active ? BaytMotion.easeOut : BaytMotion.exit,
                child: AnimatedScale(
                  scale: active ? 1.0 : 0.985,
                  duration: const Duration(milliseconds: 240),
                  curve: BaytMotion.easeOut,
                  child: TickerMode(
                    enabled: active,
                    child: mounted
                        ? RepaintBoundary(child: _buildTab(i))
                        : const SizedBox.shrink(),
                  ),
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

/// Truly floating frosted-glass capsule navigation bar with NO opaque rectangular
/// backdrop behind it — separated cleanly from scrolling content via:
/// 1. A feather-soft transparent-to-canvas scrim fade at the very bottom edge
/// 2. Real BackdropFilter frosted-glass blur inside the pill
/// 3. A luminous gold/ornament rim + calibrated floating elevation shadow
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

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // Whisper-soft bottom gradient scrim (NO solid bar background!)
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.55, 1.0],
                  colors: [
                    p.canvas.withValues(alpha: 0.0),
                    p.canvas.withValues(alpha: isDark ? 0.55 : 0.45),
                    p.canvas.withValues(alpha: isDark ? 0.90 : 0.85),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Floating Frosted-Glass Capsule
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.14),
                    blurRadius: 24,
                    spreadRadius: -3,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: p.accent.withValues(alpha: isDark ? 0.12 : 0.06),
                    blurRadius: 12,
                    spreadRadius: -2,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (isDark ? const Color(0xFF1E1C18) : p.surfaceElevated)
                              .withValues(alpha: isDark ? 0.84 : 0.88),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: p.ornament.withValues(
                          alpha: isDark ? 0.62 : 0.55,
                        ),
                        width: 1.15,
                      ),
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
                            duration: const Duration(milliseconds: 260),
                            curve: BaytMotion.easeOut,
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
                                  size: 20.5,
                                  color: active
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : p.ink.withValues(
                                          alpha: isDark ? 0.78 : 0.68,
                                        ),
                                ),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 240),
                                  curve: BaytMotion.easeOut,
                                  child: active
                                      ? Padding(
                                          padding: const EdgeInsets.only(
                                            right: 7,
                                          ),
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
            ),
          ),
        ),
      ],
    );
  }
}
