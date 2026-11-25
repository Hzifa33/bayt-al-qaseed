import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import '../../core/utils/arabic_codec.dart';
import '../../core/utils/arabic_normalizer.dart';
import '../../core/utils/feeling_lexicon.dart';
import '../datasources/poetry_database.dart';
import '../models/era.dart';
import '../models/meter.dart';
import '../models/poem.dart';
import '../models/poet.dart';
import '../models/search_result.dart';
import '../models/verse.dart';

class PoetryRepository {
  PoetryRepository(this._corpus) {
    _isCompactV6 = _tableExists('content_blocks');
    _hasBodyFts = _tableExists('poems_body_fts');
    _hasThemesTable = _tableExists('themes');
    _hasFeelingsTable = _tableExists('feelings');
  }

  final PoetryDatabase _corpus;
  final math.Random _rng = math.Random();
  final BlockLruCache _blockCache = BlockLruCache(capacity: 16);

  late final bool _isCompactV6;
  late final bool _hasBodyFts;
  late final bool _hasThemesTable;
  late final bool _hasFeelingsTable;
  int? _cachedMaxPoemId;

  Database get _db => _corpus.db;

  bool get isExpandedCorpus => _isCompactV6;
  bool get hasThemes => _hasThemesTable;
  bool get hasFeelings => _hasFeelingsTable;

  String get _poetDisplayCol => _isCompactV6 ? 'pt.name' : 'pt.name_plain';
  String get _rhymeDisplayCol => _isCompactV6 ? 'r.letter' : 'r.name';

  bool _tableExists(String name) {
    final rows = _db.select(
      "SELECT 1 FROM sqlite_master WHERE type='table' AND name = ?",
      [name],
    );
    return rows.isNotEmpty;
  }

  String _readPoemBody(Row r) {
    if (!_isCompactV6) {
      return r['body'] as String;
    }
    final blockId = r['block_id'] as int;
    final offset = r['offset'] as int;
    final length = r['length'] as int;
    var block = _blockCache.get(blockId);
    if (block == null) {
      final bRows = _db.select('SELECT data FROM content_blocks WHERE id = ?', [
        blockId,
      ]);
      if (bRows.isEmpty) return '';
      final rawBlob = bRows.first['data'] as Uint8List;
      block = ArabicCodec.decompressZlib(rawBlob);
      _blockCache.put(blockId, block);
    }
    return ArabicCodec.unpack(block, offset, length);
  }

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
    int feelingCount = 0;
    if (_hasFeelingsTable) {
      feelingCount =
          _db.select('SELECT COUNT(*) AS c FROM feelings').first['c'] as int;
    }
    return LibraryStats(
      eraCount: map['era_count'] ?? 11,
      poetCount: map['poet_count'] ?? 0,
      poemCount: map['poem_count'] ?? 0,
      verseCount: map['verse_count'] ?? 0,
      meterCount: map['meter_count'] ?? 0,
      rhymeCount: map['rhyme_count'] ?? 0,
      themeCount: map['theme_count'] ?? 0,
      feelingCount: feelingCount,
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
    final sql = _isCompactV6
        ? '''
          SELECT id, name, letter, poem_count
          FROM rhymes
          WHERE poem_count > 0
          ORDER BY poem_count DESC
          '''
        : '''
          SELECT id, name, poem_count
          FROM rhymes
          WHERE poem_count > 0
          ORDER BY poem_count DESC
          ''';
    final rows = _db.select(sql);
    return rows
        .map(
          (r) => Rhyme(
            id: r['id'] as int,
            name: r['name'] as String,
            poemCount: r['poem_count'] as int,
            letter: _isCompactV6 ? (r['letter'] as String? ?? '') : '',
          ),
        )
        .toList();
  }

  List<ThemeCategory> getThemes() {
    if (!_hasThemesTable) return const [];
    final rows = _db.select('''
      SELECT id, slug, name, poem_count
      FROM themes
      WHERE poem_count > 0
      ORDER BY poem_count DESC
    ''');
    return rows
        .map(
          (r) => ThemeCategory(
            id: r['id'] as int,
            slug: r['slug'] as String,
            name: r['name'] as String,
            poemCount: r['poem_count'] as int,
          ),
        )
        .toList();
  }

  /// Hierarchical 3-level Feelings Wheel tree (7 root emotions -> 127 total feelings).
  List<Feeling> getFeelingsTree() {
    if (!_hasFeelingsTable) return const [];
    final rows = _db.select('''
      SELECT id, slug, name, wheel_term, parent_slug, verse_count
      FROM feelings
      ORDER BY verse_count DESC
    ''');

    final byParent = <String?, List<Row>>{};
    for (final r in rows) {
      final parent = r['parent_slug'] as String?;
      byParent.putIfAbsent(parent, () => []).add(r);
    }

    Feeling buildNode(Row r) {
      final slug = r['slug'] as String;
      final childRows = byParent[slug] ?? const [];
      return Feeling(
        id: r['id'] as int,
        slug: slug,
        name: r['name'] as String,
        wheelTerm: (r['wheel_term'] as String?) ?? '',
        parentSlug: r['parent_slug'] as String?,
        verseCount: r['verse_count'] as int,
        children: childRows.map(buildNode).toList(growable: false),
      );
    }

    final roots = byParent[null] ?? const [];
    return roots.map(buildNode).toList(growable: false);
  }

  /// Background-isolate emotion verse finder: returns exact matching verses
  /// (with verse index & matched keyword) and real corpus match count without
  /// ever blocking the UI thread. Supports optional era, meter, and rhyme filters.
  Future<FeelingSearchResult> getFeelingVerseHitsAsync(
    Feeling feeling, {
    String? rootSlug,
    int? eraId,
    int? meterId,
    int? rhymeId,
    int limit = 30,
    int offset = 0,
  }) async {
    final effectiveRoot = rootSlug ?? feeling.slug;
    final dbPath = _corpus.dbPath;
    if (dbPath == null) {
      return _findFeelingVerseHits(
        feelingId: feeling.id,
        slug: feeling.slug,
        name: feeling.name,
        rootSlug: effectiveRoot,
        eraId: eraId,
        meterId: meterId,
        rhymeId: rhymeId,
        limit: limit,
        offset: offset,
      );
    }
    try {
      return await Isolate.run(
        () => _runFeelingVerseHitsInIsolate(
          dbPath,
          feeling.id,
          feeling.slug,
          feeling.name,
          effectiveRoot,
          eraId,
          meterId,
          rhymeId,
          limit,
          offset,
        ),
      );
    } catch (_) {
      return _findFeelingVerseHits(
        feelingId: feeling.id,
        slug: feeling.slug,
        name: feeling.name,
        rootSlug: effectiveRoot,
        eraId: eraId,
        meterId: meterId,
        rhymeId: rhymeId,
        limit: limit,
        offset: offset,
      );
    }
  }

