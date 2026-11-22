import 'package:flutter/material.dart';

import '../../data/models/reader_settings.dart';
import '../../data/models/verse.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../utils/arabic_normalizer.dart';

/// Zero-Defect Precision Arabic Verse Engine.
///
/// Guarantees:
/// - Clean geometric separation of الصدر (Sadr) and العجز (Ajuz).
/// - Both Side-by-Side (الشطرين المتقابلين) and Staggered (الشطرين المتدرجين) modes.
/// - Automatic detection of single-hemistich / free-verse lines (شعر حر / موشح).
/// - Dynamic Auto-Fit Scaling using exact [TextPainter] measurements so classical
///   hemistichs NEVER break awkwardly into two lines, while preserving generous
///   line-height (1.98–2.15) to prevent tashkeel collisions.
/// - Diacritic-preserving golden highlighting for search matches.
class VerseRowWidget extends StatelessWidget {
  const VerseRowWidget({
    super.key,
    required this.verse,
    required this.font,
    required this.fontSize,
    required this.layoutStyle,
    required this.showDiacritics,
    required this.showVerseNumber,
    this.isSelected = false,
    this.isHighlightedVerse = false,
    this.searchHighlightQuery,
    this.onTap,
    this.onLongPress,
  });

  final Verse verse;
  final PoetryFontOption font;
  final double fontSize;
  final VerseLayoutStyle layoutStyle;
  final bool showDiacritics;
  final bool showVerseNumber;
  final bool isSelected;
  final bool isHighlightedVerse;
  final String? searchHighlightQuery;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  String _prepare(String raw) =>
      showDiacritics ? raw : ArabicNormalizer.stripDiacritics(raw);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final sadr = _prepare(verse.sadr);
    final ajuz = _prepare(verse.ajuz);

    final baseStyle = AppTypography.poeticVerse(
      font: font,
      fontSize: fontSize,
      color: p.ink,
    );

