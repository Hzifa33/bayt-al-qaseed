import 'package:sqlite3/sqlite3.dart';

import '../datasources/user_database.dart';
import '../models/poem.dart';
import '../models/user_collection.dart';
import '../models/verse.dart';

class UserRepository {
  UserRepository(this._userDb);

  final UserDatabase _userDb;
  Database get _db => _userDb.db;

  // --- Favorite Poems ---
  Set<int> getFavoritePoemIdsSet() {
    final rows = _db.select('SELECT poem_id FROM favorite_poems');
    return {for (final r in rows) r['poem_id'] as int};
  }

  List<int> getFavoritePoemIdsOrdered() {
    final rows = _db.select(
      'SELECT poem_id FROM favorite_poems ORDER BY created_at DESC',
    );
    return [for (final r in rows) r['poem_id'] as int];
  }

  bool toggleFavoritePoem(int poemId) {
    final existing = _db.select(
      'SELECT 1 FROM favorite_poems WHERE poem_id = ?',
      [poemId],
    );
    if (existing.isNotEmpty) {
      _db.execute('DELETE FROM favorite_poems WHERE poem_id = ?', [poemId]);
      return false;
    }
    _db.execute(
      'INSERT OR REPLACE INTO favorite_poems (poem_id, created_at) VALUES (?, ?)',
      [poemId, DateTime.now().millisecondsSinceEpoch],
    );
    return true;
  }

  // --- Favorite Poets ---
  Set<int> getFavoritePoetIdsSet() {
    final rows = _db.select('SELECT poet_id FROM favorite_poets');
    return {for (final r in rows) r['poet_id'] as int};
  }

  List<int> getFavoritePoetIdsOrdered() {
    final rows = _db.select(
      'SELECT poet_id FROM favorite_poets ORDER BY created_at DESC',
    );
    return [for (final r in rows) r['poet_id'] as int];
  }

  bool toggleFavoritePoet(int poetId) {
    final existing = _db.select(
      'SELECT 1 FROM favorite_poets WHERE poet_id = ?',
      [poetId],
    );
    if (existing.isNotEmpty) {
      _db.execute('DELETE FROM favorite_poets WHERE poet_id = ?', [poetId]);
      return false;
    }
    _db.execute(
      'INSERT OR REPLACE INTO favorite_poets (poet_id, created_at) VALUES (?, ?)',
      [poetId, DateTime.now().millisecondsSinceEpoch],
    );
    return true;
  }

