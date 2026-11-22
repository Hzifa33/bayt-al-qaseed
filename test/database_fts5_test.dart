import 'dart:io';

import 'package:bayt_al_qaseed/core/utils/arabic_normalizer.dart';
import 'package:bayt_al_qaseed/data/datasources/poetry_database.dart';
import 'package:bayt_al_qaseed/data/datasources/user_database.dart';
import 'package:bayt_al_qaseed/data/models/poem.dart';
import 'package:bayt_al_qaseed/data/models/search_result.dart';
import 'package:bayt_al_qaseed/data/repositories/poetry_repository.dart';
import 'package:bayt_al_qaseed/data/repositories/user_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tempDir;
  late String corpusPath;
  late PoetryDatabase poetryDb;
  late PoetryRepository poetryRepo;
  late UserDatabase userDb;
  late UserRepository userRepo;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('bayt_al_qaseed_test_');
    corpusPath = '${tempDir.path}/test_corpus.db';

    final rawDb = sqlite3.open(corpusPath);
    rawDb.execute('''
      CREATE TABLE eras (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        display_order INTEGER NOT NULL,
        poet_count INTEGER NOT NULL DEFAULT 0,
        poem_count INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE meters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        poem_count INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE rhymes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        poem_count INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE poets (
        id INTEGER PRIMARY KEY,
        era_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        name_plain TEXT NOT NULL,
        name_norm TEXT NOT NULL,
        dates_hijri TEXT NOT NULL DEFAULT '',
        dates_gregorian TEXT NOT NULL DEFAULT '',
        bio TEXT NOT NULL DEFAULT '',
        poem_count INTEGER NOT NULL DEFAULT 0,
        verse_count INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE poems (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        legacy_poem_key INTEGER NOT NULL,
        poet_id INTEGER NOT NULL,
        era_id INTEGER NOT NULL,
        meter_id INTEGER NOT NULL,
        rhyme_id INTEGER NOT NULL,
        meter_note TEXT NOT NULL DEFAULT '',
        title TEXT NOT NULL,
        title_norm TEXT NOT NULL,
        verse_count INTEGER NOT NULL,
        has_diacritics INTEGER NOT NULL DEFAULT 0,
        is_free_verse INTEGER NOT NULL DEFAULT 0,
        body TEXT NOT NULL
      );
      CREATE TABLE featured_verses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        poem_id INTEGER NOT NULL,
        poet_id INTEGER NOT NULL,
        era_id INTEGER NOT NULL,
        verse_index INTEGER NOT NULL,
        sadr TEXT NOT NULL,
        ajuz TEXT NOT NULL,
        poet_name TEXT NOT NULL,
        era_name TEXT NOT NULL,
        tag TEXT NOT NULL DEFAULT 'من عيون الشعر'
      );
      CREATE VIRTUAL TABLE poems_fts USING fts5(
        title_norm, body_norm, poet_norm,
        content='',
        tokenize='unicode61 remove_diacritics 0'
      );
      CREATE VIRTUAL TABLE poets_fts USING fts5(
        name_norm, bio_norm,
        content='',
        tokenize='unicode61 remove_diacritics 0'
      );
      CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
    ''');

    rawDb.execute("INSERT INTO eras VALUES (5, 'العباسي', 5, 1, 2);");
    rawDb.execute(
      "INSERT INTO meters (id, name, poem_count) VALUES (1, 'الطويل', 1), (2, 'البسيط', 1);",
    );
    rawDb.execute(
      "INSERT INTO rhymes (id, name, poem_count) VALUES (1, 'م', 1), (2, 'ع', 1);",
    );

    final poetNorm = ArabicNormalizer.normalize('أبو الطيب المتنبي');
    rawDb.execute(
      '''
      INSERT INTO poets VALUES
      (4, 5, 'أَبو الطَّيِّب المُتَنَبِّي', 'أبو الطيب المتنبي', ?, '303 - 354 ه', '915 - 965 م', 'أشعر العرب في الحكمة والفخر', 2, 4)
      ''',
      [poetNorm],
    );
    rawDb.execute(
      'INSERT INTO poets_fts (rowid, name_norm, bio_norm) VALUES (?, ?, ?)',
      [4, poetNorm, ArabicNormalizer.normalize('أشعر العرب في الحكمة والفخر')],
    );

    const body1 =
        'عَلى قَدرِ أَهلِ العَزمِ تَأتي العَزائِمُ\tوَتَأتي عَلى قَدرِ الكِرامِ المَكارِمُ\n'
        'وَتَعظُمُ في عَينِ الصَغيرِ صِغارُها\tوَتَصغُرُ في عَينِ العَظيمِ العَظائِمُ';
    const title1 = 'عَلى قَدرِ أَهلِ العَزمِ تَأتي العَزائِمُ';

    const body2 =
        'قَلبي يُحَدِّثُني بِأَنَّكَ مُتلِفي\tروحي فِداكَ عَرَفتَ أَم لَم تَعرِفِ\n'
        'قُل لِلأَحِبَّةِ كَيفَ أَنعَمُ بَعدَكُم\tوَأَنا المُسافِرُ وَالقُلوبُ مَعَ الهَوى';
    const title2 = 'قَلبي يُحَدِّثُني بِأَنَّكَ مُتلِفي';

    rawDb.execute(
      '''
      INSERT INTO poems VALUES
      (1, 1, 4, 5, 1, 1, '', ?, ?, 2, 1, 0, ?),
      (2, 2, 4, 5, 2, 2, '', ?, ?, 2, 1, 0, ?)
      ''',
      [
        title1,
        ArabicNormalizer.normalize(title1),
        body1,
        title2,
        ArabicNormalizer.normalize(title2),
        body2,
      ],
    );

    rawDb.execute(
      'INSERT INTO poems_fts (rowid, title_norm, body_norm, poet_norm) VALUES (?, ?, ?, ?)',
      [
        1,
        ArabicNormalizer.normalize(title1),
        ArabicNormalizer.normalize(body1),
        poetNorm,
      ],
    );
    rawDb.execute(
      'INSERT INTO poems_fts (rowid, title_norm, body_norm, poet_norm) VALUES (?, ?, ?, ?)',
      [
        2,
        ArabicNormalizer.normalize(title2),
        ArabicNormalizer.normalize(body2),
        poetNorm,
      ],
    );

    rawDb.execute('''
      INSERT INTO featured_verses (poem_id, poet_id, era_id, verse_index, sadr, ajuz, poet_name, era_name, tag)
      VALUES (1, 4, 5, 0, 'عَلى قَدرِ أَهلِ العَزمِ تَأتي العَزائِمُ', 'وَتَأتي عَلى قَدرِ الكِرامِ المَكارِمُ', 'أبو الطيب المتنبي', 'العباسي', 'من عيون الحكمة')
      ''');
    rawDb.execute('''
      INSERT INTO metadata VALUES
      ('era_count', '1'), ('poet_count', '1'), ('poem_count', '2'),
      ('verse_count', '4'), ('meter_count', '2'), ('rhyme_count', '2');
    ''');
    rawDb.dispose();

    poetryDb = PoetryDatabase.openPath(corpusPath);
    poetryRepo = PoetryRepository(poetryDb);
    userDb = UserDatabase.openInMemory();
    userRepo = UserRepository(userDb);
  });

  tearDown(() {
    poetryDb.dispose();
    userDb.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('PoetryRepository Precision Verse-Level Search', () {
    test(
      'sameVerse matches words inside the SAME verse regardless of order',
      () {
        final hit = poetryRepo.search(
          rawQuery: 'المكارم العزم',
          filter: const SearchFilter(matchMode: SearchMatchMode.sameVerse),
        );
        expect(hit.poems.length, equals(1));
        expect(hit.poems.first.poemId, equals(1));
        expect(hit.poems.first.matchedVerseIndex, equals(0));
      },
    );

    test(
      'sameVerse rejects words split across DIFFERENT verses of the same poem',
      () {
        // "العزم" is in verse 0, "الصغير" is in verse 1 -> MUST NOT match in sameVerse!
        final miss = poetryRepo.search(
          rawQuery: 'العزم الصغير',
          filter: const SearchFilter(matchMode: SearchMatchMode.sameVerse),
        );
        expect(miss.poems, isEmpty);
      },
    );

    test('exactSequence requires consecutive words in order', () {
      final hit = poetryRepo.search(
        rawQuery: 'على قدر اهل العزم',
        filter: const SearchFilter(matchMode: SearchMatchMode.exactSequence),
      );
      expect(hit.poems.length, equals(1));

      final outOfOrder = poetryRepo.search(
        rawQuery: 'العزم اهل قدر',
        filter: const SearchFilter(matchMode: SearchMatchMode.exactSequence),
      );
      expect(outOfOrder.poems, isEmpty);
    });

    test('partial word toggle allows "قل" to match "قلبي" when enabled vs whole word only when disabled', () {
      final partial = poetryRepo.search(
        rawQuery: 'قل',
        filter: const SearchFilter(
          matchMode: SearchMatchMode.exactSequence,
          matchPartialWords: true,
        ),
      );
      expect(partial.poems.length, equals(1));
      // Both verse 0 ("قَلبي") and verse 1 ("قُل") match when partial is enabled
      expect(partial.poems.first.matchingVersesCount, equals(2));

      final wholeWord = poetryRepo.search(
        rawQuery: 'قل',
        filter: const SearchFilter(
          matchMode: SearchMatchMode.exactSequence,
          matchPartialWords: false,
        ),
      );
      expect(wholeWord.poems.length, equals(1));
      // Only verse 1 ("قُل لِلأَحِبَّةِ") matches when whole-word is enforced!
      expect(wholeWord.poems.first.matchedVerseIndex, equals(1));
      expect(wholeWord.poems.first.matchingVersesCount, equals(1));
    });

    test('supports meter filter and poet search with normalized hamzas', () {
      final filteredOut = poetryRepo.search(
        rawQuery: 'العزم',
        filter: const SearchFilter(meterId: 2),
      );
      expect(filteredOut.poems, isEmpty);

      final poetRes = poetryRepo.search(rawQuery: 'ابو الطيب');
      expect(poetRes.poets.length, equals(1));
      expect(poetRes.poets.first.id, equals(4));
    });

    test('loads poem detail, sorting, and adjacent poems cleanly', () {
      final sorted = poetryRepo.getPoemsForPoet(4, sortBy: PoemSortBy.rhyme);
      expect(sorted.length, equals(2));

      final adj = poetryRepo.getAdjacentPoemIds(4, 1);
      expect(adj.$1, isNull);
      expect(adj.$2, equals(2));
    });
  });

  group('UserRepository (Favorites, Verses, Collections, History)', () {
    test(
      'manages favorite poems, poets, individual verses, and collections',
      () {
        expect(userRepo.toggleFavoritePoem(1), isTrue);
        expect(userRepo.getFavoritePoemIdsSet(), contains(1));
        expect(userRepo.toggleFavoritePoem(1), isFalse);

        expect(userRepo.toggleFavoritePoet(4), isTrue);
        expect(userRepo.getFavoritePoetIdsSet(), contains(4));

        final poem = poetryRepo.getPoemById(1)!;
        userRepo.saveFavoriteVerses(poem: poem, verses: [poem.verses.first]);
        expect(userRepo.getFavoriteVerses().length, equals(1));

        userRepo.recordReading(poem, lastVerseIndex: 1);
        expect(userRepo.getLastReadPoem()?.poemId, equals(1));

        final colId = userRepo.createCollection('عيون الحكمة');
        expect(userRepo.togglePoemInCollection(colId, 1), isTrue);
        expect(userRepo.getCollectionPoemIds(colId), equals([1]));
      },
    );
  });
}
