import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/arabic_normalizer.dart';
import '../../../core/widgets/editorial_divider.dart';
import '../../../data/models/verse.dart';
import '../../providers/app_providers.dart';
import '../../providers/database_providers.dart';
import '../../providers/settings_provider.dart';
import '../../providers/user_data_providers.dart';
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
    final random = ref.read(poetryRepositoryProvider).getRandomFeaturedVerse();
    if (random != null) {
      setState(() => _customFeatured = random);
    }
  }

  void _openRandomPoem() {
    final poem = ref.read(poetryRepositoryProvider).getRandomPoem();
    if (poem == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PoemReaderScreen(poemId: poem.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final settings = ref.watch(readerSettingsProvider);
    final stats = ref.watch(libraryStatsProvider);
    final eras = ref.watch(erasProvider);
    final meters = ref.watch(metersProvider);
    final userData = ref.watch(userDataProvider);
    final featured = _customFeatured ?? ref.watch(verseOfTheDayProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            toolbarHeight: 68,
            titleSpacing: 20,
            centerTitle: false,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppConstants.appName,
                  style: TextStyle(
                    fontFamily: AppFonts.ruqaa,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                    height: 1.25,
                  ),
                ),
                Text(
                  'موسوعة الشعر العربي',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: p.accent, letterSpacing: 0.2),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'تبديل وضع القراءة',
                onPressed: () =>
                    ref.read(readerSettingsProvider.notifier).cycleThemeMode(),
                icon: Icon(
                  settings.themeMode.isDark
                      ? Icons.wb_sunny_outlined
                      : Icons.dark_mode_outlined,
                  color: p.accent,
                ),
              ),
              IconButton(
                tooltip: 'البحث الفوري',
                onPressed: widget.onOpenSearchTab,
                icon: Icon(Icons.search_rounded, color: p.ink),
              ),
              const SizedBox(width: 6),
            ],
          ),

          // Verse of the Day Editorial Hero Card
          if (featured != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                child: _VerseOfTheDayCard(
                  verse: featured,
                  isShuffled: _customFeatured != null,
                  onShuffle: _shuffleFeaturedVerse,
                  onOpenPoem: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PoemReaderScreen(
                          poemId: featured.poemId,
                          initialVerseIndex: featured.verseIndex,
                        ),
                      ),
                    );
                  },
                  onDesignCard: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PoetryCardStudioScreen(
                          verses: [featured.toVerse()],
                          poetName: featured.poetName,
                          eraName: featured.eraName,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // Continue Reading Banner
          if (userData.lastRead != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
                child: _ContinueReadingCard(
                  title: userData.lastRead!.poemTitle,
                  poetName: userData.lastRead!.poetName,
                  meterName: userData.lastRead!.meterName,
                  verseCount: userData.lastRead!.verseCount,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PoemReaderScreen(
                          poemId: userData.lastRead!.poemId,
                          initialVerseIndex: userData.lastRead!.lastVerseIndex,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // Serendipity Action Row
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
              child: Row(
                children: [
                  Expanded(
                    child: _QuickActionTile(
                      icon: Icons.auto_awesome_outlined,
                      title: 'قصيدة بمحض الصدفة',
                      subtitle: 'اكتشف درّة من الدواوين',
                      onTap: _openRandomPoem,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionTile(
                      icon: Icons.format_quote_rounded,
                      title: 'بيتٌ مُختار',
                      subtitle: 'تبديل اقتباس اليوم',
                      onTap: _shuffleFeaturedVerse,
                    ),
                  ),
                ],
              ),
            ),
          ),

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
                      'عرض الكل',
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
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PoetsScreen(era: era),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 162,
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
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MeterPoemsScreen(meter: m),
                        ),
                      );
                    },
                    label: Text(
                      '${m.name} (${ArabicNormalizer.toArabicNumber(m.poemCount)})',
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Library Statistics Editorial Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 26, 18, 32),
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
                          Icons.library_books_outlined,
                          size: 18,
                          color: p.accent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'إحصاءات خزانة «بيت القصيد»',
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
                          label: 'شاعر',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'تعمل الموسوعة بالكامل دون اتصال بالإنترنت عبر محرك بحث فوري FTS5 ومخطط بيانات منقّح ومشكّل.',
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

class _VerseOfTheDayCard extends StatelessWidget {
  const _VerseOfTheDayCard({
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
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: p.ornament.withValues(alpha: 0.45),
          width: 1.1,
        ),
      ),
      child: InkWell(
        onTap: onOpenPoem,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
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
                      isShuffled ? 'مختارات الديوان' : 'بيت اليوم',
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
                    tooltip: 'بيت آخر',
                    onPressed: onShuffle,
                    icon: Icon(
                      Icons.shuffle_rounded,
                      size: 19,
                      color: p.inkMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
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
                  padding: const EdgeInsets.only(right: 28),
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
                    icon: Icon(
                      Icons.palette_outlined,
                      size: 16,
                      color: p.accent,
                    ),
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
        padding: const EdgeInsets.all(16),
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
                    'استكمال القراءة',
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
