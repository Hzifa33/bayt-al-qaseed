import 'package:flutter/material.dart';

import 'app_typography.dart';

enum ReadingThemeMode {
  parchment(
    id: 'parchment',
    displayName: 'الورق الدافئ',
    subtitle: 'نهاري مريح كصفحات الكتب',
    previewBg: Color(0xFFF8F5EE),
    previewInk: Color(0xFF1C1A17),
    previewAccent: Color(0xFF8C5E35),
  ),
  sepia(
    id: 'sepia',
    displayName: 'المخطوط المعتّق',
    subtitle: 'سبيا دافئة للقراءة المسائية',
    previewBg: Color(0xFFF1E7D2),
    previewInk: Color(0xFF281F15),
    previewAccent: Color(0xFF7D4E24),
  ),
  obsidian(
    id: 'obsidian',
    displayName: 'السواد الهادئ',
    subtitle: 'ليلي فاخر بلمسات ذهبية',
    previewBg: Color(0xFF121210),
    previewInk: Color(0xFFE6E0D4),
    previewAccent: Color(0xFFC5A567),
  );

  const ReadingThemeMode({
    required this.id,
    required this.displayName,
    required this.subtitle,
    required this.previewBg,
    required this.previewInk,
    required this.previewAccent,
  });

  final String id;
  final String displayName;
  final String subtitle;
  final Color previewBg;
  final Color previewInk;
  final Color previewAccent;

  bool get isDark => this == ReadingThemeMode.obsidian;

  static ReadingThemeMode fromId(String? id) {
    for (final m in values) {
      if (m.id == id) return m;
    }
    return ReadingThemeMode.parchment;
  }
}

@immutable
class BaytPalette extends ThemeExtension<BaytPalette> {
  const BaytPalette({
    required this.canvas,
    required this.surface,
    required this.surfaceElevated,
    required this.ink,
    required this.inkMuted,
    required this.accent,
    required this.accentSoft,
    required this.hairline,
    required this.highlightFill,
    required this.selectedVerseFill,
    required this.ornament,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceElevated;
  final Color ink;
  final Color inkMuted;
  final Color accent;
  final Color accentSoft;
  final Color hairline;
  final Color highlightFill;
  final Color selectedVerseFill;
  final Color ornament;

  static const BaytPalette parchment = BaytPalette(
    canvas: Color(0xFFF8F5EE),
    surface: Color(0xFFF2ECE0),
    surfaceElevated: Color(0xFFFCF9F2),
    ink: Color(0xFF1C1A17),
    inkMuted: Color(0xFF5D564C),
    accent: Color(0xFF8C5E35),
    accentSoft: Color(0x1F8C5E35),
    hairline: Color(0xFFE2D9C8),
    highlightFill: Color(0x40C5A567),
    selectedVerseFill: Color(0x248C5E35),
    ornament: Color(0xFFB59B72),
  );

  static const BaytPalette sepia = BaytPalette(
    canvas: Color(0xFFF1E7D2),
    surface: Color(0xFFE8DAC0),
    surfaceElevated: Color(0xFFF6EEDF),
    ink: Color(0xFF261E14),
    inkMuted: Color(0xFF5E503E),
    accent: Color(0xFF7D4E24),
    accentSoft: Color(0x247D4E24),
    hairline: Color(0xFFD5C4A6),
    highlightFill: Color(0x45B88B44),
    selectedVerseFill: Color(0x287D4E24),
    ornament: Color(0xFFA68557),
  );

  static const BaytPalette obsidian = BaytPalette(
    canvas: Color(0xFF121210),
    surface: Color(0xFF1A1916),
    surfaceElevated: Color(0xFF22201C),
    ink: Color(0xFFE6E0D4),
    inkMuted: Color(0xFFA69E90),
    accent: Color(0xFFC5A567),
    accentSoft: Color(0x24C5A567),
    hairline: Color(0xFF2B2822),
    highlightFill: Color(0x45C5A567),
    selectedVerseFill: Color(0x2AC5A567),
    ornament: Color(0xFF8F7749),
  );

  @override
  BaytPalette copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceElevated,
    Color? ink,
    Color? inkMuted,
    Color? accent,
    Color? accentSoft,
    Color? hairline,
    Color? highlightFill,
    Color? selectedVerseFill,
    Color? ornament,
  }) {
    return BaytPalette(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      hairline: hairline ?? this.hairline,
      highlightFill: highlightFill ?? this.highlightFill,
      selectedVerseFill: selectedVerseFill ?? this.selectedVerseFill,
      ornament: ornament ?? this.ornament,
    );
  }

  @override
  BaytPalette lerp(ThemeExtension<BaytPalette>? other, double t) {
    if (other is! BaytPalette) return this;
    return BaytPalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      highlightFill: Color.lerp(highlightFill, other.highlightFill, t)!,
      selectedVerseFill: Color.lerp(
        selectedVerseFill,
        other.selectedVerseFill,
        t,
      )!,
      ornament: Color.lerp(ornament, other.ornament, t)!,
    );
  }
}

extension BaytThemeX on BuildContext {
  BaytPalette get palette =>
      Theme.of(this).extension<BaytPalette>() ?? BaytPalette.parchment;
}

class AppTheme {
  AppTheme._();

  static ThemeData build(ReadingThemeMode mode) {
    final palette = switch (mode) {
      ReadingThemeMode.parchment => BaytPalette.parchment,
      ReadingThemeMode.sepia => BaytPalette.sepia,
      ReadingThemeMode.obsidian => BaytPalette.obsidian,
    };

    final brightness = mode.isDark ? Brightness.dark : Brightness.light;
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: palette.accent,
      onPrimary: mode.isDark
          ? const Color(0xFF15130E)
          : const Color(0xFFFCF9F2),
      secondary: palette.ornament,
      onSecondary: palette.ink,
      error: mode.isDark ? const Color(0xFFE07A6B) : const Color(0xFFA63A2B),
      onError: Colors.white,
      surface: palette.canvas,
      onSurface: palette.ink,
      surfaceContainerHighest: palette.surface,
      outline: palette.hairline,
      outlineVariant: palette.hairline,
    );

    final textTheme = AppTypography.buildUiTextTheme(
      palette.ink,
      palette.inkMuted,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: AppFonts.ui,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.canvas,
      textTheme: textTheme,
      extensions: [palette],
      appBarTheme: AppBarTheme(
        backgroundColor: palette.canvas,
        foregroundColor: palette.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: palette.hairline,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.ruqaa,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: palette.ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.hairline, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: palette.hairline,
        thickness: 0.8,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        indicatorColor: palette.accentSoft,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? palette.accent : palette.inkMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? palette.accent : palette.inkMuted,
            size: 22,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        hintStyle: TextStyle(
          fontFamily: AppFonts.ui,
          color: palette.inkMuted,
          fontSize: 14.5,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.accent, width: 1.4),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surface,
        selectedColor: palette.accentSoft,
        side: BorderSide(color: palette.hairline),
        labelStyle: TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 13,
          color: palette.ink,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: palette.accent,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: mode.isDark ? palette.surfaceElevated : palette.ink,
        contentTextStyle: TextStyle(
          fontFamily: AppFonts.ui,
          color: mode.isDark ? palette.ink : palette.canvas,
          fontSize: 14,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
