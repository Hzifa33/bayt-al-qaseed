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
import '../eras/feelings_screen.dart';
import '../eras/meter_poems_screen.dart';
import '../eras/theme_poems_screen.dart';
import '../reader/poem_reader_screen.dart';
import '../studio/poetry_card_studio_screen.dart';
import 'masterpieces_screen.dart';

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
  static const _masterpieceCategories = <(String, IconData)>[
    ('الكل', Icons.auto_awesome_rounded),
    ('المعلّقات', Icons.workspace_premium_outlined),
    ('خالدات', Icons.menu_book_outlined),
    ('الغزل', Icons.favorite_outline_rounded),
    ('الرثاء', Icons.water_drop_outlined),
    ('الحكمة', Icons.lightbulb_outline_rounded),
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
    final poem = ref.read(poetryRepositoryProvider).getRandomPoem();
    if (poem == null) return;
    BaytNav.pushDrop(context, PoemReaderScreen(poemId: poem.id));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final settings = ref.watch(readerSettingsProvider);
    final stats = ref.watch(libraryStatsProvider);
    final meters = ref.watch(metersProvider);
    final themes = ref.watch(themesProvider);
    final feelings = ref.watch(feelingsTreeProvider);
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
                        isRawVerseIndex: true,
                        highlightMatchedVerseOnce: featured.verseIndex > 0,
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

          // 3. Zero-Truncation Quick Action Strip («قصيدة عشوائية» + «شاهدٌ آخر»)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              child: Row(
                children: [
                  Expanded(
                    child: _QuickActionTile(
                      icon: Icons.shuffle_rounded,
                      title: 'قصيدة عشوائية',
                      subtitle: 'اختر قصيدة الآن',
                      onTap: _openRandomPoem,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickActionTile(
                      icon: Icons.format_quote_rounded,
                      title: 'شاهدٌ آخر',
                      subtitle: 'تبديل بيت اليوم',
                      onTap: _shuffleFeaturedVerse,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3b. Expanded Edition: Feelings & Themes Quick Discovery Strip
          if (feelings.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.psychology_outlined,
                          size: 18,
                          color: p.accent,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'تصفّح حسب الشعور',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                    Text(
                      '${ArabicNormalizer.toArabicNumber(stats.feelingCount)} شعوراً',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: p.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: feelings.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final f = feelings[i];
                    return ActionChip(
                      avatar: Icon(
                        Icons.auto_awesome_outlined,
                        size: 15,
                        color: p.accent,
                      ),
                      label: Text(
                        f.name,
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontWeight: FontWeight.w600,
                          color: p.ink,
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        BaytNav.pushEditorial(
                          context,
                          FeelingDetailScreen(rootFeeling: f),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],

          if (themes.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                child: Row(
                  children: [
                    Icon(Icons.category_outlined, size: 17, color: p.accent),
                    const SizedBox(width: 7),
                    Text(
                      'الأغراض الشعرية',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: themes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 7),
                  itemBuilder: (context, i) {
                    final th = themes[i];
                    return ActionChip(
                      label: Text(
                        '${th.name} (${ArabicNormalizer.toArabicNumber(th.poemCount)})',
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 12,
                          color: p.ink,
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        BaytNav.pushEditorial(
                          context,
                          ThemePoemsScreen(theme: th),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],

          // 4. Refined Compact Curated Masterpieces («عيونُ القصيد الخالدة»)
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
                          size: 18,
                          color: p.accent,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'عيونُ القصيد الخالدة',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () => BaytNav.pushEditorial(
                        context,
                        MasterpiecesScreen(initialCategory: _selectedCategory),
                      ),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: Icon(
                        Icons.menu_book_rounded,
                        size: 15,
                        color: p.accent,
                      ),
                      label: Text(
                        'عرض الكل (${ArabicNormalizer.toArabicNumber(allMasterpieces.length)})',
                        style: TextStyle(
                          color: p.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _masterpieceCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final (cat, icon) = _masterpieceCategories[i];
                    final sel = cat == _selectedCategory;
                    return ChoiceChip(
                      selected: sel,
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(
                        icon,
                        size: 14.5,
                        color: sel ? p.accent : p.inkMuted,
                      ),
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
            SliverToBoxAdapter(
              child: SizedBox(
                height: 156,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredMasterpieces.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final m = filteredMasterpieces[i];
                    return _MasterpieceCard(
                      verse: m,
                      onTap: () => BaytNav.pushDrop(
                        context,
                        PoemReaderScreen(
                          poemId: m.poemId,
                          initialVerseIndex: m.verseIndex,
                          isRawVerseIndex: true,
                          highlightMatchedVerseOnce: m.verseIndex > 0,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],

          // 5. Compact 2-Row Poetic Meters Ribbon (Clean, Uncluttered Home!)
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
                  TextButton.icon(
                    onPressed: widget.onOpenErasTab,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: Icon(
                      Icons.auto_stories_outlined,
                      size: 15,
                      color: p.accent,
                    ),
                    label: Text(
                      'كل الدواوين',
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

          // 6. Clean Editorial Library Stats Footer with Expressive Icons
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 102),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 15,
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
                          Icons.library_books_outlined,
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
                          icon: Icons.format_quote_rounded,
                          value: ArabicNormalizer.toArabicNumber(
                            stats.verseCount,
                          ),
                          label: 'بيت شعري',
                        ),
                        _StatCell(
                          icon: Icons.auto_stories_outlined,
                          value: ArabicNormalizer.toArabicNumber(
                            stats.poemCount,
                          ),
                          label: 'قصيدة',
                        ),
                        _StatCell(
                          icon: Icons.history_edu_rounded,
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
                  horizontal: 11,
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
                    Icon(Icons.waves_rounded, size: 13, color: p.accent),
                    const SizedBox(width: 5),
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

/// Compact, refined editorial card for «عيونُ القصيد الخالدة» (height 156, width 256).
class _MasterpieceCard extends StatelessWidget {
  const _MasterpieceCard({required this.verse, required this.onTap});

  final FeaturedVerse verse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final verseStyle = TextStyle(
      fontFamily: AppFonts.scheherazade,
      fontSize: 18.5,
      height: 1.72,
      color: p.ink,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 256,
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        decoration: BoxDecoration(
          color: p.surfaceElevated,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: p.ornament.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
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
                    verse.category,
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: p.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        verse.tag,
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: AppFonts.ruqaa,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: p.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
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
                padding: const EdgeInsets.only(right: 16),
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
            Divider(color: p.hairline.withValues(alpha: 0.7), height: 10),
            Row(
              children: [
                Icon(Icons.history_edu_rounded, size: 12.5, color: p.accent),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    verse.poetName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: p.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
                if (verse.verseCount > 0) ...[
                  Icon(
                    Icons.format_list_numbered_rtl_rounded,
                    size: 11,
                    color: p.inkMuted,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${ArabicNormalizer.toArabicNumber(verse.verseCount)} بيت',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(fontSize: 10.5),
                  ),
                ],
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
          padding: const EdgeInsets.fromLTRB(18, 13, 18, 12),
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 12.5,
                            color: p.accent,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              isShuffled
                                  ? verse.tag
                                  : 'بيتُ اليوم  •  ${verse.tag}',
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
                        ],
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
                verticalPadding: 10,
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
                              Align(
                                alignment: Alignment.centerRight,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    verse.poetName,
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontFamily: AppFonts.ruqaa,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: p.accent,
                                    ),
                                  ),
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
    required this.onTap,
  });

  final String title;
  final String poetName;
  final String meterName;
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
                  Row(
                    children: [
                      Icon(
                        Icons.history_edu_rounded,
                        size: 11.5,
                        color: p.accent,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '$poetName  •  بحر $meterName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(fontSize: 10.5),
                        ),
                      ),
                    ],
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

/// Zero-truncation compact Quick Action Tile (fits cleanly on every screen width!).
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
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          color: p.surfaceElevated,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: p.hairline),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: p.accentSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: p.accent),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        title,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontSize: 13),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(fontSize: 10.5),
                      ),
                    ),
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
  const _StatCell({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13.5, color: p.accent),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: p.ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
