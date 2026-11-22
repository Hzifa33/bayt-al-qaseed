import 'package:sqlite3/sqlite3.dart';

import '../../core/utils/arabic_normalizer.dart';
import '../datasources/poetry_database.dart';
import '../models/era.dart';
import '../models/meter.dart';
import '../models/poem.dart';
import '../models/poet.dart';
import '../models/search_result.dart';
import '../models/verse.dart';

class PoetryRepository {
  PoetryRepository(this._corpus);

  final PoetryDatabase _corpus;
  Database get _db => _corpus.db;

  LibraryStats getLibraryStats() {
    final rows = _db.select('SELECT key, value FROM metadata');
    final map = <String, int>{};
    for (final r in rows) {
      map[r['key'] as String] = int.tryParse(r['value'] as String) ?? 0;
    }
    return LibraryStats(
      eraCount: map['era_count'] ?? 11,
      poetCount: map['poet_count'] ?? 0,
      poemCount: map['poem_count'] ?? 0,
      verseCount: map['verse_count'] ?? 0,
      meterCount: map['meter_count'] ?? 0,
      rhymeCount: map['rhyme_count'] ?? 0,
    );
  }

  List<Era> getEras() {
    final rows = _db.select('''
      SELECT id, name, display_order, poet_count, poem_count
      FROM eras
      ORDER BY display_order ASC
    ''');
    return rows
        .map(
          (r) => Era(
            id: r['id'] as int,
            name: r['name'] as String,
            displayOrder: r['display_order'] as int,
            poetCount: r['poet_count'] as int,
            poemCount: r['poem_count'] as int,
          ),
        )
        .toList();
  }

  List<Meter> getMeters() {
    final rows = _db.select('''
      SELECT id, name, poem_count
      FROM meters
      WHERE poem_count > 0
      ORDER BY poem_count DESC
    ''');
    return rows
        .map(
          (r) => Meter(
            id: r['id'] as int,
            name: r['name'] as String,
            poemCount: r['poem_count'] as int,
          ),
        )
        .toList();
  }

  List<Rhyme> getRhymes() {
    final rows = _db.select('''
      SELECT id, name, poem_count
      FROM rhymes
      WHERE poem_count > 0
      ORDER BY poem_count DESC
    ''');
    return rows
        .map(
          (r) => Rhyme(
            id: r['id'] as int,
            name: r['name'] as String,
            poemCount: r['poem_count'] as int,
          ),
        )
        .toList();
  }

  /// Returns a deterministic "Verse of the Day" based on the current calendar date.
  FeaturedVerse? getVerseOfTheDay([DateTime? now]) {
    final countRow = _db.select('SELECT COUNT(*) AS c FROM featured_verses');
    final total = countRow.first['c'] as int;
    if (total == 0) return null;
    final date = now ?? DateTime.now();
    final daySeed = date.year * 1000 + date.month * 32 + date.day;
    final offset = daySeed % total;
    final rows = _db.select('SELECT * FROM featured_verses LIMIT 1 OFFSET ?', [
      offset,
    ]);
    if (rows.isEmpty) return null;
    return _mapFeaturedVerse(rows.first);
  }

  FeaturedVerse? getRandomFeaturedVerse() {
    final rows = _db.select(
      'SELECT * FROM featured_verses ORDER BY RANDOM() LIMIT 1',
    );
    if (rows.isEmpty) return null;
    return _mapFeaturedVerse(rows.first);
  }

