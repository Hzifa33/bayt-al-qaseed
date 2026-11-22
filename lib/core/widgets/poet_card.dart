import 'package:flutter/material.dart';

import '../../data/models/poet.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../utils/arabic_normalizer.dart';

/// Compact, horizontally balanced Poet card shared across Eras, Poets directory,
/// and Favorite Poets lists.
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

  String _monogram(String namePlain) {
    final cleaned = namePlain
        .replaceFirst(RegExp(r'^(أبو|ابو|ابن|أم|ام|الإمام|الشيخ)\s+'), '')
        .replaceFirst(RegExp(r'^ال'), '')
        .trim();
    if (cleaned.isEmpty) return 'ش';
    return cleaned.substring(0, 1);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final subParts = <String>[];
    if (showEra) subParts.add('العصر ${poet.eraName}');
    if (poet.datesHijri.isNotEmpty) subParts.add(poet.datesHijri);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: p.surfaceElevated,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: p.hairline, width: 0.9),
          ),
          child: Row(
            children: [
              // Calligraphic Monogram Medallion
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: p.ornament.withValues(alpha: 0.35),
                    width: 0.9,
                  ),
                ),
                child: Text(
                  _monogram(poet.namePlain),
                  style: TextStyle(
                    fontFamily: AppFonts.ruqaa,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: p.accent,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Poet Name + Single Compact Meta Line
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      poet.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.scheherazade,
                        fontSize: 20.5,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                        height: 1.32,
                      ),
                    ),
                    if (subParts.isNotEmpty)
                      Text(
                        subParts.join('  •  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Right-aligned Compact Metrics Pill (Horizontal distribution!)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: p.hairline, width: 0.8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${ArabicNormalizer.toArabicNumber(poet.poemCount)} قصيدة',
                      style: TextStyle(
                        fontFamily: AppFonts.ui,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: p.accent,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      '${ArabicNormalizer.toArabicNumber(poet.verseCount)} بيت',
                      style: TextStyle(
                        fontFamily: AppFonts.ui,
                        fontSize: 9.8,
                        color: p.inkMuted,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 2),

              // Compact Favorite Toggle
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                tooltip: isFavorite ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
                onPressed: onToggleFavorite,
                icon: Icon(
                  isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isFavorite ? p.accent : p.inkMuted,
                  size: 19,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
