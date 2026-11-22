import 'verse.dart';

class PoemSummary {
  const PoemSummary({
    required this.id,
    required this.poetId,
    required this.poetName,
    required this.eraId,
    required this.eraName,
    required this.meterId,
    required this.meterName,
    required this.rhymeId,
    required this.rhymeName,
    required this.title,
    required this.verseCount,
    required this.hasDiacritics,
    required this.isFreeVerse,
  });

  final int id;
  final int poetId;
  final String poetName;
  final int eraId;
  final String eraName;
  final int meterId;
  final String meterName;
  final int rhymeId;
  final String rhymeName;
  final String title;
  final int verseCount;
  final bool hasDiacritics;
  final bool isFreeVerse;
}

class PoemDetail extends PoemSummary {
  const PoemDetail({
    required super.id,
    required super.poetId,
    required super.poetName,
    required super.eraId,
    required super.eraName,
    required super.meterId,
    required super.meterName,
    required super.rhymeId,
    required super.rhymeName,
    required super.title,
    required super.verseCount,
    required super.hasDiacritics,
    required super.isFreeVerse,
    required this.meterNote,
    required this.verses,
  });

  final String meterNote;
  final List<Verse> verses;
}

enum PoemSortBy {
  rhyme('حرف الرويّ'),
  meter('البحر العروضي'),
  versesDesc('الأطول أولاً'),
  versesAsc('الأقصر أولاً'),
  alphabetical('أبجدياً');

  const PoemSortBy(this.label);
  final String label;
}
