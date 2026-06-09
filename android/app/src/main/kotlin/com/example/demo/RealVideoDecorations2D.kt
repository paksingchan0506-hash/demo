package com.example.demo

import android.content.Context
import android.graphics.*
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarkerResult
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import io.flutter.FlutterInjector
import kotlin.math.max
import kotlin.math.min

interface RealVideoDecoration2D {
    fun draw(ctx: Context, canvas: Canvas, lms: List<NormalizedLandmark>, w: Int, h: Int)
}

private fun loadAssetBitmap(ctx: Context, assetPath: String): Bitmap? {
    return try {
        val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(assetPath)
        ctx.assets.open(key).use { BitmapFactory.decodeStream(it) }
    } catch (_: Throwable) { null }
}

private fun rectFromIndices(lms: List<NormalizedLandmark>, w: Int, h: Int, idx: IntArray,
                            padXRatio: Float = 0f, padYRatio: Float = 0f): RectF {
    var minX = Float.MAX_VALUE; var maxX = Float.MIN_VALUE
    var minY = Float.MAX_VALUE; var maxY = Float.MIN_VALUE
    for (i in idx) {
        val p = lms[i]
        val x = p.x() * w; val y = p.y() * h
        if (x < minX) minX = x; if (x > maxX) maxX = x
        if (y < minY) minY = y; if (y > maxY) maxY = y
    }
    val padX = (maxX - minX) * padXRatio
    val padY = (maxY - minY) * padYRatio
    return RectF(minX - padX, minY - padY, maxX + padX, maxY + padY)
}

class MaskDecoration2D : RealVideoDecoration2D {
    private val indices = intArrayOf(234, 93, 132, 58, 172, 136, 152, 365, 397, 288, 323, 454, 356, 195, 127)
    private var bmp: Bitmap? = null
    override fun draw(ctx: Context, canvas: Canvas, lms: List<NormalizedLandmark>, w: Int, h: Int) {
        if (bmp == null) bmp = loadAssetBitmap(ctx, "assets/masks/mask_logo.png")
        val rect = rectFromIndices(lms, w, h, indices, 0.10f, 0.05f)
        bmp?.let {
            val src = Rect(0, 0, it.width, it.height)
            canvas.drawBitmap(it, src, rect, null)
        }
    }
}

class UpperFaceDecoration2D : RealVideoDecoration2D {
    private val indices = intArrayOf(10, 338, 297, 332, 284, 251, 389, 356, 454, 168, 234, 127, 162, 21, 54, 103, 67, 109)
    private var bmp: Bitmap? = null
    override fun draw(ctx: Context, canvas: Canvas, lms: List<NormalizedLandmark>, w: Int, h: Int) {
        if (bmp == null) bmp = loadAssetBitmap(ctx, "assets/masks/upper_face_logo.png")
        var minX = Float.MAX_VALUE; var maxX = Float.MIN_VALUE
        var minY = Float.MAX_VALUE; var maxY = Float.MIN_VALUE
        for (i in indices) {
            val p = lms[i]; val x = p.x() * w; val y = p.y() * h
            if (x < minX) minX = x; if (x > maxX) maxX = x
            if (y < minY) minY = y; if (y > maxY) maxY = y
        }
        val cx = (minX + maxX) * 0.5f; val cy = (minY + maxY) * 0.5f
        val width = (maxX - minX) * 1.76f; val height = (maxY - minY) * 1.76f
        val down = height * 0.10f
        val dst = RectF(cx - width * 0.5f, cy - height * 0.5f + down, cx + width * 0.5f, cy + height * 0.5f + down)
        bmp?.let {
            val src = Rect(0, 0, it.width, it.height)
            canvas.drawBitmap(it, src, dst, null)
        }
    }
}

class FullFaceDecoration2D : RealVideoDecoration2D {
    private val indices = intArrayOf(
        10, 338, 297, 332, 284, 251, 389, 356, 454, 323, 361, 288, 397, 365, 379,
        378, 400, 377, 152, 148, 176, 149, 150, 136, 172, 58, 132, 93, 234, 127, 162, 21, 54, 103, 67, 109
    )
    private var bmp: Bitmap? = null
    override fun draw(ctx: Context, canvas: Canvas, lms: List<NormalizedLandmark>, w: Int, h: Int) {
        if (bmp == null) bmp = loadAssetBitmap(ctx, "assets/masks/full_face_logo.png")
        var minX = Float.MAX_VALUE; var maxX = Float.MIN_VALUE
        var minY = Float.MAX_VALUE; var maxY = Float.MIN_VALUE
        for (i in indices) {
            val p = lms[i]; val x = p.x() * w; val y = p.y() * h
            if (x < minX) minX = x; if (x > maxX) maxX = x
            if (y < minY) minY = y; if (y > maxY) maxY = y
        }
        val cx = (minX + maxX) * 0.5f; val cy = (minY + maxY) * 0.5f
        val width = (maxX - minX) * 1.76f; val height = (maxY - minY) * 1.76f
        val up = height * 0.10f
        val dst = RectF(cx - width * 0.5f, cy - height * 0.5f - up, cx + width * 0.5f, cy + height * 0.5f - up)
        bmp?.let {
            val src = Rect(0, 0, it.width, it.height)
            canvas.drawBitmap(it, src, dst, null)
        }
    }
}

object RealVideoDecorationFactory {
    fun get(type: String): RealVideoDecoration2D {
        return when (type.lowercase()) {
            "upper_face" -> UpperFaceDecoration2D()
            "full_face" -> FullFaceDecoration2D()
            else -> MaskDecoration2D()
        }
    }
}
