import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/bayt_transitions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/arabic_normalizer.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/poet_card.dart';
import '../../../data/models/era.dart';
import '../../../data/models/meter.dart';
import '../../../data/models/poet.dart';
import '../../providers/app_providers.dart';
import '../../providers/database_providers.dart';
import '../../providers/user_data_providers.dart';
import 'feelings_screen.dart';
import 'meter_poems_screen.dart';
import 'poet_detail_screen.dart';
import 'poets_screen.dart';
import 'theme_poems_screen.dart';

class ErasScreen extends ConsumerStatefulWidget {
  const ErasScreen({super.key});

  @override
  ConsumerState<ErasScreen> createState() => _ErasScreenState();
}

class _ErasScreenState extends ConsumerState<ErasScreen>
    with TickerProviderStateMixin {
  TabController? _tabCtrl;
  int _tabCount = 5;

  void _ensureTabController(int count) {
    if (_tabCtrl != null && _tabCount == count) return;
    _tabCtrl?.dispose();
    _tabCount = count;
    _tabCtrl = TabController(length: count, vsync: this);
    _tabCtrl!.addListener(() {
      if (_tabCtrl!.indexIsChanging) {
        BaytNav.unfocus();
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final eras = ref.watch(erasProvider);
    final meters = ref.watch(metersProvider);
    final themes = ref.watch(themesProvider);
    final feelings = ref.watch(feelingsTreeProvider);
    final hasExpandedTabs = themes.isNotEmpty && feelings.isNotEmpty;
    _ensureTabController(hasExpandedTabs ? 5 : 3);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الموسوعة والدواوين'),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: hasExpandedTabs,
          tabAlignment: hasExpandedTabs
              ? TabAlignment.start
              : TabAlignment.fill,
          indicatorColor: p.accent,
          labelColor: p.accent,
          unselectedLabelColor: p.inkMuted,
          dividerColor: p.hairline,
          tabs: [
            const Tab(
              icon: Icon(Icons.hourglass_bottom_rounded, size: 17),
              text: 'العصور',
            ),
            const Tab(
              icon: Icon(Icons.history_edu_rounded, size: 17),
              text: 'الشعراء',
            ),
            const Tab(
              icon: Icon(Icons.waves_rounded, size: 17),
              text: 'البحور',
            ),
            if (hasExpandedTabs) ...[
              const Tab(
                icon: Icon(Icons.category_outlined, size: 17),
                text: 'الأغراض',
              ),
              const Tab(
                icon: Icon(Icons.psychology_outlined, size: 17),
                text: 'المشاعر',
              ),
            ],
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _KeepAliveTab(child: _ErasListTab(eras: eras)),
          const _PoetsDirectoryTab(),
          _KeepAliveTab(child: _MetersListTab(meters: meters)),
          if (hasExpandedTabs) ...[
            _KeepAliveTab(child: _ThemesListTab(themes: themes)),
            _KeepAliveTab(child: FeelingsExplorerView(roots: feelings)),
          ],
        ],
      ),
    );
  }
}

/// Keeps heavy tabs alive once built so switching back is instantaneous (0ms).
class _KeepAliveTab extends StatefulWidget {
  const _KeepAliveTab({required this.child});
  final Widget child;

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RepaintBoundary(child: widget.child);
  }
}

class _ErasListTab extends StatelessWidget {
  const _ErasListTab({required this.eras});
  final List<Era> eras;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 104),
      itemCount: eras.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final era = eras[i];
        return InkWell(
          onTap: () => BaytNav.pushEditorial(context, PoetsScreen(era: era)),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            decoration: BoxDecoration(
              color: p.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.hairline),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.accentSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    ArabicNormalizer.toArabicNumber(era.displayOrder),
                    style: TextStyle(
                      fontFamily: AppFonts.ruqaa,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: p.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'العصر ${era.name}',
                            style: TextStyle(
                              fontFamily: AppFonts.ruqaa,
                              fontSize: 19.5,
                              fontWeight: FontWeight.w700,
                              color: p.ink,
                              height: 1.25,
                            ),
                          ),
                          if (era.periodHint.isNotEmpty)
                            Text(
                              era.periodHint,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: p.accent, fontSize: 11),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        era.subtitle,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontSize: 12, height: 1.45),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.history_edu_rounded,
                                size: 12.5,
                                color: p.accent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${ArabicNormalizer.toArabicNumber(era.poetCount)} شاعراً',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_stories_outlined,
                                size: 12.5,
                                color: p.accent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${ArabicNormalizer.toArabicNumber(era.poemCount)} قصيدة',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 15,
                  color: p.inkMuted,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Async, paginated, debounced 17,244-poet directory running SQLite queries
