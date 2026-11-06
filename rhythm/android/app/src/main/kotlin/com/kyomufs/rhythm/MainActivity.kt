package com.kyomufs.rhythm

import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val installerChannel = "com.kyomufs.rhythm/installer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, installerChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Hand a downloaded APK over to the system package
                    // installer ("Do you want to install this app?").
                    "installApk" -> {
                        val path = call.arguments as? String
                        if (path == null) {
                            result.error("args", "APK path is required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val uri = FileProvider.getUriForFile(
                                this,
                                "$packageName.fileprovider",
                                File(path),
                            )
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(
                                    uri,
                                    "application/vnd.android.package-archive",
                                )
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("install", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
