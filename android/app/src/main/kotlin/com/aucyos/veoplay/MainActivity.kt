package com.aucyos.veoplay

import android.content.pm.ActivityInfo
import android.content.res.Configuration
import cl.puntito.simple_pip_mode.PipCallbackHelper
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private var callbackHelper = PipCallbackHelper()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        callbackHelper.configureFlutterEngine(flutterEngine)

        // फोन घुमाने पर वीडियो अपने-आप घूमे (system का auto-rotate बंद हो तब भी)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "veoplay/orientation")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sensor" -> {
                        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_FULL_SENSOR
                        result.success(true)
                    }
                    "unspecified" -> {
                        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
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
