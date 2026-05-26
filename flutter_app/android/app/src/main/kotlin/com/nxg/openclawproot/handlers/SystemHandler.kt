package com.nxg.openclawproot.handlers

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.nxg.openclawproot.MainActivity
import com.nxg.openclawproot.WebViewActivity

class SystemHandler(private val context: Context, private val activity: MainActivity) : BaseHandler {

    override fun handleMethodCall(call: MethodCall, result: MethodChannel.Result): Boolean {
        when (call.method) {
            "requestBatteryOptimization" -> {
                try {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                        data = Uri.parse("package:${context.packageName}")
                    }
                    activity.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("BATTERY_ERROR", e.message, null)
                }
                return true
            }
            "isBatteryOptimized" -> {
                val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                result.success(!pm.isIgnoringBatteryOptimizations(context.packageName))
                return true
            }
            "getBatteryStatus" -> {
                getBatteryStatus(result)
                return true
            }
            "vibrate" -> {
                vibrate(call, result)
                return true
            }
            "copyToClipboard" -> {
                val text = call.argument<String>("text")
                if (text != null) {
                    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                    clipboard.setPrimaryClip(ClipData.newPlainText("URL", text))
                    result.success(true)
                } else {
                    result.error("INVALID_ARGS", "text required", null)
                }
                return true
            }
            "checkPermission" -> {
                val permission = call.argument<String>("permission")
                if (permission != null) {
                    val granted = ContextCompat.checkSelfPermission(context, permission) ==
                            PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                } else {
                    result.error("INVALID_ARGS", "permission required", null)
                }
                return true
            }
            "requestPermission" -> {
                val permission = call.argument<String>("permission")
                if (permission != null) {
                    ActivityCompat.requestPermissions(
                        activity, arrayOf(permission), MainActivity.GENERAL_PERMISSION_REQUEST
                    )
                    result.success(true)
                } else {
                    result.error("INVALID_ARGS", "permission required", null)
                }
                return true
            }
            "isPermissionPermanentlyDenied" -> {
                val permission = call.argument<String>("permission")
                if (permission != null) {
                    val denied = !ActivityCompat.shouldShowRequestPermissionRationale(activity, permission)
                    val isGranted = ContextCompat.checkSelfPermission(context, permission) ==
                            PackageManager.PERMISSION_GRANTED
                    result.success(!isGranted && denied)
                } else {
                    result.error("INVALID_ARGS", "permission required", null)
                }
                return true
            }
            "getAppInfo" -> {
                try {
                    val pkgInfo = context.packageManager.getPackageInfo(context.packageName, 0)
                    val info = hashMapOf<String, Any>(
                        "packageName" to context.packageName,
                        "versionName" to (pkgInfo.versionName ?: ""),
                        "versionCode" to pkgInfo.longVersionCode
                    )
                    result.success(info)
                } catch (e: Exception) {
                    result.error("APP_INFO_ERROR", e.message, null)
                }
                return true
            }
            "openUrl" -> {
                val url = call.argument<String>("url")
                if (url != null) {
                    try {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                        activity.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("URL_ERROR", e.message, null)
                    }
                } else {
                    result.error("INVALID_ARGS", "url required", null)
                }
                return true
            }
            "openWebDashboard" -> {
                val url = call.argument<String>("url") ?: "http://localhost:9090"
                val intent = Intent(activity, WebViewActivity::class.java).apply {
                    putExtra(WebViewActivity.EXTRA_URL, url)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                }
                activity.startActivity(intent)
                result.success(true)
                return true
            }
            "getString", "saveString", "getBool", "saveBool", "getInt", "saveInt", "removeKey", "clearPrefs" -> {
                handlePreferences(call, result)
                return true
            }
            "bringToForeground" -> {
                try {
                    val intent = Intent(context, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                    }
                    context.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("FOREGROUND_ERROR", e.message, null)
                }
                return true
            }
        }
        return false
    }

    private fun getBatteryStatus(result: MethodChannel.Result) {
        try {
            val batteryIntent = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            if (batteryIntent == null) {
                result.error("BATTERY_ERROR", "Battery status unavailable", null)
                return
            }

            val level = batteryIntent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
            val scale = batteryIntent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
            val temperature = batteryIntent.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, -1)
            val voltage = batteryIntent.getIntExtra(BatteryManager.EXTRA_VOLTAGE, -1)
            val status = batteryIntent.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
            val plugged = batteryIntent.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0)

            val percentage = if (level >= 0 && scale > 0) ((level * 100f) / scale).toInt() else -1

            val statusText = when (status) {
                BatteryManager.BATTERY_STATUS_CHARGING -> "CHARGING"
                BatteryManager.BATTERY_STATUS_DISCHARGING -> "DISCHARGING"
                BatteryManager.BATTERY_STATUS_FULL -> "FULL"
                BatteryManager.BATTERY_STATUS_NOT_CHARGING -> "NOT_CHARGING"
                else -> "UNKNOWN"
            }

            val pluggedText = when {
                (plugged and BatteryManager.BATTERY_PLUGGED_AC) != 0 -> "AC"
                (plugged and BatteryManager.BATTERY_PLUGGED_USB) != 0 -> "USB"
                (plugged and BatteryManager.BATTERY_PLUGGED_WIRELESS) != 0 -> "WIRELESS"
                else -> "UNPLUGGED"
            }

            val data = hashMapOf<String, Any>(
                "percentage" to percentage,
                "level" to level,
                "scale" to scale,
                "status" to statusText,
                "plugged" to pluggedText,
                "isCharging" to (
                    status == BatteryManager.BATTERY_STATUS_CHARGING ||
                        status == BatteryManager.BATTERY_STATUS_FULL
                    ),
                "temperatureC" to if (temperature >= 0) temperature / 10.0 else -1.0,
                "voltageMv" to voltage,
            )

            result.success(data)
        } catch (e: Exception) {
            result.error("BATTERY_ERROR", e.message, null)
        }
    }

    private fun vibrate(call: MethodCall, result: MethodChannel.Result) {
        val durationMs = call.argument<Int>("durationMs")?.toLong() ?: 200L
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                val vibrator = vibratorManager.defaultVibrator
                vibrator.vibrate(VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            vibrator.vibrate(VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE))
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("VIBRATE_ERROR", e.message, null)
        }
    }

    private fun handlePreferences(call: MethodCall, result: MethodChannel.Result) {
        val prefs = context.getSharedPreferences("openclaw_prefs", Context.MODE_PRIVATE)
        val key = call.argument<String>("key")
        
        when (call.method) {
            "getString" -> {
                if (key != null) result.success(prefs.getString(key, null))
                else result.error("INVALID_ARGS", "key required", null)
            }
            "saveString" -> {
                val value = call.argument<String>("value")
                if (key != null && value != null) {
                    prefs.edit().putString(key, value).apply()
                    result.success(true)
                } else result.error("INVALID_ARGS", "key and value required", null)
            }
            "getBool" -> {
                if (key != null) result.success(prefs.getBoolean(key, false))
                else result.error("INVALID_ARGS", "key required", null)
            }
            "saveBool" -> {
                val value = call.argument<Boolean>("value")
                if (key != null && value != null) {
                    prefs.edit().putBoolean(key, value).apply()
                    result.success(true)
                } else result.error("INVALID_ARGS", "key and value required", null)
            }
            "getInt" -> {
                if (key != null) {
                    val value = prefs.getInt(key, Int.MIN_VALUE)
                    result.success(if (value == Int.MIN_VALUE) null else value)
                } else result.error("INVALID_ARGS", "key required", null)
            }
            "saveInt" -> {
                val value = call.argument<Int?>("value")
                if (key != null && value != null) {
                    prefs.edit().putInt(key, value).apply()
                    result.success(true)
                } else if (key != null) {
                    prefs.edit().remove(key).apply()
                    result.success(true)
                } else result.error("INVALID_ARGS", "key required", null)
            }
            "removeKey" -> {
                if (key != null) {
                    prefs.edit().remove(key).apply()
                    result.success(true)
                } else result.error("INVALID_ARGS", "key required", null)
            }
            "clearPrefs" -> {
                prefs.edit().clear().apply()
                result.success(true)
            }
        }
    }
}
