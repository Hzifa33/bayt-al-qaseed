import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/bayt_motion.dart';
import '../../../core/animations/bayt_transitions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/arabic_normalizer.dart';
import '../../../core/widgets/bayt_ornaments.dart';
import '../../../data/models/meter.dart';
import '../../providers/database_providers.dart';
import '../reader/poem_reader_screen.dart';

Color _feelingAccent(String rootSlug, Color fallback) => switch (rootSlug) {
  'alsurur' => const Color(0xFFB37A2A),
  'alhuzn' => const Color(0xFF476985),
  'altaajjub' => const Color(0xFF6B538C),
  'alghadab' => const Color(0xFFA64B3C),
  'alkhawf' => const Color(0xFF3E6E64),
  'alishmizaz' => const Color(0xFF7B6B43),
  'aldiq' => const Color(0xFF6B5B53),
  _ => fallback,
};

IconData _feelingIcon(String rootSlug) => switch (rootSlug) {
  'alsurur' => Icons.wb_sunny_outlined,
  'alhuzn' => Icons.water_drop_outlined,
  'altaajjub' => Icons.auto_awesome_outlined,
  'alghadab' => Icons.local_fire_department_outlined,
  'alkhawf' => Icons.shield_outlined,
  'alishmizaz' => Icons.visibility_off_outlined,
  'aldiq' => Icons.cloud_outlined,
  _ => Icons.psychology_outlined,
};

String _feelingMotto(String rootSlug) => switch (rootSlug) {
  'alsurur' => 'أبيات الفرح والفخر والسكينة والودّ والأمل',
  'alhuzn' => 'مراثي الوجد والأسى والغربة والحنين والندم',
  'altaajjub' => 'روائع الدهشة والانبهار والحماسة والحيرة',
  'alghadab' => 'ثورة الإباء والسخط والغيرة والعتاب والبطش',
  'alkhawf' => 'خلجات الوجل والخشية والقلق والرهبة',
  'alishmizaz' => 'مواقف الاستنكار واللوم والنفور والهجاء',
  'aldiq' => 'شكوى السأم والكرب والتعب وضيق الصدر',
  _ => 'رحلة وجدانية في عيون الشعر العربي',
};

/// Redesigned Editorial Emotion Atlas (أطلس المشاعر الشعرية):
/// Bento grid presentation with a full-width hero card + balanced 2-column grid.
class FeelingsExplorerView extends StatelessWidget {
  const FeelingsExplorerView({super.key, required this.roots});

  final List<Feeling> roots;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (roots.isEmpty) return const SizedBox.shrink();

    final hero = roots.first;
    final rest = roots.skip(1).toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'أطلسُ المشاعر الشعرية',
                  style: TextStyle(
                    fontFamily: AppFonts.ruqaa,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'اختر الحالة الوجدانية لتنتقل مباشرةً إلى الأبيات المعنيّة داخل القصائد.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: p.inkMuted, fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
        ),

