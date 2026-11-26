import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../core/constants/app_constants.dart';

/// Read-only corpus database manager with low-memory streaming extraction.
class PoetryDatabase {
  PoetryDatabase._(this._db, this.dbPath);

  final Database _db;
  final String? dbPath;
  Database get db => _db;

  static Future<PoetryDatabase> openBundled({
    void Function(double progress, String status)? onProgress,
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();

    // Clean up older version DB files if present
    for (final oldName in AppConstants.legacyCorpusDbFileNames) {
      final legacyFile = File(p.join(docsDir.path, oldName));
      if (await legacyFile.exists()) {
        try {
          await legacyFile.delete();
        } catch (_) {}
      }
    }

    final dbPath = p.join(docsDir.path, AppConstants.corpusDbFileName);
    final dbFile = File(dbPath);

    if (!await dbFile.exists() || await dbFile.length() < 1024 * 1024) {
      onProgress?.call(0.10, 'جاري فتح خزانة الدواوين…');
      final byteData = await rootBundle.load(AppConstants.corpusAssetPath);
      final compressedBytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );

      onProgress?.call(0.18, 'جاري استخراج دواوين الشعراء…');
      final tmpPath = '$dbPath.tmp';
      try {
        await _decompressGzipWithProgress(
          compressedBytes,
          tmpPath,
          onFraction: (fraction) {
            final scaled = (0.18 + fraction * 0.74).clamp(0.18, 0.92);
            final status = fraction < 0.35
                ? 'جاري استخراج دواوين الشعراء…'
                : fraction < 0.72
                ? 'جاري فهرسة الأبيات والبحور والقوافي…'
                : 'جاري تهيئة محرّك البحث الفوري…';
            onProgress?.call(scaled, status);
          },
        );

        onProgress?.call(0.95, 'شارفت المكتبة على الجاهزية…');
        final tmpFile = File(tmpPath);
        if (await dbFile.exists()) {
          await dbFile.delete();
        }
        await tmpFile.rename(dbPath);
      } catch (_) {
        final tmpFile = File(tmpPath);
        if (await tmpFile.exists()) {
          try {
            await tmpFile.delete();
          } catch (_) {}
        }
        rethrow;
      }
    }

    onProgress?.call(0.98, 'أهلاً بك في «بيت القصيد»…');
    return openPath(dbPath);
  }

  /// Opens an already-extracted corpus database (also used directly in unit tests).
  static PoetryDatabase openPath(String path) {
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    db.execute('PRAGMA query_only = ON;');
    db.execute('PRAGMA cache_size = -24000;');
    db.execute('PRAGMA temp_store = MEMORY;');
    db.execute('PRAGMA mmap_size = 134217728;');
    return PoetryDatabase._(db, path);
  }

  static Future<void> _decompressGzipWithProgress(
    Uint8List gzBytes,
    String outputPath, {
    required void Function(double fraction) onFraction,
  }) async {
    final receivePort = ReceivePort();
    final completer = Completer<void>();

    final sub = receivePort.listen((message) {
      if (message is double) {
        onFraction(message);
      } else if (message == 'done') {
        if (!completer.isCompleted) completer.complete();
      } else if (message is List && message.isNotEmpty && message[0] == 'err') {
        if (!completer.isCompleted) {
          completer.completeError(
            StateError(
              message.length > 1 ? '${message[1]}' : 'Extraction error',
            ),
          );
        }
      }
    });

    try {
      await Isolate.spawn<_DecompressJob>(
        _decompressIsolateEntry,
        _DecompressJob(
          sendPort: receivePort.sendPort,
          gzBytes: gzBytes,
          outputPath: outputPath,
        ),
      );
      await completer.future;
    } finally {
      await sub.cancel();
      receivePort.close();
    }
  }

  static Future<void> _decompressIsolateEntry(_DecompressJob job) async {
    final outFile = File(job.outputPath);
    if (outFile.existsSync()) {
      outFile.deleteSync();
    }
    final sink = outFile.openWrite();
    try {
      const chunkSize = 256 * 1024;
      final totalBytes = job.gzBytes.length;
      final stream = Stream<List<int>>.fromIterable(
        _chunkBytesWithProgress(
          job.gzBytes,
          chunkSize,
          totalBytes,
          job.sendPort,
        ),
      ).transform(gzip.decoder);
      await sink.addStream(stream);
      await sink.flush();
      await sink.close();
      job.sendPort.send(1.0);
      job.sendPort.send('done');
    } catch (e) {
      try {
        await sink.close();
      } catch (_) {}
      job.sendPort.send(['err', e.toString()]);
    }
  }

  static Iterable<List<int>> _chunkBytesWithProgress(
    Uint8List data,
    int chunkSize,
    int totalBytes,
    SendPort sendPort,
  ) sync* {
    var lastReportedPct = -1;
    for (var offset = 0; offset < data.length; offset += chunkSize) {
      final end = (offset + chunkSize < data.length)
          ? offset + chunkSize
          : data.length;
      final pct = totalBytes > 0 ? ((end * 100) ~/ totalBytes) : 100;
      if (pct - lastReportedPct >= 2 || end == data.length) {
        lastReportedPct = pct;
        sendPort.send((end / totalBytes).clamp(0.0, 1.0));
      }
      yield Uint8List.sublistView(data, offset, end);
    }
  }

  void dispose() {
    _db.dispose();
  }
}

class _DecompressJob {
  const _DecompressJob({
    required this.sendPort,
    required this.gzBytes,
    required this.outputPath,
  });

  final SendPort sendPort;
  final Uint8List gzBytes;
  final String outputPath;
}
