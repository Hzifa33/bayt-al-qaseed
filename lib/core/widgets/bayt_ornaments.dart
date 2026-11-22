import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../utils/arabic_normalizer.dart';

/// Bespoke Neo-Heritage geometric Rub-el-Hizb + Calligraphy Qalam emblem.
class BaytEmblem extends StatelessWidget {
  const BaytEmblem({
    super.key,
    this.size = 76,
    this.backgroundColor,
    this.goldColor,
    this.nibColor,
  });

  final double size;
  final Color? backgroundColor;
  final Color? goldColor;
  final Color? nibColor;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BaytEmblemPainter(
          bg: backgroundColor ?? p.surfaceElevated,
          gold: goldColor ?? p.accent,
          nib: nibColor ?? p.ink,
          hairline: p.hairline,
        ),
      ),
    );
  }
}

class _BaytEmblemPainter extends CustomPainter {
  _BaytEmblemPainter({
    required this.bg,
    required this.gold,
    required this.nib,
    required this.hairline,
  });

  final Color bg;
  final Color gold;
  final Color nib;
  final Color hairline;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.46;

    // Soft rounded backdrop
    final bgRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.width * 0.27),
    );
    canvas.drawRRect(bgRect, Paint()..color = bg);
    canvas.drawRRect(
      bgRect,
      Paint()
        ..color = hairline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Octagonal Rub-el-Hizb double rotated squares
    final framePaint = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.024
      ..strokeJoin = StrokeJoin.miter;

    final side = r * 1.18;
    final sq = Rect.fromCenter(
      center: Offset(cx, cy),
      width: side,
      height: side,
    );
    canvas.drawRect(sq, framePaint);

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(math.pi / 4);
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: side, height: side),
      framePaint,
    );
    canvas.restore();

    // Calligraphy Qalam nib
    final nibPath = Path()
      ..moveTo(cx, cy - r * 0.44)
      ..lineTo(cx + r * 0.21, cy + r * 0.08)
      ..lineTo(cx, cy + r * 0.42)
      ..lineTo(cx - r * 0.21, cy + r * 0.08)
      ..close();
    canvas.drawPath(nibPath, Paint()..color = nib);

    // Nib slit
    canvas.drawLine(
      Offset(cx, cy - r * 0.02),
      Offset(cx, cy + r * 0.40),
      Paint()
        ..color = bg
        ..strokeWidth = size.width * 0.022,
    );

    // Nib ink eye
    canvas.drawCircle(
      Offset(cx, cy - r * 0.04),
      size.width * 0.036,
      Paint()..color = gold,
    );
  }

  @override
  bool shouldRepaint(covariant _BaytEmblemPainter oldDelegate) =>
      oldDelegate.bg != bg ||
      oldDelegate.gold != gold ||
      oldDelegate.nib != nib;
}

/// Custom 4-petal Material You dynamic palette icon.
class MaterialYouIcon extends StatelessWidget {
  const MaterialYouIcon({
    super.key,
    this.size = 22,
    required this.color,
    this.filled = false,
  });

  final double size;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MaterialYouIconPainter(color: color, filled: filled),
      ),
    );
  }
}

class _MaterialYouIconPainter extends CustomPainter {
  _MaterialYouIconPainter({required this.color, required this.filled});
  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final petalR = size.width * 0.21;
    final dist = size.width * 0.21;
    final paint = Paint()
      ..color = color
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final offsets = [
      Offset(cx, cy - dist),
      Offset(cx + dist, cy),
      Offset(cx, cy + dist),
      Offset(cx - dist, cy),
    ];
    for (final o in offsets) {
      canvas.drawCircle(o, petalR, paint);
    }
    canvas.drawCircle(
      Offset(cx, cy),
      size.width * 0.09,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _MaterialYouIconPainter old) =>
      old.color != color || old.filled != filled;
}

/// Delicate classical medallion for verse numbering (`١`, `٢`, ...).
class VerseNumberMedallion extends StatelessWidget {
  const VerseNumberMedallion({
    super.key,
    required this.number,
    required this.isSelected,
  });

