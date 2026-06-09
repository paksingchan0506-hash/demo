package com.example.demo

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import kotlin.math.min

interface DecorationDrawer {
    fun draw(canvas: Canvas, box: Rect)
}

class MaskDrawer : DecorationDrawer {
    private val fill = Paint().apply {
        style = Paint.Style.FILL
        color = 0x7F1976D2.toInt()
        isAntiAlias = true
    }
    private val stroke = Paint().apply {
        style = Paint.Style.STROKE
        strokeWidth = 3f
        color = Color.WHITE
        isAntiAlias = true
    }
    override fun draw(canvas: Canvas, box: Rect) {
        val maskTop = box.top + box.height() * 0.55f
        val rectF = android.graphics.RectF(
            (box.left + box.width() * 0.1f),
            maskTop,
            (box.right - box.width() * 0.1f),
            (box.bottom - box.height() * 0.05f)
        )
        val r = min(rectF.width(), rectF.height()) * 0.2f
        canvas.drawRoundRect(rectF, r, r, fill)
        canvas.drawRoundRect(rectF, r, r, stroke)
    }
}

class FullFaceDrawer : DecorationDrawer {
    private val fill = Paint().apply {
        style = Paint.Style.FILL
        color = 0x59AA00FF.toInt()
        isAntiAlias = true
    }
    private val stroke = Paint().apply {
        style = Paint.Style.STROKE
        strokeWidth = 3f
        color = Color.WHITE
        isAntiAlias = true
    }
    override fun draw(canvas: Canvas, box: Rect) {
        val rectF = android.graphics.RectF(box)
        canvas.drawOval(rectF, fill)
        canvas.drawOval(rectF, stroke)
    }
}

class UpperFaceDrawer : DecorationDrawer {
    private val fill = Paint().apply {
        style = Paint.Style.FILL
        color = 0x7F00897B.toInt()
        isAntiAlias = true
    }
    private val stroke = Paint().apply {
        style = Paint.Style.STROKE
        strokeWidth = 3f
        color = Color.WHITE
        isAntiAlias = true
    }
    override fun draw(canvas: Canvas, box: Rect) {
        val eyeHeight = (box.height() * 0.35f)
        val rectF = android.graphics.RectF(
            (box.left - box.width() * 0.1f),
            (box.top + box.height() * 0.15f),
            (box.right + box.width() * 0.1f),
            (box.top + eyeHeight)
        )
        val r = rectF.height() / 2f
        canvas.drawRoundRect(rectF, r, r, fill)
        canvas.drawRoundRect(rectF, r, r, stroke)
    }
}

object DecorationDrawerFactory {
    fun create(type: String): DecorationDrawer {
        return when (type) {
            "full_face" -> FullFaceDrawer()
            "upper_face" -> UpperFaceDrawer()
            else -> MaskDrawer()
        }
    }
}