  // --- Favorite Individual Verses ---
  List<FavoriteVerseItem> getFavoriteVerses() {
    final rows = _db.select(
      'SELECT * FROM favorite_verses ORDER BY created_at DESC',
    );
    return rows
        .map(
          (r) => FavoriteVerseItem(
            id: r['id'] as int,
            poemId: r['poem_id'] as int,
            poetId: r['poet_id'] as int,
            verseIndex: r['verse_index'] as int,
            sadr: r['sadr'] as String,
            ajuz: r['ajuz'] as String,
            poetName: r['poet_name'] as String,
            poemTitle: r['poem_title'] as String,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              r['created_at'] as int,
            ),
          ),
        )
        .toList();
  }

  void saveFavoriteVerses({
    required PoemDetail poem,
    required List<Verse> verses,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final stmt = _db.prepare('''
      INSERT OR REPLACE INTO favorite_verses
        (poem_id, poet_id, verse_index, sadr, ajuz, poet_name, poem_title, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''');
    try {
      for (final v in verses) {
        stmt.execute([
          poem.id,
          poem.poetId,
          v.index,
          v.sadr,
          v.ajuz,
          poem.poetName,
          poem.title,
          now,
        ]);
      }
    } finally {
      stmt.dispose();
    }
  }

  void removeFavoriteVerse(int id) {
    _db.execute('DELETE FROM favorite_verses WHERE id = ?', [id]);
  }

  // --- Reading History ---
  void recordReading(PoemDetail poem, {int lastVerseIndex = 0}) {
    _db.execute(
      '''
      INSERT INTO reading_history
        (poem_id, poet_id, poet_name, poem_title, meter_name, verse_count, last_verse_index, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(poem_id) DO UPDATE SET
        last_verse_index = excluded.last_verse_index,
        updated_at = excluded.updated_at
      ''',
      [
        poem.id,
        poem.poetId,
        poem.poetName,
        poem.title,
        poem.meterName,
        poem.verseCount,
        lastVerseIndex,
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  List<ReadingHistoryItem> getReadingHistory({int limit = 40}) {
    final rows = _db.select(
      'SELECT * FROM reading_history ORDER BY updated_at DESC LIMIT ?',
      [limit],
    );
    return rows
        .map(
          (r) => ReadingHistoryItem(
            poemId: r['poem_id'] as int,
            poetId: r['poet_id'] as int,
            poetName: r['poet_name'] as String,
            poemTitle: r['poem_title'] as String,
            meterName: r['meter_name'] as String,
            verseCount: r['verse_count'] as int,
            lastVerseIndex: r['last_verse_index'] as int,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(
              r['updated_at'] as int,
            ),
          ),
        )
        .toList();
  }

  ReadingHistoryItem? getLastReadPoem() {
    final list = getReadingHistory(limit: 1);
    return list.isEmpty ? null : list.first;
  }

  void clearReadingHistory() {
    _db.execute('DELETE FROM reading_history');
  }

  // --- Custom Collections (مجموعات القارئ) ---
  List<UserCollection> getCollections() {
    final rows = _db.select('''
      SELECT c.id, c.name, c.description, c.created_at,
             (SELECT COUNT(*) FROM collection_poems cp WHERE cp.collection_id = c.id) AS poem_count
      FROM collections c
      ORDER BY c.created_at DESC
    ''');
    return rows
        .map(
          (r) => UserCollection(
            id: r['id'] as int,
            name: r['name'] as String,
            description: r['description'] as String,
            poemCount: r['poem_count'] as int,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              r['created_at'] as int,
            ),
          ),
        )
        .toList();
  }

  int createCollection(String name, {String description = ''}) {
    _db.execute(
      'INSERT INTO collections (name, description, created_at) VALUES (?, ?, ?)',
      [name.trim(), description.trim(), DateTime.now().millisecondsSinceEpoch],
    );
    return _db.lastInsertRowId;
  }

  void deleteCollection(int collectionId) {
    _db.execute('DELETE FROM collections WHERE id = ?', [collectionId]);
  }

  List<int> getCollectionPoemIds(int collectionId) {
    final rows = _db.select(
      'SELECT poem_id FROM collection_poems WHERE collection_id = ? ORDER BY added_at DESC',
      [collectionId],
    );
    return [for (final r in rows) r['poem_id'] as int];
  }

  Set<int> getCollectionIdsForPoem(int poemId) {
    final rows = _db.select(
      'SELECT collection_id FROM collection_poems WHERE poem_id = ?',
      [poemId],
    );
    return {for (final r in rows) r['collection_id'] as int};
  }

  bool togglePoemInCollection(int collectionId, int poemId) {
    final existing = _db.select(
      'SELECT 1 FROM collection_poems WHERE collection_id = ? AND poem_id = ?',
      [collectionId, poemId],
    );
    if (existing.isNotEmpty) {
      _db.execute(
        'DELETE FROM collection_poems WHERE collection_id = ? AND poem_id = ?',
        [collectionId, poemId],
      );
      return false;
    }
    _db.execute(
      'INSERT OR REPLACE INTO collection_poems (collection_id, poem_id, added_at) VALUES (?, ?, ?)',
      [collectionId, poemId, DateTime.now().millisecondsSinceEpoch],
    );
    return true;
  }

  // --- Full Backup Export & Restore (تصدير واستيراد المفضلات والسجل والمجموعات) ---
  Map<String, dynamic> exportAllUserData() {
    final favPoems = _db
        .select(
          'SELECT poem_id, created_at FROM favorite_poems ORDER BY created_at ASC',
        )
        .map((r) => {'poem_id': r['poem_id'], 'created_at': r['created_at']})
        .toList();

    final favPoets = _db
        .select(
          'SELECT poet_id, created_at FROM favorite_poets ORDER BY created_at ASC',
        )
        .map((r) => {'poet_id': r['poet_id'], 'created_at': r['created_at']})
        .toList();

    final favVerses = _db
        .select(
          'SELECT poem_id, poet_id, verse_index, sadr, ajuz, poet_name, poem_title, created_at FROM favorite_verses ORDER BY created_at ASC',
        )
        .map(
          (r) => {
            'poem_id': r['poem_id'],
            'poet_id': r['poet_id'],
            'verse_index': r['verse_index'],
            'sadr': r['sadr'],
            'ajuz': r['ajuz'],
            'poet_name': r['poet_name'],
            'poem_title': r['poem_title'],
            'created_at': r['created_at'],
          },
        )
        .toList();

    final colRows = _db.select(
      'SELECT id, name, description, created_at FROM collections ORDER BY created_at ASC',
    );
    final collections = <Map<String, dynamic>>[];
    for (final c in colRows) {
      final cid = c['id'] as int;
      final cpRows = _db.select(
        'SELECT poem_id, added_at FROM collection_poems WHERE collection_id = ? ORDER BY added_at ASC',
        [cid],
      );
      collections.add({
        'name': c['name'],
        'description': c['description'],
        'created_at': c['created_at'],
        'poems': cpRows
            .map((p) => {'poem_id': p['poem_id'], 'added_at': p['added_at']})
            .toList(),
      });
    }

    final history = _db
        .select(
          'SELECT poem_id, poet_id, poet_name, poem_title, meter_name, verse_count, last_verse_index, updated_at FROM reading_history ORDER BY updated_at ASC',
        )
        .map(
          (r) => {
            'poem_id': r['poem_id'],
            'poet_id': r['poet_id'],
            'poet_name': r['poet_name'],
            'poem_title': r['poem_title'],
            'meter_name': r['meter_name'],
            'verse_count': r['verse_count'],
            'last_verse_index': r['last_verse_index'],
            'updated_at': r['updated_at'],
          },
        )
        .toList();

    return {
      'favorite_poems': favPoems,
      'favorite_poets': favPoets,
      'favorite_verses': favVerses,
      'collections': collections,
      'reading_history': history,
    };
  }

  int importUserData(Map<String, dynamic> data) {
    var count = 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    _db.execute('BEGIN TRANSACTION');
    try {
      final favPoems = data['favorite_poems'];
      if (favPoems is List) {
        for (final item in favPoems) {
          if (item is Map && item['poem_id'] is int) {
            _db.execute(
              'INSERT OR REPLACE INTO favorite_poems (poem_id, created_at) VALUES (?, ?)',
              [item['poem_id'], (item['created_at'] as int?) ?? now],
            );
            count++;
          } else if (item is int) {
            _db.execute(
              'INSERT OR REPLACE INTO favorite_poems (poem_id, created_at) VALUES (?, ?)',
              [item, now],
            );
            count++;
          }
        }
      }

      final favPoets = data['favorite_poets'];
      if (favPoets is List) {
        for (final item in favPoets) {
          if (item is Map && item['poet_id'] is int) {
            _db.execute(
              'INSERT OR REPLACE INTO favorite_poets (poet_id, created_at) VALUES (?, ?)',
              [item['poet_id'], (item['created_at'] as int?) ?? now],
            );
            count++;
          } else if (item is int) {
            _db.execute(
              'INSERT OR REPLACE INTO favorite_poets (poet_id, created_at) VALUES (?, ?)',
              [item, now],
            );
            count++;
          }
        }
      }

      final favVerses = data['favorite_verses'];
      if (favVerses is List) {
        for (final item in favVerses) {
          if (item is Map && item['poem_id'] is int) {
            _db.execute(
              '''
              INSERT OR REPLACE INTO favorite_verses
                (poem_id, poet_id, verse_index, sadr, ajuz, poet_name, poem_title, created_at)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?)
              ''',
              [
                item['poem_id'],
                (item['poet_id'] as int?) ?? 0,
                (item['verse_index'] as int?) ?? 0,
                (item['sadr'] as String?) ?? '',
                (item['ajuz'] as String?) ?? '',
                (item['poet_name'] as String?) ?? '',
                (item['poem_title'] as String?) ?? '',
                (item['created_at'] as int?) ?? now,
              ],
            );
            count++;
          }
        }
      }

      final collections = data['collections'];
      if (collections is List) {
        for (final col in collections) {
          if (col is Map && col['name'] is String) {
            final name = (col['name'] as String).trim();
            if (name.isEmpty) continue;
            _db.execute(
              'INSERT OR IGNORE INTO collections (name, description, created_at) VALUES (?, ?, ?)',
              [
                name,
                (col['description'] as String?) ?? '',
                (col['created_at'] as int?) ?? now,
              ],
            );
            final row = _db.select(
              'SELECT id FROM collections WHERE name = ? LIMIT 1',
              [name],
            );
            if (row.isNotEmpty) {
              final cid = row.first['id'] as int;
              final poems = col['poems'];
              if (poems is List) {
                for (final p in poems) {
                  if (p is Map && p['poem_id'] is int) {
                    _db.execute(
                      'INSERT OR REPLACE INTO collection_poems (collection_id, poem_id, added_at) VALUES (?, ?, ?)',
                      [cid, p['poem_id'], (p['added_at'] as int?) ?? now],
                    );
                  }
                }
              }
              count++;
            }
          }
        }
      }

      final history = data['reading_history'];
      if (history is List) {
        for (final h in history) {
          if (h is Map && h['poem_id'] is int) {
            _db.execute(
              '''
              INSERT OR REPLACE INTO reading_history
                (poem_id, poet_id, poet_name, poem_title, meter_name, verse_count, last_verse_index, updated_at)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?)
              ''',
              [
                h['poem_id'],
                (h['poet_id'] as int?) ?? 0,
                (h['poet_name'] as String?) ?? '',
                (h['poem_title'] as String?) ?? '',
                (h['meter_name'] as String?) ?? '',
                (h['verse_count'] as int?) ?? 0,
                (h['last_verse_index'] as int?) ?? 0,
                (h['updated_at'] as int?) ?? now,
              ],
            );
          }
        }
      }

      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
    return count;
  }
}
