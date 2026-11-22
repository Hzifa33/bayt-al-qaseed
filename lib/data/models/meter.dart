class Meter {
  const Meter({required this.id, required this.name, required this.poemCount});

  final int id;
  final String name;
  final int poemCount;
}

class Rhyme {
  const Rhyme({required this.id, required this.name, required this.poemCount});

  final int id;
  final String name;
  final int poemCount;
}

class LibraryStats {
  const LibraryStats({
    required this.eraCount,
    required this.poetCount,
    required this.poemCount,
    required this.verseCount,
    required this.meterCount,
    required this.rhymeCount,
  });

  final int eraCount;
  final int poetCount;
  final int poemCount;
  final int verseCount;
  final int meterCount;
  final int rhymeCount;
}
