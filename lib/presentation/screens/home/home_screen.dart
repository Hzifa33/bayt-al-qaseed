import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/bayt_transitions.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/arabic_normalizer.dart';
import '../../../core/widgets/bayt_ornaments.dart';
import '../../../core/widgets/editorial_divider.dart';
import '../../../data/models/meter.dart';
import '../../../data/models/verse.dart';
import '../../providers/app_providers.dart';
import '../../providers/database_providers.dart';
import '../../providers/settings_provider.dart';
import '../../providers/user_data_providers.dart';
import '../about/about_screen.dart';
import '../eras/meter_poems_screen.dart';
import '../eras/poets_screen.dart';
import '../reader/poem_reader_screen.dart';
import '../studio/poetry_card_studio_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    super.key,
    required this.onOpenErasTab,
    required this.onOpenSearchTab,
  });

  final VoidCallback onOpenErasTab;
  final VoidCallback onOpenSearchTab;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _masterpieceCategories = [
    'الكل',
    'المعلّقات',
    'خالدات',
    'الغزل',
    'الرثاء',
    'الحكمة',
  ];

  FeaturedVerse? _customFeatured;
  String _selectedCategory = 'الكل';

  void _shuffleFeaturedVerse() {
    HapticFeedback.selectionClick();
    final currentId =
        _customFeatured?.id ?? ref.read(verseOfTheDayProvider)?.id;
    final random = ref
        .read(poetryRepositoryProvider)
        .getRandomFeaturedVerse(excludeId: currentId);
    if (random != null) {
      setState(() => _customFeatured = random);
    }
  }

  void _openRandomPoem() {
    HapticFeedback.lightImpact();
    // Instant O(log N) PK lookup (< 0.1 ms!)
    final poem = ref.read(poetryRepositoryProvider).getRandomPoem();
    if (poem == null) return;
    BaytNav.pushDrop(context, PoemReaderScreen(poemId: poem.id));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final settings = ref.watch(readerSettingsProvider);
    final stats = ref.watch(libraryStatsProvider);
    final eras = ref.watch(erasProvider);
    final meters = ref.watch(metersProvider);
    final allMasterpieces = ref.watch(masterpiecesProvider);
    final userData = ref.watch(userDataProvider);
    final featured = _customFeatured ?? ref.watch(verseOfTheDayProvider);

    final filteredMasterpieces = _selectedCategory == 'الكل'
        ? allMasterpieces
        : allMasterpieces
              .where((m) => m.category == _selectedCategory)
              .toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            toolbarHeight: 66,
            titleSpacing: 16,
            centerTitle: false,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => BaytNav.pushDrop(
                    context,
                    const AboutScreen(),
                    origin: const Offset(360, 48),
                  ),
                  child: const BaytEmblem(size: 36),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppConstants.appName,
                      style: TextStyle(
                        fontFamily: AppFonts.ruqaa,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      AppConstants.appTagline,
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: p.accent, fontSize: 10.5),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              _ThemeTriadBar(
                current: settings.themeMode,
                onSelect: (mode) {
                  HapticFeedback.selectionClick();
                  ref.read(readerSettingsProvider.notifier).setThemeMode(mode);
                },
              ),
              const SizedBox(width: 2),
              IconButton(
                tooltip: 'عن التطبيق والمطوّر',
                visualDensity: VisualDensity.compact,
                onPressed: () => BaytNav.pushDrop(
                  context,
                  const AboutScreen(),
                  origin: const Offset(32, 48),
                ),
                icon: Icon(
                  Icons.info_outline_rounded,
                  size: 19,
                  color: p.inkMuted,
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),

          // 1. Verse of the Day — Zero-Wrap Auto-Fit Hero Card
          if (featured != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.98, end: 1.0).animate(anim),
                      child: child,
                    ),
                  ),
                  child: _VerseOfTheDayCard(
                    key: ValueKey(featured.id),
                    verse: featured,
                    isShuffled: _customFeatured != null,
                    onShuffle: _shuffleFeaturedVerse,
                    onOpenPoem: () => BaytNav.pushDrop(
                      context,
                      PoemReaderScreen(
                        poemId: featured.poemId,
                        initialVerseIndex: featured.verseIndex,
                      ),
                    ),
                    onDesignCard: () => BaytNav.pushDrop(
                      context,
                      PoetryCardStudioScreen(
                        verses: [featured.toVerse()],
                        poetName: featured.poetName,
                        eraName: featured.eraName,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 2. Continue Reading (Sleek Compact Strip)
          if (userData.lastRead != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                child: _ContinueReadingCard(
                  title: userData.lastRead!.poemTitle,
                  poetName: userData.lastRead!.poetName,
                  meterName: userData.lastRead!.meterName,
                  verseCount: userData.lastRead!.verseCount,
                  onTap: () => BaytNav.pushDrop(
                    context,
                    PoemReaderScreen(
                      poemId: userData.lastRead!.poemId,
                      initialVerseIndex: userData.lastRead!.lastVerseIndex,
                    ),
                  ),
                ),
              ),
            ),

          // 3. Compact Dual Quick-Action Strip («قصيدة عشوائية» + «شاهدٌ آخر»)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              child: Row(
                children: [
                  Expanded(
                    child: _QuickActionTile(
                      icon: Icons.shuffle_rounded,
                      title: 'قصيدة عشوائية',
                      subtitle: 'افتح قصيدة من الديوان',
                      onTap: _openRandomPoem,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickActionTile(
                      icon: Icons.format_quote_rounded,
                      title: 'شاهدٌ آخر',
                      subtitle: 'بيتٌ من عيون الشعر',
                      onTap: _shuffleFeaturedVerse,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Expanded Majestic Curated Masterpieces («عيونُ القصيد الخالدة» with Categories)
          if (allMasterpieces.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 19,
                          color: p.accent,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'عيونُ القصيد الخالدة',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                    Text(
                      '${ArabicNormalizer.toArabicNumber(filteredMasterpieces.length)} قصيدة',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: p.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Category filter pills (المعلّقات، خالدات، الغزل، الرثاء، الحكمة)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _masterpieceCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final cat = _masterpieceCategories[i];
                    final sel = cat == _selectedCategory;
                    return ChoiceChip(
                      selected: sel,
                      visualDensity: VisualDensity.compact,
                      label: Text(cat),
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedCategory = cat);
                      },
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
            // Larger, Majestic Masterpiece Cards
            SliverToBoxAdapter(
              child: SizedBox(
                height: 196,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredMasterpieces.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final m = filteredMasterpieces[i];
                    return _MasterpieceCard(
                      verse: m,
                      onTap: () => BaytNav.pushDrop(
                        context,
                        PoemReaderScreen(
                          poemId: m.poemId,
                          initialVerseIndex: m.verseIndex,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],

          const SliverToBoxAdapter(
            child: EditorialDivider(verticalPadding: 16),
          ),

          // 5. Literary Eras Rail (Well-Proportioned Compact Height)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.hourglass_bottom_rounded,
                        size: 18,
                        color: p.accent,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'العصور الأدبية',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: widget.onOpenErasTab,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      'الديوان كاملاً',
                      style: TextStyle(
                        color: p.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: SizedBox(
              height: 128,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: eras.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final era = eras[index];
                  return InkWell(
                    onTap: () =>
                        BaytNav.pushEditorial(context, PoetsScreen(era: era)),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 150,
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: p.surfaceElevated,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: p.hairline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: p.accentSoft,
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Text(
                                  era.periodHint,
                                  style: TextStyle(
                                    fontFamily: AppFonts.ui,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: p.accent,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 11,
                                color: p.inkMuted,
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            'العصر ${era.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppFonts.ruqaa,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: p.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            era.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(fontSize: 10.5),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${ArabicNormalizer.toArabicNumber(era.poetCount)} شاعراً',
                            style: TextStyle(
                              fontFamily: AppFonts.ui,
                              fontSize: 10.5,
                              color: p.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 6. Compact Horizontal Poetic Meters Ribbon (No overly tall wall of chips!)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.waves_rounded, size: 18, color: p.accent),
                      const SizedBox(width: 7),
                      Text(
                        'بحور الشعر العربي',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: widget.onOpenErasTab,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      'كل البحور',
                      style: TextStyle(
                        color: p.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: _CompactMetersRibbon(
              meters: meters.take(16).toList(),
              onTapMeter: (m) =>
                  BaytNav.pushEditorial(context, MeterPoemsScreen(meter: m)),
            ),
          ),

          // 7. Compact Editorial Library Stats Footer
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 102),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: p.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_stories_outlined,
                          size: 16,
                          color: p.accent,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'خزانة «بيت القصيد»',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(color: p.accent),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _StatCell(
                          value: ArabicNormalizer.toArabicNumber(
                            stats.verseCount,
                          ),
                          label: 'بيت شعري',
                        ),
                        _StatCell(
                          value: ArabicNormalizer.toArabicNumber(
                            stats.poemCount,
                          ),
                          label: 'قصيدة',
                        ),
                        _StatCell(
                          value: ArabicNormalizer.toArabicNumber(
                            stats.poetCount,
                          ),
                          label: 'شاعراً',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact 2-row horizontally scrollable Poetic Meters ribbon (~86px total height).
class _CompactMetersRibbon extends StatelessWidget {
  const _CompactMetersRibbon({required this.meters, required this.onTapMeter});

  final List<Meter> meters;
  final ValueChanged<Meter> onTapMeter;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final half = (meters.length / 2).ceil();
    final row1 = meters.take(half).toList();
    final row2 = meters.skip(half).toList();

    Widget buildRow(List<Meter> items) {
      return Row(
        children: items.map((m) {
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: InkWell(
              onTap: () => onTapMeter(m),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: p.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.hairline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      m.name,
                      style: TextStyle(
                        fontFamily: AppFonts.ui,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      ArabicNormalizer.toArabicNumber(m.poemCount),
                      style: TextStyle(
                        fontFamily: AppFonts.ui,
                        fontSize: 11,
                        color: p.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [buildRow(row1), const SizedBox(height: 8), buildRow(row2)],
      ),
    );
  }
}

/// Large, stately editorial card for «عيونُ القصيد الخالدة» with zero-wrap auto-fit hemistichs.
class _MasterpieceCard extends StatelessWidget {
  const _MasterpieceCard({required this.verse, required this.onTap});

  final FeaturedVerse verse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final verseStyle = TextStyle(
      fontFamily: AppFonts.scheherazade,
      fontSize: 20.5,
      height: 1.85,
      color: p.ink,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 292,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: p.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: p.ornament.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: p.accentSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    verse.category,
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: p.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    verse.tag,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.ruqaa,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: p.ink,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Auto-fit single-line hemistichs so they NEVER break awkwardly
            Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(verse.sadr, maxLines: 1, style: verseStyle),
              ),
            ),
            if (verse.ajuz.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 18),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(verse.ajuz, maxLines: 1, style: verseStyle),
                  ),
                ),
              ),
            const Spacer(),
            Divider(color: p.hairline.withValues(alpha: 0.7), height: 14),
            Row(
              children: [
                Icon(Icons.history_edu_rounded, size: 13.5, color: p.accent),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '${verse.poetName}  •  ${verse.eraName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: p.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (verse.verseCount > 0)
                  Text(
                    '${ArabicNormalizer.toArabicNumber(verse.verseCount)} بيتاً',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeTriadBar extends StatelessWidget {
  const _ThemeTriadBar({required this.current, required this.onSelect});

  final ReadingThemeMode current;
  final ValueChanged<ReadingThemeMode> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.hairline, width: 0.9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TriadButton(
            tooltip: 'الوضع النهاري',
            active:
                current == ReadingThemeMode.parchment ||
                current == ReadingThemeMode.sepia,
            onTap: () => onSelect(ReadingThemeMode.parchment),
            child: Icon(
              Icons.wb_sunny_outlined,
              size: 16.5,
              color:
                  (current == ReadingThemeMode.parchment ||
                      current == ReadingThemeMode.sepia)
                  ? p.accent
                  : p.inkMuted,
            ),
          ),
          _TriadButton(
            tooltip: 'الوضع الليلي',
            active: current == ReadingThemeMode.obsidian,
            onTap: () => onSelect(ReadingThemeMode.obsidian),
            child: Icon(
              Icons.dark_mode_outlined,
              size: 16.5,
              color: current == ReadingThemeMode.obsidian
                  ? p.accent
                  : p.inkMuted,
            ),
          ),
          _TriadButton(
            tooltip: 'ألوان النظام (Material You)',
            active: current == ReadingThemeMode.materialYou,
            onTap: () => onSelect(ReadingThemeMode.materialYou),
            child: MaterialYouIcon(
              size: 16.5,
              filled: current == ReadingThemeMode.materialYou,
              color: current == ReadingThemeMode.materialYou
                  ? p.accent
                  : p.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _TriadButton extends StatelessWidget {
  const _TriadButton({
    required this.tooltip,
    required this.active,
    required this.onTap,
    required this.child,
  });

  final String tooltip;
  final bool active;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 30,
          height: 27,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? p.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? p.accent.withValues(alpha: 0.4)
                  : Colors.transparent,
              width: 0.8,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Zero-Wrap Verse of the Day card: scales each hemistich cleanly inside a single
/// balanced line so long verses NEVER break onto a second line.
class _VerseOfTheDayCard extends StatelessWidget {
  const _VerseOfTheDayCard({
    super.key,
    required this.verse,
    required this.isShuffled,
    required this.onShuffle,
    required this.onOpenPoem,
    required this.onDesignCard,
  });

  final FeaturedVerse verse;
  final bool isShuffled;
  final VoidCallback onShuffle;
  final VoidCallback onOpenPoem;
  final VoidCallback onDesignCard;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final verseStyle = TextStyle(
      fontFamily: AppFonts.scheherazade,
      fontSize: 22.5,
      height: 1.95,
      color: p.ink,
    );

    return Container(
      decoration: BoxDecoration(
        color: p.surfaceElevated,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: p.ornament.withValues(alpha: 0.45),
          width: 1.05,
        ),
      ),
      child: InkWell(
        onTap: onOpenPoem,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: p.accentSoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isShuffled ? verse.tag : 'بيتُ اليوم  •  ${verse.tag}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: p.accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    tooltip: 'شاهدٌ آخر',
                    onPressed: onShuffle,
                    icon: Icon(
                      Icons.shuffle_rounded,
                      size: 18,
                      color: p.inkMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Strict single-line auto-fit Sadr & Ajuz
              LayoutBuilder(
                builder: (context, constraints) {
                  final boxW = constraints.maxWidth * 0.86;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: boxW),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              verse.sadr,
                              maxLines: 1,
                              style: verseStyle,
                            ),
                          ),
                        ),
                      ),
                      if (verse.ajuz.isNotEmpty)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: boxW),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                verse.ajuz,
                                maxLines: 1,
                                style: verseStyle,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const EditorialDivider(
                verticalPadding: 11,
                horizontalPadding: 12,
              ),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.history_edu_rounded,
                          size: 16,
                          color: p.accent,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                verse.poetName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppFonts.ruqaa,
                                  fontSize: 17.5,
                                  fontWeight: FontWeight.w700,
                                  color: p.accent,
                                ),
                              ),
                              Text(
                                'العصر ${verse.eraName}',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(fontSize: 10.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onDesignCard,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: Icon(Icons.brush_outlined, size: 15, color: p.accent),
                    label: Text(
                      'بطاقة',
                      style: TextStyle(
                        color: p.accent,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  FilledButton.tonal(
                    onPressed: onOpenPoem,
                    style: FilledButton.styleFrom(
                      backgroundColor: p.accentSoft,
                      foregroundColor: p.accent,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                    ),
                    child: const Text(
                      'اقرأ القصيدة',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContinueReadingCard extends StatelessWidget {
  const _ContinueReadingCard({
    required this.title,
    required this.poetName,
    required this.meterName,
    required this.verseCount,
    required this.onTap,
  });

  final String title;
  final String poetName;
  final String meterName;
  final int verseCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: p.hairline),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: p.accentSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.bookmark_rounded, color: p.accent, size: 18),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.scheherazade,
                      fontSize: 18.5,
                      color: p.ink,
                      height: 1.4,
                    ),
                  ),
                  Text(
                    'مواصلة القراءة  •  $poetName  •  بحر $meterName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(fontSize: 10.5),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_back_ios_new_rounded, size: 13, color: p.inkMuted),
          ],
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: p.surfaceElevated,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: p.hairline),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: p.accentSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: p.accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontSize: 13),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(fontSize: 10.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 17.5,
              fontWeight: FontWeight.w700,
              color: p.ink,
            ),
          ),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
