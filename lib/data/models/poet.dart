enum PoetSortBy {
  poemsDesc('الأغزر قصائد'),
  versesDesc('الأكثر أبياتاً'),
  alphabetical('الترتيب الهجائي'),
  oldest('الأقدم عهداً');

  const PoetSortBy(this.label);
  final String label;
}

class Poet {
  const Poet({
    required this.id,
    required this.eraId,
    required this.eraName,
    required this.name,
    required this.namePlain,
    required this.datesHijri,
    required this.datesGregorian,
    required this.bio,
    required this.poemCount,
    required this.verseCount,
  });

  final int id;
  final int eraId;
  final String eraName;
  final String name;
  final String namePlain;
  final String datesHijri;
  final String datesGregorian;
  final String bio;
  final int poemCount;
  final int verseCount;

  String get formattedDates {
    if (datesHijri.isNotEmpty && datesGregorian.isNotEmpty) {
      return '$datesHijri  •  $datesGregorian';
    }
    return datesHijri.isNotEmpty ? datesHijri : datesGregorian;
  }
}
