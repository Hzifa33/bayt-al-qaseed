import 'poet.dart';

enum SearchMatchMode {
  sameVerse('في بيتٍ واحد', 'تجمع الكلمات داخل البيت نفسه بأي ترتيب'),
  exactSequence('عبارةٌ متتابعة', 'تُطابق الكلمات متتابعةً على الترتيب');

  const SearchMatchMode(this.label, this.subtitle);
  final String label;
  final String subtitle;
}

class PoemSearchHit {
  const PoemSearchHit({
    required this.poemId,
    required this.poetId,
    required this.poetName,
    required this.eraName,
    required this.meterName,
    required this.rhymeName,
    required this.title,
    required this.verseCount,
    required this.matchedVerseIndex,
    required this.matchedSadr,
    required this.matchedAjuz,
    this.matchingVersesCount = 1,
  });

  final int poemId;
  final int poetId;
  final String poetName;
  final String eraName;
  final String meterName;
  final String rhymeName;
  final String title;
  final int verseCount;
  final int matchedVerseIndex;
  final String matchedSadr;
  final String matchedAjuz;
  final int matchingVersesCount;
}

class SearchFilter {
  const SearchFilter({
    this.eraId,
    this.poetId,
    this.meterId,
    this.rhymeId,
    this.matchMode = SearchMatchMode.sameVerse,
    this.matchPartialWords = true,
  });

  final int? eraId;
  final int? poetId;
  final int? meterId;
  final int? rhymeId;

  /// Whether words may appear anywhere inside the same verse or strictly consecutively.
  final SearchMatchMode matchMode;

  /// When true, a query like «قل» matches «قلب» & «قليل» (prefix/partial match).
  /// When false, enforces strict word boundaries (with space separation).
  final bool matchPartialWords;

  bool get hasActiveFilters =>
      eraId != null || poetId != null || meterId != null || rhymeId != null;

  SearchFilter copyWith({
    int? eraId,
    bool clearEra = false,
    int? poetId,
    bool clearPoet = false,
    int? meterId,
    bool clearMeter = false,
    int? rhymeId,
    bool clearRhyme = false,
    SearchMatchMode? matchMode,
    bool? matchPartialWords,
  }) {
    return SearchFilter(
      eraId: clearEra ? null : (eraId ?? this.eraId),
      poetId: clearPoet ? null : (poetId ?? this.poetId),
      meterId: clearMeter ? null : (meterId ?? this.meterId),
      rhymeId: clearRhyme ? null : (rhymeId ?? this.rhymeId),
      matchMode: matchMode ?? this.matchMode,
      matchPartialWords: matchPartialWords ?? this.matchPartialWords,
    );
  }
}

class SearchBundle {
  const SearchBundle({
    required this.query,
    required this.poems,
    required this.poets,
    required this.elapsedMs,
  });

  final String query;
  final List<PoemSearchHit> poems;
  final List<Poet> poets;
  final double elapsedMs;
}
