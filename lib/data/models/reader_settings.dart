import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';

enum VerseLayoutStyle {
  staggered('شطران متدرّجان', 'توازن بديع وخطّ واضح'),
  sideBySide('شطران متقابلان', 'تنسيق الديوان المطبوع');

  const VerseLayoutStyle(this.displayName, this.subtitle);
  final String displayName;
  final String subtitle;

  static VerseLayoutStyle fromId(String? id) {
    for (final v in values) {
      if (v.name == id) return v;
    }
    return VerseLayoutStyle.staggered;
  }
}

class ReaderSettings {
  const ReaderSettings({
    this.themeMode = ReadingThemeMode.parchment,
    this.poetryFont = PoetryFontOption.scheherazade,
    this.fontSize = 20.5,
    this.verseLayout = VerseLayoutStyle.staggered,
    this.showDiacritics = true,
    this.showVerseNumbers = false,
  });

  final ReadingThemeMode themeMode;
  final PoetryFontOption poetryFont;
  final double fontSize;
  final VerseLayoutStyle verseLayout;
  final bool showDiacritics;
  final bool showVerseNumbers;

  ReaderSettings copyWith({
    ReadingThemeMode? themeMode,
    PoetryFontOption? poetryFont,
    double? fontSize,
    VerseLayoutStyle? verseLayout,
    bool? showDiacritics,
    bool? showVerseNumbers,
  }) {
    return ReaderSettings(
      themeMode: themeMode ?? this.themeMode,
      poetryFont: poetryFont ?? this.poetryFont,
      fontSize: fontSize ?? this.fontSize,
      verseLayout: verseLayout ?? this.verseLayout,
      showDiacritics: showDiacritics ?? this.showDiacritics,
      showVerseNumbers: showVerseNumbers ?? this.showVerseNumbers,
    );
  }
}
