import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/bayt_motion.dart';
import '../../../core/animations/bayt_transitions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/arabic_normalizer.dart';
import '../../../core/widgets/bayt_ornaments.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../data/models/meter.dart';
import '../../../data/models/poem.dart';
import '../../providers/database_providers.dart';
import '../../widgets/corpus_filter_bar.dart';
import '../reader/poem_reader_screen.dart';

class ThemePoemsScreen extends ConsumerStatefulWidget {
  const ThemePoemsScreen({super.key, required this.theme});

  final ThemeCategory theme;

  @override
  ConsumerState<ThemePoemsScreen> createState() => _ThemePoemsScreenState();
}

class _ThemePoemsScreenState extends ConsumerState<ThemePoemsScreen> {
  static const _pageSize = 50;

  final ScrollController _scrollCtrl = ScrollController();
  final List<PoemSummary> _poems = [];
  CorpusFilterState _filter = const CorpusFilterState();
  int _offset = 0;
  bool _hasMore = true;
  bool _initialLoading = true;
  bool _filtering = false;
  bool _loadingMore = false;
  int _reqGen = 0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    // Start background isolate query immediately in parallel with the route slide!
    _reload(isInitial: true);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _initialLoading || _filtering) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 340) {
      _loadNextPage();
    }
  }

  void _onFilterChanged(CorpusFilterState next) {
    setState(() {
      _filter = next;
      _filtering = true;
    });
    _reload();
  }

  Future<void> _reload({bool isInitial = false}) async {
    final gen = ++_reqGen;
    if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
    if (!isInitial && mounted) {
      setState(() {
        _filtering = true;
        _loadingMore = false;
        _offset = 0;
        _hasMore = true;
      });
    }
    final batch = await ref
        .read(poetryRepositoryProvider)
        .getPoemsByThemeAsync(
          widget.theme.id,
          eraId: _filter.eraId,
          meterId: _filter.meterId,
          rhymeId: _filter.rhymeId,
          limit: _pageSize,
          offset: 0,
        );
    if (!mounted || gen != _reqGen) return;
    setState(() {
      _poems
        ..clear()
        ..addAll(batch);
      _offset = batch.length;
      _hasMore = batch.length >= _pageSize;
      _initialLoading = false;
      _filtering = false;
    });
  }

  Future<void> _loadNextPage() async {
    if (!_hasMore || _loadingMore) return;
    final gen = _reqGen;
    setState(() => _loadingMore = true);
    final batch = await ref
        .read(poetryRepositoryProvider)
        .getPoemsByThemeAsync(
          widget.theme.id,
          eraId: _filter.eraId,
          meterId: _filter.meterId,
          rhymeId: _filter.rhymeId,
          limit: _pageSize,
          offset: _offset,
        );
    if (!mounted || gen != _reqGen) return;
    setState(() {
      _poems.addAll(batch);
      _offset += batch.length;
      _hasMore = batch.length >= _pageSize;
      _loadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                'غرض ${widget.theme.name}',
                maxLines: 1,
                style: TextStyle(
                  fontFamily: AppFonts.ruqaa,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: p.ink,
                  height: 1.25,
                ),
              ),
            ),
            Text(
              '${ArabicNormalizer.toArabicNumber(widget.theme.poemCount)} قصيدة',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 10.5,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'قصيدة عشوائية من هذا الغرض',
            onPressed: () {
              final rnd = ref
                  .read(poetryRepositoryProvider)
                  .getRandomPoem(themeId: widget.theme.id);
              if (rnd != null) {
                BaytNav.pushDrop(context, PoemReaderScreen(poemId: rnd.id));
              }
            },
            icon: Icon(Icons.auto_awesome_outlined, color: p.accent),
          ),
        ],
      ),
      body: Column(
        children: [
          CorpusFilterBar(
            filter: _filter,
            onChanged: _onFilterChanged,
            showEra: true,
            showMeter: true,
            showRhyme: true,
            showTheme: false,
          ),
          if (_filtering && !_initialLoading)
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
                : (_poems.isEmpty && !_filtering)
                ? const EmptyStateView(
                    icon: Icons.filter_alt_off_outlined,
                    title: 'لا توجد قصائد مطابقة',
                    subtitle: 'جرّب تغيير أو مسح أحد عوامل التصفية.',
                  )
                : ListView.separated(
                    controller: _scrollCtrl,
                    cacheExtent: 650,
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 30),
                    itemCount: _poems.length + (_loadingMore ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 7),
                    itemBuilder: (context, i) {
                      if (i >= _poems.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                      final poem = _poems[i];
                      return BaytPressable(
                        child: InkWell(
                          onTap: () => BaytNav.pushDrop(
                            context,
                            PoemReaderScreen(poemId: poem.id),
                          ),
                          borderRadius: BorderRadius.circular(13),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: p.surfaceElevated,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: p.hairline,
                                width: 0.85,
                              ),
                            ),
                            child: Row(
                              children: [
                                PoemRhymeBadge(rhymeName: poem.rhymeName),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment:
                                            AlignmentDirectional.centerStart,
                                        child: Text(
                                          poem.title,
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontFamily: AppFonts.scheherazade,
                                            fontSize: 17.5,
                                            color: p.ink,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: AlignmentDirectional
                                                  .centerStart,
                                              child: Text(
                                                '${poem.poetName}  •  ${poem.eraName}  •  ${poem.meterName}',
                                                maxLines: 1,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: p.inkMuted,
                                                    ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${ArabicNormalizer.toArabicNumber(poem.verseCount)} بيت',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(color: p.accent),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
