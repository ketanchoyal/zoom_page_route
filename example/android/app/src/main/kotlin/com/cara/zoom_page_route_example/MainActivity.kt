package com.cara.zoom_page_route_example

import android.os.Build
import android.view.RoundedCorner
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The display's corner radius in logical pixels (Android 12+), which the
        // zoom transition's page corners follow; 0 where Android can't tell.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zoom_page_route_example/display")
            .setMethodCallHandler { call, result ->
                if (call.method != "cornerRadius") return@setMethodCallHandler result.notImplemented()
                val radiusPx = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    window.decorView.rootWindowInsets?.getRoundedCorner(RoundedCorner.POSITION_TOP_LEFT)?.radius ?: 0
                } else {
                    0
                }
                result.success(radiusPx / resources.displayMetrics.density.toDouble())
            }
    }
}
