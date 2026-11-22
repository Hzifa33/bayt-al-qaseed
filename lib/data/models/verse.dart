class Verse {
  const Verse({required this.index, required this.sadr, required this.ajuz});

  final int index;
  final String sadr;
  final String ajuz;

  bool get isTwoHemistich => sadr.isNotEmpty && ajuz.isNotEmpty;

  String get plainCombined => ajuz.isNotEmpty ? '$sadr — $ajuz' : sadr;

  static List<Verse> parseBody(String body) {
    if (body.isEmpty) return const [];
    final lines = body.split('\n');
    final result = <Verse>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;
      final tabIdx = line.indexOf('\t');
      if (tabIdx == -1) {
        result.add(Verse(index: result.length, sadr: line, ajuz: ''));
      } else {
        result.add(
          Verse(
            index: result.length,
            sadr: line.substring(0, tabIdx),
            ajuz: line.substring(tabIdx + 1),
          ),
        );
      }
    }
    return result;
  }
}

class FeaturedVerse {
  const FeaturedVerse({
    required this.id,
    required this.poemId,
    required this.poetId,
    required this.eraId,
    required this.verseIndex,
    required this.sadr,
    required this.ajuz,
    required this.poetName,
    required this.eraName,
    this.tag = 'من عيون الشعر',
  });

  final int id;
  final int poemId;
  final int poetId;
  final int eraId;
  final int verseIndex;
  final String sadr;
  final String ajuz;
  final String poetName;
  final String eraName;
  final String tag;

  Verse toVerse() => Verse(index: verseIndex, sadr: sadr, ajuz: ajuz);
}
