import 'package:flutter/material.dart';

import '../../data/models/reader_settings.dart';
import '../../data/models/verse.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../utils/arabic_normalizer.dart';
import 'bayt_ornaments.dart';

/// Symmetrical Equal-Width Precision Arabic Verse Engine.
///
/// Key typographic guarantees:
/// 1. Equal bounded column width for both الصدر (Sadr) and العجز (Ajuz) so both
///    flanks stay aligned like a masterfully typeset Arabic Diwan.
/// 2. Bi-directional Dynamic Auto-Fit: shrinks smoothly when a hemistich is long
///    (never breaking into 2 awkward lines) AND gently scales up + balances
///    word spacing when a hemistich is short so both sides look symmetrical.
/// 3. Refined staggered-mode verse numbering via delicate marginal medallions.
/// 4. Warm illuminated parchment-gold card glow for selected verses (no clunky side bars).
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
        ? p.highlightFill.withValues(alpha: 0.25)
        : Colors.transparent;

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: layoutStyle == VerseLayoutStyle.staggered ? 3.5 : 2,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          splashColor: p.accentSoft,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: layoutStyle == VerseLayoutStyle.staggered ? 10 : 7,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? p.accent.withValues(alpha: 0.65)
                    : isHighlightedVerse
                    ? p.accent.withValues(alpha: 0.4)
                    : Colors.transparent,
                width: isSelected ? 1.15 : 0.9,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: p.accent.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                verse.isMukhammas
                    ? (layoutStyle == VerseLayoutStyle.staggered
                          ? _buildMukhammasStaggered(context, baseStyle)
                          : _buildMukhammasSideBySide(context, baseStyle))
                    : !verse.isTwoHemistich
                    ? _buildSingleLine(
                        context,
                        sadr.isNotEmpty ? sadr : ajuz,
                        baseStyle,
                      )
                    : layoutStyle == VerseLayoutStyle.staggered
                    ? _buildStaggeredSymmetrical(context, sadr, ajuz, baseStyle)
                    : _buildSideBySideSymmetrical(
                        context,
                        sadr,
                        ajuz,
                        baseStyle,
                      ),

                // Elegant selection check medallion (top-left in RTL)
                if (isSelected)
                  Positioned(
                    top: -4,
                    left: -4,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: p.accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: p.accent.withValues(alpha: 0.35),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: Theme.of(context).colorScheme.onPrimary,
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

  /// Computes a calibrated TextStyle for a single hemistich inside [boxWidth].
  ///
  /// - If the hemistich overflows [boxWidth], shrinks smoothly (down to 0.56x).
  /// - If the hemistich is significantly shorter than [boxWidth], gently scales up
  ///   (up to 1.14x) and adds balanced wordSpacing so both flanks look harmoniously
  ///   filled and symmetrical!
  TextStyle _calibrateHemistichStyle({
    required String text,
    required TextStyle baseStyle,
    required double boxWidth,
    required TextScaler textScaler,
  }) {
    if (text.isEmpty || boxWidth <= 0) return baseStyle;
    final baseSize = baseStyle.fontSize ?? 20;

    final tp = TextPainter(
      text: TextSpan(text: text, style: baseStyle),
      textDirection: TextDirection.rtl,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final measured = tp.width;
    tp.dispose();

    if (measured <= 0) return baseStyle;

    // 1. Too wide -> shrink strictly to fit inside boxWidth with 2px cushion
    if (measured > boxWidth - 2.0) {
      final ratio = ((boxWidth - 2.0) / measured).clamp(0.54, 1.0);
      return baseStyle.copyWith(fontSize: baseSize * ratio);
    }

    // 2. Shorter than boxWidth -> gently expand font (capped at 1.14x) + distribute subtle wordSpacing
    final fillRatio = measured / boxWidth;
    if (fillRatio < 0.88) {
      final growScale = (0.94 / fillRatio).clamp(1.0, 1.14);
      final grownSize = baseSize * growScale;
      final grownStyle = baseStyle.copyWith(fontSize: grownSize);

      final tp2 = TextPainter(
        text: TextSpan(text: text, style: grownStyle),
        textDirection: TextDirection.rtl,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      final grownWidth = tp2.width;
      tp2.dispose();

      final spaces = ' '.allMatches(text.trim()).length;
      if (spaces >= 2 && grownWidth < boxWidth - 4.0) {
        final extraPerSpace = ((boxWidth - 4.0 - grownWidth) / spaces).clamp(
          0.0,
          10.0,
        );
        return grownStyle.copyWith(wordSpacing: extraPerSpace);
      }
      return grownStyle;
    }

    return baseStyle;
  }

  Widget _renderHemistich(
    BuildContext context,
    String text,
    TextStyle style, {
    required TextAlign textAlign,
    required bool allowWrap,
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
        softWrap: allowWrap,
        maxLines: allowWrap ? null : 1,
        overflow: TextOverflow.visible,
        text: TextSpan(children: spans),
      );
    }
    return Text(
      text,
      textDirection: TextDirection.rtl,
      textAlign: textAlign,
      softWrap: allowWrap,
      maxLines: allowWrap ? null : 1,
      overflow: TextOverflow.visible,
      style: style,
    );
  }

  /// Staggered layout where الصدر and العجز occupy EQUAL horizontal bounds (78% width),
  /// aligned flush right and flush left respectively for true classical symmetry.
  Widget _buildStaggeredSymmetrical(
    BuildContext context,
    String sadr,
    String ajuz,
    TextStyle baseStyle,
  ) {
    final textScaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalW = constraints.maxWidth;
        final boxW = (totalW * 0.80).clamp(160.0, 520.0);
        final indent = totalW - boxW;

        final sadrAllowWrap =
            ArabicNormalizer.stripDiacritics(sadr).length > 72;
        final ajuzAllowWrap =
            ArabicNormalizer.stripDiacritics(ajuz).length > 72;

        final sadrStyle = sadrAllowWrap
            ? baseStyle
            : _calibrateHemistichStyle(
                text: sadr,
                baseStyle: baseStyle,
                boxWidth: boxW,
                textScaler: textScaler,
              );
        final ajuzStyle = ajuzAllowWrap
            ? baseStyle
            : _calibrateHemistichStyle(
                text: ajuz,
                baseStyle: baseStyle,
                boxWidth: boxW,
                textScaler: textScaler,
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showVerseNumber)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    VerseNumberMedallion(
                      number: verse.index + 1,
                      isSelected: isSelected,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 0.6,
                        color: context.palette.hairline.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
            // الصدر (Right-aligned equal box)
            Padding(
              padding: EdgeInsets.only(left: indent),
              child: SizedBox(
                width: boxW,
                child: _renderHemistich(
                  context,
                  sadr,
                  sadrStyle,
                  textAlign: TextAlign.right,
                  allowWrap: sadrAllowWrap,
                ),
              ),
            ),
            const SizedBox(height: 2),
            // العجز (Left-aligned equal box)
            Padding(
              padding: EdgeInsets.only(right: indent),
              child: SizedBox(
                width: boxW,
                child: _renderHemistich(
                  context,
                  ajuz,
                  ajuzStyle,
                  textAlign: TextAlign.left,
                  allowWrap: ajuzAllowWrap,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Side-by-Side layout where الصدر and العجز occupy EQUAL halves with
  /// synchronized scaling & balanced symmetry.
  Widget _buildSideBySideSymmetrical(
    BuildContext context,
    String sadr,
    String ajuz,
    TextStyle baseStyle,
  ) {
    final textScaler = MediaQuery.textScalerOf(context);
    const centerGap = 16.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        const numColWidth = 34.0;
        const numGap = 8.0;
        final numReserve = showVerseNumber ? (numColWidth + numGap) : 0.0;
        final halfWidth =
            ((constraints.maxWidth - numReserve - centerGap) / 2.0).clamp(
              80.0,
              420.0,
            );

        final sadrAllowWrap =
            ArabicNormalizer.stripDiacritics(sadr).length > 68;
        final ajuzAllowWrap =
            ArabicNormalizer.stripDiacritics(ajuz).length > 68;

        final sadrStyle = sadrAllowWrap
            ? baseStyle
            : _calibrateHemistichStyle(
                text: sadr,
                baseStyle: baseStyle,
                boxWidth: halfWidth,
                textScaler: textScaler,
              );
        final ajuzStyle = ajuzAllowWrap
            ? baseStyle
            : _calibrateHemistichStyle(
                text: ajuz,
                baseStyle: baseStyle,
                boxWidth: halfWidth,
                textScaler: textScaler,
              );

        // Keep both hemistichs within a gentle font-size band of each other
        final sSz = sadrStyle.fontSize ?? (baseStyle.fontSize ?? 20);
        final aSz = ajuzStyle.fontSize ?? (baseStyle.fontSize ?? 20);
        final minSz = sSz < aSz ? sSz : aSz;
        final syncedSadr = sSz > minSz * 1.08
            ? sadrStyle.copyWith(fontSize: minSz * 1.06)
            : sadrStyle;
        final syncedAjuz = aSz > minSz * 1.08
            ? ajuzStyle.copyWith(fontSize: minSz * 1.06)
            : ajuzStyle;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Strictly parallel fixed-width vertical column for verse numbers
            if (showVerseNumber) ...[
              SizedBox(
                width: numColWidth,
                child: VerseNumberMedallion(
                  number: verse.index + 1,
                  isSelected: isSelected,
                  fixedWidth: numColWidth,
                ),
              ),
              const SizedBox(width: numGap),
            ],
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: sadrAllowWrap
                    ? _renderHemistich(
                        context,
                        sadr,
                        syncedSadr,
                        textAlign: TextAlign.right,
                        allowWrap: true,
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: _renderHemistich(
                          context,
                          sadr,
                          syncedSadr,
                          textAlign: TextAlign.right,
                          allowWrap: false,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: centerGap),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: ajuzAllowWrap
                    ? _renderHemistich(
                        context,
                        ajuz,
                        syncedAjuz,
                        textAlign: TextAlign.left,
                        allowWrap: true,
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: _renderHemistich(
                          context,
                          ajuz,
                          syncedAjuz,
                          textAlign: TextAlign.left,
                          allowWrap: false,
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMukhammasStaggered(BuildContext context, TextStyle baseStyle) {
    final textScaler = MediaQuery.textScalerOf(context);
    final p = context.palette;
    final h1 = _prepare(verse.sadr);
    final h2 = _prepare(verse.ajuz);
    final h3 = _prepare(verse.extraHemistichs[0]);
    final h4 = _prepare(verse.extraHemistichs[1]);
    final h5 = _prepare(verse.extraHemistichs[2]);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalW = constraints.maxWidth;
        final boxW = (totalW * 0.80).clamp(160.0, 520.0);
        final indent = totalW - boxW;

        Widget hemistichLine(String text, TextAlign align, {double left = 0, double right = 0, bool isRefrain = false}) {
          final allowWrap = ArabicNormalizer.stripDiacritics(text).length > 72;
          final style = allowWrap
              ? baseStyle
              : _calibrateHemistichStyle(
                  text: text,
                  baseStyle: baseStyle,
                  boxWidth: isRefrain ? totalW * 0.90 : boxW,
                  textScaler: textScaler,
                );
          return Padding(
            padding: EdgeInsets.only(left: left, right: right),
            child: SizedBox(
              width: isRefrain ? totalW : boxW,
              child: _renderHemistich(
                context,
                text,
                style,
                textAlign: align,
                allowWrap: allowWrap,
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showVerseNumber)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    VerseNumberMedallion(
                      number: verse.index + 1,
                      isSelected: isSelected,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 0.6,
                        color: p.hairline.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
            hemistichLine(h1, TextAlign.right, left: indent),
            const SizedBox(height: 2),
            hemistichLine(h2, TextAlign.left, right: indent),
            const SizedBox(height: 5),
            hemistichLine(h3, TextAlign.right, left: indent),
            const SizedBox(height: 2),
            hemistichLine(h4, TextAlign.left, right: indent),
            const SizedBox(height: 5),
            hemistichLine(h5, TextAlign.center, isRefrain: true),
          ],
        );
      },
    );
  }

  Widget _buildMukhammasSideBySide(BuildContext context, TextStyle baseStyle) {
    final textScaler = MediaQuery.textScalerOf(context);
    final h1 = _prepare(verse.sadr);
    final h2 = _prepare(verse.ajuz);
    final h3 = _prepare(verse.extraHemistichs[0]);
    final h4 = _prepare(verse.extraHemistichs[1]);
    final h5 = _prepare(verse.extraHemistichs[2]);
    const centerGap = 16.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        const numColWidth = 34.0;
        const numGap = 8.0;
        final numReserve = showVerseNumber ? (numColWidth + numGap) : 0.0;
        final contentWidth = (constraints.maxWidth - numReserve).clamp(
          160.0,
          900.0,
        );
        final halfWidth = ((contentWidth - centerGap) / 2.0).clamp(80.0, 420.0);

        Widget buildPair(String s, String a) {
          final sWrap = ArabicNormalizer.stripDiacritics(s).length > 68;
          final aWrap = ArabicNormalizer.stripDiacritics(a).length > 68;
          final sStyle = sWrap
              ? baseStyle
              : _calibrateHemistichStyle(
                  text: s,
                  baseStyle: baseStyle,
                  boxWidth: halfWidth,
                  textScaler: textScaler,
                );
          final aStyle = aWrap
              ? baseStyle
              : _calibrateHemistichStyle(
                  text: a,
                  baseStyle: baseStyle,
                  boxWidth: halfWidth,
                  textScaler: textScaler,
                );
          final sSz = sStyle.fontSize ?? (baseStyle.fontSize ?? 20);
          final aSz = aStyle.fontSize ?? (baseStyle.fontSize ?? 20);
          final minSz = sSz < aSz ? sSz : aSz;
          final syncedS = sSz > minSz * 1.08
              ? sStyle.copyWith(fontSize: minSz * 1.06)
              : sStyle;
          final syncedA = aSz > minSz * 1.08
              ? aStyle.copyWith(fontSize: minSz * 1.06)
              : aStyle;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: sWrap
                      ? _renderHemistich(
                          context,
                          s,
                          syncedS,
                          textAlign: TextAlign.right,
                          allowWrap: true,
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: _renderHemistich(
                            context,
                            s,
                            syncedS,
                            textAlign: TextAlign.right,
                            allowWrap: false,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: centerGap),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: aWrap
                      ? _renderHemistich(
                          context,
                          a,
                          syncedA,
                          textAlign: TextAlign.left,
                          allowWrap: true,
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: _renderHemistich(
                            context,
                            a,
                            syncedA,
                            textAlign: TextAlign.left,
                            allowWrap: false,
                          ),
                        ),
                ),
              ),
            ],
          );
        }

        final h5Style = _calibrateHemistichStyle(
          text: h5,
          baseStyle: baseStyle,
          boxWidth: contentWidth * 0.88,
          textScaler: textScaler,
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showVerseNumber) ...[
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SizedBox(
                  width: numColWidth,
                  child: VerseNumberMedallion(
                    number: verse.index + 1,
                    isSelected: isSelected,
                    fixedWidth: numColWidth,
                  ),
                ),
              ),
              const SizedBox(width: numGap),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  buildPair(h1, h2),
                  const SizedBox(height: 3),
                  buildPair(h3, h4),
                  const SizedBox(height: 5),
                  _renderHemistich(
                    context,
                    h5,
                    h5Style,
                    textAlign: TextAlign.center,
                    allowWrap: true,
                  ),
                ],
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
    if (layoutStyle == VerseLayoutStyle.sideBySide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showVerseNumber) ...[
            SizedBox(
              width: 34,
              child: VerseNumberMedallion(
                number: verse.index + 1,
                isSelected: isSelected,
                fixedWidth: 34,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
              child: _renderHemistich(
                context,
                text,
                baseStyle,
                textAlign: TextAlign.center,
                allowWrap: true,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showVerseNumber)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                VerseNumberMedallion(
                  number: verse.index + 1,
                  isSelected: isSelected,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 0.6,
                    color: context.palette.hairline.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
          child: _renderHemistich(
            context,
            text,
            baseStyle,
            textAlign: TextAlign.center,
            allowWrap: true,
          ),
        ),
      ],
    );
  }
}

/// Computes a harmonious poem-wide base font size so classical verses share
/// an even visual cadence while per-hemistich calibration fine-tunes symmetry.
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

  final horizontalChrome =
      48.0 +
      (showVerseNumbers && layoutStyle == VerseLayoutStyle.sideBySide
          ? 38.0
          : 0.0);
  final innerWidth = (viewportWidth - horizontalChrome).clamp(160.0, 900.0);
  final targetHemistichWidth = layoutStyle == VerseLayoutStyle.sideBySide
      ? (innerWidth - 16.0) / 2.0
      : (innerWidth * 0.80).clamp(160.0, 520.0);

  final step = (verses.length / 24).ceil().clamp(1, verses.length);
  final widths = <double>[];
  final probeStyle = AppTypography.poeticVerse(
    font: font,
    fontSize: requestedFontSize,
    color: Colors.black,
  );

  for (var i = 0; i < verses.length; i += step) {
    final v = verses[i];
    if (!v.isTwoHemistich && !v.isMukhammas) continue;
    for (final raw in v.allHemistichs) {
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
  final p80 =
      widths[(widths.length * 0.80).floor().clamp(0, widths.length - 1)];
  if (p80 <= targetHemistichWidth || p80 == 0) {
    return requestedFontSize;
  }
  final ratio = ((targetHemistichWidth - 2.0) / p80).clamp(0.64, 1.0);
  return requestedFontSize * ratio;
}