  /// Returns a random classical/modern poem for "قصيدة بمحض الصدفة".
  PoemSummary? getRandomPoem({int? eraId, int? meterId}) {
    final where = <String>[];
    final args = <Object?>[];
    if (eraId != null) {
      where.add('p.era_id = ?');
      args.add(eraId);
    }
    if (meterId != null) {
      where.add('p.meter_id = ?');
      args.add(meterId);
    }
    final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final rows = _db.select('''
      SELECT p.id, p.poet_id, pt.name_plain AS poet_name,
             p.era_id, e.name AS era_name,
             p.meter_id, m.name AS meter_name,
             p.rhyme_id, r.name AS rhyme_name,
             p.title, p.verse_count, p.has_diacritics, p.is_free_verse
      FROM poems p
      JOIN poets pt ON pt.id = p.poet_id
      JOIN eras e ON e.id = p.era_id
      JOIN meters m ON m.id = p.meter_id
      JOIN rhymes r ON r.id = p.rhyme_id
      $whereSql
      ORDER BY RANDOM()
      LIMIT 1
      ''', args);
    if (rows.isEmpty) return null;
    return _mapPoemSummary(rows.first);
  }

  List<Poet> getPoets({int? eraId, String? filterQuery}) {
    final where = <String>[];
    final args = <Object?>[];

    if (eraId != null) {
      where.add('pt.era_id = ?');
      args.add(eraId);
    }
    if (filterQuery != null && filterQuery.trim().isNotEmpty) {
      final norm = ArabicNormalizer.normalize(filterQuery);
      if (norm.isNotEmpty) {
        where.add('pt.name_norm LIKE ?');
        args.add('%$norm%');
      }
    }

    final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final rows = _db.select('''
      SELECT pt.*, e.name AS era_name
      FROM poets pt
      JOIN eras e ON e.id = pt.era_id
      $whereSql
      ORDER BY pt.poem_count DESC, pt.name_norm ASC
      ''', args);
    return rows.map(_mapPoet).toList();
  }

  Poet? getPoetById(int poetId) {
    final rows = _db.select(
      '''
      SELECT pt.*, e.name AS era_name
      FROM poets pt
      JOIN eras e ON e.id = pt.era_id
      WHERE pt.id = ?
      ''',
      [poetId],
    );
    if (rows.isEmpty) return null;
    return _mapPoet(rows.first);
  }

  List<Poet> getPoetsByIds(List<int> ids) {
    if (ids.isEmpty) return const [];
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = _db.select('''
      SELECT pt.*, e.name AS era_name
      FROM poets pt
      JOIN eras e ON e.id = pt.era_id
      WHERE pt.id IN ($placeholders)
      ''', ids);
    final byId = {for (final r in rows) r['id'] as int: _mapPoet(r)};
    return [
      for (final id in ids)
        if (byId.containsKey(id)) byId[id]!,
    ];
  }

  List<Meter> getMetersForPoet(int poetId) {
    final rows = _db.select(
      '''
      SELECT m.id, m.name, COUNT(*) AS cnt
      FROM poems p
      JOIN meters m ON m.id = p.meter_id
      WHERE p.poet_id = ?
      GROUP BY m.id, m.name
      ORDER BY cnt DESC
      ''',
      [poetId],
    );
    return rows
        .map(
          (r) => Meter(
            id: r['id'] as int,
            name: r['name'] as String,
            poemCount: r['cnt'] as int,
          ),
        )
        .toList();
  }

  List<Rhyme> getRhymesForPoet(int poetId) {
    final rows = _db.select(
      '''
      SELECT r.id, r.name, COUNT(*) AS cnt
      FROM poems p
      JOIN rhymes r ON r.id = p.rhyme_id
      WHERE p.poet_id = ?
      GROUP BY r.id, r.name
      ORDER BY cnt DESC
      ''',
      [poetId],
    );
    return rows
        .map(
          (r) => Rhyme(
            id: r['id'] as int,
            name: r['name'] as String,
            poemCount: r['cnt'] as int,
          ),
        )
        .toList();
  }

