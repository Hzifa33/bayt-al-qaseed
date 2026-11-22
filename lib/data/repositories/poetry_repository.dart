import 'dart:math' as math;

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
  final math.Random _rng = math.Random();
  int? _cachedMaxPoemId;

  Database get _db => _corpus.db;

  int _getMaxPoemId() {
    if (_cachedMaxPoemId != null) return _cachedMaxPoemId!;
    final row = _db.select('SELECT MAX(id) AS m FROM poems');
    _cachedMaxPoemId = (row.first['m'] as int?) ?? 90000;
    return _cachedMaxPoemId!;
  }

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

  FeaturedVerse? getVerseOfTheDay([DateTime? now]) {
    final countRow = _db.select('SELECT COUNT(*) AS c FROM featured_verses');
    final total = countRow.first['c'] as int;
    if (total == 0) return null;
    final date = now ?? DateTime.now();
    final daySeed = date.year * 1000 + date.month * 32 + date.day;
    final offset = daySeed % total;
    final rows = _db.select(
      'SELECT * FROM featured_verses ORDER BY id ASC LIMIT 1 OFFSET ?',
      [offset],
    );
    if (rows.isEmpty) return null;
    return _mapFeaturedVerse(rows.first);
  }

  FeaturedVerse? getRandomFeaturedVerse({int? excludeId}) {
    final rows = excludeId != null
        ? _db.select(
            'SELECT * FROM featured_verses WHERE id != ? ORDER BY RANDOM() LIMIT 1',
            [excludeId],
          )
        : _db.select('SELECT * FROM featured_verses ORDER BY RANDOM() LIMIT 1');
    if (rows.isEmpty) return null;
    return _mapFeaturedVerse(rows.first);
  }

  List<FeaturedVerse> getFeaturedMasterpieces({int limit = 80}) {
    final rows = _db.select(
      'SELECT * FROM featured_verses ORDER BY id ASC LIMIT ?',
      [limit],
    );
    return rows.map(_mapFeaturedVerse).toList();
  }

  /// Instant O(log N) random poem picker (~0.08 ms) avoiding full-table RANDOM() scans.
  PoemSummary? getRandomPoem({int? eraId, int? meterId}) {
    if (eraId == null && meterId == null) {
      final maxId = _getMaxPoemId();
      if (maxId <= 0) return null;
      final probeId = _rng.nextInt(maxId) + 1;
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
        WHERE p.id >= ?
        ORDER BY p.id ASC
        LIMIT 1
        ''',
        [probeId],
      );
      if (rows.isNotEmpty) return _mapPoemSummary(rows.first);
      return null;
    }

    // Fast indexed count + random offset when filtered by era or meter
    final where = <String>[];
    final args = <Object?>[];
    if (eraId != null) {
      where.add('era_id = ?');
      args.add(eraId);
    }
    if (meterId != null) {
      where.add('meter_id = ?');
      args.add(meterId);
    }
    final countRow = _db.select(
      'SELECT COUNT(*) AS c FROM poems WHERE ${where.join(' AND ')}',
      args,
    );
    final total = countRow.first['c'] as int;
    if (total <= 0) return null;
    final offset = _rng.nextInt(total);

    final prefixedWhere = where.map((w) => 'p.$w').join(' AND ');
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
      WHERE $prefixedWhere
      LIMIT 1 OFFSET ?
      ''',
      [...args, offset],
    );
    if (rows.isEmpty) return null;
    return _mapPoemSummary(rows.first);
  }

  List<Poet> getPoets({
    int? eraId,
    String? filterQuery,
    PoetSortBy sortBy = PoetSortBy.poemsDesc,
  }) {
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

    final orderBy = switch (sortBy) {
      PoetSortBy.poemsDesc => 'pt.poem_count DESC, pt.name_norm ASC',
      PoetSortBy.versesDesc => 'pt.verse_count DESC, pt.name_norm ASC',
      PoetSortBy.alphabetical => 'pt.name_norm ASC',
      PoetSortBy.oldest => 'pt.era_id ASC, pt.id ASC',
    };

    final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final rows = _db.select('''
      SELECT pt.*, e.name AS era_name
      FROM poets pt
      JOIN eras e ON e.id = pt.era_id
      $whereSql
      ORDER BY $orderBy
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
    int limit = 2500,
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
    int limit = 60,
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

  (int?, int?) getAdjacentPoemIds(int poetId, int currentPoemId) {
    final prev = _db.select(
      'SELECT id FROM poems WHERE poet_id = ? AND id < ? ORDER BY id DESC LIMIT 1',
      [poetId, currentPoemId],
    );
    final next = _db.select(
      'SELECT id FROM poems WHERE poet_id = ? AND id > ? ORDER BY id ASC LIMIT 1',
      [poetId, currentPoemId],
    );
    return (
      prev.isEmpty ? null : prev.first['id'] as int,
      next.isEmpty ? null : next.first['id'] as int,
    );
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

  /// Precision Verse-Level Arabic Search Engine.
  SearchBundle search({
    required String rawQuery,
    SearchFilter filter = const SearchFilter(),
    int poemLimit = 60,
    int poetLimit = 12,
  }) {
    final sw = Stopwatch()..start();
    final tokens = ArabicNormalizer.tokenize(rawQuery);
    if (tokens.isEmpty) {
      return SearchBundle(
        query: rawQuery,
        poems: const [],
        poets: const [],
        elapsedMs: 0,
      );
    }

    final ftsQuery = _buildCandidateFtsQuery(
      tokens: tokens,
      matchMode: filter.matchMode,
      matchPartialWords: filter.matchPartialWords,
    );

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

    final candidateLimit = (poemLimit * 5).clamp(160, 450);
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
      [...args, candidateLimit],
    );

    final hits = <PoemSearchHit>[];
    for (final r in poemRows) {
      final verses = Verse.parseBody(r['body'] as String);
      final match = _matchVerseInPoem(
        verses: verses,
        tokens: tokens,
        matchMode: filter.matchMode,
        matchPartialWords: filter.matchPartialWords,
      );
      if (match == null) continue;

      final (bestVerse, matchCount) = match;
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
          matchedVerseIndex: bestVerse.index,
          matchedSadr: bestVerse.sadr,
          matchedAjuz: bestVerse.ajuz,
          matchingVersesCount: matchCount,
        ),
      );
      if (hits.length >= poemLimit) break;
    }

    sw.stop();
    return SearchBundle(
      query: rawQuery,
      poems: hits,
      poets: matchedPoets,
      elapsedMs: sw.elapsedMicroseconds / 1000.0,
    );
  }

  String _buildCandidateFtsQuery({
    required List<String> tokens,
    required SearchMatchMode matchMode,
    required bool matchPartialWords,
  }) {
    if (matchMode == SearchMatchMode.exactSequence && !matchPartialWords) {
      if (tokens.length == 1) return tokens.first;
      return '"${tokens.join(' ')}"';
    }
    if (matchMode == SearchMatchMode.exactSequence && matchPartialWords) {
      if (tokens.length == 1) {
        return tokens.first.length >= 2 ? '${tokens.first}*' : tokens.first;
      }
      final parts = <String>[
        for (var i = 0; i < tokens.length - 1; i++) tokens[i],
        tokens.last.length >= 2 ? '${tokens.last}*' : tokens.last,
      ];
      return parts.join(' ');
    }
    return tokens
        .map((t) => (matchPartialWords && t.length >= 2) ? '$t*' : t)
        .join(' ');
  }

  (Verse, int)? _matchVerseInPoem({
    required List<Verse> verses,
    required List<String> tokens,
    required SearchMatchMode matchMode,
    required bool matchPartialWords,
  }) {
    Verse? bestVerse;
    var bestScore = -1;
    var matchCount = 0;
    final joinedPhrase = tokens.join(' ');

    for (final v in verses) {
      final normLine = ArabicNormalizer.normalize('${v.sadr} ${v.ajuz}');
      if (normLine.isEmpty) continue;

      final words = normLine.split(' ');
      bool matched = false;
      int score = 0;

      if (matchMode == SearchMatchMode.exactSequence) {
        if (matchPartialWords) {
          final idx = normLine.indexOf(joinedPhrase);
          if (idx != -1) {
            final validStart = idx == 0 || normLine[idx - 1] == ' ';
            if (validStart) {
              matched = true;
              final endPos = idx + joinedPhrase.length;
              final exactWordEnd =
                  endPos == normLine.length || normLine[endPos] == ' ';
              score = exactWordEnd ? 200 : 140;
            }
          }
        } else {
          final padded = ' $normLine ';
          if (padded.contains(' $joinedPhrase ')) {
            matched = true;
            score = 220;
          }
        }
      } else {
        var allMatched = true;
        for (final t in tokens) {
          final tokenHit = matchPartialWords
              ? words.any((w) => w.startsWith(t))
              : words.contains(t);
          if (!tokenHit) {
            allMatched = false;
            break;
          }
        }
        if (allMatched) {
          matched = true;
          score = 100;
          if (tokens.length > 1 && normLine.contains(joinedPhrase)) {
            score += 60;
          }
          final normSadr = ArabicNormalizer.normalize(v.sadr);
          final normAjuz = ArabicNormalizer.normalize(v.ajuz);
          if (tokens.every((t) => normSadr.contains(t)) ||
              tokens.every((t) => normAjuz.contains(t))) {
            score += 20;
          }
        }
      }

      if (matched) {
        matchCount++;
        if (score > bestScore) {
          bestScore = score;
          bestVerse = v;
        }
      }
    }

    if (bestVerse == null) return null;
    return (bestVerse, matchCount);
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

  FeaturedVerse _mapFeaturedVerse(Row r) {
    String tag = 'من عيون الشعر';
    String category = 'خالدات';
    int verseCount = 0;
    try {
      final rawTag = r['tag'];
      if (rawTag is String && rawTag.isNotEmpty) tag = rawTag;
    } catch (_) {}
    try {
      final rawCat = r['category'];
      if (rawCat is String && rawCat.isNotEmpty) category = rawCat;
    } catch (_) {}
    try {
      final rawCnt = r['verse_count'];
      if (rawCnt is int) verseCount = rawCnt;
    } catch (_) {}
    return FeaturedVerse(
      id: r['id'] as int,
      poemId: r['poem_id'] as int,
      poetId: r['poet_id'] as int,
      eraId: r['era_id'] as int,
      verseIndex: r['verse_index'] as int,
      sadr: r['sadr'] as String,
      ajuz: r['ajuz'] as String,
      poetName: r['poet_name'] as String,
      eraName: r['era_name'] as String,
      category: category,
      tag: tag,
      verseCount: verseCount,
    );
  }
}
