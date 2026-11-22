import 'package:flutter/material.dart';

/// Curated elite Arabic typography suite for «بيت القصيد».
///
/// Every literary poetry font is an authentic, distinct Arabic script bundled inside
/// the application (Android's default Noto Naskh has been completely replaced).
class AppFonts {
  AppFonts._();

  static const String ui = 'IBMPlexSansArabic';
  static const String ruqaa = 'ArefRuqaa';
  static const String gulzar = 'Gulzar';
  static const String kufi = 'ReemKufi';

  static const String scheherazade = 'ScheherazadeNew';
  static const String ruwudu = 'Ruwudu';
  static const String mirza = 'Mirza';
  static const String amiriQuran = 'AmiriQuran';
  static const String harmattan = 'Harmattan';
  static const String katibeh = 'Katibeh';
  static const String lateef = 'Lateef';
}

enum PoetryFontOption {
  scheherazade(
    id: 'scheherazade',
    family: AppFonts.scheherazade,
    displayName: 'شهرزاد النسخي',
    subtitle: 'نسخ مطبعي رفيع متقن التشكيل',
    baseHeight: 2.02,
    scaleMultiplier: 1.12,
  ),
  mirza(
    id: 'mirza',
    family: AppFonts.mirza,
    displayName: 'ميرزا الأدبي',
    subtitle: 'نسخ تراثي أنيق برشاقة فائقة',
    baseHeight: 1.98,
    scaleMultiplier: 1.08,
  ),
  ruwudu(
    id: 'ruwudu',
    family: AppFonts.ruwudu,
    displayName: 'رُودو الخطّي',
    subtitle: 'طابع خطّاطي مغربي مهيب',
    baseHeight: 2.14,
    scaleMultiplier: 1.04,
  ),
  amiriQuran(
    id: 'amiri_quran',
    family: AppFonts.amiriQuran,
    displayName: 'نسخ المخطوطات',
    subtitle: 'ضبط كلاسيكي عريق للتشكيل',
    baseHeight: 2.15,
    scaleMultiplier: 1.02,
  ),
  katibeh(
    id: 'katibeh',
    family: AppFonts.katibeh,
    displayName: 'كاتِبة الديواني',
    subtitle: 'خطّ أدبي فخم للعناوين والقصائد',
    baseHeight: 1.92,
    scaleMultiplier: 1.18,
  ),
  harmattan(
    id: 'harmattan',
    family: AppFonts.harmattan,
    displayName: 'هارماتان العصري',
    subtitle: 'واضح ومنسّق للقراءة الطويلة',
    baseHeight: 1.98,
    scaleMultiplier: 1.12,
  ),
  lateef(
    id: 'lateef',
    family: AppFonts.lateef,
    displayName: 'لطيف المشرقي',
    subtitle: 'خفيف منساب مريح للعين',
    baseHeight: 1.96,
    scaleMultiplier: 1.24,
  );

  const PoetryFontOption({
    required this.id,
    required this.family,
    required this.displayName,
    required this.subtitle,
    required this.baseHeight,
    required this.scaleMultiplier,
  });

  final String id;
  final String family;
  final String displayName;
  final String subtitle;
  final double baseHeight;
  final double scaleMultiplier;

  static PoetryFontOption fromId(String? id) {
    for (final opt in values) {
      if (opt.id == id) return opt;
    }
    return PoetryFontOption.scheherazade;
  }
}

class AppTypography {
  AppTypography._();

  static TextStyle displayTitle(
    BuildContext context, {
    double fontSize = 30,
    Color? color,
    String fontFamily = AppFonts.ruqaa,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      height: 1.45,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );
  }

  static TextStyle poeticVerse({
    required PoetryFontOption font,
    required double fontSize,
    required Color color,
    FontWeight fontWeight = FontWeight.w400,
    double? wordSpacing,
  }) {
    return TextStyle(
      fontFamily: font.family,
      fontSize: fontSize * font.scaleMultiplier,
      fontWeight: fontWeight,
      height: font.baseHeight,
      color: color,
      wordSpacing: wordSpacing,
    );
  }

  static TextTheme buildUiTextTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: AppFonts.ruqaa,
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: primary,
        height: 1.4,
      ),
      headlineMedium: TextStyle(
        fontFamily: AppFonts.ruqaa,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: primary,
        height: 1.45,
      ),
      titleLarge: TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: 19.5,
        fontWeight: FontWeight.w600,
        color: primary,
        height: 1.4,
      ),
      titleMedium: TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primary,
        height: 1.45,
      ),
      titleSmall: TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primary,
        height: 1.4,
      ),
      bodyLarge: TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: primary,
        height: 1.65,
      ),
      bodyMedium: TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: primary,
        height: 1.6,
      ),
      bodySmall: TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
        color: secondary,
        height: 1.55,
      ),
      labelLarge: TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      labelMedium: TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: secondary,
      ),
      labelSmall: TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: secondary,
      ),
    );
  }
}
