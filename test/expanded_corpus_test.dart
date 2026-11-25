import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bayt_al_qaseed/core/utils/arabic_codec.dart';
import 'package:bayt_al_qaseed/data/datasources/poetry_database.dart';
import 'package:bayt_al_qaseed/data/repositories/poetry_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

Uint8List _packArabicTest(String text) {
  final out = BytesBuilder(copy: false);
  for (final code in text.runes) {
    if (code < 0x7F) {
      out.addByte(code);
    } else if (code >= 0x0600 && code <= 0x067F) {
      out.addByte(0x80 | (code - 0x0600));
    } else {
      final bytes = utf8.encode(String.fromCharCode(code));
      out.addByte(0x7F);
      out.addByte(bytes.length);
      out.add(bytes);
    }
  }
  return out.toBytes();
}

void main() {
  group('ArabicCodec & Expanded Compact v6 Corpus', () {
    test('round-trips diacritized Arabic, ASCII tabs/newlines, and rare chars', () {
      const sample =
          'قِفا نَبكِ مِن ذِكرى حَبيبٍ وَمَنزِلِ\tبِسِقطِ اللِوى بَينَ الدَخولِ فَحَومَلِ\n'
          'إذا منحَتْك الطَّرْفَ «هندٌ» فإنها\tتَمُنُّ به والمَنحُ ليس بمِنّةِ';
      final packed = _packArabicTest(sample);
      final compressed = Uint8List.fromList(zlib.encode(packed));
      final restored = ArabicCodec.decodeCompressedText(compressed);
      expect(restored, equals(sample));
    });

    test('PoetryRepository seamlessly reads Compact v6 blocks, themes, and feelings', () {
      final tempDir = Directory.systemTemp.createTempSync('bayt_v6_test_');
      final dbPath = '${tempDir.path}/v6_test.db';
      try {
        final raw = sqlite3.open(dbPath);
        raw.execute('''
          CREATE TABLE eras (id INTEGER PRIMARY KEY, slug TEXT, name TEXT, display_order INTEGER, poet_count INTEGER, poem_count INTEGER);
          CREATE TABLE meters (id INTEGER PRIMARY KEY, slug TEXT, name TEXT, poem_count INTEGER);
          CREATE TABLE rhymes (id INTEGER PRIMARY KEY, name TEXT, letter TEXT, poem_count INTEGER);
          CREATE TABLE themes (id INTEGER PRIMARY KEY, slug TEXT, name TEXT, poem_count INTEGER);
          CREATE TABLE feelings (id INTEGER PRIMARY KEY, slug TEXT, name TEXT, wheel_term TEXT, parent_slug TEXT, verse_count INTEGER);
          CREATE TABLE poets (
            id INTEGER PRIMARY KEY, slug TEXT, era_id INTEGER, name TEXT,
            name_vocalized TEXT, name_norm TEXT, nickname TEXT,
            dates_hijri TEXT, dates_gregorian TEXT, has_avatar INTEGER,
            poem_count INTEGER, verse_count INTEGER, bio_z BLOB
          );
          CREATE TABLE content_blocks (id INTEGER PRIMARY KEY, data BLOB NOT NULL);
          CREATE TABLE poems (
            id INTEGER PRIMARY KEY, slug TEXT, poet_id INTEGER, era_id INTEGER,
            meter_id INTEGER, theme_id INTEGER, rhyme_id INTEGER, poem_type_id INTEGER,
            meter_note TEXT, title TEXT, title_norm TEXT, verse_count INTEGER,
            has_diacritics INTEGER, is_free_verse INTEGER,
            block_id INTEGER, offset INTEGER, length INTEGER
          );
          CREATE TABLE featured_verses (
            id INTEGER PRIMARY KEY AUTOINCREMENT, poem_id INTEGER, poet_id INTEGER,
            era_id INTEGER, verse_index INTEGER, verse_count INTEGER,
            sadr TEXT, ajuz TEXT, poet_name TEXT, era_name TEXT,
            category TEXT, tag TEXT
          );
          CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
          CREATE VIRTUAL TABLE poems_title_fts USING fts5(title_norm, content='poems', content_rowid='id');
          CREATE VIRTUAL TABLE poets_fts USING fts5(name_norm, content='poets', content_rowid='id');
        ''');

        raw.execute(
          "INSERT INTO eras VALUES (12, 'muasir', 'المعاصر', 12, 1, 1)",
        );
        raw.execute("INSERT INTO meters VALUES (1, 'alkamil', 'الكامل', 1)");
        raw.execute("INSERT INTO rhymes VALUES (1, 'تاء', 'ت', 1)");
        raw.execute("INSERT INTO themes VALUES (2, 'alnasib', 'النسيب', 1)");
        raw.execute(
          "INSERT INTO feelings VALUES (1, 'alsurur', 'السرور', 'Happy', NULL, 86418)",
        );
        raw.execute(
          "INSERT INTO feelings VALUES (2, 'almarah', 'المرح', 'Playful', 'alsurur', 8355)",
        );

        final bioBlob = Uint8List.fromList(
          zlib.encode(_packArabicTest('شاعرة أردنية معاصرة')),
        );
        raw.execute(
          "INSERT INTO poets VALUES (1, 'ZUqh', 12, 'مارية الرفاعي', 'مارية الرفاعي', 'ماريه الرفاعي', '', '', '', 0, 1, 2, ?)",
          [bioBlob],
        );

        const body =
            'إذا منحَتْك الطَّرْفَ هندٌ فإنها\tتَمُنُّ به والمَنحُ ليس بمِنّةِ\nفَإِنَّ الهَوى شَوقٌ وَسُرورٌ\tيُضِيءُ الدُّجى في كُلِّ لَيلَةٍ';
        final packed = _packArabicTest(body);
        final blockBlob = Uint8List.fromList(zlib.encode(packed));
        raw.execute('INSERT INTO content_blocks VALUES (1, ?)', [blockBlob]);
        raw.execute(
          "INSERT INTO poems VALUES (1, 'abc', 1, 12, 1, 2, 1, 1, '', 'إذا منحتك الطرف هند', 'اذا منحتك الطرف هند', 2, 1, 0, 1, 0, ?)",
          [packed.length],
        );
        raw.execute(
          "INSERT INTO poems_title_fts(poems_title_fts) VALUES('rebuild')",
        );
        raw.execute("INSERT INTO poets_fts(poets_fts) VALUES('rebuild')");
        raw.execute(
          "INSERT INTO metadata VALUES ('poem_count', '1'), ('poet_count', '1'), ('verse_count', '2'), ('era_count', '1'), ('meter_count', '1'), ('rhyme_count', '1'), ('theme_count', '1')",
        );
        raw.dispose();

        final db = PoetryDatabase.openPath(dbPath);
        final repo = PoetryRepository(db);
        expect(repo.isExpandedCorpus, isTrue);
        expect(repo.hasThemes, isTrue);
        expect(repo.hasFeelings, isTrue);

        final poet = repo.getPoetById(1);
        expect(poet?.bio, equals('شاعرة أردنية معاصرة'));

        final poem = repo.getPoemById(1);
        expect(poem, isNotNull);
        expect(poem!.verses.length, equals(2));
        expect(poem.verses.first.sadr, contains('هندٌ'));

        final themes = repo.getThemes();
        expect(themes.length, equals(1));
        expect(repo.getPoemsByTheme(2).length, equals(1));

        final tree = repo.getFeelingsTree();
        expect(tree.length, equals(1));
        expect(tree.first.children.length, equals(1));
        expect(repo.getPoemsByFeeling(tree.first).isNotEmpty, isTrue);

        final searchRes = repo.search(rawQuery: 'منحتك');
        expect(searchRes.poems.length, equals(1));
        db.dispose();
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