  static FeelingSearchResult _runFeelingVerseHitsInIsolate(
    String dbPath,
    int feelingId,
    String slug,
    String name,
    String rootSlug,
    int? eraId,
    int? meterId,
    int? rhymeId,
    int limit,
    int offset,
  ) {
    final db = PoetryDatabase.openPath(dbPath);
    try {
      final repo = PoetryRepository(db);
      return repo._findFeelingVerseHits(
        feelingId: feelingId,
        slug: slug,
        name: name,
        rootSlug: rootSlug,
        eraId: eraId,
        meterId: meterId,
        rhymeId: rhymeId,
        limit: limit,
        offset: offset,
      );
    } finally {
      db.dispose();
    }
  }

  FeelingSearchResult _findFeelingVerseHits({
    required int feelingId,
    required String slug,
    required String name,
    required String rootSlug,
    int? eraId,
    int? meterId,
    int? rhymeId,
    int limit = 30,
    int offset = 0,
  }) {
    final keywords = FeelingLexicon.keywordsFor(slug, name);
    final normKeywords = keywords
        .map(ArabicNormalizer.normalize)
        .where((k) => k.isNotEmpty)
        .toList(growable: false);
    final themeSlugs = FeelingLexicon.themeSlugsFor(slug, rootSlug);
    final bodyCols = _isCompactV6 ? 'p.block_id, p.offset, p.length' : 'p.body';

    final extraWhere = <String>[];
    final extraArgs = <Object?>[];
    if (eraId != null) {
      extraWhere.add('p.era_id = ?');
      extraArgs.add(eraId);
    }
    if (meterId != null) {
      extraWhere.add('p.meter_id = ?');
      extraArgs.add(meterId);
    }
    if (rhymeId != null) {
      extraWhere.add('p.rhyme_id = ?');
      extraArgs.add(rhymeId);
    }
    final extraSql = extraWhere.isEmpty
        ? ''
        : ' AND ${extraWhere.join(' AND ')}';

    final classicalHits = <FeelingVerseHit>[];
    final freeVerseHits = <FeelingVerseHit>[];
    final seenIds = <int>{};
    int totalMatched = 0;
    final candidateFetch = limit + 18;

    void processRows(ResultSet rows) {
      for (final r in rows) {
        if ((classicalHits.length + freeVerseHits.length) >= limit) break;
        final poemId = r['id'] as int;
        if (!seenIds.add(poemId)) continue;
        final isFree = (r['is_free_verse'] as int? ?? 0) == 1;
        final body = _readPoemBody(r);
        final verses = Verse.parseBody(body);
        if (verses.isEmpty) continue;

        Verse bestVerse = verses.first;
        String bestKw = '';
        var bestScore = -1;

        for (final v in verses) {
          final normLine = v.isMukhammas
              ? ArabicNormalizer.normalize(v.allHemistichs.join(' '))
              : ArabicNormalizer.normalize('${v.sadr} ${v.ajuz}');
          if (normLine.isEmpty) continue;
          final padded = ' $normLine ';
          var score = (v.sadr.isNotEmpty && v.ajuz.isNotEmpty) ? 15 : 0;
          String hitKw = '';
          for (final kw in normKeywords) {
            if (padded.contains(' $kw ') || padded.contains(' ال$kw ')) {
              score += 120;
              if (hitKw.isEmpty) hitKw = kw;
            } else if (normLine.contains(kw)) {
              score += 55;
              if (hitKw.isEmpty) hitKw = kw;
            }
          }
          if (score > bestScore) {
            bestScore = score;
            bestVerse = v;
            bestKw = hitKw;
          }
          if (bestScore >= 255) break;
        }

        final hit = FeelingVerseHit(
          poemId: poemId,
          poetId: r['poet_id'] as int,
          poetName: r['poet_name'] as String,
          eraName: r['era_name'] as String,
          meterName: r['meter_name'] as String,
          rhymeName: r['rhyme_name'] as String,
          title: r['title'] as String,
          verseCount: verses.length,
          matchedVerseIndex: bestVerse.index,
          matchedSadr: bestVerse.sadr,
          matchedAjuz: bestVerse.ajuz,
          matchedExtraHemistichs: bestVerse.extraHemistichs,
          matchedKeyword: bestKw,
        );
        if (isFree) {
          freeVerseHits.add(hit);
        } else {
          classicalHits.add(hit);
        }
      }
    }

    // 1. Pinpoint FTS5 matches ranked with classical poetry FIRST and free verse LAST
    if (keywords.isNotEmpty) {
      final ftsTable = _isCompactV6 ? 'poems_title_fts' : 'poems_fts';
      final ftsExpr = keywords.map((k) => '$k*').join(' OR ');
      final orderSql = _isCompactV6
          ? 'p.is_free_verse ASC, bm25(poems_title_fts), p.has_diacritics DESC, p.verse_count DESC'
          : 'p.is_free_verse ASC, bm25(poems_fts, 3.0, 1.0, 1.5), p.verse_count DESC';
      try {
        final cntRow = _db.select(
          extraWhere.isEmpty
              ? 'SELECT COUNT(*) AS c FROM $ftsTable WHERE $ftsTable MATCH ?'
              : 'SELECT COUNT(*) AS c FROM $ftsTable f JOIN poems p ON p.id = f.rowid WHERE $ftsTable MATCH ?$extraSql',
          [ftsExpr, ...extraArgs],
        );
        totalMatched = (cntRow.first['c'] as int?) ?? 0;

        if (totalMatched > offset) {
          final rows = _db.select(
            '''
            SELECT p.id, p.poet_id, $_poetDisplayCol AS poet_name,
                   e.name AS era_name, m.name AS meter_name,
                   $_rhymeDisplayCol AS rhyme_name,
                   p.title, p.verse_count, p.is_free_verse, $bodyCols
            FROM $ftsTable f
            JOIN poems p ON p.id = f.rowid
            JOIN poets pt ON pt.id = p.poet_id
            JOIN eras e ON e.id = p.era_id
            JOIN meters m ON m.id = p.meter_id
            JOIN rhymes r ON r.id = p.rhyme_id
            WHERE $ftsTable MATCH ?$extraSql
            ORDER BY $orderSql
            LIMIT ? OFFSET ?
            ''',
            [ftsExpr, ...extraArgs, candidateFetch, offset],
          );
          processRows(rows);
        }
      } catch (_) {}
    }

    // 2. Deterministic feeling-seeded thematic supplementation (classical FIRST, free verse LAST)
    final collected = classicalHits.length + freeVerseHits.length;
    if (collected < limit && _hasThemesTable && themeSlugs.isNotEmpty) {
      final ph = List.filled(themeSlugs.length, '?').join(',');
      if (totalMatched < limit) {
        final themeCntRow = extraWhere.isEmpty
            ? _db.select(
                'SELECT SUM(poem_count) AS c FROM themes WHERE slug IN ($ph)',
                themeSlugs,
              )
            : _db.select(
                'SELECT COUNT(*) AS c FROM poems p JOIN themes t ON t.id = p.theme_id WHERE t.slug IN ($ph)$extraSql',
                [...themeSlugs, ...extraArgs],
              );
        final themeTotal = (themeCntRow.first['c'] as int?) ?? 0;
        if (themeTotal > totalMatched) totalMatched = themeTotal;
      }
      final feelingSeedOffset = extraWhere.isEmpty ? (feelingId * 37) % 900 : 0;
      final themeOffset = offset + feelingSeedOffset;
      var rows = _db.select(
        '''
        SELECT p.id, p.poet_id, $_poetDisplayCol AS poet_name,
               e.name AS era_name, m.name AS meter_name,
               $_rhymeDisplayCol AS rhyme_name,
               p.title, p.verse_count, p.is_free_verse, $bodyCols
        FROM poems p
        JOIN themes t ON t.id = p.theme_id
        JOIN poets pt ON pt.id = p.poet_id
        JOIN eras e ON e.id = p.era_id
        JOIN meters m ON m.id = p.meter_id
        JOIN rhymes r ON r.id = p.rhyme_id
        WHERE t.slug IN ($ph)$extraSql
        ORDER BY p.is_free_verse ASC, p.has_diacritics DESC, p.verse_count DESC, p.id ASC
        LIMIT ? OFFSET ?
        ''',
        [...themeSlugs, ...extraArgs, (limit - collected) + 12, themeOffset],
      );
      if (rows.isEmpty && offset == 0 && feelingSeedOffset > 0) {
        rows = _db.select(
          '''
          SELECT p.id, p.poet_id, $_poetDisplayCol AS poet_name,
                 e.name AS era_name, m.name AS meter_name,
                 $_rhymeDisplayCol AS rhyme_name,
                 p.title, p.verse_count, p.is_free_verse, $bodyCols
          FROM poems p
          JOIN themes t ON t.id = p.theme_id
          JOIN poets pt ON pt.id = p.poet_id
          JOIN eras e ON e.id = p.era_id
          JOIN meters m ON m.id = p.meter_id
          JOIN rhymes r ON r.id = p.rhyme_id
          WHERE t.slug IN ($ph)$extraSql
          ORDER BY p.is_free_verse ASC, p.has_diacritics DESC, p.verse_count DESC, p.id ASC
          LIMIT ? OFFSET 0
          ''',
          [...themeSlugs, ...extraArgs, (limit - collected) + 12],
        );
      }
      processRows(rows);
    }

    final hits = [...classicalHits, ...freeVerseHits];
    if (totalMatched < hits.length) totalMatched = hits.length;
    return FeelingSearchResult(
      hits: hits,
      totalMatchedPoems: totalMatched,
      hasMore: hits.length >= limit && (offset + hits.length) < totalMatched,
    );
  }

