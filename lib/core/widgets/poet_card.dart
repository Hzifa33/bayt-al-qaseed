import 'package:flutter/material.dart';

import '../../data/models/poet.dart';
import '../animations/bayt_motion.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../utils/arabic_normalizer.dart';
import 'bayt_ornaments.dart';

/// Compact, zero-truncation horizontally balanced Poet card.
///
/// Features a circular person medallion, tactile 0.97 press scale, tabular
/// numerals for poem/verse counts, and a morphing favorite heart icon.
class PoetCard extends StatelessWidget {
  const PoetCard({
    super.key,
    required this.poet,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
    this.showEra = true,
  });

  final Poet poet;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final bool showEra;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return BaytPressable(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: p.surfaceElevated,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: p.hairline, width: 0.9),
            ),
            child: Row(
              children: [
                // Circular Poet Person Icon Medallion
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.accentSoft,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: p.ornament.withValues(alpha: 0.36),
                      width: 0.9,
                    ),
                  ),
                  child: PoetAvatarIcon(
                    poetId: poet.id,
                    poetName: poet.namePlain,
                    size: 20,
                    color: p.accent,
                  ),
                ),
                const SizedBox(width: 10),

                // Poet Name (auto-scaled gently so it NEVER clips with "...") + Clean Meta Row
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            poet.name,
                            maxLines: 1,
                            style: TextStyle(
                              fontFamily: AppFonts.scheherazade,
                              fontSize: 18.5,
                              fontWeight: FontWeight.w700,
                              color: p.ink,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 1.5),
                      Row(
                        children: [
                          if (showEra) ...[
                            Icon(
                              Icons.hourglass_bottom_rounded,
                              size: 11,
                              color: p.accent,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              poet.eraName,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(fontSize: 10.5),
                            ),
                            const SizedBox(width: 8),
                          ] else if (poet.datesHijri.isNotEmpty) ...[
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 10.5,
                              color: p.accent,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                poet.datesHijri,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(fontSize: 10.5),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Icon(
                            Icons.format_quote_rounded,
                            size: 11,
                            color: p.inkMuted,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${ArabicNormalizer.toArabicNumber(poet.verseCount)} بيت',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontSize: 10.5,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),

                // Ultra-Compact Poem Count Badge (tabular numerals)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: p.hairline, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_stories_outlined,
                        size: 11.5,
                        color: p.accent,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        ArabicNormalizer.toArabicNumber(poet.poemCount),
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: p.accent,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),

                // Morphing Favorite Toggle
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 34,
                    minHeight: 34,
                  ),
                  tooltip: isFavorite ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
                  onPressed: onToggleFavorite,
                  icon: BaytIconMorph(
                    icon: Icon(
                      isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      key: ValueKey(isFavorite),
                      color: isFavorite ? p.accent : p.inkMuted,
                      size: 18.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
