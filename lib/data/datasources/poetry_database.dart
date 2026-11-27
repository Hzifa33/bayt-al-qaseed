import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../core/constants/app_constants.dart';

/// Structured live progress emitted while extracting or opening the corpus DB.
class CorpusExtractionProgress {
  const CorpusExtractionProgress({
    required this.fraction,
    required this.status,
    this.isExtracting = false,
    this.bytesWritten = 0,
    this.expectedTotalBytes = 0,
    this.etaSeconds,
  });

  final double fraction;
  final String status;
  final bool isExtracting;
  final int bytesWritten;
  final int expectedTotalBytes;
  final int? etaSeconds;
}

/// Thrown when internal storage does not have enough free space to safely
/// decompress the offline poetry corpus without risking corruption.
class InsufficientStorageException implements Exception {
  const InsufficientStorageException({
    required this.requiredBytes,
    required this.availableBytes,
  });

  final int requiredBytes;
  final int availableBytes;

  int get missingBytes =>
      requiredBytes > availableBytes ? requiredBytes - availableBytes : 0;

  int get requiredMb => (requiredBytes / (1024 * 1024)).ceil();
  int get availableMb => (availableBytes / (1024 * 1024)).floor();
  int get missingMb => (missingBytes / (1024 * 1024)).ceil();

  @override
  String toString() =>
      'InsufficientStorageException(required=${requiredMb}MB, available=${availableMb}MB)';
}

/// Read-only corpus database manager with zero-RAM-spike native streaming
/// extraction on Android, pre-flight storage verification, and atomic commit.
class PoetryDatabase {
  PoetryDatabase._(this._db, this.dbPath);

  static const MethodChannel _corpusChannel = MethodChannel(
    'com.baytalqaseed.app/corpus',
  );
  static const EventChannel _corpusProgressChannel = EventChannel(
    'com.baytalqaseed.app/corpus_progress',
  );

  final Database _db;
  final String? dbPath;
  Database get db => _db;

