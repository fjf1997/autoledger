package com.example.auto_ledger

import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    companion object {
        private const val OCR_CHANNEL = "auto_ledger/ocr"
        private const val NOTIF_METHOD = "auto_ledger/notification"
        private const val NOTIF_EVENT = "auto_ledger/notification_events"
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── OCR：端侧 ML Kit 中文识别 ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OCR_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAvailable" -> result.success(true)
                    "recognizeText" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrEmpty()) {
                            result.error("NO_PATH", "缺少图片路径", null)
                        } else {
                            recognize(path, result)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // ── 通知：跳转授权 / 查询状态 ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIF_METHOD)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasPermission" -> result.success(NotificationSink.hasPermission(this))
                    "openListenerSettings" -> {
                        val intent = android.content.Intent(
                            android.provider.Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS
                        )
                        intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── 通知：文本流 ──
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIF_EVENT)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    NotificationSink.sink = events
                }

                override fun onCancel(arguments: Any?) {
                    NotificationSink.sink = null
                }
            })
    }

    private fun recognize(path: String, result: MethodChannel.Result) {
        try {
            val image = InputImage.fromFilePath(this, Uri.fromFile(File(path)))
            val recognizer =
                TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
            recognizer.process(image)
                .addOnSuccessListener { text -> result.success(text.text) }
                .addOnFailureListener { e ->
                    result.error("OCR_FAIL", e.message ?: "识别失败", null)
                }
                .addOnCompleteListener { recognizer.close() }
        } catch (e: Exception) {
            result.error("OCR_FAIL", e.message ?: "识别失败", null)
        }
    }
}

/// 通知文本的中转站：Service 在后台线程收到后，切主线程送到 Flutter
object NotificationSink {
    var sink: EventChannel.EventSink? = null

    fun emit(text: String, pkg: String) {
        Handler(Looper.getMainLooper()).post {
            sink?.success(mapOf("text" to text, "package" to pkg))
        }
    }

    fun hasPermission(context: android.content.Context): Boolean {
        val flat = android.provider.Settings.Secure.getString(
            context.contentResolver,
            "enabled_notification_listeners"
        ) ?: return false
        return flat.contains(context.packageName)
    }
}
