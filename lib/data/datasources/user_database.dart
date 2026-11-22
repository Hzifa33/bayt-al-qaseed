import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../core/constants/app_constants.dart';

/// Separate writable SQLite database for user data (favorites, reading history,
/// saved verses, and custom collections) so corpus upgrades never overwrite user data.
class UserDatabase {
  UserDatabase._(this._db);

  final Database _db;
  Database get db => _db;

  static Future<UserDatabase> openDefault() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, AppConstants.userDbFileName);
    return openPath(dbPath);
  }

  static UserDatabase openPath(String path) {
    final db = sqlite3.open(path);
    _initSchema(db);
    return UserDatabase._(db);
  }

  static UserDatabase openInMemory() {
    final db = sqlite3.openInMemory();
    _initSchema(db);
    return UserDatabase._(db);
  }

  static void _initSchema(Database db) {
    db.execute('PRAGMA foreign_keys = ON;');
    db.execute('PRAGMA journal_mode = WAL;');
    db.execute('''
      CREATE TABLE IF NOT EXISTS favorite_poems (
        poem_id INTEGER PRIMARY KEY,
        created_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS favorite_poets (
        poet_id INTEGER PRIMARY KEY,
        created_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS favorite_verses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        poem_id INTEGER NOT NULL,
        poet_id INTEGER NOT NULL,
        verse_index INTEGER NOT NULL,
        sadr TEXT NOT NULL,
        ajuz TEXT NOT NULL,
        poet_name TEXT NOT NULL,
        poem_title TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        UNIQUE(poem_id, verse_index)
      );

      CREATE TABLE IF NOT EXISTS reading_history (
        poem_id INTEGER PRIMARY KEY,
        poet_id INTEGER NOT NULL,
        poet_name TEXT NOT NULL,
        poem_title TEXT NOT NULL,
        meter_name TEXT NOT NULL,
        verse_count INTEGER NOT NULL,
        last_verse_index INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS collections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        description TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS collection_poems (
        collection_id INTEGER NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
        poem_id INTEGER NOT NULL,
        added_at INTEGER NOT NULL,
        PRIMARY KEY (collection_id, poem_id)
      );

      CREATE INDEX IF NOT EXISTS idx_reading_history_updated
        ON reading_history(updated_at DESC);
      CREATE INDEX IF NOT EXISTS idx_favorite_verses_created
        ON favorite_verses(created_at DESC);
    ''');
  }

  void dispose() {
    _db.dispose();
  }
}
