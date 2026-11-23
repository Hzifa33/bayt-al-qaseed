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
    this.eraIds = const {},
    this.poetId,
    this.meterIds = const {},
    this.rhymeIds = const {},
    this.matchMode = SearchMatchMode.exactSequence,
    this.matchPartialWords = true,
  });

  final Set<int> eraIds;
  final int? poetId;
  final Set<int> meterIds;
  final Set<int> rhymeIds;
  final SearchMatchMode matchMode;

  /// When true, «قل» matches «قلب» & «قليل».
  /// When false, enforces whole-word boundaries.
  final bool matchPartialWords;

  int get activeFilterCount =>
      eraIds.length +
      meterIds.length +
      rhymeIds.length +
      (poetId != null ? 1 : 0);

  bool get hasActiveFilters => activeFilterCount > 0;

  SearchFilter withToggledEra(int id) {
    final next = Set<int>.of(eraIds);
    if (!next.add(id)) next.remove(id);
    return copyWith(eraIds: Set<int>.unmodifiable(next));
  }

  SearchFilter withToggledMeter(int id) {
    final next = Set<int>.of(meterIds);
    if (!next.add(id)) next.remove(id);
    return copyWith(meterIds: Set<int>.unmodifiable(next));
  }

  SearchFilter withToggledRhyme(int id) {
    final next = Set<int>.of(rhymeIds);
    if (!next.add(id)) next.remove(id);
    return copyWith(rhymeIds: Set<int>.unmodifiable(next));
  }

  SearchFilter copyWith({
    Set<int>? eraIds,
    bool clearEras = false,
    int? poetId,
    bool clearPoet = false,
    Set<int>? meterIds,
    bool clearMeters = false,
    Set<int>? rhymeIds,
    bool clearRhymes = false,
    SearchMatchMode? matchMode,
    bool? matchPartialWords,
  }) {
    return SearchFilter(
      eraIds: clearEras ? const {} : (eraIds ?? this.eraIds),
      poetId: clearPoet ? null : (poetId ?? this.poetId),
      meterIds: clearMeters ? const {} : (meterIds ?? this.meterIds),
      rhymeIds: clearRhymes ? const {} : (rhymeIds ?? this.rhymeIds),
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
    this.hasMore = false,
  });

  final String query;
  final List<PoemSearchHit> poems;
  final List<Poet> poets;
  final double elapsedMs;

  /// True when matching poems exceeded the requested limit (e.g. > 200 poems).
  final bool hasMore;
}
