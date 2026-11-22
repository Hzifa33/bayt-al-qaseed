import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../core/constants/app_constants.dart';

/// Read-only corpus SQLite 3 + FTS5 database manager.
///
/// On first launch, streams decompression of `assets/db/bayt_al_qaseed.db.gz`
/// inside a background isolate with low memory footprint, writing atomically
/// to application documents storage.
class PoetryDatabase {
  PoetryDatabase._(this._db);

  final Database _db;
  Database get db => _db;

  static Future<PoetryDatabase> openBundled({
    void Function(double progress, String status)? onProgress,
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, AppConstants.corpusDbFileName);
    final dbFile = File(dbPath);

    if (!await dbFile.exists() || await dbFile.length() < 1024 * 1024) {
      onProgress?.call(0.10, 'جاري قراءة أرشيف الدواوين…');
      final byteData = await rootBundle.load(AppConstants.corpusAssetPath);
      final compressedBytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );

      onProgress?.call(0.30, 'جاري فك ضغط وفهرسة مليون ومئة ألف بيت…');
      final tmpPath = '$dbPath.tmp';
      await Isolate.run(() => _decompressGzipToFile(compressedBytes, tmpPath));

      onProgress?.call(0.92, 'جاري تهيئة محرك البحث السريع…');
      final tmpFile = File(tmpPath);
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      await tmpFile.rename(dbPath);
    }

    onProgress?.call(0.98, 'فتح مكتبة «بيت القصيد»…');
    return openPath(dbPath);
  }

  /// Opens an already-extracted SQLite corpus database (also used directly in unit tests).
  static PoetryDatabase openPath(String path) {
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    db.execute('PRAGMA cache_size = -16000;'); // 16 MB page cache
    db.execute('PRAGMA temp_store = MEMORY;');
    db.execute('PRAGMA mmap_size = 67108864;'); // 64 MB mmap for instant reads
    return PoetryDatabase._(db);
  }

  static Future<void> _decompressGzipToFile(
    Uint8List gzBytes,
    String outputPath,
  ) async {
    final outFile = File(outputPath);
    if (outFile.existsSync()) {
      outFile.deleteSync();
    }
    final sink = outFile.openWrite();
    try {
      const chunkSize = 256 * 1024;
      final stream = Stream<List<int>>.fromIterable(
        _chunkBytes(gzBytes, chunkSize),
      ).transform(gzip.decoder);
      await sink.addStream(stream);
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  static Iterable<List<int>> _chunkBytes(Uint8List data, int chunkSize) sync* {
    for (var offset = 0; offset < data.length; offset += chunkSize) {
      final end = (offset + chunkSize < data.length)
          ? offset + chunkSize
          : data.length;
      yield Uint8List.sublistView(data, offset, end);
    }
  }

  void dispose() {
    _db.dispose();
  }
}
