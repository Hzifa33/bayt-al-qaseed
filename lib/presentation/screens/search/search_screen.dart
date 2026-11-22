import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../eras/poet_detail_screen.dart';
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
  Timer? _debounce;
  SearchFilter _filter = const SearchFilter();
  SearchBundle? _bundle;
  bool _isSearching = false;
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
    _debounce?.cancel();
    _ctrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _isSearching = false;
        _bundle = null;
      });
      return;
    }
    // Set searching state immediately so "لم يتم العثور" NEVER flashes prematurely!
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 220), _executeSearch);
  }

  void _executeSearch({bool saveHistory = false}) {
    final q = _ctrl.text.trim();
    if (q.isEmpty) {
      setState(() {
        _isSearching = false;
        _bundle = null;
      });
      return;
    }
    if (saveHistory) _saveRecentQuery(q);
    final res = ref
        .read(poetryRepositoryProvider)
        .search(rawQuery: q, filter: _filter, poemLimit: 80, poetLimit: 12);
    if (!mounted) return;
    setState(() {
      _bundle = res;
      _isSearching = false;
    });
  }

  void _applySuggestion(String text) {
    _searchFocus.unfocus();
    _ctrl.text = text;
    _ctrl.selection = TextSelection.collapsed(offset: text.length);
    setState(() => _isSearching = true);
    Future.microtask(() => _executeSearch(saveHistory: true));
  }

  int get _activeFilterCount {
    var c = 0;
    if (_filter.eraId != null) c++;
    if (_filter.meterId != null) c++;
    if (_filter.rhymeId != null) c++;
    return c;
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
      setState(() {
        _filter = updated;
        if (_ctrl.text.trim().isNotEmpty) _isSearching = true;
      });
      if (_ctrl.text.trim().isNotEmpty) {
        Future.microtask(_executeSearch);
      }
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
          // 1. Clean Search Input Field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _ctrl,
              focusNode: _searchFocus,
              autofocus: false,
              onChanged: _onQueryChanged,
              onTapOutside: (_) => _searchFocus.unfocus(),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) {
                _searchFocus.unfocus();
                setState(() => _isSearching = true);
                Future.microtask(() => _executeSearch(saveHistory: true));
              },
              decoration: InputDecoration(
                hintText: 'ابحث في الأبيات أو الشعراء…',
                prefixIcon: Icon(Icons.search_rounded, color: p.accent),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(
                        tooltip: 'مسح النص',
                        onPressed: () {
                          _debounce?.cancel();
                          _ctrl.clear();
                          setState(() {
                            _isSearching = false;
                            _bundle = null;
                          });
                          _searchFocus.requestFocus();
                        },
                        icon: Icon(Icons.close_rounded, color: p.inkMuted),
                      )
                    : null,
              ),
            ),
          ),

          // 2. Simple, Crystal-Clear Single-Row Search Controls
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                // Toggle 1: Same-Verse vs Exact Consecutive Phrase
                Expanded(
                  child: _SimpleOptionPill(
                    icon: _filter.matchMode == SearchMatchMode.exactSequence
                        ? Icons.format_quote_rounded
                        : Icons.view_headline_rounded,
                    label: _filter.matchMode == SearchMatchMode.exactSequence
                        ? 'عبارة متتابعة'
                        : 'في نفس البيت',
                    active: _filter.matchMode == SearchMatchMode.exactSequence,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      final next =
                          _filter.matchMode == SearchMatchMode.sameVerse
                          ? SearchMatchMode.exactSequence
                          : SearchMatchMode.sameVerse;
                      setState(() {
                        _filter = _filter.copyWith(matchMode: next);
                        if (_ctrl.text.trim().isNotEmpty) _isSearching = true;
                      });
                      if (_ctrl.text.trim().isNotEmpty) {
                        Future.microtask(_executeSearch);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Toggle 2: Partial Word (قل -> قلب) vs Whole Word (قل فقط)
                Expanded(
                  child: _SimpleOptionPill(
                    icon: _filter.matchPartialWords
                        ? Icons.short_text_rounded
                        : Icons.space_bar_rounded,
                    label: _filter.matchPartialWords
                        ? 'بداية الكلمة'
                        : 'كلمة تامة',
                    active: !_filter.matchPartialWords,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _filter = _filter.copyWith(
                          matchPartialWords: !_filter.matchPartialWords,
                        );
                        if (_ctrl.text.trim().isNotEmpty) _isSearching = true;
                      });
                      if (_ctrl.text.trim().isNotEmpty) {
                        Future.microtask(_executeSearch);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Unified Classification Button (Era / Meter / Rhyme)
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
            child: _ctrl.text.trim().isEmpty
                ? _buildInitialSuggestions(context)
                : _isSearching && _bundle == null
                ? Center(
                    child: CircularProgressIndicator(
                      color: p.accent,
                      strokeWidth: 2.2,
                    ),
                  )
                : _bundle == null
                ? const SizedBox.shrink()
                : _buildResults(context, _bundle!),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialSuggestions(BuildContext context) {
    final p = context.palette;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 108),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Clear 2-line helper explaining the two simple search toggles
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: p.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تلميح للبحث الدقيق',
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(color: p.accent),
                ),
                const SizedBox(height: 4),
                Text(
                  '• «في نفس البيت» يجمع الكلمات داخل البيت الواحد، و«عبارة متتابعة» يشترط الترتيب.\n'
                  '• «بداية الكلمة» يجعل البحث عن «قل» يُظهر «قلب» و«قليل»، بينما «كلمة تامة» يطابق «قل» وحدها.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(height: 1.7),
                ),
              ],
            ),
          ),
          if (_recentQueries.isNotEmpty) ...[
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'عمليات البحث الأخيرة',
                  style: Theme.of(context).textTheme.titleSmall,
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
          Text(
            'مقترحات من عيون الشعر:',
            style: Theme.of(context).textTheme.titleSmall,
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

    // Never show "not found" while a fresh query is still running!
    if (!_isSearching && bundle.poems.isEmpty && bundle.poets.isEmpty) {
      return EmptyStateView(
        icon: Icons.search_off_rounded,
        title: 'لا توجد نتائج مطابقة',
        subtitle: _filter.matchMode == SearchMatchMode.exactSequence
            ? 'جرّب التبديل إلى «في نفس البيت» أو اختيار «بداية الكلمة».'
            : 'جرّب كلماتٍ أخرى أو أزل التصفية بالعصر أو البحر.',
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
            child: Text(
              'عُثر على ${ArabicNormalizer.toArabicNumber(bundle.poems.length)} قصيدة'
              '${bundle.poets.isNotEmpty ? ' و${ArabicNormalizer.toArabicNumber(bundle.poets.length)} شاعر' : ''}',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: p.accent, fontWeight: FontWeight.w600),
            ),
          ),
        ),

        // Matched Poets Strip
        if (bundle.poets.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: SizedBox(
              height: 68,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: bundle.poets.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final poet = bundle.poets[i];
                  return InkWell(
                    onTap: () {
                      _saveRecentQuery(bundle.query);
                      BaytNav.pushEditorial(
                        context,
                        PoetDetailScreen(poetId: poet.id),
                      );
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: p.accentSoft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: p.accent.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            poet.namePlain,
                            style: TextStyle(
                              fontFamily: AppFonts.ruqaa,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              color: p.ink,
                            ),
                          ),
                          Text(
                            'العصر ${poet.eraName}  •  ${ArabicNormalizer.toArabicNumber(poet.poemCount)} قصيدة',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
        ],

        // Clean Verse-Only Search Result Cards (NO word-by-word highlighting!)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 106),
          sliver: SliverList.separated(
            itemCount: bundle.poems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 9),
            itemBuilder: (context, i) {
              final hit = bundle.poems[i];
              final verseStyle = TextStyle(
                fontFamily: AppFonts.scheherazade,
                fontSize: 20,
                color: p.ink,
                height: 1.85,
              );
              return InkWell(
                onTap: () {
                  _saveRecentQuery(bundle.query);
                  BaytNav.pushDrop(
                    context,
                    PoemReaderScreen(
                      poemId: hit.poemId,
                      initialVerseIndex: hit.matchedVerseIndex,
                      highlightMatchedVerseOnce: true,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: p.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: p.hairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Clean verse display without highlighting individual words
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: p.surface.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              hit.matchedSadr,
                              textAlign: TextAlign.right,
                              style: verseStyle,
                            ),
                            if (hit.matchedAjuz.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 22),
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
                            size: 14,
                            color: p.accent,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            hit.poetName,
                            style: TextStyle(
                              fontFamily: AppFonts.ui,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: p.accent,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '•  ${hit.eraName}  •  بحر ${hit.meterName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                          if (hit.matchingVersesCount > 1)
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
                                  fontSize: 10.5,
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
            Icon(icon, size: 15, color: active ? p.accent : p.inkMuted),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 11.8,
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

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'تصفية نتائج البحث',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _draft = SearchFilter(
                          matchMode: _draft.matchMode,
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
              Text(
                'العصر الأدبي',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: widget.eras.map((e) {
                  final sel = _draft.eraId == e.id;
                  return ChoiceChip(
                    selected: sel,
                    visualDensity: VisualDensity.compact,
                    label: Text(e.name),
                    onSelected: (_) => setState(() {
                      _draft = sel
                          ? _draft.copyWith(clearEra: true)
                          : _draft.copyWith(eraId: e.id);
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Text(
                'البحر العروضي',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: widget.meters.take(16).map((m) {
                  final sel = _draft.meterId == m.id;
                  return ChoiceChip(
                    selected: sel,
                    visualDensity: VisualDensity.compact,
                    label: Text(m.name),
                    onSelected: (_) => setState(() {
                      _draft = sel
                          ? _draft.copyWith(clearMeter: true)
                          : _draft.copyWith(meterId: m.id);
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Text('حرف الرويّ', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: widget.rhymes.take(28).map((r) {
                  final sel = _draft.rhymeId == r.id;
                  return ChoiceChip(
                    selected: sel,
                    visualDensity: VisualDensity.compact,
                    label: Text(r.name),
                    onSelected: (_) => setState(() {
                      _draft = sel
                          ? _draft.copyWith(clearRhyme: true)
                          : _draft.copyWith(rhymeId: r.id);
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.pop(context, _draft),
                child: const Text('تطبيق التصفية'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