/// off the UI thread for effortless 120fps tab transitions & scrolling.
class _PoetsDirectoryTab extends ConsumerStatefulWidget {
  const _PoetsDirectoryTab();

  @override
  ConsumerState<_PoetsDirectoryTab> createState() => _PoetsDirectoryTabState();
}

class _PoetsDirectoryTabState extends ConsumerState<_PoetsDirectoryTab>
    with AutomaticKeepAliveClientMixin {
  static const _pageSize = 50;

  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();

  String _filter = '';
  PoetSortBy _sort = PoetSortBy.poemsDesc;
  bool _ascending = false;
  final List<Poet> _poets = [];
  int _offset = 0;
  bool _hasMore = true;
  bool _initialLoading = true;
  bool _searching = false;
  bool _loadingMore = false;
  int _reqGen = 0;
  Timer? _debounce;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _resetAndLoad(isInitial: true);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _initialLoading || _searching) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 320) {
      _loadNextPage();
    }
  }

  void _onQueryChanged(String value) {
    setState(() {
      _filter = value;
      _searching = true;
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 85), () {
      if (mounted) _resetAndLoad();
    });
  }

  void _onSortChanged(PoetSortBy sort) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_sort == sort) {
        _ascending = !_ascending;
      } else {
        _sort = sort;
        _ascending =
            sort == PoetSortBy.alphabetical || sort == PoetSortBy.oldest;
      }
      _searching = true;
    });
    _resetAndLoad();
  }

  void _toggleSortDirection() {
    HapticFeedback.selectionClick();
    setState(() {
      _ascending = !_ascending;
      _searching = true;
    });
    _resetAndLoad();
  }

  Future<void> _resetAndLoad({bool isInitial = false}) async {
    final gen = ++_reqGen;
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.jumpTo(0);
    }
    setState(() {
      if (isInitial) _initialLoading = true;
      _searching = true;
      _loadingMore = false;
      _offset = 0;
      _hasMore = true;
    });
    final batch = await ref
        .read(poetryRepositoryProvider)
        .getPoetsAsync(
          filterQuery: _filter,
          sortBy: _sort,
          ascending: _ascending,
          limit: _pageSize,
          offset: 0,
        );
    if (!mounted || gen != _reqGen) return;
    setState(() {
      _poets
        ..clear()
        ..addAll(batch);
      _offset = batch.length;
      _hasMore = batch.length >= _pageSize;
      _initialLoading = false;
      _searching = false;
    });
  }

  Future<void> _loadNextPage() async {
    if (!_hasMore || _loadingMore) return;
    final gen = _reqGen;
    setState(() => _loadingMore = true);
    final batch = await ref
        .read(poetryRepositoryProvider)
        .getPoetsAsync(
          filterQuery: _filter,
          sortBy: _sort,
          ascending: _ascending,
          limit: _pageSize,
          offset: _offset,
        );
    if (!mounted || gen != _reqGen) return;
    setState(() {
      _poets.addAll(batch);
      _offset += batch.length;
      _hasMore = batch.length >= _pageSize;
      _loadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = context.palette;
    final favPoetIds = ref.watch(userDataProvider).favoritePoetIds;

    return RepaintBoundary(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              onChanged: _onQueryChanged,
              onTapOutside: (_) => _searchFocus.unfocus(),
              decoration: InputDecoration(
                hintText: 'ابحث باسم الشاعر (مثلاً: المتنبي، جرير، مارية)…',
                prefixIcon: Icon(Icons.search_rounded, color: p.inkMuted),
                suffixIcon: _filter.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchCtrl.clear();
                          _onQueryChanged('');
                          _searchFocus.requestFocus();
                        },
                        icon: Icon(Icons.close_rounded, color: p.inkMuted),
                      )
                    : null,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ActionChip(
                    visualDensity: VisualDensity.compact,
                    avatar: AnimatedRotation(
                      turns: _ascending ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutBack,
                      child: Icon(
                        Icons.arrow_downward_rounded,
                        size: 15,
                        color: p.accent,
                      ),
                    ),
                    label: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Text(
                        _ascending ? 'تصاعدي' : 'تنازلي',
                        key: ValueKey<bool>(_ascending),
                        style: TextStyle(
                          color: p.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    onPressed: _toggleSortDirection,
                  ),
                ),
                ...PoetSortBy.values.map((s) {
                  final selected = _sort == s;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      selected: selected,
                      visualDensity: VisualDensity.compact,
                      label: Text(s.label),
                      onSelected: (_) => _onSortChanged(s),
                    ),
                  );
                }),
              ],
            ),
          ),
          if (_searching && !_initialLoading)
            LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation(p.accent),
            )
          else
            const SizedBox(height: 2),
          Expanded(
            child: _initialLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: p.accent,
                      strokeWidth: 2.2,
                    ),
                  )
                : (_poets.isEmpty && !_searching)
                ? const EmptyStateView(
                    icon: Icons.person_search_outlined,
                    title: 'لا يوجد شاعرٌ مطابق',
                    subtitle: 'جرّب كتابة جزءٍ من الاسم دون تشكيل.',
                  )
                : ListView.separated(
                    controller: _scrollCtrl,
                    cacheExtent: 600,
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 104),
                    itemCount: _poets.length + (_loadingMore ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      if (i >= _poets.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: p.accent,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        );
                      }
                      final poet = _poets[i];
                      return PoetCard(
                        poet: poet,
                        showEra: true,
                        isFavorite: favPoetIds.contains(poet.id),
                        onTap: () => BaytNav.pushEditorial(
                          context,
                          PoetDetailScreen(poetId: poet.id),
                        ),
                        onToggleFavorite: () => ref
                            .read(userDataProvider.notifier)
                            .toggleFavoritePoet(poet.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MetersListTab extends StatelessWidget {
  const _MetersListTab({required this.meters});
  final List<Meter> meters;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 104),
      itemCount: meters.length,
      separatorBuilder: (_, __) => const SizedBox(height: 9),
      itemBuilder: (context, i) {
        final m = meters[i];
        return InkWell(
          onTap: () =>
              BaytNav.pushEditorial(context, MeterPoemsScreen(meter: m)),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(
              color: p.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.hairline),
            ),
            child: Row(
              children: [
                Icon(Icons.waves_rounded, size: 19, color: p.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'بحر ${m.name}',
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: AppFonts.ruqaa,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: p.accentSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${ArabicNormalizer.toArabicNumber(m.poemCount)} قصيدة',
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: p.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 14,
                  color: p.inkMuted,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ThemesListTab extends StatelessWidget {
  const _ThemesListTab({required this.themes});
  final List<ThemeCategory> themes;

  IconData _themeIcon(String slug) => switch (slug) {
    'alnasib' => Icons.favorite_outline_rounded,
    'almadih' => Icons.workspace_premium_outlined,
    'alhikma' => Icons.lightbulb_outline_rounded,
    'alritha' => Icons.water_drop_outlined,
    'alhija' => Icons.bolt_outlined,
    'alitab' => Icons.chat_bubble_outline_rounded,
    'alzuhd' => Icons.spa_outlined,
    'alhamasa' => Icons.shield_outlined,
    'alwasf' => Icons.landscape_outlined,
    _ => Icons.category_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 104),
      itemCount: themes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final th = themes[i];
        return InkWell(
          onTap: () =>
              BaytNav.pushEditorial(context, ThemePoemsScreen(theme: th)),
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: p.surfaceElevated,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: p.hairline),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: p.accentSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_themeIcon(th.slug), size: 20, color: p.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                th.name,
                                maxLines: 1,
                                style: TextStyle(
                                  fontFamily: AppFonts.ruqaa,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: p.ink,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: p.accentSoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${ArabicNormalizer.toArabicNumber(th.poemCount)} قصيدة',
                              style: TextStyle(
                                fontFamily: AppFonts.ui,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: p.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Full readable description — never truncated with ellipsis!
                      Text(
                        th.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11.8,
                          color: p.inkMuted,
                          height: 1.48,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 14,
                  color: p.inkMuted,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
