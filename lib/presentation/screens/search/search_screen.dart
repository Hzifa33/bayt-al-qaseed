import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/arabic_normalizer.dart';
import '../../../core/widgets/empty_state_view.dart';
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
  final TextEditingController _ctrl = TextEditingController();
  Timer? _debounce;
  SearchFilter _filter = const SearchFilter();
  SearchBundle? _bundle;

  static const _quickSuggestions = [
    'لا تعذليه',
    'على قدر أهل العزم',
    'قفا نبك',
    'سيف الدولة',
    'يا ليل الصب',
    'المتنبي',
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _bundle = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 140), _executeSearch);
  }

  void _executeSearch() {
    final q = _ctrl.text.trim();
    if (q.isEmpty) {
      setState(() => _bundle = null);
      return;
    }
    final res = ref
        .read(poetryRepositoryProvider)
        .search(rawQuery: q, filter: _filter, poemLimit: 80, poetLimit: 12);
    setState(() => _bundle = res);
  }

  void _applySuggestion(String text) {
    _ctrl.text = text;
    _ctrl.selection = TextSelection.collapsed(offset: text.length);
    _executeSearch();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final eras = ref.watch(erasProvider);
    final meters = ref.watch(metersProvider);
    final rhymes = ref.watch(rhymesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('البحث الفوري')),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
            child: TextField(
              controller: _ctrl,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _executeSearch(),
              decoration: InputDecoration(
                hintText: 'ابحث في ١٬١٦٢٬٠٠٠ بيت أو شاعر (بالتشكيل أو بدونه)…',
                prefixIcon: Icon(Icons.search_rounded, color: p.accent),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _ctrl.clear();
                          setState(() => _bundle = null);
                        },
                        icon: Icon(Icons.close_rounded, color: p.inkMuted),
                      )
                    : null,
              ),
            ),
          ),

          // Precision Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                FilterChip(
                  selected: _filter.exactPhrase,
                  label: const Text('عبارة مطابقة'),
                  onSelected: (v) {
                    setState(() => _filter = _filter.copyWith(exactPhrase: v));
                    _executeSearch();
                  },
                ),
                const SizedBox(width: 8),
                _SearchFilterPill(
                  label: _filter.eraId == null
                      ? 'العصر'
                      : eras.firstWhere((e) => e.id == _filter.eraId).name,
                  active: _filter.eraId != null,
                  onTap: () => _pickFilter(
                    title: 'تصفية حسب العصر',
                    items: eras.map((e) => (e.id, 'العصر ${e.name}')).toList(),
                    current: _filter.eraId,
                    onPick: (id) {
                      setState(() {
                        _filter = id == null
                            ? _filter.copyWith(clearEra: true)
                            : _filter.copyWith(eraId: id);
                      });
                      _executeSearch();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                _SearchFilterPill(
                  label: _filter.meterId == null
                      ? 'البحر'
                      : meters.firstWhere((m) => m.id == _filter.meterId).name,
                  active: _filter.meterId != null,
                  onTap: () => _pickFilter(
                    title: 'تصفية حسب البحر العروضي',
                    items: meters.map((m) => (m.id, 'بحر ${m.name}')).toList(),
                    current: _filter.meterId,
                    onPick: (id) {
                      setState(() {
                        _filter = id == null
                            ? _filter.copyWith(clearMeter: true)
                            : _filter.copyWith(meterId: id);
                      });
                      _executeSearch();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                _SearchFilterPill(
                  label: _filter.rhymeId == null
                      ? 'الرويّ'
                      : 'قافية (${rhymes.firstWhere((r) => r.id == _filter.rhymeId).name})',
                  active: _filter.rhymeId != null,
                  onTap: () => _pickFilter(
                    title: 'تصفية حسب حرف الرويّ',
                    items: rhymes
                        .map((r) => (r.id, 'قافية (${r.name})'))
                        .toList(),
                    current: _filter.rhymeId,
                    onPick: (id) {
                      setState(() {
                        _filter = id == null
                            ? _filter.copyWith(clearRhyme: true)
                            : _filter.copyWith(rhymeId: id);
                      });
                      _executeSearch();
                    },
                  ),
                ),
                if (_filter.hasActiveFilters) ...[
                  const SizedBox(width: 8),
                  ActionChip(
                    label: const Text('إعادة ضبط'),
                    onPressed: () {
                      setState(() => _filter = const SearchFilter());
                      _executeSearch();
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Results Area
          Expanded(
            child: _bundle == null
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
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.manage_search_rounded, size: 42, color: p.ornament),
          const SizedBox(height: 12),
          Text(
            'ابحث في ذاكرة الشعر العربي',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'محرك FTS5 يعالج الهمزات والتاء المربوطة والتشكيل تلقائياً خلال أجزاء من الثانية.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 22),
          Text('جرّب البحث عن:', style: Theme.of(context).textTheme.titleSmall),
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
    if (bundle.poems.isEmpty && bundle.poets.isEmpty) {
      return const EmptyStateView(
        icon: Icons.search_off_rounded,
        title: 'لا توجد نتائج مطابقة',
        subtitle: 'جرّب كلمات أقل أو أزل أحد فلاتر العصر أو البحر.',
      );
    }

    return CustomScrollView(
      slivers: [
        // Speed & Count Telemetry Banner
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
            child: Text(
              'عُثر على ${ArabicNormalizer.toArabicNumber(bundle.poems.length)} قصيدة'
              '${bundle.poets.isNotEmpty ? ' و${ArabicNormalizer.toArabicNumber(bundle.poets.length)} شاعر' : ''}'
              ' خلال ${bundle.elapsedMs.toStringAsFixed(1)} مللي ثانية',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: p.accent),
            ),
          ),
        ),

        // Matched Poets Strip
        if (bundle.poets.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                itemCount: bundle.poets.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final poet = bundle.poets[i];
                  return InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PoetDetailScreen(poetId: poet.id),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
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
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: p.ink,
                            ),
                          ),
                          Text(
                            'العصر ${poet.eraName} • ${ArabicNormalizer.toArabicNumber(poet.poemCount)} قصيدة',
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
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
        ],

        // Matched Poems & Highlighted Verses
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
          sliver: SliverList.separated(
            itemCount: bundle.poems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final hit = bundle.poems[i];
              final verseStyle = TextStyle(
                fontFamily: AppFonts.scheherazade,
                fontSize: 20,
                color: p.ink,
                height: 1.85,
              );
              return InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PoemReaderScreen(
                      poemId: hit.poemId,
                      initialVerseIndex: hit.matchedVerseIndex,
                      highlightQuery: bundle.query,
                    ),
                  ),
                ),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: p.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: p.hairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RichText(
                        textDirection: TextDirection.rtl,
                        text: TextSpan(
                          children: ArabicNormalizer.buildHighlightedSpans(
                            originalText: hit.matchedSadr,
                            rawQuery: bundle.query,
                            baseStyle: verseStyle,
                            highlightBackground: p.highlightFill,
                            highlightForeground: p.ink,
                          ),
                        ),
                      ),
                      if (hit.matchedAjuz.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 22),
                          child: RichText(
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.left,
                            text: TextSpan(
                              children: ArabicNormalizer.buildHighlightedSpans(
                                originalText: hit.matchedAjuz,
                                rawQuery: bundle.query,
                                baseStyle: verseStyle,
                                highlightBackground: p.highlightFill,
                                highlightForeground: p.ink,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            hit.poetName,
                            style: TextStyle(
                              fontFamily: AppFonts.ui,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: p.accent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '•  ${hit.eraName}  •  بحر ${hit.meterName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall,
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

  Future<void> _pickFilter({
    required String title,
    required List<(int, String)> items,
    required int? current,
    required void Function(int?) onPick,
  }) async {
    final p = context.palette;
    final res = await showModalBottomSheet<int?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, -1),
                    child: Text('الكل', style: TextStyle(color: p.accent)),
                  ),
                ],
              ),
            ),
            const Divider(),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final (id, label) = items[i];
                  return ListTile(
                    title: Text(label),
                    trailing: id == current
                        ? Icon(Icons.check_rounded, color: p.accent)
                        : null,
                    onTap: () => Navigator.pop(ctx, id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (res == -1) {
      onPick(null);
    } else if (res != null) {
      onPick(res);
    }
  }
}

class _SearchFilterPill extends StatelessWidget {
  const _SearchFilterPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? p.accentSoft : p.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? p.accent.withValues(alpha: 0.45) : p.hairline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 12.5,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? p.accent : p.ink,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: active ? p.accent : p.inkMuted,
            ),
          ],
        ),
      ),
    );
  }
}