        // Full-width Hero Emotion Card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
            child: _EmotionAtlasCard(feeling: hero, isHero: true),
          ),
        ),

        // 2-Column Editorial Bento Grid for remaining 6 primary emotions
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 108),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.96,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _EmotionAtlasCard(feeling: rest[i]),
              childCount: rest.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmotionAtlasCard extends StatelessWidget {
  const _EmotionAtlasCard({required this.feeling, this.isHero = false});

  final Feeling feeling;
  final bool isHero;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final accent = _feelingAccent(feeling.slug, p.accent);
    final totalNuances = feeling.children.fold<int>(
      feeling.children.length,
      (acc, c) => acc + c.children.length,
    );

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        BaytNav.pushEditorial(
          context,
          FeelingDetailScreen(rootFeeling: feeling),
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: EdgeInsets.all(isHero ? 16 : 13),
        decoration: BoxDecoration(
          color: p.surfaceElevated,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: accent.withValues(alpha: 0.28),
            width: 0.95,
          ),
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [accent.withValues(alpha: 0.11), p.surfaceElevated],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: isHero ? 42 : 36,
                  height: isHero ? 42 : 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _feelingIcon(feeling.slug),
                    color: accent,
                    size: isHero ? 21 : 18,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${ArabicNormalizer.toArabicNumber(totalNuances)} فرعاً',
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isHero ? 12 : 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                feeling.name,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: AppFonts.ruqaa,
                  fontSize: isHero ? 24 : 21,
                  fontWeight: FontWeight.w700,
                  color: p.ink,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _feelingMotto(feeling.slug),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: isHero ? 12 : 11,
                color: p.inkMuted,
                height: 1.45,
              ),
            ),
            if (isHero && feeling.children.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: feeling.children.take(6).map((c) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: p.surface.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      c.name,
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: p.ink, fontSize: 10.8),
                    ),
                  );
                }).toList(),
              ),
            ] else ...[
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        feeling.children.take(3).map((e) => e.name).join(' · '),
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 10.2,
                          color: accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 12,
                    color: accent,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Interactive Emotion & Direct-Verse Explorer:
/// Features a 2-tier Mood Selector (Branch Rail + Animated Sub-Nuance Matrix)
/// and surfaces exact matching verses that jump straight to that verse in the reader.
class FeelingDetailScreen extends ConsumerStatefulWidget {
  const FeelingDetailScreen({super.key, required this.rootFeeling});

  final Feeling rootFeeling;

  @override
  ConsumerState<FeelingDetailScreen> createState() =>
      _FeelingDetailScreenState();
}

class _FeelingDetailScreenState extends ConsumerState<FeelingDetailScreen> {
  static const _pageSize = 30;

  final ScrollController _scrollCtrl = ScrollController();
  Feeling? _selectedBranch;
  late Feeling _activeFeeling;

  final List<FeelingVerseHit> _hits = [];
  int _totalMatched = 0;
  int _offset = 0;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  int _reqGen = 0;

  @override
  void initState() {
    super.initState();
    _activeFeeling = widget.rootFeeling;
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reloadVerses();
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loading || _loadingMore) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 340) {
      _loadNextPage();
    }
  }

  void _selectFeeling(Feeling target, {Feeling? branch}) {
    if (target.slug == _activeFeeling.slug &&
        branch?.slug == _selectedBranch?.slug) {
      return;
    }
    HapticFeedback.selectionClick();
    if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
    setState(() {
      _selectedBranch = branch;
      _activeFeeling = target;
    });
    _reloadVerses();
  }

  Future<void> _reloadVerses() async {
    final gen = ++_reqGen;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _offset = 0;
      _hasMore = true;
    });
    final res = await ref
        .read(poetryRepositoryProvider)
        .getFeelingVerseHitsAsync(
          _activeFeeling,
          rootSlug: widget.rootFeeling.slug,
          limit: _pageSize,
          offset: 0,
        );
    if (!mounted || gen != _reqGen) return;
    setState(() {
      _hits
        ..clear()
        ..addAll(res.hits);
      _totalMatched = res.totalMatchedPoems;
      _offset = res.hits.length;
      _hasMore = res.hasMore;
      _loading = false;
    });
  }

  Future<void> _loadNextPage() async {
    if (!_hasMore || _loadingMore) return;
    final gen = _reqGen;
    setState(() => _loadingMore = true);
    final res = await ref
        .read(poetryRepositoryProvider)
        .getFeelingVerseHitsAsync(
          _activeFeeling,
          rootSlug: widget.rootFeeling.slug,
          limit: _pageSize,
          offset: _offset,
        );
    if (!mounted || gen != _reqGen) return;
    setState(() {
      _hits.addAll(res.hits);
      _totalMatched = res.totalMatchedPoems;
      _offset += res.hits.length;
      _hasMore = res.hasMore;
      _loadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final accent = _feelingAccent(widget.rootFeeling.slug, p.accent);
    final branches = widget.rootFeeling.children;
    final subLeaves = _selectedBranch?.children ?? const <Feeling>[];
    final breadcrumb = _selectedBranch == null
        ? widget.rootFeeling.name
        : _activeFeeling.slug == _selectedBranch!.slug
        ? '${widget.rootFeeling.name}  ›  ${_selectedBranch!.name}'
        : '${widget.rootFeeling.name}  ›  ${_selectedBranch!.name}  ›  ${_activeFeeling.name}';

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
                'مشاعر ${widget.rootFeeling.name}',
                maxLines: 1,
                style: TextStyle(
                  fontFamily: AppFonts.ruqaa,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: p.ink,
                  height: 1.2,
                ),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                _loading
                    ? breadcrumb
                    : '$breadcrumb  •  ${ArabicNormalizer.toArabicNumber(_totalMatched)} شاهداً',
                maxLines: 1,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(fontSize: 10.8, color: accent),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Smart 2-Tier Mood Selector Panel
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: p.surface.withValues(alpha: 0.65),
              border: Border(bottom: BorderSide(color: p.hairline, width: 0.8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tier 1: Branch Pill Rail
                if (branches.isNotEmpty)
                  SizedBox(
                    height: 46,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                      children: [
                        _MoodBranchPill(
                          label: 'الكل',
                          selected:
                              _activeFeeling.slug == widget.rootFeeling.slug,
                          accent: accent,
                          onTap: () =>
                              _selectFeeling(widget.rootFeeling, branch: null),
                        ),
                        ...branches.map((br) {
                          final selected = _selectedBranch?.slug == br.slug;
                          return _MoodBranchPill(
                            label: br.name,
                            hasChildren: br.children.isNotEmpty,
                            selected: selected,
                            accent: accent,
                            onTap: () => _selectFeeling(br, branch: br),
                          );
                        }),
                      ],
                    ),
                  ),

                // Tier 2: Expandable Sub-Nuance Matrix (all visible cleanly at once!)
                AnimatedSize(
                  duration: const Duration(milliseconds: 240),
                  curve: BaytMotion.easeOut,
                  child: subLeaves.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                            decoration: BoxDecoration(
                              color: p.surfaceElevated,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.24),
                                width: 0.85,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.tune_rounded,
                                      size: 13.5,
                                      color: accent,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'ظلال ${_selectedBranch!.name} الدقيقة:',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: accent,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: subLeaves.map((leaf) {
                                    final selected =
                                        _activeFeeling.slug == leaf.slug;
                                    return InkWell(
                                      onTap: () {
                                        if (selected &&
                                            _selectedBranch != null) {
                                          _selectFeeling(
                                            _selectedBranch!,
                                            branch: _selectedBranch,
                                          );
                                        } else {
                                          _selectFeeling(
                                            leaf,
                                            branch: _selectedBranch,
                                          );
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(999),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 11,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? accent
                                              : accent.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: Border.all(
                                            color: selected
                                                ? accent
                                                : accent.withValues(
                                                    alpha: 0.25,
                                                  ),
                                            width: 0.85,
                                          ),
                                        ),
                                        child: Text(
                                          leaf.name,
                                          style: TextStyle(
                                            fontFamily: AppFonts.ui,
                                            fontSize: 11.8,
                                            fontWeight: selected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: selected
                                                ? Theme.of(context)
                                                      .colorScheme
                                                      .onPrimary
                                                : p.ink,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          // Matching Verses Feed (Direct Jump to Exact Verse in Poem!)
          Expanded(
            child: AnimatedSwitcher(
              duration: BaytMotion.popover,
              switchInCurve: BaytMotion.easeOut,
              child: _loading
                  ? Center(
                      key: const ValueKey('loading'),
                      child: CircularProgressIndicator(
                        color: accent,
                        strokeWidth: 2.2,
                      ),
                    )
                  : _hits.isEmpty
                  ? Center(
                      key: const ValueKey('empty'),
                      child: Text(
                        'لا توجد أبيات مطابقة لهذا التفرّع حالياً',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: p.inkMuted),
                      ),
                    )
                  : ListView.separated(
                      key: ValueKey(_activeFeeling.slug),
                      controller: _scrollCtrl,
                      cacheExtent: 650,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                      itemCount: _hits.length + (_loadingMore ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        if (i >= _hits.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: accent,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        }
                        final hit = _hits[i];
                        return _FeelingVerseCard(
                          hit: hit,
                          accent: accent,
                          onTap: () => BaytNav.pushDrop(
                            context,
                            PoemReaderScreen(
                              poemId: hit.poemId,
                              initialVerseIndex: hit.matchedVerseIndex,
                              isRawVerseIndex: true,
                              highlightMatchedVerseOnce: true,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodBranchPill extends StatelessWidget {
  const _MoodBranchPill({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.hasChildren = false,
  });

  final String label;
  final bool selected;
  final bool hasChildren;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(left: 7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 190),
          curve: BaytMotion.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? accent : p.surfaceElevated,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? accent : p.hairline,
              width: 0.9,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 12.2,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? Theme.of(context).colorScheme.onPrimary
                      : p.ink,
                ),
              ),
              if (hasChildren) ...[
                const SizedBox(width: 4),
                Icon(
                  selected
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_left_rounded,
                  size: 14,
                  color: selected
                      ? Theme.of(context).colorScheme.onPrimary
                      : p.inkMuted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FeelingVerseCard extends StatelessWidget {
  const _FeelingVerseCard({
    required this.hit,
    required this.accent,
    required this.onTap,
  });

  final FeelingVerseHit hit;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final verseNum = ArabicNormalizer.toArabicNumber(hit.matchedVerseIndex + 1);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 11),
        decoration: BoxDecoration(
          color: p.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.hairline, width: 0.9),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Exact Matched Verse Quote (never truncated!)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(11),
                border: Border(right: BorderSide(color: accent, width: 2.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hit.matchedSadr.isNotEmpty)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        hit.matchedSadr,
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: AppFonts.scheherazade,
                          fontSize: 18.5,
                          color: p.ink,
                          height: 1.55,
                        ),
                      ),
                    ),
                  if (hit.matchedAjuz.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerEnd,
                      child: Text(
                        hit.matchedAjuz,
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: AppFonts.scheherazade,
                          fontSize: 18.5,
                          color: p.ink,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 9),
            // Poem & Poet Footer with Rhyme Badge + Direct Verse Jump Indicator
            Row(
              children: [
                PoemRhymeBadge(
                  rhymeName: hit.rhymeName,
                  size: 28,
                  accentColor: accent,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          '${hit.poetName}  •  ${hit.eraName}',
                          maxLines: 1,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: p.ink,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          '${hit.title}  •  بحر ${hit.meterName}',
                          maxLines: 1,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: p.inkMuted, fontSize: 10.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'البيت $verseNum',
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