  List<PoemSummary> getPoemsForPoet(
    int poetId, {
    PoemSortBy sortBy = PoemSortBy.rhyme,
    int? meterId,
    int? rhymeId,
    String? titleFilter,
    int limit = 1000,
    int offset = 0,
  }) {
    final where = <String>['p.poet_id = ?'];
    final args = <Object?>[poetId];

    if (meterId != null) {
      where.add('p.meter_id = ?');
      args.add(meterId);
    }
    if (rhymeId != null) {
      where.add('p.rhyme_id = ?');
      args.add(rhymeId);
    }
    if (titleFilter != null && titleFilter.trim().isNotEmpty) {
      final norm = ArabicNormalizer.normalize(titleFilter);
      if (norm.isNotEmpty) {
        where.add('p.title_norm LIKE ?');
        args.add('%$norm%');
      }
    }

    final orderBy = switch (sortBy) {
      PoemSortBy.rhyme => 'r.name ASC, p.verse_count DESC',
      PoemSortBy.meter => 'm.name ASC, p.verse_count DESC',
      PoemSortBy.versesDesc => 'p.verse_count DESC, p.id ASC',
      PoemSortBy.versesAsc => 'p.verse_count ASC, p.id ASC',
      PoemSortBy.alphabetical => 'p.title_norm ASC',
    };

    final rows = _db.select(
      '''
      SELECT p.id, p.poet_id, pt.name_plain AS poet_name,
             p.era_id, e.name AS era_name,
             p.meter_id, m.name AS meter_name,
             p.rhyme_id, r.name AS rhyme_name,
             p.title, p.verse_count, p.has_diacritics, p.is_free_verse
      FROM poems p
      JOIN poets pt ON pt.id = p.poet_id
      JOIN eras e ON e.id = p.era_id
      JOIN meters m ON m.id = p.meter_id
      JOIN rhymes r ON r.id = p.rhyme_id
      WHERE ${where.join(' AND ')}
      ORDER BY $orderBy
      LIMIT ? OFFSET ?
      ''',
      [...args, limit, offset],
    );
    return rows.map(_mapPoemSummary).toList();
  }

  List<PoemSummary> getPoemsByMeter(
    int meterId, {
    int limit = 80,
    int offset = 0,
  }) {
    final rows = _db.select(
      '''
      SELECT p.id, p.poet_id, pt.name_plain AS poet_name,
             p.era_id, e.name AS era_name,
             p.meter_id, m.name AS meter_name,
             p.rhyme_id, r.name AS rhyme_name,
             p.title, p.verse_count, p.has_diacritics, p.is_free_verse
      FROM poems p
      JOIN poets pt ON pt.id = p.poet_id
      JOIN eras e ON e.id = p.era_id
      JOIN meters m ON m.id = p.meter_id
      JOIN rhymes r ON r.id = p.rhyme_id
      WHERE p.meter_id = ?
      ORDER BY p.verse_count DESC
      LIMIT ? OFFSET ?
      ''',
      [meterId, limit, offset],
    );
    return rows.map(_mapPoemSummary).toList();
  }

  List<PoemSummary> getPoemsByIds(List<int> ids) {
    if (ids.isEmpty) return const [];
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = _db.select('''
      SELECT p.id, p.poet_id, pt.name_plain AS poet_name,
             p.era_id, e.name AS era_name,
             p.meter_id, m.name AS meter_name,
             p.rhyme_id, r.name AS rhyme_name,
             p.title, p.verse_count, p.has_diacritics, p.is_free_verse
      FROM poems p
      JOIN poets pt ON pt.id = p.poet_id
      JOIN eras e ON e.id = p.era_id
      JOIN meters m ON m.id = p.meter_id
      JOIN rhymes r ON r.id = p.rhyme_id
      WHERE p.id IN ($placeholders)
      ''', ids);
    final byId = {for (final r in rows) r['id'] as int: _mapPoemSummary(r)};
    return [
      for (final id in ids)
        if (byId.containsKey(id)) byId[id]!,
    ];
  }