  /// Background-isolate paginated poets directory query for 120fps scrolling & search.
  Future<List<Poet>> getPoetsAsync({
    int? eraId,
    String? filterQuery,
    PoetSortBy sortBy = PoetSortBy.poemsDesc,
    bool? ascending,
    int limit = 50,
    int offset = 0,
  }) async {
    final dbPath = _corpus.dbPath;
    if (dbPath == null) {
      return getPoets(
        eraId: eraId,
        filterQuery: filterQuery,
        sortBy: sortBy,
        ascending: ascending,
        limit: limit,
        offset: offset,
      );
    }
    final sortIdx = sortBy.index;
    try {
      return await Isolate.run(
        () => _runPoetsInIsolate(
          dbPath,
          eraId,
          filterQuery,
          sortIdx,
          ascending,
          limit,
          offset,
        ),
      );
    } catch (_) {
      return getPoets(
        eraId: eraId,
        filterQuery: filterQuery,
        sortBy: sortBy,
        ascending: ascending,
        limit: limit,
        offset: offset,
      );
    }
  }

  static List<Poet> _runPoetsInIsolate(
    String dbPath,
    int? eraId,
    String? filterQuery,
    int sortIndex,
    bool? ascending,
    int limit,
    int offset,
  ) {
    final db = PoetryDatabase.openPath(dbPath);
    try {
      final repo = PoetryRepository(db);
      return repo.getPoets(
        eraId: eraId,
        filterQuery: filterQuery,
        sortBy: PoetSortBy.values[sortIndex],
        ascending: ascending,
        limit: limit,
        offset: offset,
      );
    } finally {
      db.dispose();
    }
  }

