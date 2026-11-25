import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_constants.dart';
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
    this.showExpandedBadge,
  });

  final double size;
  final Color? backgroundColor;
  final Color? goldColor;
  final Color? nibColor;

  /// Shows the Expanded Edition (+) corner badge; defaults to [AppConstants.isExpanded].
  final bool? showExpandedBadge;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final expandedBadge = showExpandedBadge ?? AppConstants.isExpanded;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BaytEmblemPainter(
          bg: backgroundColor ?? p.surfaceElevated,
          gold: goldColor ?? p.accent,
          nib: nibColor ?? p.ink,
          hairline: p.hairline,
          showPlusBadge: expandedBadge,
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
    required this.showPlusBadge,
  });

  final Color bg;
  final Color gold;
  final Color nib;
  final Color hairline;
  final bool showPlusBadge;

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

    // Expanded Edition (+) badge in top-left corner (visually prominent in RTL)
    if (showPlusBadge) {
      final badgeR = size.width * 0.175;
      final badgeCenter = Offset(size.width * 0.82, size.height * 0.18);
      // Outer ring matching backdrop for crisp separation
      canvas.drawCircle(
        badgeCenter,
        badgeR + size.width * 0.036,
        Paint()..color = bg,
      );
      // Accent circle
      canvas.drawCircle(badgeCenter, badgeR, Paint()..color = gold);
      // Crisp '+' cross
      final arm = badgeR * 0.56;
      final plusPaint = Paint()
        ..color = bg
        ..strokeWidth = math.max(1.5, size.width * 0.048)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(badgeCenter.dx - arm, badgeCenter.dy),
        Offset(badgeCenter.dx + arm, badgeCenter.dy),
        plusPaint,
      );
      canvas.drawLine(
        Offset(badgeCenter.dx, badgeCenter.dy - arm),
        Offset(badgeCenter.dx, badgeCenter.dy + arm),
        plusPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BaytEmblemPainter oldDelegate) =>
      oldDelegate.bg != bg ||
      oldDelegate.gold != gold ||
      oldDelegate.nib != nib ||
      oldDelegate.showPlusBadge != showPlusBadge;
}

/// Editorial circular badge displaying a poem's single-letter rhyme (حرف الروي)
/// when available, or a refined book/quill icon for multi-rhyme / unspecified poems.
class PoemRhymeBadge extends StatelessWidget {
  const PoemRhymeBadge({
    super.key,
    required this.rhymeName,
    this.size = 31,
    this.accentColor,
  });

  final String rhymeName;
  final double size;
  final Color? accentColor;

  static bool hasSingleRhymeLetter(String rhyme) {
    final clean = rhyme.trim();
    return clean.isNotEmpty &&
        clean.length <= 2 &&
        clean != '؟' &&
        clean != '-';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = accentColor ?? p.accent;
    final isSingle = hasSingleRhymeLetter(rhymeName);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.surface,
        shape: BoxShape.circle,
        border: Border.all(color: p.hairline, width: 0.85),
      ),
      child: isSingle
          ? Text(
              rhymeName.trim(),
              style: TextStyle(
                fontFamily: AppFonts.ruqaa,
                fontSize: size * 0.49,
                color: fg,
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
            )
          : Icon(Icons.auto_stories_outlined, size: size * 0.48, color: fg),
    );
  }
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

/// Identifies female Arab & international poets (الشاعرات) across both Standard
/// and Expanded corpora, rendering a custom veiled woman (امرأة محجبة) icon for
/// poetesses or a classic person icon for male poets.
class PoetGender {
  PoetGender._();

  /// Legacy v5 poet IDs (only valid in Standard Edition where IDs are fixed).
  static const Set<int> _legacyFemalePoetIds = {
    16, // الخنساء
    149, // جليلة بنت مرة
    165, // ليلى العفيفة
    859, // ليلى الأخيلية
    1024, // عائشة التيمورية
    1544, // رابعة العدوية
    10035, // صفية بنت ثعلبة
    10048, // صفية بنت عبد المطلب
  };

  static const Set<String> _maleExceptions = {
    'مجنون ليلى',
    'زهير بن أبي سلمى',
    'العباس بن مرداس',
    'مروان بن أبي حفصة',
    'ابن سارة الأندلسي',
    'صخر بن عمرو السلمي',
    'البراق بن روحان',
    'عبد الله بن الزبعرى',
    'عميرة بن جعل التغلبي',
    'تأبط شرا',
    'الشنفرى',
    'أبو العلاء المعري',
  };

