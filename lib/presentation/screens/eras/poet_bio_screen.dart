import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/bayt_motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/arabic_normalizer.dart';
import '../../../core/widgets/bayt_ornaments.dart';
import '../../../core/widgets/editorial_divider.dart';
import '../../../data/models/meter.dart';
import '../../../data/models/poet.dart';
import '../../providers/user_data_providers.dart';

/// Sumptuously designed Poet Biography & Literary Profile screen.
///
/// Features:
/// - Full-screen subtle Arabic calligraphy watermark backdrop
/// - Double-ringed circular portrait medallion with gender-aware avatar
///   (veiled woman icon for female poets, classic poet icon for male poets)
/// - 3-column literary statistics bento with tabular numbers
/// - Manuscript-styled biography card with one-tap copy & generous line height
/// - Prosodic meter distribution with proportional visual bars
class PoetBioScreen extends ConsumerWidget {
  const PoetBioScreen({super.key, required this.poet, required this.meters});

  final Poet poet;
  final List<Meter> meters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFav = ref.watch(userDataProvider).favoritePoetIds.contains(poet.id);
    final isFemale = PoetGender.isFemale(
      poetId: poet.id,
      poetName: poet.namePlain,
    );
    final roleLabel = isFemale ? 'شاعرة من العصر' : 'شاعر من العصر';

    return Scaffold(
      appBar: AppBar(
        title: Text(isFemale ? 'ترجمة الشاعرة' : 'ترجمة الشاعر'),
        actions: [
          if (poet.bio.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedCopyButton(
                tooltip: 'نسخ الترجمة',
                size: 19,
                color: p.inkMuted,
                padding: const EdgeInsets.all(8),
                borderRadius: 12,
                onCopy: () {
                  Clipboard.setData(
                    ClipboardData(text: '${poet.name}\n\n${poet.bio}'),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('نُسخت ترجمة الشاعر إلى الحافظة'),
                    ),
                  );
                },
              ),
            ),
          IconButton(
            tooltip: isFav
                ? 'إزالة من الشعراء المفضلين'
                : 'حفظ في الشعراء المفضلين',
            onPressed: () {
              HapticFeedback.selectionClick();
              ref.read(userDataProvider.notifier).toggleFavoritePoet(poet.id);
            },
            icon: BaytIconMorph(
              icon: Icon(
                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                key: ValueKey(isFav),
                color: isFav ? p.accent : p.ink,
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Stack(
        children: [
          // Subtle Full-Screen Arabic Calligraphy Watermark
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: Image.asset(
                  'assets/images/calligraphy_bg.webp',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  color: p.accent.withValues(alpha: isDark ? 0.065 : 0.055),
                  colorBlendMode: BlendMode.srcIn,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),

          ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
            children: [
              // 1. Hero Poet Identity & Bento Stats Card
              Container(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                decoration: BoxDecoration(
                  color: p.surfaceElevated.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: p.ornament.withValues(alpha: 0.48),
                    width: 1.1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.22 : 0.05,
                      ),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Double-Ringed Ornamental Portrait Medallion
                    Container(
                      width: 72,
                      height: 72,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: p.ornament.withValues(alpha: 0.55),
                          width: 1.2,
                        ),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: p.accentSoft,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: p.accent.withValues(alpha: 0.35),
                            width: 0.9,
                          ),
                        ),
                        child: PoetAvatarIcon(
                          poetId: poet.id,
                          poetName: poet.namePlain,
                          size: 34,
                          color: p.accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Calligraphic Full Name
                    Text(
                      poet.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.ruqaa,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Era & Historical Dates Pills
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _BioChip(
                          icon: Icons.hourglass_bottom_rounded,
                          label: '$roleLabel ${poet.eraName}',
                          accented: true,
                        ),
                        if (poet.formattedDates.isNotEmpty)
                          _BioChip(
                            icon: Icons.calendar_today_outlined,
                            label: poet.formattedDates,
                          ),
                      ],
                    ),

                    const EditorialDivider(
                      verticalPadding: 16,
                      horizontalPadding: 32,
                    ),

                    // 3-Column Literary Statistics Bento
                    Row(
                      children: [
                        _BioStatTile(
                          icon: Icons.auto_stories_outlined,
                          value: ArabicNormalizer.toArabicNumber(
                            poet.poemCount,
                          ),
                          label: 'قصيدة',
                        ),
                        const SizedBox(width: 8),
                        _BioStatTile(
                          icon: Icons.format_quote_rounded,
                          value: ArabicNormalizer.toArabicNumber(
                            poet.verseCount,
                          ),
                          label: 'بيت شعري',
                        ),
                        const SizedBox(width: 8),
                        _BioStatTile(
                          icon: Icons.waves_rounded,
                          value: ArabicNormalizer.toArabicNumber(meters.length),
                          label: 'بحر عروضي',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 2. Manuscript Biography Card («السيرة والترجمة الأدبية»)
              if (poet.bio.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                  decoration: BoxDecoration(
                    color: p.surfaceElevated.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: p.hairline, width: 0.95),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: p.accentSoft,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(
                              Icons.history_edu_rounded,
                              size: 17,
                              color: p.accent,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'السيرة والترجمة الأدبية',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: p.accent,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(
                        height: 1,
                        thickness: 0.7,
                        color: p.hairline.withValues(alpha: 0.8),
                      ),
                      const SizedBox(height: 14),
                      SelectionArea(
                        child: Text(
                          poet.bio.trim(),
                          textAlign: TextAlign.justify,
                          style: TextStyle(
                            fontFamily: AppFonts.amiri,
                            fontSize: 18.5,
                            height: 1.95,
                            color: p.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 3. Prosodic Meters Distribution Card («البحور الشعرية في الديوان»)
              if (meters.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  decoration: BoxDecoration(
                    color: p.surfaceElevated.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: p.hairline, width: 0.95),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: p.accentSoft,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(
                              Icons.waves_rounded,
                              size: 16.5,
                              color: p.accent,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isFemale
                                  ? 'أبرز بحورها الشعرية'
                                  : 'أبرز بحوره الشعرية',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: p.accent,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ...meters.take(8).map((m) {
                        final maxCount = meters.first.poemCount > 0
                            ? meters.first.poemCount
                            : 1;
                        final ratio = (m.poemCount / maxCount).clamp(0.06, 1.0);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'بحر ${m.name}',
                                    style: TextStyle(
                                      fontFamily: AppFonts.ui,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: p.ink,
                                    ),
                                  ),
                                  Text(
                                    '${ArabicNormalizer.toArabicNumber(m.poemCount)} قصيدة',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: p.accent,
                                          fontWeight: FontWeight.w600,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  minHeight: 5.5,
                                  backgroundColor: p.surface,
                                  valueColor: AlwaysStoppedAnimation(
                                    p.accent.withValues(alpha: 0.78),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _BioChip extends StatelessWidget {
  const _BioChip({
    required this.icon,
    required this.label,
    this.accented = false,
  });

  final IconData icon;
  final String label;
  final bool accented;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: accented ? p.accentSoft : p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accented ? p.accent.withValues(alpha: 0.35) : p.hairline,
          width: 0.85,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: p.accent),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 11.5,
              fontWeight: accented ? FontWeight.w600 : FontWeight.w500,
              color: accented ? p.accent : p.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _BioStatTile extends StatelessWidget {
  const _BioStatTile({
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
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: p.surface.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.hairline, width: 0.85),
        ),
        child: Column(
          children: [
            Icon(icon, size: 15, color: p.accent),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: p.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }
}
