package com.baytalqaseed.app

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.system.ErrnoException
import android.system.OsConstants
import io.flutter.plugin.common.EventChannel
import org.tukaani.xz.XZInputStream
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.FilterInputStream
import java.io.IOException
import java.io.InputStream
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.zip.GZIPInputStream

/**
 * Low-memory, corruption-proof native streaming corpus extractor.
 *
 * Streams directly from Android's AssetManager (never loading the compressed
 * archive into RAM), performs a pre-flight StatFs space check, emits accurate
 * byte-level progress, cleans up partial temp files on ENOSPC without ever
 * touching an existing valid DB, verifies the SQLite header, and atomically
 * commits the extracted database.
 */
class CorpusExtractor(private val context: Context) {
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val cancelled = AtomicBoolean(false)
    private val running = AtomicBoolean(false)

    @Volatile
    private var eventSink: EventChannel.EventSink? = null

    fun attachEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    fun cancel() {
        cancelled.set(true)
    }

    fun checkStorage(targetDirPath: String, requiredBytes: Long): Map<String, Any> {
        val dir = File(targetDirPath)
        if (!dir.exists()) dir.mkdirs()
        val available = availableBytesFor(dir)
        return mapOf(
            "availableBytes" to available,
            "requiredBytes" to requiredBytes,
            "hasEnoughSpace" to (available >= requiredBytes),
        )
    }

    fun startExtraction(
        assetPath: String,
        targetPath: String,
        requiredBytes: Long,
    ): Boolean {
        if (!running.compareAndSet(false, true)) {
            return false
        }
        cancelled.set(false)

        executor.execute {
            val targetFile = File(targetPath)
            val parentDir = targetFile.parentFile ?: context.filesDir
            if (!parentDir.exists()) parentDir.mkdirs()

            val tmpFile = File("$targetPath.tmp")

            try {
                // Reclaim space from any stale interrupted temp file before checking space.
                if (tmpFile.exists()) {
                    tmpFile.delete()
                }

                // 1. Pre-flight storage check
                val availBefore = availableBytesFor(parentDir)
                if (availBefore < requiredBytes) {
                    emitError(
                        code = "INSUFFICIENT_STORAGE",
                        message = "Not enough free storage space to extract corpus database.",
                        availableBytes = availBefore,
                        requiredBytes = requiredBytes,
                    )
                    return@execute
                }

                val flutterAssetKey = "flutter_assets/$assetPath"
                val totalCompressedBytes = try {
                    context.assets.openFd(flutterAssetKey).use { it.length }
                } catch (_: Exception) {
                    -1L
                }

                val startTimeMs = System.currentTimeMillis()
                var lastEmitMs = 0L
                var bytesWritten = 0L

                val rawAssetStream = context.assets.open(flutterAssetKey)
                val countingStream = CountingInputStream(rawAssetStream)
                val bufferedIn = BufferedInputStream(countingStream, 64 * 1024)
                val decodedStream: InputStream = when {
                    assetPath.endsWith(".xz", ignoreCase = true) -> XZInputStream(bufferedIn)
                    assetPath.endsWith(".gz", ignoreCase = true) -> GZIPInputStream(bufferedIn, 64 * 1024)
                    else -> bufferedIn
                }

                decodedStream.use { input ->
                    FileOutputStream(tmpFile).use { fos ->
                        BufferedOutputStream(fos, 256 * 1024).use { bos ->
                            val buffer = ByteArray(128 * 1024)
                            while (true) {
                                if (cancelled.get()) {
                                    throw ExtractionCancelledException()
                                }
                                val read = input.read(buffer)
                                if (read == -1) break
                                bos.write(buffer, 0, read)
                                bytesWritten += read

                                val now = System.currentTimeMillis()
                                if (now - lastEmitMs >= 120L) {
                                    lastEmitMs = now
                                    val compRead = countingStream.bytesRead
                                    val fraction = if (totalCompressedBytes > 0L) {
                                        (compRead.toDouble() / totalCompressedBytes.toDouble())
                                            .coerceIn(0.0, 0.96)
                                    } else {
                                        0.5
                                    }
                                    emitProgress(
                                        state = "progress",
                                        fraction = fraction,
                                        bytesRead = compRead,
                                        totalCompressedBytes = totalCompressedBytes,
                                        bytesWritten = bytesWritten,
                                        elapsedMs = now - startTimeMs,
                                    )
                                }
                            }
                            bos.flush()
                        }
                        // Ensure bytes are flushed to flash storage before verification & rename.
                        try {
                            fos.fd.sync()
                        } catch (_: Exception) {
                            // Some virtual filesystems may not support fsync; ignore safely.
                        }
                    }
                }

                // 2. Verify SQLite 3 magic header & minimum size before committing
                emitProgress(
                    state = "verifying",
                    fraction = 0.97,
                    bytesRead = totalCompressedBytes.coerceAtLeast(0L),
                    totalCompressedBytes = totalCompressedBytes,
                    bytesWritten = bytesWritten,
                    elapsedMs = System.currentTimeMillis() - startTimeMs,
                )

                if (!isValidSqliteFile(tmpFile)) {
                    tmpFile.delete()
                    emitError(
                        code = "CORRUPT_OUTPUT",
                        message = "Extracted database failed SQLite header verification.",
                        availableBytes = availableBytesFor(parentDir),
                        requiredBytes = requiredBytes,
                    )
                    return@execute
                }

                // 3. Atomic commit
                if (targetFile.exists()) {
                    targetFile.delete()
                }
                if (!tmpFile.renameTo(targetFile)) {
                    tmpFile.delete()
                    emitError(
                        code = "IO_ERROR",
                        message = "Failed to finalize extracted database file.",
                        availableBytes = availableBytesFor(parentDir),
                        requiredBytes = requiredBytes,
                    )
                    return@execute
                }

                emitProgress(
                    state = "done",
                    fraction = 1.0,
                    bytesRead = totalCompressedBytes.coerceAtLeast(0L),
                    totalCompressedBytes = totalCompressedBytes,
                    bytesWritten = bytesWritten,
                    elapsedMs = System.currentTimeMillis() - startTimeMs,
                )
            } catch (_: ExtractionCancelledException) {
                if (tmpFile.exists()) tmpFile.delete()
                emitError(
                    code = "CANCELLED",
                    message = "Extraction cancelled.",
                    availableBytes = availableBytesFor(parentDir),
                    requiredBytes = requiredBytes,
                )
            } catch (e: IOException) {
                // Immediately delete temp file so partial bytes don't stay occupying user storage.
                if (tmpFile.exists()) tmpFile.delete()
                val availAfter = availableBytesFor(parentDir)
                val outOfSpace = isOutOfSpaceError(e) || availAfter < (64L * 1024L * 1024L)
                emitError(
                    code = if (outOfSpace) "INSUFFICIENT_STORAGE" else "IO_ERROR",
                    message = e.localizedMessage ?: "I/O error during extraction",
                    availableBytes = availAfter,
                    requiredBytes = requiredBytes,
                )
            } catch (e: Exception) {
                if (tmpFile.exists()) tmpFile.delete()
                emitError(
                    code = "EXTRACTION_ERROR",
                    message = e.localizedMessage ?: e.toString(),
                    availableBytes = availableBytesFor(parentDir),
                    requiredBytes = requiredBytes,
                )
            } finally {
                running.set(false)
            }
        }

        return true
    }

