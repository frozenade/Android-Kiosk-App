package id.examkiosk.exam_browser

import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Host activity. Bridges the Dart [KioskService] (channel `exam_browser/kiosk`)
 * to [KioskManager] and reports violations back to Dart via `onViolation`.
 */
class MainActivity : FlutterActivity() {
    private lateinit var kiosk: KioskManager
    private var channel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Block screenshots, screen recording and the preview in Recents.
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SECURE or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
        )
        // Hide floating windows of other apps (chat heads, floating notes) on top of the exam.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            window.setHideOverlayWindows(true)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        kiosk = KioskManager(applicationContext)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "getStatus" -> result.success(kiosk.status())
                        "startKiosk" -> result.success(kiosk.start(this@MainActivity))
                        "stopKiosk" -> result.success(kiosk.stop(this@MainActivity))
                        "releaseDeviceOwner" -> result.success(kiosk.releaseDeviceOwner(this@MainActivity))
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("KIOSK_ERROR", e.message, null)
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && isInMultiWindowMode) {
            reportViolation("multi_window")
        }
    }

    override fun onMultiWindowModeChanged(isInMultiWindowMode: Boolean, newConfig: Configuration) {
        super.onMultiWindowModeChanged(isInMultiWindowMode, newConfig)
        if (isInMultiWindowMode) reportViolation("multi_window")
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        if (isInPictureInPictureMode) reportViolation("multi_window")
    }

    private fun reportViolation(type: String) {
        channel?.invokeMethod("onViolation", type)
    }

    companion object {
        private const val CHANNEL = "exam_browser/kiosk"
    }
}
