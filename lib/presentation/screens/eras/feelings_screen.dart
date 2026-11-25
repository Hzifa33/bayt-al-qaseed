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
import '../../../data/models/verse.dart';
import '../../providers/database_providers.dart';
import '../../widgets/corpus_filter_bar.dart';
import '../reader/poem_reader_screen.dart';
import '../studio/poetry_card_studio_screen.dart';

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
  'alsurur' => 'الفرح والفخر والسكينة والأمل',
  'alhuzn' => 'الوجد والأسى والغربة والحنين',
  'altaajjub' => 'الدهشة والانبهار والحماسة والحيرة',
  'alghadab' => 'الإباء والسخط والغيرة والعتاب',
  'alkhawf' => 'الوجل والخشية والقلق والرهبة',
  'alishmizaz' => 'الاستنكار واللوم والنفور والهجاء',
  'aldiq' => 'السأم والكرب والتعب وضيق الصدر',
  _ => 'شواهد وجدانية من الشعر العربي',
};

/// Clean, minimalist Editorial Emotion Atlas (أطلس المشاعر الشعرية).
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
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'اختر الشعور للانتقال مباشرةً إلى الأبيات المعنيّة.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: p.inkMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),

        // Full-width featured emotion card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 9),
            child: _EmotionAtlasCard(feeling: hero, isHero: true),
          ),
        ),

        // Clean, compact 2-column grid for remaining 6 primary emotions
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 9,
              mainAxisSpacing: 9,
              childAspectRatio: 1.24,
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
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isHero ? 15 : 13,
            vertical: isHero ? 14 : 12,
          ),
          decoration: BoxDecoration(
            color: p.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.hairline, width: 0.9),
          ),
          child: isHero
              ? Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _feelingIcon(feeling.slug),
                        color: accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                feeling.name,
                                style: TextStyle(
                                  fontFamily: AppFonts.ruqaa,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: p.ink,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${ArabicNormalizer.toArabicNumber(totalNuances)} فرعاً',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: accent,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _feelingMotto(feeling.slug),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontSize: 11.8,
                                  color: p.inkMuted,
                                  height: 1.4,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 14,
                      color: p.inkMuted,
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _feelingIcon(feeling.slug),
                            color: accent,
                            size: 17.5,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${ArabicNormalizer.toArabicNumber(totalNuances)} فرعاً',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w600,
                                fontSize: 10.5,
                              ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        feeling.name,
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: AppFonts.ruqaa,
                          fontSize: 20.5,
                          fontWeight: FontWeight.w700,
                          color: p.ink,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _feelingMotto(feeling.slug),
                      maxLines: 2,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: p.inkMuted,
                        height: 1.38,
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
/// and surfaces exact matching verses with instant Copy & Card Studio actions.
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
  CorpusFilterState _filter = const CorpusFilterState();

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
    // Start isolate query immediately alongside the 180ms slide transition!
    _reloadVerses(isInitial: true);
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

  void _onFilterChanged(CorpusFilterState next) {
    if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
    setState(() => _filter = next);
    _reloadVerses();
  }

  Future<void> _reloadVerses({bool isInitial = false}) async {
    final gen = ++_reqGen;
    if (!isInitial && mounted) {
      setState(() {
        _loading = true;
        _loadingMore = false;
        _offset = 0;
        _hasMore = true;
      });
    }
    final res = await ref
        .read(poetryRepositoryProvider)
        .getFeelingVerseHitsAsync(
          _activeFeeling,
          rootSlug: widget.rootFeeling.slug,
          eraId: _filter.eraId,
          meterId: _filter.meterId,
          rhymeId: _filter.rhymeId,
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
          eraId: _filter.eraId,
          meterId: _filter.meterId,
          rhymeId: _filter.rhymeId,
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

  void _copyVerse(FeelingVerseHit hit) {
    HapticFeedback.lightImpact();
    final verseText = hit.matchedAjuz.isNotEmpty
        ? '${hit.matchedSadr}\n${hit.matchedAjuz}'
        : hit.matchedSadr;
    Clipboard.setData(ClipboardData(text: '$verseText\n— ${hit.poetName}'));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('نُسخ البيت إلى الحافظة'),
          duration: Duration(milliseconds: 1400),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _openCardStudio(FeelingVerseHit hit) {
    HapticFeedback.selectionClick();
    final verse = Verse(
      index: hit.matchedVerseIndex,
      sadr: hit.matchedSadr,
      ajuz: hit.matchedAjuz,
      extraHemistichs: hit.matchedExtraHemistichs,
    );
    BaytNav.pushModal(
      context,
      PoetryCardStudioScreen(
        verses: [verse],
        poetName: hit.poetName,
        eraName: hit.eraName,
      ),
    );
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
                CorpusFilterBar(
                  filter: _filter,
                  onChanged: _onFilterChanged,
                  showEra: true,
                  showMeter: true,
                  showRhyme: true,
                  showTheme: false,
                  accentColor: accent,
                ),
                const SizedBox(height: 2),
              ],
            ),
          ),

          // Compact Matching Verses Feed with Direct Copy & Card Studio Actions
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
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                      itemCount: _hits.length + (_loadingMore ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                          onCopy: () => _copyVerse(hit),
                          onDesignCard: () => _openCardStudio(hit),
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

/// Compact, refined Emotion Verse Card with instant Copy & Card Studio actions.
class _FeelingVerseCard extends StatelessWidget {
  const _FeelingVerseCard({
    required this.hit,
    required this.accent,
    required this.onTap,
    required this.onCopy,
    required this.onDesignCard,
  });

  final FeelingVerseHit hit;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onCopy;
  final VoidCallback onDesignCard;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return BaytPressable(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 11, 13, 9),
          decoration: BoxDecoration(
            color: p.surfaceElevated,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: p.hairline, width: 0.85),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Clean centered couplet
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
                        fontSize: 18.5,
                        fontWeight: FontWeight.w600,
                        color: p.ink,
                        height: 1.48,
                      ),
                    ),
                  ),
                ),
              if (hit.matchedAjuz.isNotEmpty)
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      hit.matchedAjuz,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.scheherazade,
                        fontSize: 18.5,
                        fontWeight: FontWeight.w600,
                        color: p.ink,
                        height: 1.48,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 8),

              // Compact footer: rhyme badge + poet + instant Copy & Card actions
              Container(
                padding: const EdgeInsets.only(top: 7),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: p.hairline, width: 0.7),
                  ),
                ),
                child: Row(
                  children: [
                    PoemRhymeBadge(
                      rhymeName: hit.rhymeName,
                      size: 25,
                      accentColor: accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              hit.poetName,
                              maxLines: 1,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: p.ink,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11.8,
                                  ),
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              '${hit.eraName}  •  بحر ${hit.meterName}',
                              maxLines: 1,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: p.inkMuted, fontSize: 10.2),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    _CompactCardAction(
                      icon: Icons.copy_rounded,
                      tooltip: 'نسخ البيت',
                      color: p.inkMuted,
                      onTap: onCopy,
                    ),
                    const SizedBox(width: 4),
                    _CompactCardAction(
                      icon: Icons.palette_outlined,
                      tooltip: 'تصميم بطاقة للبيت',
                      color: accent,
                      onTap: onDesignCard,
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

class _CompactCardAction extends StatelessWidget {
  const _CompactCardAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: p.hairline, width: 0.75),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }
}