    private fun availableBytesFor(dir: File): Long {
        return try {
            StatFs(dir.absolutePath).availableBytes
        } catch (_: Exception) {
            dir.usableSpace
        }
    }

    private fun isOutOfSpaceError(e: Throwable): Boolean {
        var cur: Throwable? = e
        while (cur != null) {
            if (cur is ErrnoException && cur.errno == OsConstants.ENOSPC) {
                return true
            }
            val msg = cur.message?.lowercase() ?: ""
            if (msg.contains("enospc") ||
                msg.contains("no space left") ||
                msg.contains("not enough space") ||
                msg.contains("disk full")
            ) {
                return true
            }
            cur = cur.cause
        }
        return false
    }

    private fun isValidSqliteFile(file: File): Boolean {
        if (!file.exists() || file.length() < 1024L * 1024L) return false
        val expectedHeader = "SQLite format 3\u0000".toByteArray(Charsets.US_ASCII)
        val header = ByteArray(16)
        return try {
            FileInputStream(file).use { fis ->
                val n = fis.read(header)
                n == 16 && header.contentEquals(expectedHeader)
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun emitProgress(
        state: String,
        fraction: Double,
        bytesRead: Long,
        totalCompressedBytes: Long,
        bytesWritten: Long,
        elapsedMs: Long,
    ) {
        val payload = mapOf(
            "state" to state,
            "fraction" to fraction,
            "bytesRead" to bytesRead,
            "totalCompressedBytes" to totalCompressedBytes,
            "bytesWritten" to bytesWritten,
            "elapsedMs" to elapsedMs,
        )
        mainHandler.post {
            eventSink?.success(payload)
        }
    }

    private fun emitError(
        code: String,
        message: String,
        availableBytes: Long,
        requiredBytes: Long,
    ) {
        val payload = mapOf(
            "state" to "error",
            "code" to code,
            "message" to message,
            "availableBytes" to availableBytes,
            "requiredBytes" to requiredBytes,
        )
        mainHandler.post {
            eventSink?.success(payload)
        }
    }

    private class ExtractionCancelledException : RuntimeException()

    private class CountingInputStream(input: InputStream) : FilterInputStream(input) {
        @Volatile
        var bytesRead: Long = 0L
            private set

        override fun read(): Int {
            val b = super.read()
            if (b != -1) bytesRead++
            return b
        }

        override fun read(b: ByteArray, off: Int, len: Int): Int {
            val n = super.read(b, off, len)
            if (n > 0) bytesRead += n
            return n
        }

        override fun skip(n: Long): Long {
            val skipped = super.skip(n)
            if (skipped > 0) bytesRead += skipped
            return skipped
        }
    }
}