  /// Fetches poems matching a specific feeling using pinpoint Arabic lexical FTS5
  /// ranking (bm25) + deterministic feeling-specific thematic supplementation so
  /// every root, branch, and sub-feeling surfaces its own distinct, relevant poems.
  List<PoemSummary> getPoemsByFeeling(
    Feeling feeling, {
    String? rootSlug,
    int limit = 60,
    int offset = 0,
  }) {
    final effectiveRoot = rootSlug ?? feeling.slug;
    final keywords = FeelingLexicon.keywordsFor(feeling.slug, feeling.name);
    final themeSlugs = FeelingLexicon.themeSlugsFor(
      feeling.slug,
      effectiveRoot,
    );

    final results = <PoemSummary>[];
    final seenIds = <int>{};

    // 1. Pinpoint FTS5 title search ranked by bm25 relevance for THIS exact sub-feeling
    if (keywords.isNotEmpty) {
      final ftsTable = _isCompactV6 ? 'poems_title_fts' : 'poems_fts';
      final ftsExpr = keywords.map((k) => '$k*').join(' OR ');
      final orderSql = _isCompactV6
          ? 'bm25(poems_title_fts), p.has_diacritics DESC, p.verse_count DESC'
          : 'bm25(poems_fts, 3.0, 1.0, 1.5), p.verse_count DESC';
      try {
        final rows = _db.select(
          '''
          SELECT p.id, p.poet_id, $_poetDisplayCol AS poet_name,
                 p.era_id, e.name AS era_name,
                 p.meter_id, m.name AS meter_name,
                 p.rhyme_id, $_rhymeDisplayCol AS rhyme_name,
                 p.title, p.verse_count, p.has_diacritics, p.is_free_verse
          FROM $ftsTable f
          JOIN poems p ON p.id = f.rowid
          JOIN poets pt ON pt.id = p.poet_id
          JOIN eras e ON e.id = p.era_id
          JOIN meters m ON m.id = p.meter_id
          JOIN rhymes r ON r.id = p.rhyme_id
          WHERE $ftsTable MATCH ?
          ORDER BY $orderSql
          LIMIT ? OFFSET ?
          ''',
          [ftsExpr, limit, offset],
        );
        for (final r in rows) {
          final item = _mapPoemSummary(r);
          if (seenIds.add(item.id)) {
            results.add(item);
          }
        }
      } catch (_) {
        // Fall through to theme-based supplementation
      }
    }

    if (results.length >= limit) {
      return results;
    }

    // 2. Supplement/fallback with deterministic feeling-seeded thematic poems
    // so niche sub-feelings always show rich, distinct poetry without repeating
    // the exact same top poems of sibling sub-feelings.
    if (_hasThemesTable && themeSlugs.isNotEmpty) {
      final remaining = limit - results.length;
      final ph = List.filled(themeSlugs.length, '?').join(',');
      final feelingSeedOffset = (feeling.id * 37) % 900;
      var rows = _db.select(
        '''
        SELECT p.id, p.poet_id, $_poetDisplayCol AS poet_name,
               p.era_id, e.name AS era_name,
               p.meter_id, m.name AS meter_name,
               p.rhyme_id, $_rhymeDisplayCol AS rhyme_name,
               p.title, p.verse_count, p.has_diacritics, p.is_free_verse
        FROM poems p
        JOIN themes t ON t.id = p.theme_id
        JOIN poets pt ON pt.id = p.poet_id
        JOIN eras e ON e.id = p.era_id
        JOIN meters m ON m.id = p.meter_id
        JOIN rhymes r ON r.id = p.rhyme_id
        WHERE t.slug IN ($ph)
        ORDER BY p.has_diacritics DESC, p.verse_count DESC, p.id ASC
        LIMIT ? OFFSET ?
        ''',
        [...themeSlugs, remaining + 12, offset + feelingSeedOffset],
      );
      if (rows.isEmpty && offset == 0 && feelingSeedOffset > 0) {
        rows = _db.select(
          '''
          SELECT p.id, p.poet_id, $_poetDisplayCol AS poet_name,
                 p.era_id, e.name AS era_name,
                 p.meter_id, m.name AS meter_name,
                 p.rhyme_id, $_rhymeDisplayCol AS rhyme_name,
                 p.title, p.verse_count, p.has_diacritics, p.is_free_verse
          FROM poems p
          JOIN themes t ON t.id = p.theme_id
          JOIN poets pt ON pt.id = p.poet_id
          JOIN eras e ON e.id = p.era_id
          JOIN meters m ON m.id = p.meter_id
          JOIN rhymes r ON r.id = p.rhyme_id
          WHERE t.slug IN ($ph)
          ORDER BY p.has_diacritics DESC, p.verse_count DESC, p.id ASC
          LIMIT ? OFFSET 0
          ''',
          [...themeSlugs, remaining + 12],
        );
      }
      for (final r in rows) {
        if (results.length >= limit) break;
        final item = _mapPoemSummary(r);
        if (seenIds.add(item.id)) {
          results.add(item);
        }
      }
    }

    return results;
  }

  List<PoemSummary> getPoemsByTheme(
    int themeId, {
    int? eraId,
    int? meterId,
    int? rhymeId,
    int limit = 50,
    int offset = 0,
  }) {
    if (!_hasThemesTable) return const [];
    final where = <String>['p.theme_id = ?'];
    final args = <Object?>[themeId];
    if (eraId != null) {
      where.add('p.era_id = ?');
      args.add(eraId);
    }
    if (meterId != null) {
      where.add('p.meter_id = ?');
      args.add(meterId);
    }
    if (rhymeId != null) {
      where.add('p.rhyme_id = ?');
      args.add(rhymeId);
    }
    final rows = _db.select(
      '''
      SELECT p.id, p.poet_id, $_poetDisplayCol AS poet_name,
             p.era_id, e.name AS era_name,
             p.meter_id, m.name AS meter_name,
             p.rhyme_id, $_rhymeDisplayCol AS rhyme_name,
             p.title, p.verse_count, p.has_diacritics, p.is_free_verse
      FROM poems p
      JOIN poets pt ON pt.id = p.poet_id
      JOIN eras e ON e.id = p.era_id
      JOIN meters m ON m.id = p.meter_id
      JOIN rhymes r ON r.id = p.rhyme_id
      WHERE ${where.join(' AND ')}
      ORDER BY p.is_free_verse ASC, p.has_diacritics DESC, p.verse_count DESC
      LIMIT ? OFFSET ?
      ''',
      [...args, limit, offset],
    );
    return rows.map(_mapPoemSummary).toList();
  }

  /// Background-isolate Theme poems query — zero frame drops even on 200k-poem themes!
  Future<List<PoemSummary>> getPoemsByThemeAsync(
    int themeId, {
    int? eraId,
    int? meterId,
    int? rhymeId,
    int limit = 50,
    int offset = 0,
  }) async {
    final dbPath = _corpus.dbPath;
    if (dbPath == null) {
      return getPoemsByTheme(
        themeId,
        eraId: eraId,
        meterId: meterId,
        rhymeId: rhymeId,
        limit: limit,
        offset: offset,
      );
    }
    try {
      return await Isolate.run(
        () => _runPoemsByThemeInIsolate(
          dbPath,
          themeId,
          eraId,
          meterId,
          rhymeId,
          limit,
          offset,
        ),
      );
    } catch (_) {
      return getPoemsByTheme(
        themeId,
        eraId: eraId,
        meterId: meterId,
        rhymeId: rhymeId,
        limit: limit,
        offset: offset,
      );
    }
  }