  /// Classical & modern male first names ending in ة (must NOT be classified as female).
  static const Set<String> _maleTaaMarbutaFirstNames = {
    'أسامة',
    'اسامة',
    'حمزة',
    'معاوية',
    'عنترة',
    'طرفة',
    'حذيفة',
    'طلحة',
    'قتيبة',
    'عقبة',
    'عكرمة',
    'ربيعة',
    'عبيدة',
    'عروة',
    'علقمة',
    'مسلمة',
    'ثعلبة',
    'شعبة',
    'أمية',
    'امية',
    'عتبة',
    'شيبة',
    'خليفة',
    'عطية',
    'جمعة',
    'سلامة',
    'بركة',
    'حنظلة',
    'مغيرة',
    'ضمرة',
    'عميرة',
    'عمارة',
    'بشامة',
    'أرطاة',
    'ارطاة',
    'قبيصة',
    'حارثة',
    'زرعة',
    'جهيمة',
    'أذينة',
    'اذينة',
    'وهبة',
    'نضلة',
    'عبادة',
    'قتادة',
    'سبرة',
    'فروة',
    'مرة',
    'حجلة',
    'غاضرة',
    'شبيبة',
    'خصيفة',
    'طليحة',
  };

  /// Comprehensive curated set of unambiguously female Arabic & world poet first names.
  static const Set<String> _femaleFirstNames = {
    'مارية',
    'ماري',
    'ماريا',
    'مارينا',
    'مريم',
    'مريام',
    'آسية',
    'اسية',
    'فاطمة',
    'عائشة',
    'خديجة',
    'زينب',
    'سلمى',
    'سلمي',
    'ليلى',
    'ليلي',
    'لبنى',
    'لبني',
    'بثينة',
    'سكينة',
    'رابعة',
    'صفية',
    'حفصة',
    'جويرية',
    'أسماء',
    'اسماء',
    'أروى',
    'اروى',
    'هند',
    'دعد',
    'سعاد',
    'سعدى',
    'فدوى',
    'فدوي',
    'نازك',
    'مي',
    'ميادة',
    'ندى',
    'ندي',
    'نهى',
    'هدى',
    'منى',
    'مها',
    'رشا',
    'رنا',
    'ريم',
    'ريما',
    'ديما',
    'ديمة',
    'لينا',
    'لين',
    'نورة',
    'نورا',
    'نوال',
    'منال',
    'آمال',
    'امال',
    'أمل',
    'امل',
    'أحلام',
    'احلام',
    'إلهام',
    'الهام',
    'ابتسام',
    'انتصار',
    'إيمان',
    'ايمان',
    'آمنة',
    'امنة',
    'أمينة',
    'امينة',
    'حليمة',
    'كريمة',
    'لطيفة',
    'شريفة',
    'جميلة',
    'نبيلة',
    'بديعة',
    'سميرة',
    'منيرة',
    'أميرة',
    'اميرة',
    'عبير',
    'غادة',
    'وفاء',
    'هيفاء',
    'شيماء',
    'آلاء',
    'الاء',
    'سارة',
    'سارا',
    'سمر',
    'سحر',
    'سمية',
    'رقية',
    'عاتكة',
    'تماضر',
    'جليلة',
    'عمرة',
    'عفراء',
    'عزة',
    'علية',
    'عنان',
    'حمدة',
    'حمدونة',
    'نزهون',
    'ياسمين',
    'ياسمينة',
    'فرح',
    'ملاك',
    'حنان',
    'جنان',
    'إيناس',
    'ايناس',
    'ميسون',
    'ميساء',
    'لمياء',
    'لميس',
    'لجين',
    'تسنيم',
    'سجى',
    'ضحى',
    'شذى',
    'ربى',
    'تقوى',
    'تقى',
    'نجوى',
    'سلوى',
    'ذكرى',
    'بشرى',
    'يسرى',
    'يسرا',
    'دينا',
    'دانية',
    'دانا',
    'تالا',
    'تالة',
    'يارا',
    'تارا',
    'لارا',
    'سيلين',
    'جودي',
    'شهد',
    'وعد',
    'رغد',
    'رهف',
    'غيداء',
    'حسناء',
    'زهراء',
    'نجلاء',
    'سمراء',
    'علياء',
    'صفاء',
    'سناء',
    'ثناء',
    'رجاء',
    'هناء',
    'ولاء',
    'دعاء',
    'نداء',
    'إسراء',
    'اسراء',
    'مروة',
    'نجاة',
    'حياة',
    'وداد',
    'إخلاص',
    'اخلاص',
    'أفراح',
    'افراح',
    'أفنان',
    'افنان',
    'أريج',
    'اريج',
    'عايدة',
    'ماجدة',
    'ساجدة',
    'خالدة',
    'راشدة',
    'ناهدة',
    'ناهد',
    'زاهدة',
    'عابدة',
    'حامدة',
    'شاهدة',
    'ماهرة',
    'طاهرة',
    'زهرة',
    'وردة',
    'سوسن',
    'نرجس',
    'نسرين',
    'شيرين',
    'نيفين',
    'سيرين',
    'دارين',
    'كارين',
    'نادين',
    'نرمين',
    'سيلفيا',
    'إيميلي',
    'إميلي',
    'اميلي',
    'آنا',
    'إليزابيث',
    'فيرجينيا',
    'سابفو',
    'سافو',
    'خولة',
    'عبلة',
    'أميمة',
    'اميمة',
    'أمامة',
    'امامة',
    'بدرية',
    'فوزية',
    'نادية',
    'شادية',
    'راوية',
    'سامية',
    'صافية',
    'غالية',
    'عالية',
    'دالية',
    'هالة',
    'نبال',
    'ختام',
    'هيام',
    'وئام',
    'باسمة',
    'بسمة',
    'رحمة',
    'نعمة',
    'همسة',
    'نسمة',
    'أسمهان',
    'اسمهان',
    'بلقيس',
    'ظبية',
    'عفاف',
    'عواطف',
    'فريدة',
    'كوكب',
    'لبيبة',
    'محاسن',
    'مديحة',
    'مفيدة',
    'منتهى',
    'مهجة',
    'نجيبة',
    'نزيهة',
    'نعمات',
    'نهلة',
    'هبة',
    'وجدان',
    'وديعة',
    'ولادة',
    'الخرنق',
    'الخنساء',
    'الشيماء',
    'الفارعة',
    'الزرقاء',
    'العالية',
    'حبيبة',
    'شمس',
    'قمرية',
    'سلافة',
    'سلاف',
    'رندة',
    'رند',
    'خلود',
    'عنود',
    'العنود',
    'الجوهرة',
    'جوهرة',
    'نوف',
    'العنقاء',
    'لطوف',
    'شوقية',
    'درية',
    'سميحة',
    'صباح',
    'نجاح',
    'فاتن',
    'سهام',
    'إكرام',
    'اكرام',
    'انعام',
    'إنعام',
    'نعمت',
    'عصمت',
    'حكمت',
    'ثريا',
    'الثريا',
    'رتيبة',
    'صديقة',
    'رشيدة',
    'سعيدة',
    'سالمة',
    'سلمية',
    'نجمة',
    'نديمة',
    'حورية',
    'نورية',
    'فاطمه',
    'عائشه',
    'ماريه',
  };

