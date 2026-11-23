import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/bayt_motion.dart';
import '../../../core/animations/bayt_transitions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/arabic_normalizer.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../data/models/era.dart';
import '../../../data/models/meter.dart';
import '../../../data/models/search_result.dart';
import '../../providers/app_providers.dart';
import '../../providers/database_providers.dart';
import '../reader/poem_reader_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  static const _kHistoryKey = 'recent_search_queries';
  static const _quickSuggestions = [
    'لا تعذليه',
    'على قدر أهل العزم',
    'قفا نبك',
    'سيف الدولة',
    'يا ليل الصب',
    'أراك عصي الدمع',
  ];

  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _returnFlashTimer;

  // Search strictly uses contiguous character sequence (الحروف المتتابعة) + multi-select filters
  SearchFilter _filter = const SearchFilter(
    matchMode: SearchMatchMode.exactSequence,
    matchPartialWords: true,
  );
  SearchBundle? _bundle;
  bool _isSearching = false;
  int _searchSeq = 0;
  int? _recentlyReadPoemId;
  List<String> _recentQueries = const [];

  @override
  void initState() {
    super.initState();
    _loadRecentQueries();
  }

  void _loadRecentQueries() {
    final prefs = ref.read(appServicesProvider)?.prefs;
    if (prefs == null) return;
    setState(() {
      _recentQueries = prefs.getStringList(_kHistoryKey) ?? const [];
    });
  }

  void _saveRecentQuery(String q) {
    final trimmed = q.trim();
    if (trimmed.length < 2) return;
    final prefs = ref.read(appServicesProvider)?.prefs;
    if (prefs == null) return;
    final updated = [
      trimmed,
      ..._recentQueries.where((e) => e != trimmed),
    ].take(8).toList();
    prefs.setStringList(_kHistoryKey, updated);
    setState(() => _recentQueries = updated);
  }

  @override
  void dispose() {
    _returnFlashTimer?.cancel();
    _ctrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    // Do NOT trigger search while typing; wait until the user presses Enter/Search!
    if (value.trim().isEmpty) {
      _searchSeq++;
      setState(() {
        _isSearching = false;
        _bundle = null;
      });
    } else {
      setState(() {});
    }
  }

  void _showExceededCapToast() {
    if (!mounted) return;
    final p = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Ultra-high contrast in BOTH Dark & Light mode so it stands out unmistakably!
    final bgColor = isDark ? p.accent : const Color(0xFF231A11);
    final titleColor = isDark
        ? const Color(0xFF14110C)
        : const Color(0xFFE8C885);
    final bodyColor = isDark
        ? const Color(0xFF1E1912)
        : const Color(0xFFFAF6EE);
    final badgeBg = isDark
        ? const Color(0xFF18140E).withValues(alpha: 0.16)
        : const Color(0xFFE8C885).withValues(alpha: 0.18);

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 82),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.35) : p.accent,
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: badgeBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 19,
                  color: titleColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تجاوزت النتائج ٢٠٠ قصيدة',
                      style: TextStyle(
                        fontFamily: AppFonts.ui,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    Text(
                      'ضيّق بحثك بحروف إضافية أو استخدم التصفية للوصول الدقيق.',
                      style: TextStyle(
                        fontFamily: AppFonts.ui,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: bodyColor,
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

  Future<void> _executeSearch({bool saveHistory = false}) async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) {
      _searchSeq++;
      setState(() {
        _isSearching = false;
        _bundle = null;
      });
      return;
    }
    _searchFocus.unfocus();
    if (saveHistory) _saveRecentQuery(q);
    final seq = ++_searchSeq;
    setState(() => _isSearching = true);
    final res = await ref
        .read(poetryRepositoryProvider)
        .searchAsync(
          rawQuery: q,
          filter: _filter,
          poemLimit: 200,
          poetLimit: 0,
        );
    if (!mounted || seq != _searchSeq) return;
    setState(() {
      _bundle = res;
      _isSearching = false;
    });
    if (res.hasMore) {
      _showExceededCapToast();
    }
  }

  void _applySuggestion(String text) {
    _searchFocus.unfocus();
    _ctrl.text = text;
    _ctrl.selection = TextSelection.collapsed(offset: text.length);
    setState(() => _isSearching = true);
    _executeSearch(saveHistory: true);
  }

  Future<void> _openPoemFromCard(
    BuildContext cardContext,
    PoemSearchHit hit,
    String query,
  ) async {
    _saveRecentQuery(query);
    Offset? cardOrigin;
    final renderObj = cardContext.findRenderObject();
    if (renderObj is RenderBox && renderObj.hasSize) {
      cardOrigin = renderObj.localToGlobal(renderObj.size.center(Offset.zero));
    }

    await BaytNav.pushDrop(
      context,
      PoemReaderScreen(
        poemId: hit.poemId,
        initialVerseIndex: hit.matchedVerseIndex,
        highlightMatchedVerseOnce: true,
      ),
      origin: cardOrigin,
    );

    if (!mounted) return;
    // Highlight the card the user just returned from for ~2.5s so they never lose their place!
    _returnFlashTimer?.cancel();
    setState(() => _recentlyReadPoemId = hit.poemId);
    _returnFlashTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) {
        setState(() => _recentlyReadPoemId = null);
      }
    });
  }

  int get _activeFilterCount => _filter.activeFilterCount;

  void _updateFilterAndSearch(SearchFilter next) {
    setState(() {
      _filter = next.copyWith(matchMode: SearchMatchMode.exactSequence);
      if (_ctrl.text.trim().isNotEmpty) _isSearching = true;
    });
    if (_ctrl.text.trim().isNotEmpty) {
      _executeSearch();
    }
  }

  Future<void> _openUnifiedFiltersSheet(
    List<Era> eras,
    List<Meter> meters,
    List<Rhyme> rhymes,
  ) async {
    BaytNav.unfocus();
    final updated = await showModalBottomSheet<SearchFilter>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SearchFiltersSheet(
        initial: _filter,
        eras: eras,
        meters: meters,
        rhymes: rhymes,
      ),
    );
    if (updated != null) {
      _updateFilterAndSearch(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final eras = ref.watch(erasProvider);
    final meters = ref.watch(metersProvider);
    final rhymes = ref.watch(rhymesProvider);
    final filterCount = _activeFilterCount;

    return Scaffold(
      appBar: AppBar(title: const Text('البحث في الديوان')),
      body: Column(
        children: [
          // 1. Clean Search Input Field + Inline Multi-Select Filter Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _searchFocus,
                    autofocus: false,
                    onChanged: _onQueryChanged,
                    onTapOutside: (_) => _searchFocus.unfocus(),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _executeSearch(saveHistory: true),
                    decoration: InputDecoration(
                      hintText: 'ابحث بحروف متتابعة ثم اضغط إدخال…',
                      prefixIcon: IconButton(
                        tooltip: 'تنفيذ البحث',
                        onPressed: () => _executeSearch(saveHistory: true),
                        icon: Icon(Icons.search_rounded, color: p.accent),
                      ),
                      suffixIcon: _ctrl.text.isNotEmpty
                          ? IconButton(
                              tooltip: 'مسح النص',
                              onPressed: () {
                                _searchSeq++;
                                _ctrl.clear();
                                setState(() {
                                  _isSearching = false;
                                  _bundle = null;
                                });
                                _searchFocus.requestFocus();
                              },
                              icon: Icon(
                                Icons.close_rounded,
                                color: p.inkMuted,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _SimpleOptionPill(
                  icon: Icons.tune_rounded,
                  label: filterCount > 0
                      ? 'تصفية (${ArabicNormalizer.toArabicNumber(filterCount)})'
                      : 'تصفية',
                  active: filterCount > 0,
                  onTap: () => _openUnifiedFiltersSheet(eras, meters, rhymes),
                ),
              ],
            ),
          ),

          // Active Multi-Select Filter Tags Strip (tap any chip to remove)
          if (filterCount > 0)
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                children: [
                  for (final e in eras.where(
                    (e) => _filter.eraIds.contains(e.id),
                  ))
                    _ActiveFilterChip(
                      icon: Icons.hourglass_bottom_rounded,
                      label: e.name,
                      onRemove: () =>
                          _updateFilterAndSearch(_filter.withToggledEra(e.id)),
                    ),
                  for (final m in meters.where(
                    (m) => _filter.meterIds.contains(m.id),
                  ))
                    _ActiveFilterChip(
                      icon: Icons.waves_rounded,
                      label: m.name,
                      onRemove: () => _updateFilterAndSearch(
                        _filter.withToggledMeter(m.id),
                      ),
                    ),
                  for (final r in rhymes.where(
                    (r) => _filter.rhymeIds.contains(r.id),
                  ))
                    _ActiveFilterChip(
                      icon: Icons.music_note_outlined,
                      label: 'رويّ ${r.name}',
                      onRemove: () => _updateFilterAndSearch(
                        _filter.withToggledRhyme(r.id),
                      ),
                    ),
                ],
              ),
            ),

          if (_isSearching)
            LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation(p.accent),
            )
          else
            const SizedBox(height: 2),

          // 3. Results / Loading / Suggestions Area
          Expanded(
            child: _isSearching
                ? Center(
                    child: CircularProgressIndicator(
                      color: p.accent,
                      strokeWidth: 2.2,
                    ),
                  )
                : _bundle == null
                ? _buildInitialSuggestions(context)
                : _buildResults(context, _bundle!),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialSuggestions(BuildContext context) {
    final p = context.palette;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 108),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: p.hairline),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.tips_and_updates_outlined,
                  size: 19,
                  color: p.accent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'اكتب أيّ حروفٍ متتابعة بالتشكيل أو بدونه ثم اضغط زر البحث (إدخال) لتظهر لك الأبيات المطابقة في الديوان، ويمكنك التصفية بأكثر من عصر وبحر ورويّ معاً.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(height: 1.7),
                  ),
                ),
              ],
            ),
          ),
          if (_recentQueries.isNotEmpty) ...[
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.history_rounded, size: 16, color: p.accent),
                    const SizedBox(width: 6),
                    Text(
                      'عمليات البحث الأخيرة',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    ref.read(appServicesProvider)?.prefs.remove(_kHistoryKey);
                    setState(() => _recentQueries = const []);
                  },
                  child: Text('مسح', style: TextStyle(color: p.inkMuted)),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recentQueries
                  .map(
                    (s) => ActionChip(
                      avatar: Icon(
                        Icons.history_rounded,
                        size: 15,
                        color: p.inkMuted,
                      ),
                      label: Text(s),
                      onPressed: () => _applySuggestion(s),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: p.accent),
              const SizedBox(width: 6),
              Text(
                'مقترحات من عيون الشعر:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickSuggestions
                .map(
                  (s) => ActionChip(
                    avatar: Icon(
                      Icons.north_west_rounded,
                      size: 15,
                      color: p.accent,
                    ),
                    label: Text(s),
                    onPressed: () => _applySuggestion(s),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context, SearchBundle bundle) {
    final p = context.palette;

    if (!_isSearching && bundle.poems.isEmpty) {
      return const EmptyStateView(
        icon: Icons.search_off_rounded,
        title: 'لا توجد نتائج مطابقة',
        subtitle: 'تأكّد من تتابع الحروف أو أزل بعض خيارات التصفية إن وُجدت.',
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: bundle.hasMore
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: p.accent.withValues(
                        alpha: Theme.of(context).brightness == Brightness.dark
                            ? 0.22
                            : 0.13,
                      ),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: p.accent.withValues(alpha: 0.72),
                        width: 1.15,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: p.accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'تجاوزت النتائج ٢٠٠ قصيدة • عُرضت أول ٢٠٠ قصيدة، أضف حروفاً أخرى أو استخدم التصفية لتضييق البحث.',
                            style: TextStyle(
                              fontFamily: AppFonts.ui,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: p.ink,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Row(
                    children: [
                      Icon(
                        Icons.auto_stories_outlined,
                        size: 15,
                        color: p.accent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'عُثر على ${ArabicNormalizer.toArabicNumber(bundle.poems.length)} قصيدة',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: p.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),

        // Clean Verse-Only Search Result Cards with Return-Origin Highlight
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 98),
          sliver: SliverList.separated(
            itemCount: bundle.poems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 9),
            itemBuilder: (context, i) {
              final hit = bundle.poems[i];
              final wasJustRead = _recentlyReadPoemId == hit.poemId;
              final verseStyle = TextStyle(
                fontFamily: AppFonts.scheherazade,
                fontSize: 19.5,
                color: p.ink,
                height: 1.82,
              );
              return BaytStaggeredItem(
                index: i,
                child: Builder(
                  builder: (cardContext) {
                    return BaytPressable(
                      child: InkWell(
                        onTap: () =>
                            _openPoemFromCard(cardContext, hit, bundle.query),
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 420),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: wasJustRead
                                ? p.accentSoft.withValues(alpha: 0.24)
                                : p.surfaceElevated,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: wasJustRead ? p.accent : p.hairline,
                              width: wasJustRead ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: wasJustRead
                                      ? p.surfaceElevated.withValues(alpha: 0.8)
                                      : p.surface.withValues(alpha: 0.72),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      hit.matchedSadr,
                                      textAlign: TextAlign.right,
                                      style: verseStyle,
                                    ),
                                    if (hit.matchedAjuz.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 22,
                                        ),
                                        child: Text(
                                          hit.matchedAjuz,
                                          textAlign: TextAlign.left,
                                          style: verseStyle,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.history_edu_rounded,
                                    size: 13.5,
                                    color: p.accent,
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    flex: 3,
                                    child: Text(
                                      hit.poetName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: AppFonts.ui,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: p.accent,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.waves_rounded,
                                    size: 12,
                                    color: p.inkMuted,
                                  ),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      '${hit.meterName}  •  ${hit.eraName}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                    ),
                                  ),
                                  if (wasJustRead)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: p.accent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'قرأتها للتو',
                                        style: TextStyle(
                                          fontFamily: AppFonts.ui,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimary,
                                        ),
                                      ),
                                    )
                                  else if (hit.matchingVersesCount > 1)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: p.accentSoft,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${ArabicNormalizer.toArabicNumber(hit.matchingVersesCount)} أبيات',
                                        style: TextStyle(
                                          fontFamily: AppFonts.ui,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: p.accent,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SimpleOptionPill extends StatelessWidget {
  const _SimpleOptionPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: active ? p.accentSoft : p.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? p.accent.withValues(alpha: 0.48) : p.hairline,
            width: 0.9,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15.5, color: active ? p.accent : p.inkMuted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? p.accent : p.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({
    required this.icon,
    required this.label,
    required this.onRemove,
  });

  final IconData icon;
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: InkWell(
        onTap: onRemove,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: p.accentSoft,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: p.accent.withValues(alpha: 0.4),
              width: 0.85,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: p.accent),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: p.accent,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.close_rounded, size: 13, color: p.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchFiltersSheet extends StatefulWidget {
  const _SearchFiltersSheet({
    required this.initial,
    required this.eras,
    required this.meters,
    required this.rhymes,
  });

  final SearchFilter initial;
  final List<Era> eras;
  final List<Meter> meters;
  final List<Rhyme> rhymes;

  @override
  State<_SearchFiltersSheet> createState() => _SearchFiltersSheetState();
}

class _SearchFiltersSheetState extends State<_SearchFiltersSheet> {
  late SearchFilter _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
  }

  Widget _buildSectionHeader({
    required BuildContext context,
    required IconData icon,
    required String title,
    required int count,
    required VoidCallback onClear,
  }) {
    final p = context.palette;
    return Row(
      children: [
        Icon(icon, size: 15.5, color: p.accent),
        const SizedBox(width: 6),
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: p.accentSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              ArabicNormalizer.toArabicNumber(count),
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: p.accent,
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onClear,
            child: Text(
              'مسح',
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: p.inkMuted,
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final totalSelected = _draft.activeFilterCount;
    final maxH = MediaQuery.sizeOf(context).height * 0.82;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.hairline,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.tune_rounded, size: 20, color: p.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تصفية نتائج البحث',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          'يمكنك اختيار أكثر من عصر أو بحر أو رويّ معاً',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  if (totalSelected > 0)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _draft = SearchFilter(
                            matchMode: SearchMatchMode.exactSequence,
                            matchPartialWords: _draft.matchPartialWords,
                          );
                        });
                      },
                      child: Text(
                        'إلغاء الكل',
                        style: TextStyle(color: p.accent),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSectionHeader(
                        context: context,
                        icon: Icons.hourglass_bottom_rounded,
                        title: 'العصر الأدبي',
                        count: _draft.eraIds.length,
                        onClear: () => setState(
                          () => _draft = _draft.copyWith(clearEras: true),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: widget.eras.map((e) {
                          final sel = _draft.eraIds.contains(e.id);
                          return FilterChip(
                            selected: sel,
                            showCheckmark: true,
                            visualDensity: VisualDensity.compact,
                            label: Text(e.name),
                            onSelected: (_) => setState(() {
                              _draft = _draft.withToggledEra(e.id);
                            }),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      _buildSectionHeader(
                        context: context,
                        icon: Icons.waves_rounded,
                        title: 'البحر العروضي',
                        count: _draft.meterIds.length,
                        onClear: () => setState(
                          () => _draft = _draft.copyWith(clearMeters: true),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: widget.meters.map((m) {
                          final sel = _draft.meterIds.contains(m.id);
                          return FilterChip(
                            selected: sel,
                            showCheckmark: true,
                            visualDensity: VisualDensity.compact,
                            label: Text(m.name),
                            onSelected: (_) => setState(() {
                              _draft = _draft.withToggledMeter(m.id);
                            }),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      _buildSectionHeader(
                        context: context,
                        icon: Icons.music_note_outlined,
                        title: 'حرف الرويّ',
                        count: _draft.rhymeIds.length,
                        onClear: () => setState(
                          () => _draft = _draft.copyWith(clearRhymes: true),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: widget.rhymes.map((r) {
                          final sel = _draft.rhymeIds.contains(r.id);
                          return FilterChip(
                            selected: sel,
                            showCheckmark: true,
                            visualDensity: VisualDensity.compact,
                            label: Text(r.name),
                            onSelected: (_) => setState(() {
                              _draft = _draft.withToggledRhyme(r.id);
                            }),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, _draft),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(
                  totalSelected > 0
                      ? 'تطبيق التصفية (${ArabicNormalizer.toArabicNumber(totalSelected)})'
                      : 'تطبيق التصفية',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
