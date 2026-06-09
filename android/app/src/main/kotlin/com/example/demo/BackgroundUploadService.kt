package com.example.demo

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.os.Handler
import android.os.Looper
import androidx.core.app.NotificationCompat
import java.io.File
import java.io.FileInputStream
import java.net.HttpURLConnection
import java.net.URL

class BackgroundUploadService : Service() {
    private val CHANNEL_ID = "bg_upload"
    private val TAG = "BGUploadService"

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Background Upload",
                NotificationManager.IMPORTANCE_LOW
            )
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }

        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("正在上傳影片")
            .setContentText("背景上傳進行中…")
            .setSmallIcon(android.R.drawable.stat_sys_upload)
            .build()

        // ★ 修復：Android 14 (API 34) 起必須傳入 foregroundServiceType
        //   否則拋出 SecurityException 導致閃退
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                1001,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else {
            startForeground(1001, notification)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val filePath = intent?.getStringExtra("filePath") ?: return START_NOT_STICKY
        val presignedUrl = intent.getStringExtra("presignedUrl") ?: return START_NOT_STICKY
        val s3Url = intent.getStringExtra("s3Url") ?: ""
        val offset = intent.getLongExtra("offset", -1L)
        val length = intent.getLongExtra("length", -1L)
        val uploadId = intent.getStringExtra("uploadId")
        val partNumber = intent.getIntExtra("partNumber", -1)

        Thread {
            try {
                if (offset >= 0 && length > 0 && uploadId != null && partNumber > 0) {
                    val eTag = uploadPart(File(filePath), presignedUrl, offset, length)
                    val args = hashMapOf<String, Any?>(
                        "uploadId" to uploadId,
                        "partNumber" to partNumber,
                        "eTag" to (eTag ?: "")
                    )
                    Handler(Looper.getMainLooper()).post {
                        MainActivity.uploaderChannel?.invokeMethod("uploadPartCompleted", args)
                    }
                } else {
                    uploadFile(File(filePath), presignedUrl)
                    Handler(Looper.getMainLooper()).post {
                        MainActivity.uploaderChannel?.invokeMethod("uploadCompleted", s3Url)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Upload failed", e)
                Handler(Looper.getMainLooper()).post {
                    MainActivity.uploaderChannel?.invokeMethod("uploadFailed", e.message)
                }
            } finally {
                stopForeground(true)
                stopSelf()
            }
        }.start()

        return START_NOT_STICKY
    }

    private fun uploadFile(file: File, urlStr: String) {
        val url = URL(urlStr)
        val conn = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "PUT"
            doOutput = true
            setFixedLengthStreamingMode(file.length())
        }
        var sent: Long = 0
        val out = conn.outputStream
        val buff = ByteArray(1024 * 128)
        val input = FileInputStream(file)
        var read: Int
        while (input.read(buff).also { read = it } > 0) {
            out.write(buff, 0, read)
            sent += read
            try {
                val progressArgs = hashMapOf<String, Any?>(
                    "bytes" to sent,
                    "total" to file.length()
                )
                Handler(Looper.getMainLooper()).post {
                    MainActivity.uploaderChannel?.invokeMethod("uploadProgress", progressArgs)
                }
            } catch (_: Throwable) {}
        }
        input.close()
        out.flush()
        out.close()
        val code = conn.responseCode
        if (code !in 200..299) {
            val errorBody = conn.errorStream?.bufferedReader()?.readText()
            Log.e(TAG, "Upload failed with code $code: $errorBody")
            throw RuntimeException("HTTP $code ${conn.responseMessage}")
        }
    }

    private fun uploadPart(file: File, urlStr: String, offset: Long, length: Long): String? {
        val url = URL(urlStr)
        val conn = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "PUT"
            doOutput = true
            setFixedLengthStreamingMode(length)
        }
        val out = conn.outputStream
        val raf = java.io.RandomAccessFile(file, "r")
        raf.seek(offset)
        val buff = ByteArray(1024 * 128)
        var remaining = length
        var sent: Long = 0
        while (remaining > 0) {
            val toRead = if (remaining > buff.size) buff.size else remaining.toInt()
            val r = raf.read(buff, 0, toRead)
            if (r <= 0) break
            out.write(buff, 0, r)
            remaining -= r
            sent += r
            try {
                val progressArgs = hashMapOf<String, Any?>(
                    "bytes" to sent,
                    "total" to length
                )
                Handler(Looper.getMainLooper()).post {
                    MainActivity.uploaderChannel?.invokeMethod("uploadProgress", progressArgs)
                }
            } catch (_: Throwable) {}
        }
        raf.close()
        out.flush()
        out.close()
        val code = conn.responseCode
        if (code !in 200..299) {
            throw RuntimeException("HTTP $code ${conn.responseMessage}")
        }
        return conn.getHeaderField("ETag")
    }
}