  static bool isFemale({int? poetId, String? poetName}) {
    if (!AppConstants.isExpanded &&
        poetId != null &&
        _legacyFemalePoetIds.contains(poetId)) {
      return true;
    }
    if (poetName == null || poetName.isEmpty) return false;
    final clean = ArabicNormalizer.stripDiacritics(poetName).trim();
    if (clean.isEmpty) return false;
    if (_maleExceptions.contains(clean)) return false;

    // Unmistakable male patronymics & titles
    if (clean.contains(' بن ') ||
        clean.startsWith('أبو ') ||
        clean.startsWith('ابو ') ||
        clean.startsWith('ابن ') ||
        clean.startsWith('أبي ') ||
        clean.startsWith('ابي ') ||
        clean.startsWith('الشيخ ') ||
        clean.startsWith('الأمير ') ||
        clean.startsWith('الامير ') ||
        clean.startsWith('الإمام ') ||
        clean.startsWith('الامام ') ||
        clean.startsWith('الملك ') ||
        clean.startsWith('السيد ') ||
        clean.startsWith('الشاعر ') ||
        clean.startsWith('ماريو ')) {
      return false;
    }

    // Explicit female markers & titles
    if (clean.contains(' بنت ') ||
        clean.startsWith('بنت ') ||
        clean.contains(' ابنة ') ||
        clean.startsWith('ابنة ') ||
        clean.startsWith('أم ') ||
        clean.startsWith('ام ') ||
        clean.contains('الشاعرة') ||
        clean.startsWith('الأميرة ') ||
        clean.startsWith('الاميرة ') ||
        clean.startsWith('الشيخة ') ||
        clean.startsWith('السيدة ') ||
        clean.startsWith('الملكة ') ||
        clean.contains('الخنساء') ||
        clean.contains('ولادة بنت') ||
        clean.startsWith('ولادة ')) {
      return true;
    }

    // Strip leading honorific abbreviations like "د." / "أ."
    var normalized = clean;
    for (final prefix in const [
      'د. ',
      'د.',
      'أ. ',
      'ا. ',
      'أ.د. ',
      'الآنسة ',
    ]) {
      if (normalized.startsWith(prefix)) {
        normalized = normalized.substring(prefix.length).trim();
      }
    }
    if (normalized.isEmpty) return false;

    final firstWord = normalized.split(RegExp(r'\s+')).first;
    if (_femaleFirstNames.contains(firstWord)) {
      return true;
    }

    // Classical/modern Arabic first names ending in ة (excluding the closed male set)
    if (firstWord.length >= 3 &&
        firstWord.endsWith('ة') &&
        !firstWord.startsWith('ال') &&
        !_maleTaaMarbutaFirstNames.contains(firstWord)) {
      return true;
    }

    return false;
  }
}

