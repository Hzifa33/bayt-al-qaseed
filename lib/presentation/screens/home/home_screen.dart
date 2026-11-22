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
  FeaturedVerse? _customFeatured;

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
    final eras = ref.watch(erasProvider);
    final meters = ref.watch(metersProvider);
    final masterpieces = ref.watch(masterpiecesProvider);
    final userData = ref.watch(userDataProvider);
    final featured = _customFeatured ?? ref.watch(verseOfTheDayProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            toolbarHeight: 70,
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
                  child: const BaytEmblem(size: 38),
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
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      AppConstants.appTagline,
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: p.accent),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              // Dedicated Triad: Day (Parchment) | Night (Obsidian) | Material You
              _ThemeTriadBar(
                current: settings.themeMode,
                onSelect: (mode) {
                  HapticFeedback.selectionClick();
                  ref.read(readerSettingsProvider.notifier).setThemeMode(mode);
                },
              ),
              const SizedBox(width: 4),
              // Discreet Developer / About side icon button
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
                  size: 20,
                  color: p.inkMuted,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),

          // Curated Iconic Verse of the Day Hero Card
          if (featured != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 340),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.97, end: 1.0).animate(anim),
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

          // Continue Reading Banner
          if (userData.lastRead != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
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

          // Eloquent Arabic Discovery Tiles
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
              child: Row(
                children: [
                  Expanded(
                    child: _QuickActionTile(
                      icon: Icons.auto_awesome_outlined,
                      title: 'درّةٌ من الديوان',
                      subtitle: 'قصيدةٌ تلوح بغير ميعاد',
                      onTap: _openRandomPoem,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionTile(
                      icon: Icons.format_quote_rounded,
                      title: 'شاهدٌ آخر',
                      subtitle: 'بيتٌ من عيون القصيد',
                      onTap: _shuffleFeaturedVerse,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Immortal Arabic Masterpieces Horizontal Carousel
          if (masterpieces.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'عيونُ القصيد الخالدة',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(
                      'مختاراتٌ شهيرة',
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: p.accent),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 158,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  itemCount: masterpieces.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final m = masterpieces[i];
                    return InkWell(
                      onTap: () => BaytNav.pushDrop(
                        context,
                        PoemReaderScreen(
                          poemId: m.poemId,
                          initialVerseIndex: m.verseIndex,
                        ),
                      ),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 248,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: p.surfaceElevated,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: p.hairline),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                m.tag,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppFonts.ui,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: p.accent,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Text(
                                m.ajuz.isNotEmpty
                                    ? '${m.sadr}\n${m.ajuz}'
                                    : m.sadr,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppFonts.scheherazade,
                                  fontSize: 18,
                                  height: 1.65,
                                  color: p.ink,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${m.poetName}  •  ${m.eraName}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: p.accent,
                                          fontWeight: FontWeight.w600,
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
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],

          const SliverToBoxAdapter(
            child: EditorialDivider(verticalPadding: 18),
          ),

          // Literary Eras Header + Horizontal Strip
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'العصور الأدبية',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  TextButton(
                    onPressed: widget.onOpenErasTab,
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
              height: 146,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                itemCount: eras.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final era = eras[index];
                  return InkWell(
                    onTap: () =>
                        BaytNav.pushEditorial(context, PoetsScreen(era: era)),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 164,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: p.surfaceElevated,
                        borderRadius: BorderRadius.circular(18),
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
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: p.accentSoft,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  era.periodHint,
                                  style: TextStyle(
                                    fontFamily: AppFonts.ui,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: p.accent,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 12,
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
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: p.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            era.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${ArabicNormalizer.toArabicNumber(era.poetCount)} شاعراً  •  ${ArabicNormalizer.toArabicNumber(era.poemCount)} قصيدة',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppFonts.ui,
                              fontSize: 11,
                              color: p.accent,
                              fontWeight: FontWeight.w500,
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

          // Poetic Meters Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
              child: Text(
                'بحور الشعر العربي',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: meters.take(12).map((m) {
                  return ActionChip(
                    onPressed: () => BaytNav.pushEditorial(
                      context,
                      MeterPoemsScreen(meter: m),
                    ),
                    label: Text(
                      '${m.name} (${ArabicNormalizer.toArabicNumber(m.poemCount)})',
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Clean Literary Library Statistics Card (Zero Technical Jargon!)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 112),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: p.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_stories_outlined,
                          size: 18,
                          color: p.accent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'خزانة «بيت القصيد»',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(color: p.accent),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 12),
                    Text(
                      'موسوعةٌ شعريةٌ مضبوطةُ التشكيل تمتدُّ عبر أحدَ عشرَ عصراً أدبياً، جاهزةٌ للمطالعة والبحث في كلّ حينٍ دون اتصال.',
                      style: Theme.of(context).textTheme.bodySmall,
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

/// Compact 3-mode Theme Triad right in the AppBar:
/// Day (Warm Parchment) | Night (Quiet Obsidian) | Material You (Dynamic System Colors)
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
              size: 17,
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
              size: 17,
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
              size: 17,
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
          width: 31,
          height: 28,
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
    return Container(
      decoration: BoxDecoration(
        color: p.surfaceElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: p.ornament.withValues(alpha: 0.45),
          width: 1.1,
        ),
      ),
      child: InkWell(
        onTap: onOpenPoem,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: p.accentSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isShuffled ? verse.tag : 'بيتُ اليوم  •  ${verse.tag}',
                      style: TextStyle(
                        fontFamily: AppFonts.ui,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: p.accent,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'شاهدٌ آخر',
                    onPressed: onShuffle,
                    icon: Icon(
                      Icons.shuffle_rounded,
                      size: 19,
                      color: p.inkMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                verse.sadr,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: AppFonts.scheherazade,
                  fontSize: 23,
                  height: 2.0,
                  color: p.ink,
                ),
              ),
              if (verse.ajuz.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 26),
                  child: Text(
                    verse.ajuz,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontFamily: AppFonts.scheherazade,
                      fontSize: 23,
                      height: 2.0,
                      color: p.ink,
                    ),
                  ),
                ),
              const EditorialDivider(
                verticalPadding: 14,
                horizontalPadding: 12,
              ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          verse.poetName,
                          style: TextStyle(
                            fontFamily: AppFonts.ruqaa,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: p.accent,
                          ),
                        ),
                        Text(
                          'العصر ${verse.eraName}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onDesignCard,
                    icon: Icon(Icons.brush_outlined, size: 16, color: p.accent),
                    label: Text(
                      'بطاقة',
                      style: TextStyle(
                        color: p.accent,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                    child: const Text('اقرأ القصيدة'),
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
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(18),
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
              child: Icon(Icons.bookmark_rounded, color: p.accent, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مواصلة القراءة',
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: p.accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.scheherazade,
                      fontSize: 19,
                      color: p.ink,
                      height: 1.5,
                    ),
                  ),
                  Text(
                    '$poetName  •  بحر $meterName  •  ${ArabicNormalizer.toArabicNumber(verseCount)} بيتاً',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: p.inkMuted),
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: p.accent),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
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
              fontSize: 19,
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
