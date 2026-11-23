import '../../core/utils/arabic_normalizer.dart';

class Verse {
  const Verse({
    required this.index,
    required this.sadr,
    required this.ajuz,
    this.extraHemistichs = const [],
    this.rawStartIndex,
    this.rawEndIndex,
  });

  final int index;
  final String sadr;
  final String ajuz;

  /// Holds hemistichs 3, 4, and 5 when this unit is a 5-hemistich Mukhammas stanza
  /// (`مخمّس`: 2 couplets + 1 refrain hemistich treated as a single numbered stanza).
  final List<String> extraHemistichs;

  /// Original raw line index bounds in `poems.body` (used to map search/featured hits).
  final int? rawStartIndex;
  final int? rawEndIndex;

  bool get isMukhammas =>
      extraHemistichs.length == 3 && sadr.isNotEmpty && ajuz.isNotEmpty;

  bool get isTwoHemistich =>
      !isMukhammas && sadr.isNotEmpty && ajuz.isNotEmpty;

  List<String> get allHemistichs {
    if (isMukhammas) return [sadr, ajuz, ...extraHemistichs];
    if (isTwoHemistich) return [sadr, ajuz];
    final single = sadr.isNotEmpty ? sadr : ajuz;
    return [single];
  }

  String get plainCombined {
    if (isMukhammas) {
      return '$sadr — $ajuz\n${extraHemistichs[0]} — ${extraHemistichs[1]}\n${extraHemistichs[2]}';
    }
    return ajuz.isNotEmpty ? '$sadr — $ajuz' : sadr;
  }

  /// Resolves a raw line index (from search or `featured_verses`) to the
  /// corresponding grouped verse index (handles 5-hemistich Mukhammas poems).
  static int resolveGroupedIndex(List<Verse> verses, int rawIndex) {
    if (verses.isEmpty) return 0;
    for (var i = 0; i < verses.length; i++) {
      final v = verses[i];
      final start = v.rawStartIndex ?? v.index;
      final end = v.rawEndIndex ?? v.index;
      if (rawIndex >= start && rawIndex <= end) {
        return i;
      }
    }
    return rawIndex.clamp(0, verses.length - 1);
  }