/// Gender-aware Poet Avatar Icon: renders a graceful veiled woman (امرأة محجبة)
/// silhouette for female poets and a classic person icon for male poets.
class PoetAvatarIcon extends StatelessWidget {
  const PoetAvatarIcon({
    super.key,
    this.poetId,
    this.poetName,
    this.size = 20,
    required this.color,
  });

  final int? poetId;
  final String? poetName;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (PoetGender.isFemale(poetId: poetId, poetName: poetName)) {
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _HijabiPoetessIconPainter(color: color)),
      );
    }
    return Icon(Icons.person_rounded, size: size, color: color);
  }
}

class _HijabiPoetessIconPainter extends CustomPainter {
  const _HijabiPoetessIconPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // 1. Outer Hijab Hood & Flowing Modest Shoulder Drape
    final hijabPath = Path()
      ..moveTo(cx, h * 0.08)
      ..cubicTo(w * 0.78, h * 0.08, w * 0.86, h * 0.34, w * 0.84, h * 0.56)
      ..cubicTo(w * 0.89, h * 0.68, w * 0.92, h * 0.82, w * 0.90, h * 0.91)
      ..quadraticBezierTo(cx, h * 0.96, w * 0.10, h * 0.91)
      ..cubicTo(w * 0.08, h * 0.82, w * 0.11, h * 0.68, w * 0.16, h * 0.56)
      ..cubicTo(w * 0.14, h * 0.34, w * 0.22, h * 0.08, cx, h * 0.08)
      ..close();

    // 2. Inner Serene Face Oval & Graceful Hijab Wrap Fold (subtracted via evenOdd)
    final faceCutout = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(cx, h * 0.37),
          width: w * 0.34,
          height: h * 0.33,
        ),
      );

    // Subtle V-fold of the scarf drape below the chin for unmistakable hijab silhouette
    final foldCutout = Path()
      ..moveTo(cx - w * 0.17, h * 0.60)
      ..quadraticBezierTo(cx, h * 0.73, cx + w * 0.17, h * 0.60)
      ..quadraticBezierTo(cx, h * 0.67, cx - w * 0.17, h * 0.60)
      ..close();

    final combined = Path.combine(
      PathOperation.difference,
      hijabPath,
      faceCutout,
    );
    final finalPath = Path.combine(
      PathOperation.difference,
      combined,
      foldCutout,
    );

    canvas.drawPath(finalPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _HijabiPoetessIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Delicate classical medallion for verse numbering (`١`, `٢`, ...).
class VerseNumberMedallion extends StatelessWidget {
  const VerseNumberMedallion({
    super.key,
    required this.number,
    required this.isSelected,
    this.fixedWidth,
  });

  final int number;
  final bool isSelected;
  final double? fixedWidth;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = isSelected ? p.accent : p.inkMuted.withValues(alpha: 0.78);
    return Container(
      width: fixedWidth,
      alignment: fixedWidth != null ? Alignment.center : null,
      padding: EdgeInsets.symmetric(
        horizontal: fixedWidth != null ? 3 : 7,
        vertical: 2,
      ),
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
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          ArabicNormalizer.toArabicNumber(number),
          maxLines: 1,
          style: TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: fg,
            height: 1.2,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
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
