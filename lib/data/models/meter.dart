class Meter {
  const Meter({required this.id, required this.name, required this.poemCount});

  final int id;
  final String name;
  final int poemCount;
}

class Rhyme {
  const Rhyme({
    required this.id,
    required this.name,
    required this.poemCount,
    this.letter = '',
  });

  final int id;
  final String name;
  final int poemCount;
  final String letter;
}

class ThemeCategory {
  const ThemeCategory({
    required this.id,
    required this.slug,
    required this.name,
    required this.poemCount,
  });

  final int id;
  final String slug;
  final String name;
  final int poemCount;

  String get subtitle => switch (slug) {
    'alnasib' => 'الغزل والوجدان ومطالع الأشواق',
    'almadih' => 'الثناء والمكارم ومدائح العظماء',
    'alhikma' => 'الأمثال والتجارب وفلسفة الحياة',
    'alritha' => 'المراثي والوفاء والدموع الصادقة',
    'alhija' => 'النقائض والذم والنقد اللاذع',
    'alitab' => 'اللوم الرقيق وعتاب الأحبة والخلّان',
    'alzuhd' => 'المواعظ والورع والزهد في الدنيا',
    'alhamasa' => 'الشجاعة والفروسية والفخر والإباء',
    'alwasf' => 'وصف الطبيعة والرياض والخيل والديار',
    _ => 'قصائد متنوّعة الأغراض والموضوعات',
  };
}

class Feeling {
  const Feeling({
    required this.id,
    required this.slug,
    required this.name,
    required this.wheelTerm,
    required this.parentSlug,
    required this.verseCount,
    this.children = const [],
  });

  final int id;
  final String slug;
  final String name;
  final String wheelTerm;
  final String? parentSlug;
  final int verseCount;
  final List<Feeling> children;

  bool get isRoot => parentSlug == null || parentSlug!.isEmpty;
}

/// A pinpoint verse matched inside a poem for a specific emotion or sub-feeling,
/// enabling direct jump & highlight inside [PoemReaderScreen].
class FeelingVerseHit {
  const FeelingVerseHit({
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
    this.matchedExtraHemistichs = const [],
    this.matchedKeyword = '',
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
  final List<String> matchedExtraHemistichs;
  final String matchedKeyword;
}

class FeelingSearchResult {
  const FeelingSearchResult({
    required this.hits,
    required this.totalMatchedPoems,
    required this.hasMore,
  });

  final List<FeelingVerseHit> hits;
  final int totalMatchedPoems;
  final bool hasMore;
}

class LibraryStats {
  const LibraryStats({
    required this.eraCount,
    required this.poetCount,
    required this.poemCount,
    required this.verseCount,
    required this.meterCount,
    required this.rhymeCount,
    this.themeCount = 0,
    this.feelingCount = 0,
  });

  final int eraCount;
  final int poetCount;
  final int poemCount;
  final int verseCount;
  final int meterCount;
  final int rhymeCount;
  final int themeCount;
  final int feelingCount;
}
