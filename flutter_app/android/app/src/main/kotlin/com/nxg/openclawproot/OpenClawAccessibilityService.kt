package com.nxg.openclawproot

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Bitmap
import android.graphics.Path
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.ConcurrentHashMap

/**
 * Accessibility service that enables screen interaction macros:
 * tap, swipe, type text, navigate (back/home/recents), screenshot, and notifications.
 *
 * Users must enable this service in:
 *   Settings > Accessibility > Installed Apps > OpenClaw
 */
class OpenClawAccessibilityService : AccessibilityService() {

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        isRunning = true
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Service is alive — no processing needed for individual events
    }

    override fun onInterrupt() {
        // Service interrupted
    }

    override fun onDestroy() {
        instance = null
        isRunning = false
        super.onDestroy()
    }

    // ─── Screenshot result (API 34+) ───

    private val screenshotCallback = TakeScreenshotCallback()

    private inner class TakeScreenshotCallback :
        android.accessibilityservice.AccessibilityService.TakeScreenshotCallback {
        override fun onSuccess(screenshot: Bitmap?) {
            if (screenshot != null) {
                try {
                    val file = File(cacheDir, "screenshot_${System.currentTimeMillis()}.png")
                    FileOutputStream(file).use { out ->
                        screenshot.compress(Bitmap.CompressFormat.PNG, 90, out)
                    }
                    lastScreenshotPath = file.absolutePath
                } catch (_: Exception) {}
            }
        }

        override fun onFailure(errorCode: Int) {}
    }

    companion object {
        @Volatile
        var instance: OpenClawAccessibilityService? = null
            private set

        @Volatile
        var isRunning: Boolean = false
            private set

        @Volatile
        var lastScreenshotPath: String? = null

        fun isServiceEnabled(): Boolean = isRunning && instance != null

        fun performTap(x: Int, y: Int) {
            val svc = instance ?: return
            val path = Path().apply { moveTo(x.toFloat(), y.toFloat()) }
            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0, 100))
                .build()
            svc.dispatchGesture(gesture, null, null)
        }

        fun performSwipe(x1: Int, y1: Int, x2: Int, y2: Int, durationMs: Long = 300) {
            val svc = instance ?: return
            val path = Path().apply {
                moveTo(x1.toFloat(), y1.toFloat())
                lineTo(x2.toFloat(), y2.toFloat())
            }
            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0, durationMs))
                .build()
            svc.dispatchGesture(gesture, null, null)
        }

        fun performGlobalAction(action: Int): Boolean {
            val svc = instance ?: return false
            return svc.performGlobalAction(action)
        }

        fun typeText(text: String): Boolean {
            val svc = instance ?: return false
            val root = svc.rootInActiveWindow ?: return false
            try {
                val focused = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
                if (focused != null) {
                    val args = android.os.Bundle()
                    args.putCharSequence(
                        AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                        text
                    )
                    focused.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
                    focused.recycle()
                    root.recycle()
                    return true
                }
                root.recycle()
            } catch (_: Exception) {
                try { root.recycle() } catch (_: Exception) {}
            }
            return false
        }

        fun takeScreenshot() {
            val svc = instance ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                lastScreenshotPath = null
                svc.takeScreenshot(svc.screenshotCallback, Handler(Looper.getMainLooper()))
            }
        }
    }
}
