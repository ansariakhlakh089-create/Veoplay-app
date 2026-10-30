package com.aucyos.veoplay

import android.content.pm.ActivityInfo
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import cl.puntito.simple_pip_mode.PipCallbackHelper
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private var callbackHelper = PipCallbackHelper()

    // कैमरा-कटआउट (notch) वाली जगह में भी वीडियो फैले, VLC जैसा
    private fun allowDrawingInCutout() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val params = window.attributes
            params.layoutInDisplayCutoutMode =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
                } else {
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
                }
            window.attributes = params
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        allowDrawingInCutout()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        callbackHelper.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "veoplay/orientation")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // फोन घुमाने पर वीडियो अपने-आप घूमे (system का auto-rotate बंद हो तब भी)
                    "sensor" -> {
                        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_FULL_SENSOR
                        result.success(true)
                    }
                    "unspecified" -> {
                        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
                        result.success(true)
                    }
                    "cutout" -> {
                        allowDrawingInCutout()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onPictureInPictureModeChanged(active: Boolean, newConfig: Configuration?) {
        super.onPictureInPictureModeChanged(active, newConfig)
        callbackHelper.onPictureInPictureModeChanged(active)
    }
}
