import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/reader_settings.dart';

class ReaderSettingsNotifier extends StateNotifier<ReaderSettings> {
  ReaderSettingsNotifier() : super(const ReaderSettings());

  SharedPreferences? _prefs;

  static const _kTheme = 'reader_theme';
  static const _kFont = 'reader_font';
  static const _kSize = 'reader_font_size';
  static const _kLayout = 'reader_layout';
  static const _kDiacritics = 'reader_diacritics';
  static const _kNumbers = 'reader_verse_numbers';

  void hydrate(SharedPreferences prefs) {
    _prefs = prefs;
    state = ReaderSettings(
      themeMode: ReadingThemeMode.fromId(prefs.getString(_kTheme)),
      poetryFont: PoetryFontOption.fromId(prefs.getString(_kFont)),
      fontSize: (prefs.getDouble(_kSize) ?? 20.5).clamp(15.0, 30.0),
      verseLayout: VerseLayoutStyle.fromId(prefs.getString(_kLayout)),
      showDiacritics: prefs.getBool(_kDiacritics) ?? true,
      showVerseNumbers: prefs.getBool(_kNumbers) ?? false,
    );
  }

  void setThemeMode(ReadingThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _prefs?.setString(_kTheme, mode.id);
  }

  void cycleThemeMode() {
    final next = switch (state.themeMode) {
      ReadingThemeMode.parchment => ReadingThemeMode.obsidian,
      ReadingThemeMode.obsidian => ReadingThemeMode.materialYou,
      ReadingThemeMode.materialYou => ReadingThemeMode.sepia,
      ReadingThemeMode.sepia => ReadingThemeMode.parchment,
    };
    setThemeMode(next);
  }

  void setPoetryFont(PoetryFontOption font) {
    state = state.copyWith(poetryFont: font);
    _prefs?.setString(_kFont, font.id);
  }

  void setFontSize(double size) {
    final clamped = size.clamp(15.0, 30.0);
    state = state.copyWith(fontSize: clamped);
    _prefs?.setDouble(_kSize, clamped);
  }

  void setVerseLayout(VerseLayoutStyle layout) {
    state = state.copyWith(verseLayout: layout);
    _prefs?.setString(_kLayout, layout.name);
  }

  void toggleDiacritics() {
    final next = !state.showDiacritics;
    state = state.copyWith(showDiacritics: next);
    _prefs?.setBool(_kDiacritics, next);
  }

  void toggleVerseNumbers() {
    final next = !state.showVerseNumbers;
    state = state.copyWith(showVerseNumbers: next);
    _prefs?.setBool(_kNumbers, next);
  }

  Map<String, dynamic> toMap() => {
    'theme': state.themeMode.id,
    'font': state.poetryFont.id,
    'font_size': state.fontSize,
    'layout': state.verseLayout.name,
    'show_diacritics': state.showDiacritics,
    'show_verse_numbers': state.showVerseNumbers,
  };

  void importFromMap(Map<String, dynamic> map) {
    if (map['theme'] is String) {
      setThemeMode(ReadingThemeMode.fromId(map['theme'] as String));
    }
    if (map['font'] is String) {
      setPoetryFont(PoetryFontOption.fromId(map['font'] as String));
    }
    if (map['font_size'] is num) {
      setFontSize((map['font_size'] as num).toDouble());
    }
    if (map['layout'] is String) {
      setVerseLayout(VerseLayoutStyle.fromId(map['layout'] as String));
    }
    if (map['show_diacritics'] is bool) {
      final v = map['show_diacritics'] as bool;
      state = state.copyWith(showDiacritics: v);
      _prefs?.setBool(_kDiacritics, v);
    }
    if (map['show_verse_numbers'] is bool) {
      final v = map['show_verse_numbers'] as bool;
      state = state.copyWith(showVerseNumbers: v);
      _prefs?.setBool(_kNumbers, v);
    }
  }
}

final readerSettingsProvider =
    StateNotifierProvider<ReaderSettingsNotifier, ReaderSettings>(
      (ref) => ReaderSettingsNotifier(),
    );
