import 'poet.dart';

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
}

class SearchFilter {
  const SearchFilter({
    this.eraId,
    this.poetId,
    this.meterId,
    this.rhymeId,
    this.exactPhrase = false,
  });

  final int? eraId;
  final int? poetId;
  final int? meterId;
  final int? rhymeId;
  final bool exactPhrase;

  bool get hasActiveFilters =>
      eraId != null ||
      poetId != null ||
      meterId != null ||
      rhymeId != null ||
      exactPhrase;

  SearchFilter copyWith({
    int? eraId,
    bool clearEra = false,
    int? poetId,
    bool clearPoet = false,
    int? meterId,
    bool clearMeter = false,
    int? rhymeId,
    bool clearRhyme = false,
    bool? exactPhrase,
  }) {
    return SearchFilter(
      eraId: clearEra ? null : (eraId ?? this.eraId),
      poetId: clearPoet ? null : (poetId ?? this.poetId),
      meterId: clearMeter ? null : (meterId ?? this.meterId),
      rhymeId: clearRhyme ? null : (rhymeId ?? this.rhymeId),
      exactPhrase: exactPhrase ?? this.exactPhrase,
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