  /// Checks available internal storage for the corpus directory on Android.
  /// Returns `null` on non-Android platforms.
  static Future<({int availableBytes, int requiredBytes, bool hasEnoughSpace})?>
  checkStorageSpace() async {
    if (!Platform.isAndroid) return null;
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final res = await _corpusChannel.invokeMapMethod<String, dynamic>(
        'checkStorage',
        {
          'targetDir': docsDir.path,
          'requiredBytes': AppConstants.corpusRequiredStorageBytes,
        },
      );
      if (res == null) return null;
      return (
        availableBytes: (res['availableBytes'] as num?)?.toInt() ?? 0,
        requiredBytes:
            (res['requiredBytes'] as num?)?.toInt() ??
            AppConstants.corpusRequiredStorageBytes,
        hasEnoughSpace: (res['hasEnoughSpace'] as bool?) ?? false,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<PoetryDatabase> openBundled({
    void Function(CorpusExtractionProgress progress)? onProgress,
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();

    // 1. Clean up older version DB files and any stale interrupted .tmp files
    //    FIRST so upgrading users immediately reclaim storage before the space check.
    for (final oldName in AppConstants.legacyCorpusDbFileNames) {
      await _deleteIfExists(p.join(docsDir.path, oldName));
      await _deleteIfExists(p.join(docsDir.path, '$oldName.tmp'));
    }

    final dbPath = p.join(docsDir.path, AppConstants.corpusDbFileName);
    await _deleteIfExists('$dbPath.tmp');

    final dbFile = File(dbPath);
    final needsExtraction = !await _isValidExistingDatabase(dbFile);

    if (needsExtraction) {
      if (Platform.isAndroid) {
        await _extractOnAndroid(dbPath: dbPath, onProgress: onProgress);
      } else {
        await _extractGzipFallback(dbPath: dbPath, onProgress: onProgress);
      }
    }

    onProgress?.call(
      const CorpusExtractionProgress(
        fraction: 0.98,
        status: 'جاري التحقّق من سلامة الخزانة وفتحها…',
      ),
    );

    try {
      final opened = openPath(dbPath);
      // Lightweight sanity query (<1 ms) to guarantee schema readability.
      opened.db.select('SELECT COUNT(*) FROM eras');
      onProgress?.call(
        const CorpusExtractionProgress(
          fraction: 1.0,
          status: 'أهلاً بك في «بيت القصيد»…',
        ),
      );
      return opened;
    } catch (_) {
      // If a pre-existing DB file was somehow corrupted on disk, remove it so
      // the next retry cleanly re-extracts from the bundled asset.
      await _deleteIfExists(dbPath);
      rethrow;
    }
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

  static Future<bool> _isValidExistingDatabase(File file) async {
    if (!await file.exists()) return false;
    final len = await file.length();
    if (len < 1024 * 1024) return false;
    try {
      final raf = await file.open();
      try {
        final header = await raf.read(16);
        const expected = 'SQLite format 3\x00';
        if (header.length != 16) return false;
        for (var i = 0; i < 16; i++) {
          if (header[i] != expected.codeUnitAt(i)) return false;
        }
        return true;
      } finally {
        await raf.close();
      }
    } catch (_) {
      return false;
    }
  }

  static Future<void> _deleteIfExists(String filePath) async {
    final f = File(filePath);
    if (await f.exists()) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }

  static Future<void> _extractOnAndroid({
    required String dbPath,
    void Function(CorpusExtractionProgress progress)? onProgress,
  }) async {
    onProgress?.call(
      const CorpusExtractionProgress(
        fraction: 0.04,
        status: 'جاري التحقّق من المساحة التخزينية المتاحة…',
        isExtracting: true,
        expectedTotalBytes: AppConstants.corpusExpectedUncompressedBytes,
      ),
    );

    final completer = Completer<void>();
    late final StreamSubscription<dynamic> sub;

    sub = _corpusProgressChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is! Map) return;
        final state = event['state'] as String? ?? '';

        if (state == 'progress') {
          final rawFraction =
              (event['fraction'] as num?)?.toDouble().clamp(0.0, 0.96) ?? 0.0;
          final bytesWritten = (event['bytesWritten'] as num?)?.toInt() ?? 0;
          final elapsedMs = (event['elapsedMs'] as num?)?.toInt() ?? 0;

          int? etaSeconds;
          if (rawFraction >= 0.03 && rawFraction < 0.96 && elapsedMs >= 1200) {
            final totalEstMs = elapsedMs / rawFraction;
            final remainMs = (totalEstMs - elapsedMs).clamp(0, 600000);
            etaSeconds = (remainMs / 1000).ceil();
          }

          final scaled = (0.05 + rawFraction * 0.90).clamp(0.05, 0.95);
          final status = rawFraction < 0.30
              ? 'جاري فك ضغط دواوين الشعراء…'
              : rawFraction < 0.68
              ? 'جاري استخراج الأبيات والبحور والقوافي…'
              : 'جاري تجهيز فهرس البحث الفوري…';

          onProgress?.call(
            CorpusExtractionProgress(
              fraction: scaled,
              status: status,
              isExtracting: true,
              bytesWritten: bytesWritten,
              expectedTotalBytes: AppConstants.corpusExpectedUncompressedBytes,
              etaSeconds: etaSeconds,
            ),
          );
        } else if (state == 'verifying') {
          final bytesWritten = (event['bytesWritten'] as num?)?.toInt() ?? 0;
          onProgress?.call(
            CorpusExtractionProgress(
              fraction: 0.96,
              status: 'جاري التحقّق من سلامة قاعدة البيانات…',
              isExtracting: true,
              bytesWritten: bytesWritten,
              expectedTotalBytes: bytesWritten > 0
                  ? bytesWritten
                  : AppConstants.corpusExpectedUncompressedBytes,
            ),
          );
        } else if (state == 'done') {
          if (!completer.isCompleted) completer.complete();
        } else if (state == 'error') {
          final code = event['code'] as String? ?? 'EXTRACTION_ERROR';
          final message = event['message'] as String? ?? 'Extraction error';
          final availableBytes =
              (event['availableBytes'] as num?)?.toInt() ?? 0;
          final requiredBytes =
              (event['requiredBytes'] as num?)?.toInt() ??
              AppConstants.corpusRequiredStorageBytes;

          if (!completer.isCompleted) {
            if (code == 'INSUFFICIENT_STORAGE') {
              completer.completeError(
                InsufficientStorageException(
                  requiredBytes: requiredBytes,
                  availableBytes: availableBytes,
                ),
              );
            } else {
              completer.completeError(StateError('$code: $message'));
            }
          }
        }
      },
      onError: (Object err) {
        if (!completer.isCompleted) completer.completeError(err);
      },
    );

    try {
      await _corpusChannel.invokeMethod<bool>('extractCorpus', {
        'assetPath': AppConstants.corpusAssetPath,
        'targetPath': dbPath,
        'requiredBytes': AppConstants.corpusRequiredStorageBytes,
      });
      await completer.future;
    } finally {
      await sub.cancel();
    }
  }

  /// Fallback extractor for non-Android targets (e.g. desktop dev runs).
  static Future<void> _extractGzipFallback({
    required String dbPath,
    void Function(CorpusExtractionProgress progress)? onProgress,
  }) async {
    onProgress?.call(
      const CorpusExtractionProgress(
        fraction: 0.10,
        status: 'جاري فتح خزانة الدواوين…',
        isExtracting: true,
      ),
    );
    final byteData = await rootBundle.load(AppConstants.corpusAssetPath);
    final compressedBytes = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );

    final tmpPath = '$dbPath.tmp';
    try {
      await _decompressGzipWithProgress(
        compressedBytes,
        tmpPath,
        onFraction: (fraction) {
          final scaled = (0.15 + fraction * 0.80).clamp(0.15, 0.95);
          onProgress?.call(
            CorpusExtractionProgress(
              fraction: scaled,
              status: 'جاري استخراج دواوين الشعراء…',
              isExtracting: true,
            ),
          );
        },
      );
      final tmpFile = File(tmpPath);
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      await tmpFile.rename(dbPath);
    } catch (_) {
      await _deleteIfExists(tmpPath);
      rethrow;
    }
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