    final bgColor = isSelected
        ? p.selectedVerseFill
        : isHighlightedVerse
        ? p.highlightFill.withValues(alpha: 0.22)
        : Colors.transparent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        splashColor: p.accentSoft,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: EdgeInsets.symmetric(
            horizontal: 10,
            vertical: layoutStyle == VerseLayoutStyle.staggered ? 8 : 6,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border(right: BorderSide(color: p.accent, width: 3))
                : isHighlightedVerse
                ? Border.all(color: p.accent.withValues(alpha: 0.45), width: 1)
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showVerseNumber)
                SizedBox(
                  width: 30,
                  child: Text(
                    ArabicNormalizer.toArabicNumber(verse.index + 1),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? p.accent
                          : p.inkMuted.withValues(alpha: 0.72),
                    ),
                  ),
                ),
              Expanded(
                child: !verse.isTwoHemistich
                    ? _buildSingleLine(
                        context,
                        sadr.isNotEmpty ? sadr : ajuz,
                        baseStyle,
                      )
                    : layoutStyle == VerseLayoutStyle.sideBySide
                    ? _buildSideBySide(context, sadr, ajuz, baseStyle)
                    : _buildStaggered(context, sadr, ajuz, baseStyle),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextSpanWidget(
    BuildContext context,
    String text,
    TextStyle style, {
    required TextAlign textAlign,
    required bool softWrap,
  }) {
    final p = context.palette;
    final query = searchHighlightQuery;
    if (query != null && query.trim().isNotEmpty) {
      final spans = ArabicNormalizer.buildHighlightedSpans(
        originalText: text,
        rawQuery: query,
        baseStyle: style,
        highlightBackground: p.highlightFill,
        highlightForeground: p.ink,
      );
      return RichText(
        textDirection: TextDirection.rtl,
        textAlign: textAlign,
        softWrap: softWrap,
        maxLines: softWrap ? null : 1,
        overflow: TextOverflow.visible,
        text: TextSpan(children: spans),
      );
    }
    return Text(
      text,
      textDirection: TextDirection.rtl,
      textAlign: textAlign,
      softWrap: softWrap,
      maxLines: softWrap ? null : 1,
      overflow: TextOverflow.visible,
      style: style,
    );
  }

  /// Computes a smooth proportional font size so both hemistichs fit strictly on one line.
  double _computeFittedFontSize({
    required List<String> hemistichs,
    required TextStyle baseStyle,
    required double maxWidth,
    required TextScaler textScaler,
  }) {
    if (maxWidth <= 0) return baseStyle.fontSize ?? 20;
    final originalSize = baseStyle.fontSize ?? 20;
    double maxMeasured = 0;

    for (final h in hemistichs) {
      if (h.isEmpty) continue;
      final tp = TextPainter(
        text: TextSpan(text: h, style: baseStyle),
        textDirection: TextDirection.rtl,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      if (tp.width > maxMeasured) {
        maxMeasured = tp.width;
      }
      tp.dispose();
    }

    if (maxMeasured <= maxWidth || maxMeasured == 0) {
      return originalSize;
    }

    // Reserve a tiny 2px safety cushion for glyph bearings & tashkeel overhang.
    final ratio = ((maxWidth - 2.0) / maxMeasured).clamp(0.52, 1.0);
    return originalSize * ratio;
  }

  Widget _buildSideBySide(
    BuildContext context,
    String sadr,
    String ajuz,
    TextStyle baseStyle,
  ) {
    final textScaler = MediaQuery.textScalerOf(context);
    const centerGap = 18.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final halfWidth = (constraints.maxWidth - centerGap) / 2.0;
        final fittedSize = _computeFittedFontSize(
          hemistichs: [sadr, ajuz],
          baseStyle: baseStyle,
          maxWidth: halfWidth,
          textScaler: textScaler,
        );
        final fittedStyle = baseStyle.copyWith(fontSize: fittedSize);
        // Only wrap extreme prose-like outliers (>68 base chars)
        final allowWrap =
            ArabicNormalizer.stripDiacritics(sadr).length > 68 ||
            ArabicNormalizer.stripDiacritics(ajuz).length > 68;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: _buildTextSpanWidget(
                context,
                sadr,
                fittedStyle,
                textAlign: TextAlign.start,
                softWrap: allowWrap,
              ),
            ),
            const SizedBox(width: centerGap),
            Expanded(
              child: _buildTextSpanWidget(
                context,
                ajuz,
                fittedStyle,
                textAlign: TextAlign.end,
                softWrap: allowWrap,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStaggered(
    BuildContext context,
    String sadr,
    String ajuz,
    TextStyle baseStyle,
  ) {
    final textScaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final indent = (constraints.maxWidth * 0.14).clamp(24.0, 56.0);
        final availWidth = constraints.maxWidth - indent;
        final fittedSize = _computeFittedFontSize(
          hemistichs: [sadr, ajuz],
          baseStyle: baseStyle,
          maxWidth: availWidth,
          textScaler: textScaler,
        );
        final fittedStyle = baseStyle.copyWith(fontSize: fittedSize);
        final allowWrap =
            ArabicNormalizer.stripDiacritics(sadr).length > 72 ||
            ArabicNormalizer.stripDiacritics(ajuz).length > 72;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.only(left: indent),
              child: _buildTextSpanWidget(
                context,
                sadr,
                fittedStyle,
                textAlign: TextAlign.start,
                softWrap: allowWrap,
              ),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: EdgeInsets.only(right: indent),
              child: _buildTextSpanWidget(
                context,
                ajuz,
                fittedStyle,
                textAlign: TextAlign.end,
                softWrap: allowWrap,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSingleLine(
    BuildContext context,
    String text,
    TextStyle baseStyle,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
      child: _buildTextSpanWidget(
        context,
        text,
        baseStyle,
        textAlign: TextAlign.center,
        softWrap: true,
      ),
    );
  }
}

/// Computes a consistent poem-wide harmonious base font size so classical verses
/// look evenly typeset like a printed anthology, while individual longer verses
/// still benefit from per-verse Dynamic Auto-Fit Scaling.
double computePoemHarmoniousFontSize({
  required List<Verse> verses,
  required PoetryFontOption font,
  required double requestedFontSize,
  required VerseLayoutStyle layoutStyle,
  required bool showDiacritics,
  required bool showVerseNumbers,
  required double viewportWidth,
  required TextScaler textScaler,
}) {
  if (verses.isEmpty || viewportWidth <= 0) return requestedFontSize;

  final horizontalChrome = 40.0 + (showVerseNumbers ? 30.0 : 0.0);
  final innerWidth = (viewportWidth - horizontalChrome).clamp(160.0, 900.0);
  final targetHemistichWidth = layoutStyle == VerseLayoutStyle.sideBySide
      ? (innerWidth - 18.0) / 2.0
      : innerWidth - (innerWidth * 0.14).clamp(24.0, 56.0);

  // Sample up to 24 classical two-hemistich verses evenly across the poem.
  final step = (verses.length / 24).ceil().clamp(1, verses.length);
  final widths = <double>[];
  final probeStyle = AppTypography.poeticVerse(
    font: font,
    fontSize: requestedFontSize,
    color: Colors.black,
  );

  for (var i = 0; i < verses.length; i += step) {
    final v = verses[i];
    if (!v.isTwoHemistich) continue;
    for (final raw in [v.sadr, v.ajuz]) {
      final t = showDiacritics ? raw : ArabicNormalizer.stripDiacritics(raw);
      if (ArabicNormalizer.stripDiacritics(t).length > 65) continue;
      final tp = TextPainter(
        text: TextSpan(text: t, style: probeStyle),
        textDirection: TextDirection.rtl,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      widths.add(tp.width);
      tp.dispose();
    }
  }

  if (widths.isEmpty) return requestedFontSize;
  widths.sort();
  // Use the 85th-percentile width so the entire poem adopts a calm uniform rhythm.
  final p85 =
      widths[(widths.length * 0.85).floor().clamp(0, widths.length - 1)];
  if (p85 <= targetHemistichWidth || p85 == 0) {
    return requestedFontSize;
  }
  final ratio = ((targetHemistichWidth - 2.0) / p85).clamp(0.62, 1.0);
  return requestedFontSize * ratio;
}