  PoemDetail? getPoemById(int poemId) {
    final rows = _db.select(
      '''
      SELECT p.id, p.poet_id, pt.name_plain AS poet_name,
             p.era_id, e.name AS era_name,
             p.meter_id, m.name AS meter_name,
             p.rhyme_id, r.name AS rhyme_name,
             p.meter_note, p.title, p.verse_count,
             p.has_diacritics, p.is_free_verse, p.body
      FROM poems p
      JOIN poets pt ON pt.id = p.poet_id
      JOIN eras e ON e.id = p.era_id
      JOIN meters m ON m.id = p.meter_id
      JOIN rhymes r ON r.id = p.rhyme_id
      WHERE p.id = ?
      ''',
      [poemId],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    final verses = Verse.parseBody(r['body'] as String);
    return PoemDetail(
      id: r['id'] as int,
      poetId: r['poet_id'] as int,
      poetName: r['poet_name'] as String,
      eraId: r['era_id'] as int,
      eraName: r['era_name'] as String,
      meterId: r['meter_id'] as int,
      meterName: r['meter_name'] as String,
      rhymeId: r['rhyme_id'] as int,
      rhymeName: r['rhyme_name'] as String,
      meterNote: r['meter_note'] as String,
      title: r['title'] as String,
      verseCount: verses.length,
      hasDiacritics: (r['has_diacritics'] as int) == 1,
      isFreeVerse: (r['is_free_verse'] as int) == 1,
      verses: verses,
    );
  }

  /// Instant FTS5 search across 1.16M+ Arabic verses, poem titles, and poets.
  ///
  /// Normalizes Arabic input seamlessly (tashkeel, alef, alef maqsura, taa marbuta)
  /// and locates the exact best-matching verse inside each hit while preserving
  /// original diacritics for golden highlighting in the UI.
  SearchBundle search({
    required String rawQuery,
    SearchFilter filter = const SearchFilter(),
    int poemLimit = 60,
    int poetLimit = 12,
  }) {
    final sw = Stopwatch()..start();
    final ftsQuery = ArabicNormalizer.buildFts5Query(
      rawQuery,
      exactPhrase: filter.exactPhrase,
      prefixLastToken: !filter.exactPhrase,
    );
    if (ftsQuery.isEmpty) {
      return SearchBundle(
        query: rawQuery,
        poems: const [],
        poets: const [],
        elapsedMs: 0,
      );
    }

    // 1. Search Poets via poets_fts (only when no poem-only filter is narrowing it)
    final matchedPoets = <Poet>[];
    if (filter.poetId == null &&
        filter.meterId == null &&
        filter.rhymeId == null) {
      final poetWhere = <String>['poets_fts MATCH ?'];
      final poetArgs = <Object?>[ftsQuery];
      if (filter.eraId != null) {
        poetWhere.add('pt.era_id = ?');
        poetArgs.add(filter.eraId);
      }
      final poetRows = _db.select(
        '''
        SELECT pt.*, e.name AS era_name
        FROM poets_fts f
        JOIN poets pt ON pt.id = f.rowid
        JOIN eras e ON e.id = pt.era_id
        WHERE ${poetWhere.join(' AND ')}
        ORDER BY bm25(poets_fts, 4.0, 1.0)
        LIMIT ?
        ''',
        [...poetArgs, poetLimit],
      );
      matchedPoets.addAll(poetRows.map(_mapPoet));
    }

    // 2. Search Poems & Verses via poems_fts
    final where = <String>['poems_fts MATCH ?'];
    final args = <Object?>[ftsQuery];
    if (filter.eraId != null) {
      where.add('p.era_id = ?');
      args.add(filter.eraId);
    }
    if (filter.poetId != null) {
      where.add('p.poet_id = ?');
      args.add(filter.poetId);
    }
    if (filter.meterId != null) {
      where.add('p.meter_id = ?');
      args.add(filter.meterId);
    }
    if (filter.rhymeId != null) {
      where.add('p.rhyme_id = ?');
      args.add(filter.rhymeId);
    }

    final poemRows = _db.select(
      '''
      SELECT p.id, p.poet_id, pt.name_plain AS poet_name,
             e.name AS era_name, m.name AS meter_name, r.name AS rhyme_name,
             p.title, p.verse_count, p.body
      FROM poems_fts f
      JOIN poems p ON p.id = f.rowid
      JOIN poets pt ON pt.id = p.poet_id
      JOIN eras e ON e.id = p.era_id
      JOIN meters m ON m.id = p.meter_id
      JOIN rhymes r ON r.id = p.rhyme_id
      WHERE ${where.join(' AND ')}
      ORDER BY bm25(poems_fts, 2.5, 1.0, 1.5)
      LIMIT ?
      ''',
      [...args, poemLimit],
    );

    final tokens = ArabicNormalizer.tokenize(rawQuery);
    final hits = <PoemSearchHit>[];
    for (final r in poemRows) {
      final verses = Verse.parseBody(r['body'] as String);
      final best = _findBestMatchingVerse(verses, tokens);
      hits.add(
        PoemSearchHit(
          poemId: r['id'] as int,
          poetId: r['poet_id'] as int,
          poetName: r['poet_name'] as String,
          eraName: r['era_name'] as String,
          meterName: r['meter_name'] as String,
          rhymeName: r['rhyme_name'] as String,
          title: r['title'] as String,
          verseCount: r['verse_count'] as int,
          matchedVerseIndex: best.index,
          matchedSadr: best.sadr,
          matchedAjuz: best.ajuz,
        ),
      );
    }

    sw.stop();
    return SearchBundle(
      query: rawQuery,
      poems: hits,
      poets: matchedPoets,
      elapsedMs: sw.elapsedMicroseconds / 1000.0,
    );
  }

  Verse _findBestMatchingVerse(List<Verse> verses, List<String> tokens) {
    if (verses.isEmpty) {
      return const Verse(index: 0, sadr: '', ajuz: '');
    }
    if (tokens.isEmpty) return verses.first;

    var bestVerse = verses.first;
    var bestScore = -1;
    final fullPhrase = tokens.join(' ');

    for (final v in verses) {
      final normLine = ArabicNormalizer.normalize('${v.sadr} ${v.ajuz}');
      var score = 0;
      if (tokens.length > 1 && normLine.contains(fullPhrase)) {
        score += 100;
      }
      for (final t in tokens) {
        if (normLine.contains(t)) {
          score += 10;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        bestVerse = v;
        if (score >= 100 + tokens.length * 10) break;
      }
    }
    return bestVerse;
  }

  Poet _mapPoet(Row r) => Poet(
    id: r['id'] as int,
    eraId: r['era_id'] as int,
    eraName: r['era_name'] as String,
    name: r['name'] as String,
    namePlain: r['name_plain'] as String,
    datesHijri: r['dates_hijri'] as String,
    datesGregorian: r['dates_gregorian'] as String,
    bio: r['bio'] as String,
    poemCount: r['poem_count'] as int,
    verseCount: r['verse_count'] as int,
  );

  PoemSummary _mapPoemSummary(Row r) => PoemSummary(
    id: r['id'] as int,
    poetId: r['poet_id'] as int,
    poetName: r['poet_name'] as String,
    eraId: r['era_id'] as int,
    eraName: r['era_name'] as String,
    meterId: r['meter_id'] as int,
    meterName: r['meter_name'] as String,
    rhymeId: r['rhyme_id'] as int,
    rhymeName: r['rhyme_name'] as String,
    title: r['title'] as String,
    verseCount: r['verse_count'] as int,
    hasDiacritics: (r['has_diacritics'] as int) == 1,
    isFreeVerse: (r['is_free_verse'] as int) == 1,
  );

  FeaturedVerse _mapFeaturedVerse(Row r) => FeaturedVerse(
    id: r['id'] as int,
    poemId: r['poem_id'] as int,
    poetId: r['poet_id'] as int,
    eraId: r['era_id'] as int,
    verseIndex: r['verse_index'] as int,
    sadr: r['sadr'] as String,
    ajuz: r['ajuz'] as String,
    poetName: r['poet_name'] as String,
    eraName: r['era_name'] as String,
  );
}
