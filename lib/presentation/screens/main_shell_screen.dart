import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
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
    setState(() => _index = tabIndex);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final pages = [
      HomeScreen(
        onOpenErasTab: () => _goToTab(1),
        onOpenSearchTab: () => _goToTab(2),
      ),
      const ErasScreen(),
      const SearchScreen(),
      const LibraryScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: p.hairline, width: 0.8)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _goToTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book_rounded),
              label: 'الدواوين',
            ),
            NavigationDestination(
              icon: Icon(Icons.search_rounded),
              selectedIcon: Icon(Icons.search_rounded),
              label: 'البحث',
            ),
            NavigationDestination(
              icon: Icon(Icons.bookmarks_outlined),
              selectedIcon: Icon(Icons.bookmarks_rounded),
              label: 'مكتبتي',
            ),
          ],
        ),
      ),
    );
  }
}