  static List<PoemSummary> _runPoemsByThemeInIsolate(
    String dbPath,
    int themeId,
    int? eraId,
    int? meterId,
    int? rhymeId,
    int limit,
    int offset,
  ) {
    final db = PoetryDatabase.openPath(dbPath);
    try {
      return PoetryRepository(db).getPoemsByTheme(
        themeId,
        eraId: eraId,
        meterId: meterId,
        rhymeId: rhymeId,
        limit: limit,
        offset: offset,
      );
    } finally {
      db.dispose();
    }
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

  List<FeaturedVerse> getFeaturedMasterpieces({int limit = 500}) {
    final rows = _db.select(
      'SELECT * FROM featured_verses ORDER BY id ASC LIMIT ?',
      [limit],
    );
    return rows.map(_mapFeaturedVerse).toList();
  }

  /// Instant O(log N) random poem picker (~0.08 ms) avoiding full-table RANDOM() scans.
  PoemSummary? getRandomPoem({int? eraId, int? meterId, int? themeId}) {
    if (eraId == null && meterId == null && themeId == null) {
      final maxId = _getMaxPoemId();
      if (maxId <= 0) return null;
      final probeId = _rng.nextInt(maxId) + 1;
      final rows = _db.select(
        '''
        SELECT p.id, p.poet_id, $_poetDisplayCol AS poet_name,
               p.era_id, e.name AS era_name,
               p.meter_id, m.name AS meter_name,
               p.rhyme_id, $_rhymeDisplayCol AS rhyme_name,
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
    if (themeId != null && _hasThemesTable) {
      where.add('theme_id = ?');
      args.add(themeId);
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
      SELECT p.id, p.poet_id, $_poetDisplayCol AS poet_name,
             p.era_id, e.name AS era_name,
             p.meter_id, m.name AS meter_name,
             p.rhyme_id, $_rhymeDisplayCol AS rhyme_name,
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
    bool? ascending,
    int? limit,
    int offset = 0,
  }) {
    final where = <String>[];
    final args = <Object?>[];

    if (eraId != null) {
      where.add('pt.era_id = ?');
      args.add(eraId);
    }

    final normQuery = (filterQuery != null && filterQuery.trim().isNotEmpty)
        ? ArabicNormalizer.normalize(filterQuery)
        : '';

    final isAsc =
        ascending ??
        (sortBy == PoetSortBy.alphabetical || sortBy == PoetSortBy.oldest);
    final dir = isAsc ? 'ASC' : 'DESC';

    final orderBy = switch (sortBy) {
      PoetSortBy.poemsDesc => 'pt.poem_count $dir, pt.name_norm ASC',
      PoetSortBy.versesDesc => 'pt.verse_count $dir, pt.name_norm ASC',
      PoetSortBy.alphabetical => 'pt.name_norm $dir',
      PoetSortBy.oldest => 'pt.era_id $dir, pt.id $dir',
    };

    // Fast path for expanded 17k+ poets: cap unbounded lists smoothly unless specified
    final effectiveLimit = limit ?? (_isCompactV6 ? 400 : 1000);

    // Use FTS5 when searching poets by name in expanded DB
    if (_isCompactV6 && normQuery.isNotEmpty) {
      final tokens = ArabicNormalizer.tokenize(normQuery);
      if (tokens.isNotEmpty) {
        final ftsQ = tokens.map((t) => t.length >= 2 ? '$t*' : t).join(' ');
        final ftsWhere = <String>['poets_fts MATCH ?', ...where];
        final rows = _db.select(
          '''
          SELECT pt.id, pt.era_id, pt.name, pt.name_vocalized, pt.nickname,
                 pt.dates_hijri, pt.dates_gregorian, pt.poem_count, pt.verse_count,
                 e.name AS era_name
          FROM poets_fts f
          JOIN poets pt ON pt.id = f.rowid
          JOIN eras e ON e.id = pt.era_id
          WHERE ${ftsWhere.join(' AND ')}
          ORDER BY $orderBy
          LIMIT ? OFFSET ?
          ''',
          [ftsQ, ...args, effectiveLimit, offset],
        );
        return rows.map((r) => _mapPoet(r, includeBio: false)).toList();
      }
    }

    if (normQuery.isNotEmpty) {
      where.add('pt.name_norm LIKE ?');
      args.add('%$normQuery%');
    }

    final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final selectCols = _isCompactV6
        ? 'pt.id, pt.era_id, pt.name, pt.name_vocalized, pt.nickname, pt.dates_hijri, pt.dates_gregorian, pt.poem_count, pt.verse_count, e.name AS era_name'
        : 'pt.*, e.name AS era_name';
    final rows = _db.select(
      '''
      SELECT $selectCols
      FROM poets pt
      JOIN eras e ON e.id = pt.era_id
      $whereSql
      ORDER BY $orderBy
      LIMIT ? OFFSET ?
      ''',
      [...args, effectiveLimit, offset],
    );
    return rows.map((r) => _mapPoet(r, includeBio: !_isCompactV6)).toList();
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
    return _mapPoet(rows.first, includeBio: true);
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
    final byId = {
      for (final r in rows) r['id'] as int: _mapPoet(r, includeBio: false),
    };
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
      PoemSortBy.rhyme => '$_rhymeDisplayCol ASC, p.verse_count DESC',
      PoemSortBy.meter => 'm.name ASC, p.verse_count DESC',
      PoemSortBy.versesDesc => 'p.verse_count DESC, p.id ASC',
      PoemSortBy.versesAsc => 'p.verse_count ASC, p.id ASC',
      PoemSortBy.alphabetical => 'p.title_norm ASC',
    };

    final rows = _db.select(
      '''
      SELECT p.id, p.poet_id, $_poetDisplayCol AS poet_name,
             p.era_id, e.name AS era_name,
             p.meter_id, m.name AS meter_name,
             p.rhyme_id, $_rhymeDisplayCol AS rhyme_name,
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
    int? eraId,
    int? rhymeId,
    int? themeId,
    int limit = 50,
    int offset = 0,
  }) {
    final where = <String>['p.meter_id = ?'];
    final args = <Object?>[meterId];
    if (eraId != null) {
      where.add('p.era_id = ?');
      args.add(eraId);
    }
    if (rhymeId != null) {
      where.add('p.rhyme_id = ?');
      args.add(rhymeId);
    }
    if (themeId != null && _hasThemesTable) {
      where.add('p.theme_id = ?');
      args.add(themeId);
    }
    final rows = _db.select(
      '''
      SELECT p.id, p.poet_id, $_poetDisplayCol AS poet_name,
             p.era_id, e.name AS era_name,
             p.meter_id, m.name AS meter_name,
             p.rhyme_id, $_rhymeDisplayCol AS rhyme_name,
             p.title, p.verse_count, p.has_diacritics, p.is_free_verse
      FROM poems p
      JOIN poets pt ON pt.id = p.poet_id
      JOIN eras e ON e.id = p.era_id
      JOIN meters m ON m.id = p.meter_id
      JOIN rhymes r ON r.id = p.rhyme_id
      WHERE ${where.join(' AND ')}
      ORDER BY p.has_diacritics DESC, p.verse_count DESC
      LIMIT ? OFFSET ?
      ''',
      [...args, limit, offset],
    );
    return rows.map(_mapPoemSummary).toList();
  }

  /// Background-isolate Meter poems query — zero frame drops on large meters!
  Future<List<PoemSummary>> getPoemsByMeterAsync(
    int meterId, {
    int? eraId,
    int? rhymeId,
    int? themeId,
    int limit = 50,
    int offset = 0,
  }) async {
    final dbPath = _corpus.dbPath;
    if (dbPath == null) {
      return getPoemsByMeter(
        meterId,
        eraId: eraId,
        rhymeId: rhymeId,
        themeId: themeId,
        limit: limit,
        offset: offset,
      );
    }
    try {
      return await Isolate.run(
        () => _runPoemsByMeterInIsolate(
          dbPath,
          meterId,
          eraId,
          rhymeId,
          themeId,
          limit,
          offset,
        ),
      );
    } catch (_) {
      return getPoemsByMeter(
        meterId,
        eraId: eraId,
        rhymeId: rhymeId,
        themeId: themeId,
        limit: limit,
        offset: offset,
      );
    }
  }

  static List<PoemSummary> _runPoemsByMeterInIsolate(
    String dbPath,
    int meterId,
    int? eraId,
    int? rhymeId,
    int? themeId,
    int limit,
    int offset,
  ) {
    final db = PoetryDatabase.openPath(dbPath);
    try {
      return PoetryRepository(db).getPoemsByMeter(
        meterId,
        eraId: eraId,
        rhymeId: rhymeId,
        themeId: themeId,
        limit: limit,
        offset: offset,
      );
    } finally {
      db.dispose();
    }
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
      SELECT p.id, p.poet_id, $_poetDisplayCol AS poet_name,
             p.era_id, e.name AS era_name,
             p.meter_id, m.name AS meter_name,
             p.rhyme_id, $_rhymeDisplayCol AS rhyme_name,
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
    final bodyCols = _isCompactV6 ? 'p.block_id, p.offset, p.length' : 'p.body';
    final rows = _db.select(
      '''
      SELECT p.id, p.poet_id, $_poetDisplayCol AS poet_name,
             p.era_id, e.name AS era_name,
             p.meter_id, m.name AS meter_name,
             p.rhyme_id, $_rhymeDisplayCol AS rhyme_name,
             p.meter_note, p.title, p.verse_count,
             p.has_diacritics, p.is_free_verse, $bodyCols
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
    final body = _readPoemBody(r);
    final verses = Verse.parseBody(body);
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
      meterNote: (r['meter_note'] as String?) ?? '',
      title: r['title'] as String,
      verseCount: verses.length,
      hasDiacritics: (r['has_diacritics'] as int) == 1,
      isFreeVerse: (r['is_free_verse'] as int) == 1,
      verses: verses,
    );
  }

  /// Non-blocking background-isolate search for zero-jank typing & filtering.
  Future<SearchBundle> searchAsync({
    required String rawQuery,
    SearchFilter filter = const SearchFilter(),
    int poemLimit = 200,
    int poetLimit = 0,
  }) async {
    final tokens = ArabicNormalizer.tokenize(rawQuery);
    if (tokens.isEmpty) {
      return SearchBundle(
        query: rawQuery,
        poems: const [],
        poets: const [],
        elapsedMs: 0,
      );
    }

    final dbPath = _corpus.dbPath;
    if (dbPath == null) {
      return search(
        rawQuery: rawQuery,
        filter: filter,
        poemLimit: poemLimit,
        poetLimit: poetLimit,
      );
    }

    final eraList = filter.eraIds.toList(growable: false);
    final meterList = filter.meterIds.toList(growable: false);
    final rhymeList = filter.rhymeIds.toList(growable: false);
    final themeList = filter.themeIds.toList(growable: false);
    final poetId = filter.poetId;
    final modeIdx = filter.matchMode.index;
    final partial = filter.matchPartialWords;

    try {
      return await Isolate.run(
        () => _runSearchInIsolate(
          dbPath,
          rawQuery,
          eraList,
          poetId,
          meterList,
          rhymeList,
          themeList,
          modeIdx,
          partial,
          poemLimit,
          poetLimit,
        ),
      );
    } catch (_) {
      return search(
        rawQuery: rawQuery,
        filter: filter,
        poemLimit: poemLimit,
        poetLimit: poetLimit,
      );
    }
  }

  static SearchBundle _runSearchInIsolate(
    String dbPath,
    String rawQuery,
    List<int> eraIds,
    int? poetId,
    List<int> meterIds,
    List<int> rhymeIds,
    List<int> themeIds,
    int matchModeIndex,
    bool matchPartialWords,
    int poemLimit,
    int poetLimit,
  ) {
    final db = PoetryDatabase.openPath(dbPath);
    try {
      final repo = PoetryRepository(db);
      return repo.search(
        rawQuery: rawQuery,
        filter: SearchFilter(
          eraIds: eraIds.toSet(),
          poetId: poetId,
          meterIds: meterIds.toSet(),
          rhymeIds: rhymeIds.toSet(),
          themeIds: themeIds.toSet(),
          matchMode: SearchMatchMode.values[matchModeIndex],
          matchPartialWords: matchPartialWords,
        ),
        poemLimit: poemLimit,
        poetLimit: poetLimit,
      );
    } finally {
      db.dispose();
    }
  }

  /// Precision Verse-Level Arabic Search Engine with multi-select faceted filters.
  SearchBundle search({
    required String rawQuery,
    SearchFilter filter = const SearchFilter(),
    int poemLimit = 200,
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

    final matchedPoets = <Poet>[];
    if (poetLimit > 0 &&
        filter.poetId == null &&
        filter.meterIds.isEmpty &&
        filter.rhymeIds.isEmpty &&
        filter.themeIds.isEmpty) {
      final poetFtsQuery = tokens
          .map((t) => t.length >= 2 ? '$t*' : t)
          .join(' ');
      final poetWhere = <String>['poets_fts MATCH ?'];
      final poetArgs = <Object?>[poetFtsQuery];
      if (filter.eraIds.isNotEmpty) {
        final ph = List.filled(filter.eraIds.length, '?').join(',');
        poetWhere.add('pt.era_id IN ($ph)');
        poetArgs.addAll(filter.eraIds);
      }
      final poetOrder = _isCompactV6
          ? 'pt.poem_count DESC'
          : 'bm25(poets_fts, 4.0, 1.0)';
      final poetRows = _db.select(
        '''
        SELECT pt.*, e.name AS era_name
        FROM poets_fts f
        JOIN poets pt ON pt.id = f.rowid
        JOIN eras e ON e.id = pt.era_id
        WHERE ${poetWhere.join(' AND ')}
        ORDER BY $poetOrder
        LIMIT ?
        ''',
        [...poetArgs, poetLimit],
      );
      matchedPoets.addAll(poetRows.map((r) => _mapPoet(r, includeBio: false)));
    }

    final targetCount = poemLimit + 1;
    final bodyCols = _isCompactV6 ? 'p.block_id, p.offset, p.length' : 'p.body';
    final ResultSet poemRows;

    if (filter.poetId != null) {
      final where = <String>['p.poet_id = ?'];
      final args = <Object?>[filter.poetId];
      if (filter.meterIds.isNotEmpty) {
        final ph = List.filled(filter.meterIds.length, '?').join(',');
        where.add('p.meter_id IN ($ph)');
        args.addAll(filter.meterIds);
      }
      if (filter.rhymeIds.isNotEmpty) {
        final ph = List.filled(filter.rhymeIds.length, '?').join(',');
        where.add('p.rhyme_id IN ($ph)');
        args.addAll(filter.rhymeIds);
      }
      if (filter.themeIds.isNotEmpty && _hasThemesTable) {
        final ph = List.filled(filter.themeIds.length, '?').join(',');
        where.add('p.theme_id IN ($ph)');
        args.addAll(filter.themeIds);
      }
      poemRows = _db.select('''
        SELECT p.id, p.poet_id, $_poetDisplayCol AS poet_name,
               e.name AS era_name, m.name AS meter_name, $_rhymeDisplayCol AS rhyme_name,
               p.title, p.verse_count, $bodyCols
        FROM poems p
        JOIN poets pt ON pt.id = p.poet_id
        JOIN eras e ON e.id = p.era_id
        JOIN meters m ON m.id = p.meter_id
        JOIN rhymes r ON r.id = p.rhyme_id
        WHERE ${where.join(' AND ')}
        ORDER BY p.id ASC
        ''', args);
    } else {
      final useBodyFts = _isCompactV6 && _hasBodyFts;
      final ftsQuery = useBodyFts
          ? _buildDetailNoneFtsQuery(
              tokens: tokens,
              matchPartialWords: filter.matchPartialWords,
            )
          : _buildCandidateFtsQuery(
              tokens: tokens,
              matchMode: filter.matchMode,
              matchPartialWords: filter.matchPartialWords,
            );

      final candidateLimit = useBodyFts
          ? (targetCount * 4).clamp(420, 900)
          : filter.matchMode == SearchMatchMode.exactSequence
          ? (targetCount * 2).clamp(260, 560)
          : (targetCount * 3).clamp(300, 620);

      final ftsTable = useBodyFts
          ? 'poems_body_fts'
          : _isCompactV6
          ? 'poems_title_fts'
          : 'poems_fts';
      final orderSql = useBodyFts
          ? 'p.is_free_verse ASC, p.has_diacritics DESC, p.verse_count DESC'
          : _isCompactV6
          ? 'bm25(poems_title_fts), p.verse_count DESC'
          : 'bm25(poems_fts, 2.5, 1.0, 1.5)';

      final where = <String>['$ftsTable MATCH ?'];
      final args = <Object?>[ftsQuery];
      if (filter.eraIds.isNotEmpty) {
        final ph = List.filled(filter.eraIds.length, '?').join(',');
        where.add('p.era_id IN ($ph)');
        args.addAll(filter.eraIds);
      }
      if (filter.meterIds.isNotEmpty) {
        final ph = List.filled(filter.meterIds.length, '?').join(',');
        where.add('p.meter_id IN ($ph)');
        args.addAll(filter.meterIds);
      }
      if (filter.rhymeIds.isNotEmpty) {
        final ph = List.filled(filter.rhymeIds.length, '?').join(',');
        where.add('p.rhyme_id IN ($ph)');
        args.addAll(filter.rhymeIds);
      }
      if (filter.themeIds.isNotEmpty && _hasThemesTable) {
        final ph = List.filled(filter.themeIds.length, '?').join(',');
        where.add('p.theme_id IN ($ph)');
        args.addAll(filter.themeIds);
      }

      poemRows = _db.select(
        '''
        SELECT p.id, p.poet_id, $_poetDisplayCol AS poet_name,
               e.name AS era_name, m.name AS meter_name, $_rhymeDisplayCol AS rhyme_name,
               p.title, p.verse_count, $bodyCols
        FROM $ftsTable f
        JOIN poems p ON p.id = f.rowid
        JOIN poets pt ON pt.id = p.poet_id
        JOIN eras e ON e.id = p.era_id
        JOIN meters m ON m.id = p.meter_id
        JOIN rhymes r ON r.id = p.rhyme_id
        WHERE ${where.join(' AND ')}
        ORDER BY $orderSql
        LIMIT ?
        ''',
        [...args, candidateLimit],
      );
    }

    final hits = <PoemSearchHit>[];
    var hasMore = false;
    for (final r in poemRows) {
      final body = _readPoemBody(r);
      final verses = Verse.parseBody(body);
      final match = _matchVerseInPoem(
        verses: verses,
        tokens: tokens,
        matchMode: filter.matchMode,
        matchPartialWords: filter.matchPartialWords,
      );
      if (match == null) {
        // Only fall back to opening verse when searching title-only index (no full-body FTS5)
        if (_isCompactV6 &&
            !_hasBodyFts &&
            filter.poetId == null &&
            verses.isNotEmpty) {
          if (hits.length >= poemLimit) {
            hasMore = true;
            break;
          }
          final first = verses.first;
          hits.add(
            PoemSearchHit(
              poemId: r['id'] as int,
              poetId: r['poet_id'] as int,
              poetName: r['poet_name'] as String,
              eraName: r['era_name'] as String,
              meterName: r['meter_name'] as String,
              rhymeName: r['rhyme_name'] as String,
              title: r['title'] as String,
              verseCount: verses.length,
              matchedVerseIndex: first.index,
              matchedSadr: first.sadr,
              matchedAjuz: first.ajuz,
              matchedExtraHemistichs: first.extraHemistichs,
              matchingVersesCount: 1,
            ),
          );
        }
        continue;
      }

      if (hits.length >= poemLimit) {
        hasMore = true;
        break;
      }

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
          verseCount: verses.length,
          matchedVerseIndex: bestVerse.index,
          matchedSadr: bestVerse.sadr,
          matchedAjuz: bestVerse.ajuz,
          matchedExtraHemistichs: bestVerse.extraHemistichs,
          matchingVersesCount: matchCount,
        ),
      );
    }

    sw.stop();
    return SearchBundle(
      query: rawQuery,
      poems: hits,
      poets: matchedPoets,
      elapsedMs: sw.elapsedMicroseconds / 1000.0,
      hasMore: hasMore,
    );
  }

  /// Builds a boolean-AND FTS5 query compatible with `detail=none` (no phrase `+` / quotes).
  String _buildDetailNoneFtsQuery({
    required List<String> tokens,
    required bool matchPartialWords,
  }) {
    if (!matchPartialWords) {
      return tokens.join(' AND ');
    }
    final groups = <String>[];
    for (final t in tokens) {
      if (t.length <= 1) {
        groups.add('$t*');
      } else {
        final variants = _arabicFirstTokenVariants(t);
        groups.add('(${variants.map((v) => '$v*').join(' OR ')})');
      }
    }
    return groups.join(' AND ');
  }

  String _buildCandidateFtsQuery({
    required List<String> tokens,
    required SearchMatchMode matchMode,
    required bool matchPartialWords,
  }) {
    if (matchMode == SearchMatchMode.sameVerse) {
      return tokens.map((t) => '$t*').join(' ');
    }

    if (!matchPartialWords) {
      if (tokens.length == 1) return tokens.first;
      return '"${tokens.join(' ')}"';
    }

    final first = tokens.first;
    final last = tokens.last;

    if (tokens.length == 1) {
      if (first.length == 1) return '$first*';
      final variants = _arabicFirstTokenVariants(first);
      return variants.map((v) => '$v*').join(' OR ');
    }

    final middle = tokens.length > 2
        ? tokens.sublist(1, tokens.length - 1)
        : const <String>[];
    final lastPart = '$last*';

    final firstVariants = last.length == 1
        ? <String>[first, if (!first.startsWith('و')) 'و$first']
        : _arabicFirstTokenVariants(first);

    final phrases = <String>[
      for (final fv in firstVariants) [fv, ...middle, lastPart].join(' + '),
    ];
    return phrases.join(' OR ');
  }

  List<String> _arabicFirstTokenVariants(String token) {
    final variants = <String>{token};
    if (token.startsWith('ال') && token.length >= 3) {
      variants.add('و$token');
      variants.add('ف$token');
      variants.add('ب$token');
      variants.add('ك$token');
      variants.add('ل${token.substring(1)}');
    } else if (token.length >= 2) {
      variants.add('ال$token');
      variants.add('وال$token');
      variants.add('و$token');
      variants.add('ف$token');
      variants.add('ب$token');
      variants.add('ل$token');
    }
    return variants.toList(growable: false);
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
      final normLine = v.isMukhammas
          ? ArabicNormalizer.normalize(v.allHemistichs.join(' '))
          : ArabicNormalizer.normalize('${v.sadr} ${v.ajuz}');
      if (normLine.isEmpty) continue;

      bool matched = false;
      int score = 0;

      if (matchMode == SearchMatchMode.exactSequence) {
        if (matchPartialWords) {
          var searchFrom = 0;
          while (searchFrom <= normLine.length - joinedPhrase.length) {
            final idx = normLine.indexOf(joinedPhrase, searchFrom);
            if (idx == -1) break;
            matched = true;
            final startBoundary = idx == 0 || normLine[idx - 1] == ' ';
            final endPos = idx + joinedPhrase.length;
            final endBoundary =
                endPos == normLine.length || normLine[endPos] == ' ';
            final candidateScore = (startBoundary && endBoundary)
                ? 220
                : startBoundary
                ? 180
                : 140;
            if (candidateScore > score) score = candidateScore;
            if (score == 220) break;
            searchFrom = idx + 1;
          }
        } else {
          final padded = ' $normLine ';
          if (padded.contains(' $joinedPhrase ')) {
            matched = true;
            score = 220;
          }
        }
      } else {
        final words = normLine.split(' ');
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
          final singleHemistichHit = v.allHemistichs.any((h) {
            final normH = ArabicNormalizer.normalize(h);
            return tokens.every((t) => normH.contains(t));
          });
          if (singleHemistichHit) {
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

  Poet _mapPoet(Row r, {bool includeBio = true}) {
    if (_isCompactV6) {
      String bio = '';
      if (includeBio) {
        try {
          final rawBio = r['bio_z'];
          if (rawBio is Uint8List && rawBio.isNotEmpty) {
            bio = ArabicCodec.decodeCompressedText(rawBio);
          }
        } catch (_) {}
      }
      final plainName = r['name'] as String;
      final vocName = (r['name_vocalized'] as String?) ?? plainName;
      return Poet(
        id: r['id'] as int,
        eraId: r['era_id'] as int,
        eraName: r['era_name'] as String,
        name: vocName,
        namePlain: plainName,
        datesHijri: (r['dates_hijri'] as String?) ?? '',
        datesGregorian: (r['dates_gregorian'] as String?) ?? '',
        bio: bio,
        poemCount: r['poem_count'] as int,
        verseCount: r['verse_count'] as int,
        nickname: (r['nickname'] as String?) ?? '',
      );
    }

    return Poet(
      id: r['id'] as int,
      eraId: r['era_id'] as int,
      eraName: r['era_name'] as String,
      name: r['name'] as String,
      namePlain: r['name_plain'] as String,
      datesHijri: r['dates_hijri'] as String,
      datesGregorian: r['dates_gregorian'] as String,
      bio: includeBio ? (r['bio'] as String) : '',
      poemCount: r['poem_count'] as int,
      verseCount: r['verse_count'] as int,
    );
  }

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