  final int number;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = isSelected ? p.accent : p.inkMuted.withValues(alpha: 0.78);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? p.accentSoft : p.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected
              ? p.accent.withValues(alpha: 0.55)
              : p.ornament.withValues(alpha: 0.35),
          width: 0.85,
        ),
      ),
      child: Text(
        ArabicNormalizer.toArabicNumber(number),
        style: TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: fg,
          height: 1.2,
        ),
      ),
    );
  }
}

/// Contacts-style interactive Fast-Scroll Section Scrubber with a calligraphic
/// preview bubble showing the current section label (قافية / بحر / حرف).
class SectionFastScroller extends StatefulWidget {
  const SectionFastScroller({
    super.key,
    required this.sectionLabels,
    required this.onSelectSection,
    required this.child,
  });

  final List<String> sectionLabels;
  final void Function(int sectionIndex) onSelectSection;
  final Widget child;

  @override
  State<SectionFastScroller> createState() => _SectionFastScrollerState();
}

class _SectionFastScrollerState extends State<SectionFastScroller> {
  bool _dragging = false;
  int _activeIndex = 0;
  double _dragFrac = 0.0;

  void _handleDrag(double dy, double trackHeight) {
    if (widget.sectionLabels.isEmpty || trackHeight <= 0) return;
    final frac = (dy / trackHeight).clamp(0.0, 1.0);
    final idx = (frac * (widget.sectionLabels.length - 1)).round();
    if (idx != _activeIndex || !_dragging) {
      HapticFeedback.selectionClick();
      widget.onSelectSection(idx);
    }
    setState(() {
      _dragging = true;
      _activeIndex = idx;
      _dragFrac = frac;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final labels = widget.sectionLabels;
    if (labels.length < 3) return widget.child;

    // Show up to 22 crisp markers along the rail to avoid overcrowding
    final displayIndices = <int>[];
    if (labels.length <= 22) {
      for (var i = 0; i < labels.length; i++) {
        displayIndices.add(i);
      }
    } else {
      for (var i = 0; i < 22; i++) {
        displayIndices.add(((i / 21) * (labels.length - 1)).round());
      }
    }

    return Stack(
      children: [
        widget.child,
        // Interactive scrubber rail on the left (end in RTL)
        Positioned(
          left: 3,
          top: 12,
          bottom: 24,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final h = constraints.maxHeight;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: (d) => _handleDrag(d.localPosition.dy, h),
                onVerticalDragUpdate: (d) => _handleDrag(d.localPosition.dy, h),
                onVerticalDragEnd: (_) => setState(() => _dragging = false),
                onTapDown: (d) {
                  _handleDrag(d.localPosition.dy, h);
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted) setState(() => _dragging = false);
                  });
                },
                child: Container(
                  width: 24,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: _dragging
                        ? p.surfaceElevated.withValues(alpha: 0.92)
                        : p.surface.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _dragging
                          ? p.accent.withValues(alpha: 0.5)
                          : p.hairline.withValues(alpha: 0.7),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: displayIndices.map((idx) {
                      final raw = labels[idx];
                      final shortText = raw.length <= 2
                          ? raw
                          : raw.substring(0, 1);
                      final isCurrent = _dragging && idx == _activeIndex;
                      return Text(
                        shortText,
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: isCurrent ? 11.5 : 9.5,
                          fontWeight: isCurrent
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isCurrent ? p.accent : p.inkMuted,
                          height: 1.0,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ),

        // Floating Calligraphic Preview Bubble while scrubbing
        if (_dragging && _activeIndex < labels.length)
          Positioned(
            left: 36,
            top: (18 + _dragFrac * (MediaQuery.sizeOf(context).height * 0.45))
                .clamp(24.0, MediaQuery.sizeOf(context).height * 0.58),
            child: IgnorePointer(
              child: AnimatedScale(
                scale: _dragging ? 1.0 : 0.85,
                duration: const Duration(milliseconds: 140),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 58),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: p.accent,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                      topLeft: Radius.circular(24),
                      bottomLeft: Radius.circular(6),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    labels[_activeIndex],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.ruqaa,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
