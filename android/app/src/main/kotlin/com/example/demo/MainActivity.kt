package com.example.demo

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.media.MediaCodec
import android.media.MediaFormat
import android.media.MediaMuxer
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.SystemClock
import android.provider.MediaStore
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.tensorflow.lite.Interpreter
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import android.graphics.Canvas
import android.view.WindowManager
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import kotlin.math.max
import kotlin.math.min
import com.arthenica.ffmpegkit.FFmpegKit
import com.arthenica.ffmpegkit.FFprobeKit
import com.arthenica.ffmpegkit.MediaInformationSession
import com.arthenica.ffmpegkit.ReturnCode
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarkerResult
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker.FaceLandmarkerOptions
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import io.flutter.FlutterInjector

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.realvideo/processor"
    private val TAG = "MediaPipeVideo"

    companion object {
        @JvmStatic var uploaderChannel: MethodChannel? = null
    }

    private var processorChannel: MethodChannel? = null
    private var nsfwInterpreter: Interpreter? = null

    // ★ 修復：FloatBuffer 只分配一次，所有幀重用
    private var nsfwInputBuffer: FloatBuffer? = null

    private val NSFW_MODEL_ASSET = "assets/NSFW/nsfw.tflite"
    private val NSFW_INPUT_SIZE = 224

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val procCh = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        processorChannel = procCh
        procCh.setMethodCallHandler { call, result ->
            when (call.method) {
                "processVideo" -> {
                    val inputPath = call.argument<String>("inputPath")
                    if (inputPath == null) {
                        result.error("INVALID_ARGUMENT", "Input path cannot be null", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        processVideo(inputPath, result)
                    }.start()
                }
                "processVideo2D" -> {
                    val inputPath = call.argument<String>("inputPath")
                    val decorationType = call.argument<String>("decorationType") ?: "mask"
                    if (inputPath == null) {
                        result.error("INVALID_ARGUMENT", "Input path cannot be null", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        try {
                            val outPath = processVideo2DRealVideo(inputPath, decorationType)
                            runOnUiThread { result.success(outPath) }
                        } catch (e: Exception) {
                            Log.e(TAG, "processVideo2D error", e)
                            runOnUiThread { result.error("PROCESS_2D_ERROR", e.message, null) }
                        }
                    }.start()
                }
                "checkNsfw" -> {
                    val inputPath = call.argument<String>("inputPath")
                    if (inputPath == null) {
                        result.error("INVALID_ARGUMENT", "Input path cannot be null", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        checkNsfw(inputPath, result)
                    }.start()
                }
                "getVideoInfo" -> {
                    val inputPath = call.argument<String>("inputPath")
                    if (inputPath.isNullOrEmpty()) {
                        result.error("INVALID_ARGUMENT", "inputPath required", null)
                        return@setMethodCallHandler
                    }
                    val sz = getVideoDisplaySize(inputPath)
                    if (sz == null) {
                        result.error("META_ERROR", "Failed to read metadata", null)
                    } else {
                        val isPortrait = sz.second > sz.first
                        val durationMs = getVideoDurationMs(inputPath) ?: 0L
                        result.success(
                            mapOf(
                                "width" to sz.first,
                                "height" to sz.second,
                                "isPortrait" to isPortrait,
                                "duration" to durationMs
                            )
                        )
                    }
                }
                "setScreenBrightness" -> {
                    val b = call.argument<Double>("brightness")
                    if (b == null) {
                        result.error("INVALID_ARGUMENT", "brightness required", null)
                        return@setMethodCallHandler
                    }
                    runOnUiThread {
                        try {
                            val params = window.attributes
                            params.screenBrightness = b.toFloat()
                            window.attributes = params
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("BRIGHTNESS_ERROR", e.message, null)
                        }
                    }
                }
                "setKeepScreenOn" -> {
                    val enabled = call.argument<Boolean>("enabled")
                    if (enabled == null) {
                        result.error("INVALID_ARGUMENT", "enabled required", null)
                        return@setMethodCallHandler
                    }
                    runOnUiThread {
                        try {
                            if (enabled) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("KEEP_SCREEN_ERROR", e.message, null)
                        }
                    }
                }
                "openUrl" -> {
                    val url = call.argument<String>("url")
                    if (url.isNullOrEmpty()) {
                        result.error("INVALID_ARGUMENT", "url required", null)
                        return@setMethodCallHandler
                    }
                    runOnUiThread {
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OPEN_URL_ERROR", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Uploader channel
        val upCh = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.realvideo/uploader"
        )
        uploaderChannel = upCh
        upCh.setMethodCallHandler { call, result ->
            when (call.method) {
                "startBackgroundUpload" -> {
                    val filePath = call.argument<String>("filePath")
                    val presignedUrl = call.argument<String>("presignedUrl")
                    val bucket = call.argument<String>("bucket") ?: ""
                    val objectKey = call.argument<String>("objectKey") ?: ""
                    if (filePath.isNullOrEmpty() || presignedUrl.isNullOrEmpty()) {
                        result.error("INVALID_ARGUMENT", "Missing filePath or presignedUrl", null)
                        return@setMethodCallHandler
                    }
                    val s3Url = "s3://$bucket/$objectKey"
                    val intent = Intent(this, BackgroundUploadService::class.java).apply {
                        putExtra("filePath", filePath)
                        putExtra("presignedUrl", presignedUrl)
                        putExtra("s3Url", s3Url)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "startBackgroundUploadPart" -> {
                    val filePath = call.argument<String>("filePath")
                    val presignedUrl = call.argument<String>("presignedUrl")
                    val offset = call.argument<Int>("offset")?.toLong() ?: -1L
                    val length = call.argument<Int>("length")?.toLong() ?: -1L
                    val uploadId = call.argument<String>("uploadId")
                    val partNumber = call.argument<Int>("partNumber") ?: -1
                    val bucket = call.argument<String>("bucket") ?: ""
                    val objectKey = call.argument<String>("objectKey") ?: ""
                    if (filePath.isNullOrEmpty() || presignedUrl.isNullOrEmpty() ||
                        offset < 0 || length <= 0 || uploadId.isNullOrEmpty() || partNumber <= 0
                    ) {
                        result.error(
                            "INVALID_ARGUMENT",
                            "Missing arguments for part upload",
                            null
                        )
                        return@setMethodCallHandler
                    }
                    val s3Url = "s3://$bucket/$objectKey"
                    val intent = Intent(this, BackgroundUploadService::class.java).apply {
                        putExtra("filePath", filePath)
                        putExtra("presignedUrl", presignedUrl)
                        putExtra("s3Url", s3Url)
                        putExtra("offset", offset)
                        putExtra("length", length)
                        putExtra("uploadId", uploadId)
                        putExtra("partNumber", partNumber)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    // ─────────────────────────────────────────────
    // Video metadata helpers
    // ─────────────────────────────────────────────

    private fun getVideoDisplaySize(path: String): Pair<Int, Int>? {
        return try {
            val retriever = MediaMetadataRetriever()
            retriever.setDataSource(path)
            val w = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
                ?.toIntOrNull() ?: 0
            val h = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
                ?.toIntOrNull() ?: 0
            val rot = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
                ?.toIntOrNull() ?: 0
            retriever.release()
            if (rot == 90 || rot == 270) Pair(h, w) else Pair(w, h)
        } catch (_: Exception) {
            null
        }
    }

    private fun getVideoDurationMs(path: String): Long? {
        return try {
            val retriever = MediaMetadataRetriever()
            retriever.setDataSource(path)
            val durationStr =
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
            retriever.release()
            durationStr?.toLongOrNull()
        } catch (_: Exception) {
            null
        }
    }

    private fun parseFpsString(fps: String?): Double? {
        if (fps == null || fps.isEmpty()) return null
        return try {
            if (fps.contains("/")) {
                val parts = fps.split("/")
                val num = parts[0].toDouble()
                val den = parts.getOrNull(1)?.toDouble() ?: 1.0
                if (den == 0.0) null else num / den
            } else {
                fps.toDouble()
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun probeVideoFps(path: String): Int {
        return try {
            val session: MediaInformationSession = FFprobeKit.getMediaInformation(path)
            val info = session.mediaInformation ?: return 24
            val streams = info.streams
            var fpsStr: String? = null
            streams?.forEach { s ->
                if (s.type == "video") {
                    fpsStr = s.averageFrameRate ?: s.realFrameRate
                }
            }
            val fps = parseFpsString(fpsStr) ?: 24.0
            max(1, Math.round(fps).toInt())
        } catch (_: Exception) {
            24
        }
    }

    private fun probeRotation(path: String): Int {
        return try {
            val retriever = MediaMetadataRetriever()
            retriever.setDataSource(path)
            val rot =
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
                    ?.toIntOrNull() ?: 0
            retriever.release()
            rot
        } catch (_: Exception) {
            0
        }
    }

    // ─────────────────────────────────────────────
    // 2D mask processing
    // ─────────────────────────────────────────────

    private var faceLandmarker: FaceLandmarker? = null

    private fun setupMediaPipeTasks() {
        if (faceLandmarker != null) return
        val modelAssetName = "face_landmarker.task"
        val base = BaseOptions.builder().setModelAssetPath(modelAssetName).build()
        val opts = FaceLandmarkerOptions.builder()
            .setBaseOptions(base)
            .setMinFaceDetectionConfidence(0.15f)
            .setMinFacePresenceConfidence(0.15f)
            .setMinTrackingConfidence(0.15f)
            .setNumFaces(1)
            .setRunningMode(RunningMode.VIDEO)
            .build()
        faceLandmarker = FaceLandmarker.createFromOptions(this, opts)
    }

    private fun processVideo2DRealVideo(inputPath: String, decorationType: String): String {
        setupMediaPipeTasks()
        if (faceLandmarker == null) throw RuntimeException("MediaPipe initialization failed")

        val framesDir = File(getExternalFilesDir(null), "frames")
        if (framesDir.exists()) framesDir.deleteRecursively()
        framesDir.mkdirs()

        val outputFps = 24
        val capFps = 24

        val extractCmd =
            "-y -i \"$inputPath\" -vf \"fps=$capFps\" -q:v 5 \"${framesDir.absolutePath}/frame_%05d.jpg\""

        runOnUiThread {
            try {
                processorChannel?.invokeMethod(
                    "maskProgress", mapOf("progress" to 0.01)
                )
            } catch (_: Exception) {}
        }

        val extractSession = FFmpegKit.execute(extractCmd)
        if (!ReturnCode.isSuccess(extractSession.returnCode)) {
            throw RuntimeException("FFmpeg extract failed")
        }

        runOnUiThread {
            try {
                processorChannel?.invokeMethod(
                    "maskProgress", mapOf("progress" to 0.10)
                )
            } catch (_: Exception) {}
        }

        val frameFiles =
            framesDir.listFiles { _, name -> name.startsWith("frame_") && name.endsWith(".jpg") }
        if (frameFiles == null || frameFiles.isEmpty()) throw RuntimeException("No frames extracted")
        frameFiles.sortBy { it.name }

        val decodeOpts = BitmapFactory.Options().apply {
            inPreferredConfig = Bitmap.Config.ARGB_8888
            inMutable = true
            inSampleSize = 1
        }

        val startMs = SystemClock.elapsedRealtime()
        var totalDecodeMs = 0L
        var totalDetectMs = 0L
        var totalDrawMs = 0L
        var totalSaveMs = 0L

        val targetDetectFps = 8
        val sampleEvery = max(1, Math.round(outputFps.toFloat() / targetDetectFps).toInt())

        val decoration = RealVideoDecorationFactory.get(decorationType)

        var lastResult: FaceLandmarkerResult? = null
        for ((index, file) in frameFiles.withIndex()) {
            val timeMs = (index * (1000f / outputFps)).toLong()

            var resultToUse: FaceLandmarkerResult? = lastResult
            val isDetectionFrame = (index % sampleEvery == 0 || lastResult == null)

            if (!isDetectionFrame && (lastResult == null || lastResult!!.faceLandmarks()
                    .isEmpty())
            ) {
                continue
            }

            val decodeStart = SystemClock.elapsedRealtime()
            val frame = BitmapFactory.decodeFile(file.absolutePath, decodeOpts) ?: continue
            totalDecodeMs += (SystemClock.elapsedRealtime() - decodeStart)

            if (isDetectionFrame) {
                val detectStart = SystemClock.elapsedRealtime()
                val detectMaxWidth = 240
                val detectBitmap = if (frame.width > detectMaxWidth) {
                    val detectW = detectMaxWidth
                    val detectH = max(1, (detectW * (frame.height / frame.width.toFloat())).toInt())
                    Bitmap.createScaledBitmap(frame, detectW, detectH, true)
                } else frame

                val mpImage: MPImage = BitmapImageBuilder(detectBitmap).build()
                val det: FaceLandmarkerResult = faceLandmarker!!.detectForVideo(mpImage, timeMs)
                resultToUse = det
                lastResult = det

                if (detectBitmap !== frame) detectBitmap.recycle()
                totalDetectMs += (SystemClock.elapsedRealtime() - detectStart)
            }

            val lms = resultToUse?.faceLandmarks()?.getOrNull(0)
            if (lms == null) {
                frame.recycle()
                continue
            }

            val drawStart = SystemClock.elapsedRealtime()
            val canvas = Canvas(frame)
            decoration.draw(this, canvas, lms, frame.width, frame.height)
            totalDrawMs += (SystemClock.elapsedRealtime() - drawStart)

            val saveStart = SystemClock.elapsedRealtime()
            file.outputStream().buffered().use { out ->
                frame.compress(Bitmap.CompressFormat.JPEG, 75, out)
            }
            frame.recycle()
            totalSaveMs += (SystemClock.elapsedRealtime() - saveStart)

            if (index % 10 == 0 || index == frameFiles.size - 1) {
                val frac = 0.10f + ((index + 1).toFloat() / frameFiles.size) * 0.80f
                runOnUiThread {
                    try {
                        processorChannel?.invokeMethod(
                            "maskProgress", mapOf("progress" to frac)
                        )
                    } catch (_: Exception) {}
                }
            }
        }

        val loopDoneMs = SystemClock.elapsedRealtime()
        Log.d(
            TAG,
            "2D Loop Done. Total: ${loopDoneMs - startMs}ms, " +
                "Decode: ${totalDecodeMs}ms, Detect: ${totalDetectMs}ms, " +
                "Draw: ${totalDrawMs}ms, Save: ${totalSaveMs}ms"
        )

        val outFile =
            File(getExternalFilesDir(null), "output_${System.currentTimeMillis()}.mp4")
        val stitchCmd =
            "-y -framerate $outputFps -i ${framesDir.absolutePath}/frame_%05d.jpg " +
                "-c:v h264_mediacodec -b:v 6M -pix_fmt yuv420p ${outFile.absolutePath}"

        runOnUiThread {
            try {
                processorChannel?.invokeMethod(
                    "maskProgress", mapOf("progress" to 0.95)
                )
            } catch (_: Exception) {}
        }

        val stitchSession = FFmpegKit.execute(stitchCmd)
        framesDir.deleteRecursively()
        if (!ReturnCode.isSuccess(stitchSession.returnCode)) {
            throw RuntimeException("FFmpeg stitch failed")
        }

        runOnUiThread {
            try {
                processorChannel?.invokeMethod(
                    "maskProgress", mapOf("progress" to 1.0)
                )
            } catch (_: Exception) {}
        }
        return outFile.absolutePath
    }

    private fun drawDecorationFromResult(
        canvas: Canvas,
        result: FaceLandmarkerResult,
        w: Int,
        h: Int,
        type: String
    ) {
        if (result.faceLandmarks().isEmpty()) return
        val lms = result.faceLandmarks()[0]
        val deco = RealVideoDecorationFactory.get(type)
        deco.draw(this, canvas, lms, w, h)
    }

    private fun loadFlutterAssetBitmap(assetPath: String): Bitmap? {
        return try {
            val key =
                FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(assetPath)
            assets.open(key).use { BitmapFactory.decodeStream(it) }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to load asset $assetPath", e)
            null
        }
    }

    // ─────────────────────────────────────────────
    // NSFW — 修復版
    // ─────────────────────────────────────────────

    /**
     * 載入 TFLite 模型。
     * ★ 修復：加入 numThreads = 2 避免與 UI thread 搶資源導致 ANR/閃退。
     */
    private fun setupNsfwInterpreter(): Boolean {
        if (nsfwInterpreter != null) return true
        return try {
            val assetKey = if (NSFW_MODEL_ASSET.startsWith("assets/"))
                FlutterInjector.instance().flutterLoader()
                    .getLookupKeyForAsset(NSFW_MODEL_ASSET)
            else NSFW_MODEL_ASSET

            val bytes = assets.open(assetKey).readBytes()
            val buffer = ByteBuffer.allocateDirect(bytes.size)
                .order(ByteOrder.nativeOrder())
                .also { it.put(bytes); it.rewind() }

            // ★ 限制線程數
            val options = Interpreter.Options().apply { numThreads = 2 }
            nsfwInterpreter = Interpreter(buffer, options)
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load NSFW model", e)
            false
        }
    }

    /**
     * 對單幀評分。
     *
     * 舊版問題：
     *   frame → resized(256) → JPEG encode → decoded(256) → cropped(224) → nested Array tensor
     *   每幀同時存在 4 個 Bitmap + 每幀重新分配巨大 Array，100 幀 × ~10 MB = OOM 閃退。
     *
     * 修復：
     *   - 直接縮放到 224×224，省去 JPEG encode/decode 來回
     *   - FloatBuffer 由 checkNsfw 層級建立並重用，此函數只負責填值
     *   - 用完立即 recycle()
     */
    private fun classifyFrame(frame: Bitmap): Float {
        val interpreter = nsfwInterpreter ?: return 0f

        // ★ 直接縮到 224×224，不做無意義的 JPEG encode → decode
        val scaled = Bitmap.createScaledBitmap(frame, NSFW_INPUT_SIZE, NSFW_INPUT_SIZE, true)

        val pixelCount = NSFW_INPUT_SIZE * NSFW_INPUT_SIZE
        val floatCount = pixelCount * 3

        // ★ 重用 FloatBuffer，避免每幀重新 allocate
        if (nsfwInputBuffer == null || nsfwInputBuffer!!.capacity() < floatCount) {
            nsfwInputBuffer = ByteBuffer
                .allocateDirect(floatCount * 4)
                .order(ByteOrder.nativeOrder())
                .asFloatBuffer()
        }
        val buf = nsfwInputBuffer!!
        buf.rewind()

        val pixels = IntArray(pixelCount)
        scaled.getPixels(pixels, 0, NSFW_INPUT_SIZE, 0, 0, NSFW_INPUT_SIZE, NSFW_INPUT_SIZE)
        scaled.recycle() // ★ 立即釋放，不等 GC

        for (color in pixels) {
            val r = (color shr 16) and 0xFF
            val g = (color shr 8) and 0xFF
            val b = color and 0xFF
            buf.put(b - 104.0f)
            buf.put(g - 117.0f)
            buf.put(r - 123.0f)
        }
        buf.rewind()

        val outputShape = interpreter.getOutputTensor(0).shape()
        val numClasses = outputShape[outputShape.size - 1]
        val output = Array(1) { FloatArray(numClasses) }
        interpreter.run(buf, output)

        return if (numClasses <= 1) output[0][0]
        else output[0][numClasses - 1]
    }

    /**
     * 對整條影片做 NSFW 檢測。
     *
     * 舊版問題：
     *   - 最多採樣 100 幀，每 250ms 一幀，完全不必要
     *   - getFrameAtTime 拿到的是原始解析度（可能 4K），每幀 ~8 MB
     *   - frame 沒有在用完後立即 recycle()
     *
     * 修復：
     *   - 採樣上限降到 20 幀（已足夠判斷內容）
     *   - 改用 getScaledFrameAtTime(480, 480) 直接拿小圖
     *   - 每幀用完立即 recycle()
     *   - 偵測到高概率 NSFW (>0.7) 立即提前結束
     */
    private fun checkNsfw(inputPath: String, result: MethodChannel.Result) {
        try {
            if (!setupNsfwInterpreter()) {
                runOnUiThread {
                    result.error(
                        "NSFW_MODEL_ERROR",
                        "NSFW 模型載入失敗，請確認 nsfw.tflite 已放在 assets/NSFW/ 並隨 app 打包。",
                        null
                    )
                }
                return
            }

            val retriever = MediaMetadataRetriever()
            retriever.setDataSource(inputPath)
            val durationMs = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull() ?: 0L

            // ★ 最多 20 幀，已足夠；原本 100 幀造成 OOM
            val maxFrames = 20
            val framesToSample = minOf(maxFrames, maxOf(1, (durationMs / 1000L).toInt()))

            var maxProb = 0f
            var used = 0

            for (i in 0 until framesToSample) {
                val timeUs =
                    ((i + 0.5f) * (durationMs / framesToSample.toFloat()) * 1000L).toLong()

                // ★ 直接抓縮小版，避免處理原始 4K 大圖
                val frame = try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                        retriever.getScaledFrameAtTime(
                            timeUs,
                            MediaMetadataRetriever.OPTION_CLOSEST_SYNC,
                            480, 480
                        )
                    } else {
                        retriever.getFrameAtTime(
                            timeUs,
                            MediaMetadataRetriever.OPTION_CLOSEST_SYNC
                        )
                    }
                } catch (_: Exception) {
                    retriever.getFrameAtTime(
                        timeUs,
                        MediaMetadataRetriever.OPTION_CLOSEST_SYNC
                    )
                }

                if (frame == null) continue

                val prob = classifyFrame(frame)
                frame.recycle() // ★ 用完立即回收
                if (prob > maxProb) maxProb = prob
                used++

                // ★ 提前結束：高概率 NSFW 不需要繼續採樣
                if (maxProb > 0.7f) break
            }

            retriever.release()

            if (used == 0) {
                runOnUiThread {
                    result.error("NO_VALID_FRAMES", "Failed to decode frames", null)
                }
                return
            }

            Log.d(TAG, "NSFW check: frames=$used maxProb=$maxProb")
            runOnUiThread { result.success(maxProb.toDouble()) }

        } catch (e: Exception) {
            Log.e(TAG, "Error in NSFW check", e)
            runOnUiThread { result.error("NSFW_ERROR", e.message, null) }
        }
    }

    // ─────────────────────────────────────────────
    // processVideo (placeholder)
    // ─────────────────────────────────────────────

    private fun processVideo(inputPath: String, result: MethodChannel.Result) {
        try {
            runOnUiThread { result.success(inputPath) }
        } catch (e: Exception) {
            Log.e(TAG, "Error processing video", e)
            runOnUiThread { result.error("PROCESS_ERROR", e.message, null) }
        }
    }

    // ─────────────────────────────────────────────
    // Save to gallery
    // ─────────────────────────────────────────────

    private fun saveToGallery(videoFile: File): String? {
        val videoFileName = "RealVideo_${System.currentTimeMillis()}.mp4"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Video.Media.DISPLAY_NAME, videoFileName)
                put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
                put(
                    MediaStore.Video.Media.RELATIVE_PATH,
                    Environment.DIRECTORY_MOVIES + "/RealVideo"
                )
            }
            val url =
                contentResolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values)
            if (url != null) {
                try {
                    val out = contentResolver.openOutputStream(url)
                    val input = FileInputStream(videoFile)
                    val buffer = ByteArray(1024)
                    var len: Int
                    while (input.read(buffer).also { len = it } > 0) {
                        out?.write(buffer, 0, len)
                    }
                    input.close()
                    out?.close()
                    return "Saved to Movies/RealVideo"
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to save to gallery", e)
                }
            }
        } else {
            val publicDir = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES),
                "RealVideo"
            )
            if (!publicDir.exists()) publicDir.mkdirs()
            val destFile = File(publicDir, videoFileName)
            try {
                val input = FileInputStream(videoFile)
                val out = FileOutputStream(destFile)
                val buffer = ByteArray(1024)
                var len: Int
                while (input.read(buffer).also { len = it } > 0) {
                    out.write(buffer, 0, len)
                }
                input.close()
                out.close()
                sendBroadcast(
                    Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE).apply {
                        data = Uri.fromFile(destFile)
                    }
                )
                return destFile.absolutePath
            } catch (e: Exception) {
                Log.e(TAG, "Failed to save to gallery", e)
            }
        }
        return null
    }
}