  static List<Verse> parseBody(String body) {
    if (body.isEmpty) return const [];
    final lines = body.split('\n');
    final raw = <Verse>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) continue;
      final tabIdx = line.indexOf('\t');
      if (tabIdx == -1) {
        raw.add(
          Verse(
            index: raw.length,
            sadr: line.trim(),
            ajuz: '',
            rawStartIndex: raw.length,
            rawEndIndex: raw.length,
          ),
        );
      } else {
        final left = line.substring(0, tabIdx).trim();
        final right = line.substring(tabIdx + 1).trim();
        raw.add(
          Verse(
            index: raw.length,
            sadr: left,
            ajuz: right,
            rawStartIndex: raw.length,
            rawEndIndex: raw.length,
          ),
        );
      }
    }

    if (raw.length < 5) return raw;

    // 1. Detect classical 2-2-1 Mukhammas (تخميس / مخمّس: 2 couplets + 1 refrain hemistich = 5 hemistichs)
    final grouped221 = _tryGroupMukhammas221(raw);
    if (grouped221 != null) return grouped221;

    // 2. Detect 5x1 stanza-rhymed Mukhammas (5 single lines per stanza: AAAA R / BBBB R)
    final grouped5x1 = _tryGroupMukhammas5x1(raw);
    if (grouped5x1 != null) return grouped5x1;

    return raw;
  }

  static List<Verse>? _tryGroupMukhammas221(List<Verse> raw) {
    if (raw.length < 6) return null;
    int tripletMatches = 0;
    int matchedRows = 0;
    int i = 0;
    while (i + 2 < raw.length) {
      if (raw[i].isTwoHemistich &&
          raw[i + 1].isTwoHemistich &&
          !raw[i + 2].isTwoHemistich) {
        tripletMatches++;
        matchedRows += 3;
        i += 3;
      } else {
        i++;
      }
    }

    // Must have at least 2 complete 2-2-1 stanzas covering >= 72% of raw rows
    if (tripletMatches < 2 || (matchedRows / raw.length) < 0.72) {
      return null;
    }

    final result = <Verse>[];
    i = 0;
    while (i < raw.length) {
      if (i + 2 < raw.length &&
          raw[i].isTwoHemistich &&
          raw[i + 1].isTwoHemistich &&
          !raw[i + 2].isTwoHemistich) {
        final r0 = raw[i];
        final r1 = raw[i + 1];
        final r2 = raw[i + 2];
        final refrain = r2.sadr.isNotEmpty ? r2.sadr : r2.ajuz;
        result.add(
          Verse(
            index: result.length,
            sadr: r0.sadr,
            ajuz: r0.ajuz,
            extraHemistichs: [r1.sadr, r1.ajuz, refrain],
            rawStartIndex: i,
            rawEndIndex: i + 2,
          ),
        );
        i += 3;
      } else {
        final r = raw[i];
        result.add(
          Verse(
            index: result.length,
            sadr: r.sadr,
            ajuz: r.ajuz,
            rawStartIndex: i,
            rawEndIndex: i,
          ),
        );
        i++;
      }
    }
    return result;
  }

  static String _rhymeChar(String hemistich) {
    final clean = ArabicNormalizer.stripDiacritics(
      hemistich,
    ).replaceAll(RegExp(r'[^\u0621-\u064A]'), '');
    if (clean.isEmpty) return '';
    // Ignore trailing vowel letters (ا/و/ي/ه) if word has enough letters
    var idx = clean.length - 1;
    if (idx > 1 && 'اويىه'.contains(clean[idx])) {
      idx--;
    }
    return clean[idx];
  }

  static List<Verse>? _tryGroupMukhammas5x1(List<Verse> raw) {
    if (raw.length < 10 || raw.length % 5 != 0) return null;
    if (raw.any((v) => v.isTwoHemistich)) return null;

    final stanzas = raw.length ~/ 5;
    int validStanzas = 0;
    final refrainRhymes = <String, int>{};

    for (var s = 0; s < stanzas; s++) {
      final base = s * 5;
      final firstFour = [
        for (var k = 0; k < 4; k++) _rhymeChar(raw[base + k].sadr),
      ];
      final fifth = _rhymeChar(raw[base + 4].sadr);
      if (fifth.isNotEmpty) {
        refrainRhymes[fifth] = (refrainRhymes[fifth] ?? 0) + 1;
      }
      final counts = <String, int>{};
      for (final ch in firstFour) {
        if (ch.isNotEmpty) counts[ch] = (counts[ch] ?? 0) + 1;
      }
      if (counts.isEmpty) continue;
      final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
      // Stanza rhyme (at least 3 of first 4 match) AND differs from the 5th refrain
      if (top.value >= 3 && top.key != fifth) {
        validStanzas++;
      }
    }

    if (refrainRhymes.isEmpty) return null;
    final topRefrainCount = refrainRhymes.values.reduce((a, b) => a > b ? a : b);
    // Require distinct stanza rhymes + consistent refrain rhyme across >= 70% of stanzas
    if ((validStanzas / stanzas) < 0.70 ||
        (topRefrainCount / stanzas) < 0.70) {
      return null;
    }

    final result = <Verse>[];
    for (var s = 0; s < stanzas; s++) {
      final base = s * 5;
      result.add(
        Verse(
          index: s,
          sadr: raw[base].sadr,
          ajuz: raw[base + 1].sadr,
          extraHemistichs: [
            raw[base + 2].sadr,
            raw[base + 3].sadr,
            raw[base + 4].sadr,
          ],
          rawStartIndex: base,
          rawEndIndex: base + 4,
        ),
      );
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
    this.category = 'خالدات',
    this.tag = 'من عيون الشعر',
    this.verseCount = 0,
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
  final String category;
  final String tag;
  final int verseCount;

  Verse toVerse() => Verse(index: verseIndex, sadr: sadr, ajuz: ajuz);
}
