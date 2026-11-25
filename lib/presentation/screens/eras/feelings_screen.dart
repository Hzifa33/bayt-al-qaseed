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
              childAspectRatio: 0.94,
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

    return BaytPressable(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          BaytNav.pushEditorial(
            context,
            FeelingDetailScreen(rootFeeling: feeling),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: p.surfaceElevated,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: accent.withValues(alpha: 0.26),
              width: 0.95,
            ),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                accent.withValues(alpha: 0.13),
                p.surfaceElevated,
                p.surfaceElevated,
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.07),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: -18,
                bottom: -18,
                child: IgnorePointer(
                  child: Icon(
                    _feelingIcon(feeling.slug),
                    size: isHero ? 88 : 68,
                    color: accent.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(isHero ? 16 : 14),
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
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: accent.withValues(alpha: 0.30),
                              width: 0.9,
                            ),
                          ),
                          child: Icon(
                            _feelingIcon(feeling.slug),
                            color: accent,
                            size: isHero ? 20 : 17.5,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: p.surface.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.24),
                              width: 0.75,
                            ),
                          ),
                          child: Text(
                            '${ArabicNormalizer.toArabicNumber(totalNuances)} فرعاً',
                            style: TextStyle(
                              fontFamily: AppFonts.ui,
                              fontSize: 10.2,
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
                          fontSize: isHero ? 25 : 21.5,
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
                      const SizedBox(height: 11),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: feeling.children.take(6).map((c) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: p.surface.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.24),
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
                      Container(
                        padding: const EdgeInsets.only(top: 6),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: accent.withValues(alpha: 0.14),
                              width: 0.8,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  feeling.children
                                      .take(3)
                                      .map((e) => e.name)
                                      .join(' · '),
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontFamily: AppFonts.ui,
                                    fontSize: 10.3,
                                    color: accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 11.5,
                              color: accent,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
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
                AnimatedSize(
                  duration: const Duration(milliseconds: 170),
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
                                          milliseconds: 140,
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
                      separatorBuilder: (_, __) => const SizedBox(height: 11),
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
          duration: const Duration(milliseconds: 145),
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

/// Manuscript-style Emotion Verse Card — clean editorial framing with top
/// diamond ornament, balanced centered couplet, and zero heavy side borders.
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

    return BaytPressable(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 13, 16, 12),
          decoration: BoxDecoration(
            color: p.surfaceElevated,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accent.withValues(alpha: 0.22),
              width: 0.9,
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [accent.withValues(alpha: 0.045), p.surfaceElevated],
              stops: const [0.0, 0.45],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Subtle manuscript top ornament divider
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 0.7,
                      color: accent.withValues(alpha: 0.18),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Container(
                      width: 6,
                      height: 6,
                      transform: Matrix4.rotationZ(0.785398),
                      transformAlignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 0.7,
                      color: accent.withValues(alpha: 0.18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Centered, balanced classical couplet (zero side stripe, zero truncation!)
              if (hit.matchedSadr.isNotEmpty)
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      hit.matchedSadr,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.scheherazade,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: p.ink,
                        height: 1.55,
                      ),
                    ),
                  ),
                ),
              if (hit.matchedAjuz.isNotEmpty) ...[
                const SizedBox(height: 3),
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      hit.matchedAjuz,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.scheherazade,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: p.ink,
                        height: 1.55,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Clean editorial footer
              Container(
                padding: const EdgeInsets.only(top: 9),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: p.hairline, width: 0.8),
                  ),
                ),
                child: Row(
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
                                  ?.copyWith(color: p.inkMuted, fontSize: 10.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.5,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.11),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.22),
                          width: 0.75,
                        ),
                      ),
                      child: Text(
                        'البيت $verseNum',
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 10.2,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
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
}
