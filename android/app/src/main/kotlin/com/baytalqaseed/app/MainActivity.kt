package com.baytalqaseed.app

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "com.baytalqaseed.app/media"
    private val corpusChannelName = "com.baytalqaseed.app/corpus"
    private val corpusProgressChannelName = "com.baytalqaseed.app/corpus_progress"

    private lateinit var corpusExtractor: CorpusExtractor

    private val reqExportJson = 4101
    private val reqImportJson = 4102

    private var pendingExportResult: MethodChannel.Result? = null
    private var pendingExportContent: String? = null
    private var pendingImportResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        corpusExtractor = CorpusExtractor(applicationContext)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, corpusProgressChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    corpusExtractor.attachEventSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    corpusExtractor.attachEventSink(null)
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, corpusChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkStorage" -> {
                        val targetDir = call.argument<String>("targetDir")
                        val requiredBytes = (call.argument<Number>("requiredBytes"))?.toLong() ?: 0L
                        if (targetDir == null) {
                            result.error("INVALID_ARGS", "Missing targetDir", null)
                            return@setMethodCallHandler
                        }
                        result.success(corpusExtractor.checkStorage(targetDir, requiredBytes))
                    }

                    "extractCorpus" -> {
                        val assetPath = call.argument<String>("assetPath")
                        val targetPath = call.argument<String>("targetPath")
                        val requiredBytes = (call.argument<Number>("requiredBytes"))?.toLong() ?: 0L
                        if (assetPath == null || targetPath == null) {
                            result.error("INVALID_ARGS", "Missing assetPath or targetPath", null)
                            return@setMethodCallHandler
                        }
                        val started = corpusExtractor.startExtraction(
                            assetPath = assetPath,
                            targetPath = targetPath,
                            requiredBytes = requiredBytes,
                        )
                        result.success(started)
                    }

                    "cancelExtraction" -> {
                        corpusExtractor.cancel()
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveImageToGallery" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val filename = call.argument<String>("filename")
                            ?: "bayt_al_qaseed_${System.currentTimeMillis()}.png"
                        if (bytes == null) {
                            result.error("INVALID_ARGS", "Missing image bytes", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val savedPath = savePngToGallery(bytes, filename)
                            result.success(savedPath)
                        } catch (e: Exception) {
                            result.error("SAVE_ERROR", e.localizedMessage ?: "Failed to save image", null)
                        }
                    }

                    "exportJsonFile" -> {
                        val content = call.argument<String>("content")
                        val filename = call.argument<String>("filename") ?: "bayt_al_qaseed_backup.json"
                        if (content == null) {
                            result.error("INVALID_ARGS", "Missing JSON content", null)
                            return@setMethodCallHandler
                        }
                        pendingExportResult?.error("CANCELLED", "Superseded by new request", null)
                        pendingExportResult = result
                        pendingExportContent = content
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "application/json"
                            putExtra(Intent.EXTRA_TITLE, filename)
                        }
                        @Suppress("DEPRECATION")
                        startActivityForResult(intent, reqExportJson)
                    }

                    "importJsonFile" -> {
                        pendingImportResult?.error("CANCELLED", "Superseded by new request", null)
                        pendingImportResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/json", "text/plain", "application/octet-stream"))
                        }
                        @Suppress("DEPRECATION")
                        startActivityForResult(intent, reqImportJson)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Handled for native SAF document picker")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == reqExportJson) {
            val res = pendingExportResult
            val content = pendingExportContent
            pendingExportResult = null
            pendingExportContent = null
            if (res == null) return

            if (resultCode == Activity.RESULT_OK && data?.data != null && content != null) {
                try {
                    contentResolver.openOutputStream(data.data!!)?.use { out ->
                        out.write(content.toByteArray(Charsets.UTF_8))
                        out.flush()
                    } ?: throw IllegalStateException("Could not open file for writing")
                    res.success(true)
                } catch (e: Exception) {
                    res.error("EXPORT_ERROR", e.localizedMessage ?: "Failed to write JSON file", null)
                }
            } else {
                res.success(false)
            }
            return
        }

        if (requestCode == reqImportJson) {
            val res = pendingImportResult
            pendingImportResult = null
            if (res == null) return

            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                try {
                    val jsonText = contentResolver.openInputStream(data.data!!)?.use { input ->
                        input.bufferedReader(Charsets.UTF_8).readText()
                    } ?: throw IllegalStateException("Could not open JSON file")
                    res.success(jsonText)
                } catch (e: Exception) {
                    res.error("IMPORT_ERROR", e.localizedMessage ?: "Failed to read JSON file", null)
                }
            } else {
                res.success(null)
            }
        }
    }

    private fun savePngToGallery(bytes: ByteArray, filename: String): String {
        val resolver = applicationContext.contentResolver
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, filename)
                put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/BaytAlQaseed")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
            val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Could not create MediaStore entry")
            resolver.openOutputStream(uri)?.use { out ->
                out.write(bytes)
                out.flush()
            } ?: throw IllegalStateException("Could not open MediaStore output stream")
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return "Pictures/BaytAlQaseed/$filename"
        } else {
            @Suppress("DEPRECATION")
            val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), "BaytAlQaseed")
            if (!dir.exists()) dir.mkdirs()
            val file = File(dir, filename)
            FileOutputStream(file).use { out ->
                out.write(bytes)
                out.flush()
            }
            MediaScannerConnection.scanFile(
                applicationContext,
                arrayOf(file.absolutePath),
                arrayOf("image/png"),
                null
            )
            return file.absolutePath
        }
    }
}
