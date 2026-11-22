import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/arabic_normalizer.dart';
import '../../../core/widgets/editorial_divider.dart';
import '../../../data/models/meter.dart';
import '../../../data/models/poet.dart';
import '../../providers/user_data_providers.dart';

/// Dedicated, generously typeset Poet Biography & Diwan Profile screen.
class PoetBioScreen extends ConsumerWidget {
  const PoetBioScreen({super.key, required this.poet, required this.meters});

  final Poet poet;
  final List<Meter> meters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final isFav = ref.watch(userDataProvider).favoritePoetIds.contains(poet.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('سيرة الشاعر'),
        actions: [
          IconButton(
            tooltip: isFav
                ? 'إزالة من الشعراء المفضلين'
                : 'حفظ في الشعراء المفضلين',
            onPressed: () =>
                ref.read(userDataProvider.notifier).toggleFavoritePoet(poet.id),
            icon: Icon(
              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isFav ? p.accent : p.ink,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            decoration: BoxDecoration(
              color: p.surfaceElevated,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: p.ornament.withValues(alpha: 0.45),
                width: 1.05,
              ),
            ),
            child: Column(
              children: [
                Text(
                  poet.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.ruqaa,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _BioChip(label: 'العصر ${poet.eraName}'),
                    if (poet.formattedDates.isNotEmpty)
                      _BioChip(label: poet.formattedDates),
                  ],
                ),
                const EditorialDivider(
                  verticalPadding: 18,
                  horizontalPadding: 28,
                ),
                Row(
                  children: [
                    _BioStat(
                      value: ArabicNormalizer.toArabicNumber(poet.poemCount),
                      label: 'قصيدة في الديوان',
                    ),
                    _BioStat(
                      value: ArabicNormalizer.toArabicNumber(poet.verseCount),
                      label: 'بيتاً شعرياً',
                    ),
                    _BioStat(
                      value: ArabicNormalizer.toArabicNumber(meters.length),
                      label: 'بحراً عروضياً',
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (poet.bio.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: p.surfaceElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: p.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الترجمة والتعريف',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: p.accent),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    poet.bio,
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(height: 2.0, color: p.ink),
                  ),
                ],
              ),
            ),
          ],
          if (meters.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: p.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'أبرز بحوره الشعرية',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(color: p.accent),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: meters.take(10).map((m) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: p.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: p.hairline),
                        ),
                        child: Text(
                          'بحر ${m.name} (${ArabicNormalizer.toArabicNumber(m.poemCount)})',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BioChip extends StatelessWidget {
  const _BioChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: p.accentSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: p.accent,
        ),
      ),
    );
  }
}

class _BioStat extends StatelessWidget {
  const _BioStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Expanded(
      child: Column(
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
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
