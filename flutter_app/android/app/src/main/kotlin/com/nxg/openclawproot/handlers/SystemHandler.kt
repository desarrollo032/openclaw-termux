package com.nxg.openclawproot.handlers

import android.app.ActivityManager
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.content.ClipData
import android.content.ClipboardManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.media.AudioManager
import android.media.MediaRecorder
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.net.wifi.WifiConfiguration
import android.net.wifi.WifiManager
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.ContactsContract
import android.provider.Settings
import android.telephony.TelephonyManager
import android.view.WindowManager
import android.provider.Settings.SettingNotFoundException
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.nxg.openclawproot.MainActivity
import com.nxg.openclawproot.OpenClawAccessibilityService
import com.nxg.openclawproot.WebViewActivity
import java.io.File

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
            "getNetworkInfo" -> {
                getNetworkInfo(result)
                return true
            }
            "recordAudio" -> {
                recordAudio(call, result)
                return true
            }
            "getAudioVolume" -> {
                getAudioVolume(result)
                return true
            }
            "setAudioVolume" -> {
                setAudioVolume(call, result)
                return true
            }
            "setSpeakerphone" -> {
                setSpeakerphone(call, result)
                return true
            }
            "isSpeakerphoneOn" -> {
                isSpeakerphoneOn(result)
                return true
            }
            "ttsSpeak" -> {
                ttsSpeak(call, result)
                return true
            }
            "ttsListVoices" -> {
                ttsListVoices(result)
                return true
            }
            "ttsStop" -> {
                ttsStop()
                result.success(true)
                return true
            }
            "getDeviceInfo" -> {
                getDeviceInfo(result)
                return true
            }
            // ── Display ──
            "getScreenBrightness" -> {
                getScreenBrightness(result)
                return true
            }
            "setScreenBrightness" -> {
                setScreenBrightness(call, result)
                return true
            }
            "getScreenTimeout" -> {
                getScreenTimeout(result)
                return true
            }
            "setScreenTimeout" -> {
                setScreenTimeout(call, result)
                return true
            }
            "getScreenOrientation" -> {
                getScreenOrientation(result)
                return true
            }
            "setScreenOrientation" -> {
                setScreenOrientation(call, result)
                return true
            }
            "getDisplayInfo" -> {
                getDisplayInfo(result)
                return true
            }
            // ── NFC ──
            "getNfcStatus" -> {
                getNfcStatus(result)
                return true
            }
            "enableNfc" -> {
                enableNfc(result)
                return true
            }
            "disableNfc" -> {
                disableNfc(result)
                return true
            }
            "nfcReadTag" -> {
                nfcReadTag(result)
                return true
            }
            "nfcWriteTag" -> {
                nfcWriteTag(call, result)
                return true
            }
            // ── Clipboard ──
            "getClipboard" -> {
                getClipboard(result)
                return true
            }
            // ── Ringer ──
            "getRingerMode" -> {
                getRingerMode(result)
                return true
            }
            "setRingerMode" -> {
                setRingerMode(call, result)
                return true
            }
            "getStreamVolume" -> {
                getStreamVolume(call, result)
                return true
            }
            "setStreamVolume" -> {
                setStreamVolume(call, result)
                return true
            }
            // ── Bluetooth ──
            "getBluetoothStatus" -> {
                getBluetoothStatus(result)
                return true
            }
            "getPairedBluetoothDevices" -> {
                getPairedBluetoothDevices(result)
                return true
            }
            "enableBluetooth" -> {
                enableBluetooth(result)
                return true
            }
            "disableBluetooth" -> {
                disableBluetooth(result)
                return true
            }
            "bluetoothScan" -> {
                bluetoothScan(call, result)
                return true
            }
            "bluetoothConnect" -> {
                bluetoothConnect(call, result)
                return true
            }
            "bluetoothDisconnect" -> {
                bluetoothDisconnect(call, result)
                return true
            }
            "makeBluetoothDiscoverable" -> {
                makeBluetoothDiscoverable(call, result)
                return true
            }
            // ── Hotspot ──
            "getHotspotStatus" -> {
                getHotspotStatus(result)
                return true
            }
            "enableHotspot" -> {
                enableHotspot(call, result)
                return true
            }
            "disableHotspot" -> {
                disableHotspot(result)
                return true
            }
            "getHotspotClients" -> {
                getHotspotClients(result)
                return true
            }
            // ── Telephony ──
            "dialNumber" -> {
                dialNumber(call, result)
                return true
            }
            "sendSmsIntent" -> {
                sendSmsIntent(call, result)
                return true
            }
            "getContacts" -> {
                getContacts(result)
                return true
            }
            "searchContacts" -> {
                searchContacts(call, result)
                return true
            }
            "getCellularNetworkType" -> {
                getCellularNetworkType(result)
                return true
            }
            // ── Macros ──
            "isAccessibilityServiceEnabled" -> {
                isAccessibilityServiceEnabled(result)
                return true
            }
            "openApp" -> {
                openApp(call, result)
                return true
            }
            "webSearch" -> {
                webSearch(call, result)
                return true
            }
            "openSettingsPanel" -> {
                openSettingsPanel(call, result)
                return true
            }
            "macroTap" -> {
                macroTap(call, result)
                return true
            }
            "macroSwipe" -> {
                macroSwipe(call, result)
                return true
            }
            "macroType" -> {
                macroType(call, result)
                return true
            }
            "macroBack" -> {
                macroBack(result)
                return true
            }
            "macroHome" -> {
                macroHome(result)
                return true
            }
            "macroRecents" -> {
                macroRecents(result)
                return true
            }
            "takeScreenshot" -> {
                takeScreenshot(result)
                return true
            }
            "listNotifications" -> {
                listNotifications(result)
                return true
            }
            "clickNotification" -> {
                clickNotification(call, result)
                return true
            }
            "clearNotification" -> {
                clearNotification(call, result)
                return true
            }
        }
        return false
    }

    // ──────────────────────────────────────────────
    // Battery
    // ──────────────────────────────────────────────

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

    private fun getNetworkInfo(result: MethodChannel.Result) {
        try {
            val connectivityManager =
                context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val activeNetwork = connectivityManager.activeNetwork
            val capabilities = connectivityManager.getNetworkCapabilities(activeNetwork)

            val data = hashMapOf<String, Any>()

            val hasWifi = capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
            val hasCellular = capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true
            val hasEthernet = capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) == true

            data["activeNetwork"] = when {
                hasWifi -> "wifi"
                hasCellular -> "cellular"
                hasEthernet -> "ethernet"
                else -> "unknown"
            }
            data["isMetered"] = capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED) == false
            data["hasInternet"] = capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) ?: false

            if (hasWifi) {
                try {
                    val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                    val wifiInfo = wifiManager.connectionInfo
                    if (wifiInfo != null) {
                        data["wifiConnected"] = true
                        val ssid = wifiInfo.ssid
                        if (ssid != null && ssid != "<unknown ssid>") {
                            data["wifiSSID"] = ssid.removeSurrounding("\"")
                        }
                        data["wifiSignalStrength"] = wifiInfo.rssi
                        data["wifiFrequency"] = wifiInfo.frequency
                        data["wifiSpeedMbps"] = wifiInfo.linkSpeed
                    }
                } catch (_: Exception) {
                    data["wifiConnected"] = false
                }
            } else {
                data["wifiConnected"] = false
            }

            if (hasCellular) {
                try {
                    val telephonyManager = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
                    data["cellularAvailable"] = true
                    val carrierName = telephonyManager.networkOperatorName
                    if (!carrierName.isNullOrEmpty()) data["cellularCarrier"] = carrierName
                    val networkType = telephonyManager.dataNetworkType
                    data["cellularNetworkType"] = when (networkType) {
                        TelephonyManager.NETWORK_TYPE_LTE -> "LTE"
                        TelephonyManager.NETWORK_TYPE_NR -> "5G"
                        TelephonyManager.NETWORK_TYPE_HSPAP -> "HSPA+"
                        TelephonyManager.NETWORK_TYPE_UMTS -> "UMTS"
                        TelephonyManager.NETWORK_TYPE_EDGE -> "EDGE"
                        TelephonyManager.NETWORK_TYPE_GPRS -> "GPRS"
                        TelephonyManager.NETWORK_TYPE_CDMA -> "CDMA"
                        TelephonyManager.NETWORK_TYPE_EVDO_0 -> "EVDO"
                        else -> "unknown"
                    }
                    try {
                        val cellInfoList = telephonyManager.allCellInfo
                        if (cellInfoList != null && cellInfoList.isNotEmpty()) {
                            val cellInfo = cellInfoList.firstOrNull()
                            if (cellInfo is android.telephony.CellInfoLte) {
                                data["cellularSignalDbm"] = cellInfo.cellSignalStrength.dbm
                            } else if (cellInfo is android.telephony.CellInfoWcdma) {
                                data["cellularSignalDbm"] = cellInfo.cellSignalStrength.dbm
                            }
                        }
                    } catch (_: Exception) {}
                } catch (_: Exception) {
                    data["cellularAvailable"] = false
                }
            } else {
                data["cellularAvailable"] = false
            }
            result.success(data)
        } catch (e: Exception) {
            result.error("NETWORK_ERROR", e.message, null)
        }
    }

    private fun recordAudio(call: MethodCall, result: MethodChannel.Result) {
        val durationMs = call.argument<Int>("durationMs") ?: 5000
        val executor = java.util.concurrent.Executors.newSingleThreadExecutor()
        executor.execute {
            var recorder: MediaRecorder? = null
            try {
                val outputDir = context.cacheDir
                val outputFile = File(outputDir, "audio_recording_${System.currentTimeMillis()}.aac")
                recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    MediaRecorder(context)
                } else {
                    @Suppress("DEPRECATION") MediaRecorder()
                }
                recorder.setAudioSource(MediaRecorder.AudioSource.MIC)
                recorder.setOutputFormat(MediaRecorder.OutputFormat.AAC_ADTS)
                recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                recorder.setAudioSamplingRate(44100)
                recorder.setAudioBitRate(128000)
                recorder.setOutputFile(outputFile.absolutePath)
                recorder.prepare()
                recorder.start()
                Thread.sleep(durationMs.toLong())
                recorder.stop()
                recorder.release()
                recorder = null
                activity.runOnUiThread { result.success(outputFile.absolutePath) }
            } catch (e: Exception) {
                try { recorder?.stop() } catch (_: Exception) {}
                try { recorder?.release() } catch (_: Exception) {}
                activity.runOnUiThread { result.error("RECORD_ERROR", e.message, null) }
            } finally {
                executor.shutdown()
            }
        }
    }

    private fun getAudioVolume(result: MethodChannel.Result) {
        try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            val currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
            val normalized = if (maxVolume > 0) currentVolume.toDouble() / maxVolume.toDouble() else 0.0
            result.success(normalized)
        } catch (e: Exception) {
            result.error("VOLUME_ERROR", e.message, null)
        }
    }

    private fun setAudioVolume(call: MethodCall, result: MethodChannel.Result) {
        try {
            val level = call.argument<Double>("level") ?: 0.5
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            val newVolume = (level * maxVolume).toInt().coerceIn(0, maxVolume)
            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, newVolume,
                AudioManager.FLAG_SHOW_UI or AudioManager.FLAG_PLAY_SOUND)
            result.success(true)
        } catch (e: Exception) {
            result.error("VOLUME_ERROR", e.message, null)
        }
    }

    private fun setSpeakerphone(call: MethodCall, result: MethodChannel.Result) {
        try {
            val on = call.argument<Boolean>("on") ?: return result.error("INVALID_ARGS", "'on' required", null)
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioManager.isSpeakerphoneOn = on
            result.success(true)
        } catch (e: Exception) {
            result.error("SPEAKER_ERROR", e.message, null)
        }
    }

    private fun isSpeakerphoneOn(result: MethodChannel.Result) {
        try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            result.success(audioManager.isSpeakerphoneOn)
        } catch (e: Exception) {
            result.error("SPEAKER_ERROR", e.message, null)
        }
    }

    // ──────────────────────────────────────────────
    // Text-to-Speech
    // ──────────────────────────────────────────────

    private var tts: android.speech.tts.TextToSpeech? = null

    private fun getTts(): android.speech.tts.TextToSpeech {
        if (tts == null) tts = android.speech.tts.TextToSpeech(context, null)
        return tts!!
    }

    private fun ttsSpeak(call: MethodCall, result: MethodChannel.Result) {
        try {
            val text = call.argument<String>("text") ?: return result.error("MISSING_PARAM", "text required", null)
            val language = call.argument<String>("language") ?: ""
            val pitch = call.argument<Double>("pitch") ?: 1.0
            val speechRate = call.argument<Double>("speechRate") ?: 1.0
            val engine = getTts()
            engine.language = if (language.isNotEmpty()) java.util.Locale.forLanguageTag(language)
            else java.util.Locale.getDefault()
            engine.setPitch(pitch.toFloat())
            engine.setSpeechRate(speechRate.toFloat())
            engine.speak(text, android.speech.tts.TextToSpeech.QUEUE_FLUSH, null, "tts-${System.currentTimeMillis()}")
            result.success(true)
        } catch (e: Exception) {
            result.error("TTS_ERROR", e.message, null)
        }
    }

    private fun ttsListVoices(result: MethodChannel.Result) {
        try {
            val engine = getTts()
            val voicesInfo = mutableListOf<Map<String, Any>>()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                for (voice in engine.voices) {
                    voicesInfo.add(hashMapOf(
                        "name" to voice.name,
                        "language" to voice.locale.toLanguageTag(),
                        "displayName" to (voice.displayName ?: voice.name),
                        "quality" to voice.quality,
                        "latency" to voice.latency,
                        "requiresNetwork" to voice.isNetworkConnectionRequired,
                    ))
                }
            } else {
                @Suppress("DEPRECATION")
                for (locale in engine.availableLanguages) {
                    voicesInfo.add(hashMapOf("language" to locale.toLanguageTag(), "displayName" to locale.displayName))
                }
            }
            result.success(voicesInfo)
        } catch (e: Exception) {
            result.error("TTS_ERROR", e.message, null)
        }
    }

    private fun ttsStop() {
        try { getTts().stop() } catch (_: Exception) {}
    }

    // ──────────────────────────────────────────────
    // Device Info
    // ──────────────────────────────────────────────

    private fun getDeviceInfo(result: MethodChannel.Result) {
        try {
            val displayMetrics = activity.resources.displayMetrics
            val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val memoryInfo = ActivityManager.MemoryInfo()
            activityManager.getMemoryInfo(memoryInfo)
            val storage = android.os.StatFs(activity.filesDir.absolutePath)
            val blockSize = storage.blockSizeLong
            val totalBlocks = storage.blockCountLong
            val freeBlocks = storage.availableBlocksLong
            val data = hashMapOf<String, Any>(
                "model" to Build.MODEL, "manufacturer" to Build.MANUFACTURER,
                "brand" to Build.BRAND, "deviceName" to Build.DEVICE, "hardware" to Build.HARDWARE,
                "androidVersion" to Build.VERSION.RELEASE, "sdkInt" to Build.VERSION.SDK_INT,
                "buildId" to Build.DISPLAY,
                "screenWidthPx" to displayMetrics.widthPixels, "screenHeightPx" to displayMetrics.heightPixels,
                "screenDensity" to displayMetrics.density.toDouble(), "screenDensityDpi" to displayMetrics.densityDpi,
                "totalRamMb" to (memoryInfo.totalMem / (1024 * 1024)).toLong(),
                "availableRamMb" to (memoryInfo.availMem / (1024 * 1024)).toLong(),
                "internalStorageTotalMb" to ((totalBlocks * blockSize) / (1024 * 1024)).toLong(),
                "internalStorageFreeMb" to ((freeBlocks * blockSize) / (1024 * 1024)).toLong(),
                "supportedAbis" to listOf(*Build.SUPPORTED_ABIS),
            )
            result.success(data)
        } catch (e: Exception) {
            result.error("DEVICE_ERROR", e.message, null)
        }
    }

    // ──────────────────────────────────────────────
    // Display
    // ──────────────────────────────────────────────

    private fun getScreenBrightness(result: MethodChannel.Result) {
        try {
            val level = Settings.System.getInt(context.contentResolver, Settings.System.SCREEN_BRIGHTNESS)
            result.success(level)
        } catch (e: Exception) {
            result.error("BRIGHTNESS_ERROR", e.message, null)
        }
    }

    private fun setScreenBrightness(call: MethodCall, result: MethodChannel.Result) {
        try {
            val level = call.argument<Int>("level") ?: return result.error("INVALID_ARGS", "level required", null)
            Settings.System.putInt(context.contentResolver, Settings.System.SCREEN_BRIGHTNESS, level.coerceIn(0, 255))
            result.success(true)
        } catch (e: Exception) {
            result.error("BRIGHTNESS_ERROR", e.message, null)
        }
    }

    private fun getScreenTimeout(result: MethodChannel.Result) {
        try {
            val timeout = Settings.System.getInt(context.contentResolver, Settings.System.SCREEN_OFF_TIMEOUT)
            result.success(timeout)
        } catch (e: Exception) {
            result.error("TIMEOUT_ERROR", e.message, null)
        }
    }

    private fun setScreenTimeout(call: MethodCall, result: MethodChannel.Result) {
        try {
            val timeoutMs = call.argument<Int>("timeoutMs") ?: return result.error("INVALID_ARGS", "timeoutMs required", null)
            Settings.System.putInt(context.contentResolver, Settings.System.SCREEN_OFF_TIMEOUT, timeoutMs)
            result.success(true)
        } catch (e: Exception) {
            result.error("TIMEOUT_ERROR", e.message, null)
        }
    }

    private fun getScreenOrientation(result: MethodChannel.Result) {
        try {
            val rotation = activity.windowManager.defaultDisplay.rotation
            val mode = when (rotation) {
                android.view.Surface.ROTATION_0 -> "portrait"
                android.view.Surface.ROTATION_90 -> "landscape"
                android.view.Surface.ROTATION_180 -> "reverse_portrait"
                android.view.Surface.ROTATION_270 -> "reverse_landscape"
                else -> "unknown"
            }
            result.success(mode)
        } catch (e: Exception) {
            result.error("ORIENTATION_ERROR", e.message, null)
        }
    }

    private fun setScreenOrientation(call: MethodCall, result: MethodChannel.Result) {
        try {
            val mode = call.argument<String>("mode") ?: return result.error("INVALID_ARGS", "mode required", null)
            val locked = mode != "auto"
            // Use requestedOrientation on the activity
            activity.requestedOrientation = when (mode) {
                "portrait" -> android.content.pm.ActivityInfo.SCREEN_ORIENTATION_USER_PORTRAIT
                "landscape" -> android.content.pm.ActivityInfo.SCREEN_ORIENTATION_USER_LANDSCAPE
                "reverse_portrait" -> android.content.pm.ActivityInfo.SCREEN_ORIENTATION_REVERSE_PORTRAIT
                "reverse_landscape" -> android.content.pm.ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE
                else -> android.content.pm.ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("ORIENTATION_ERROR", e.message, null)
        }
    }

    private fun getDisplayInfo(result: MethodChannel.Result) {
        try {
            val metrics = activity.resources.displayMetrics
            val data = hashMapOf<String, Any>(
                "widthPx" to metrics.widthPixels,
                "heightPx" to metrics.heightPixels,
                "density" to metrics.density.toDouble(),
                "densityDpi" to metrics.densityDpi,
                "scaledDensity" to metrics.scaledDensity.toDouble(),
                "xdpi" to metrics.xdpi.toDouble(),
                "ydpi" to metrics.ydpi.toDouble(),
                "refreshRate" to activity.windowManager.defaultDisplay.refreshRate.toDouble(),
            )
            result.success(data)
        } catch (e: Exception) {
            result.error("DISPLAY_ERROR", e.message, null)
        }
    }

    // ──────────────────────────────────────────────
    // NFC
    // ──────────────────────────────────────────────

    private fun getNfcStatus(result: MethodChannel.Result) {
        try {
            val nfcManager = context.getSystemService(Context.NFC_SERVICE) as android.nfc.NfcManager?
            if (nfcManager == null) {
                result.success(hashMapOf("available" to false, "enabled" to false))
                return
            }
            val adapter = nfcManager.defaultAdapter
            result.success(hashMapOf(
                "available" to (adapter != null),
                "enabled" to (adapter?.isEnabled == true),
            ))
        } catch (e: Exception) {
            result.success(hashMapOf("available" to false, "enabled" to false, "error" to e.message))
        }
    }

    private fun enableNfc(result: MethodChannel.Result) {
        try {
            val nfcManager = context.getSystemService(Context.NFC_SERVICE) as android.nfc.NfcManager?
            val adapter = nfcManager?.defaultAdapter
            if (adapter != null && !adapter.isEnabled) {
                adapter.enable()
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("NFC_ERROR", e.message, null)
        }
    }

    private fun disableNfc(result: MethodChannel.Result) {
        try {
            val nfcManager = context.getSystemService(Context.NFC_SERVICE) as android.nfc.NfcManager?
            val adapter = nfcManager?.defaultAdapter
            if (adapter != null && adapter.isEnabled) {
                adapter.disable()
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("NFC_ERROR", e.message, null)
        }
    }

    // ──────────────────────────────────────────────
    // Ringer
    // ──────────────────────────────────────────────

    private fun getRingerMode(result: MethodChannel.Result) {
        try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val mode = when (audioManager.ringerMode) {
                AudioManager.RINGER_MODE_NORMAL -> "normal"
                AudioManager.RINGER_MODE_SILENT -> "silent"
                AudioManager.RINGER_MODE_VIBRATE -> "vibrate"
                else -> "normal"
            }
            result.success(mode)
        } catch (e: Exception) {
            result.error("RINGER_ERROR", e.message, null)
        }
    }

    private fun setRingerMode(call: MethodCall, result: MethodChannel.Result) {
        try {
            val mode = call.argument<String>("mode") ?: return result.error("INVALID_ARGS", "mode required", null)
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioManager.ringerMode = when (mode) {
                "silent" -> AudioManager.RINGER_MODE_SILENT
                "vibrate" -> AudioManager.RINGER_MODE_VIBRATE
                else -> AudioManager.RINGER_MODE_NORMAL
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("RINGER_ERROR", e.message, null)
        }
    }

    private fun getStreamVolume(call: MethodCall, result: MethodChannel.Result) {
        try {
            val streamName = call.argument<String>("stream") ?: "ring"
            val streamType = when (streamName) {
                "music" -> AudioManager.STREAM_MUSIC
                "notification" -> AudioManager.STREAM_NOTIFICATION
                "alarm" -> AudioManager.STREAM_ALARM
                else -> AudioManager.STREAM_RING
            }
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val max = audioManager.getStreamMaxVolume(streamType)
            val current = audioManager.getStreamVolume(streamType)
            result.success(current.toDouble())
        } catch (e: Exception) {
            result.error("VOLUME_ERROR", e.message, null)
        }
    }

    private fun setStreamVolume(call: MethodCall, result: MethodChannel.Result) {
        try {
            val streamName = call.argument<String>("stream") ?: "ring"
            val level = call.argument<Int>("level") ?: return result.error("INVALID_ARGS", "level required", null)
            val streamType = when (streamName) {
                "music" -> AudioManager.STREAM_MUSIC
                "notification" -> AudioManager.STREAM_NOTIFICATION
                "alarm" -> AudioManager.STREAM_ALARM
                else -> AudioManager.STREAM_RING
            }
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioManager.setStreamVolume(streamType, level.coerceIn(0, audioManager.getStreamMaxVolume(streamType)), 0)
            result.success(true)
        } catch (e: Exception) {
            result.error("VOLUME_ERROR", e.message, null)
        }
    }

    // ──────────────────────────────────────────────
    // Bluetooth
    // ──────────────────────────────────────────────

    private fun getBluetoothStatus(result: MethodChannel.Result) {
        try {
            val btManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
            val adapter = btManager.adapter
            val device = adapter ?: return result.success(hashMapOf(
                "available" to false, "enabled" to false
            ))
            result.success(hashMapOf(
                "available" to true,
                "enabled" to adapter.isEnabled,
                "name" to (adapter.name ?: ""),
                "address" to (adapter.address ?: ""),
                "state" to when (adapter.state) {
                    BluetoothAdapter.STATE_ON -> "on"
                    BluetoothAdapter.STATE_TURNING_ON -> "turning_on"
                    BluetoothAdapter.STATE_OFF -> "off"
                    BluetoothAdapter.STATE_TURNING_OFF -> "turning_off"
                    else -> "unknown"
                },
                "isDiscovering" to adapter.isDiscovering,
            ))
        } catch (e: Exception) {
            result.success(hashMapOf("available" to false, "enabled" to false, "error" to e.message))
        }
    }

    private fun getPairedBluetoothDevices(result: MethodChannel.Result) {
        try {
            val btManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
            val adapter = btManager.adapter ?: return result.success(emptyList<Map<String, Any>>())
            val devices = adapter.bondedDevices.map { device: BluetoothDevice ->
                hashMapOf<String, Any>(
                    "name" to (device.name ?: "Unknown"),
                    "address" to device.address,
                    "type" to when (device.type) {
                        BluetoothDevice.DEVICE_TYPE_CLASSIC -> "classic"
                        BluetoothDevice.DEVICE_TYPE_LE -> "le"
                        BluetoothDevice.DEVICE_TYPE_DUAL -> "dual"
                        else -> "unknown"
                    },
                    "bondState" to when (device.bondState) {
                        BluetoothDevice.BOND_BONDED -> "bonded"
                        BluetoothDevice.BOND_BONDING -> "bonding"
                        else -> "none"
                    },
                )
            }
            result.success(devices)
        } catch (e: Exception) {
            result.error("BT_ERROR", e.message, null)
        }
    }

    private fun enableBluetooth(result: MethodChannel.Result) {
        try {
            val btManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
            btManager.adapter?.enable()
            result.success(true)
        } catch (e: Exception) {
            result.error("BT_ERROR", e.message, null)
        }
    }

    private fun disableBluetooth(result: MethodChannel.Result) {
        try {
            val btManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
            btManager.adapter?.disable()
            result.success(true)
        } catch (e: Exception) {
            result.error("BT_ERROR", e.message, null)
        }
    }

    private fun makeBluetoothDiscoverable(call: MethodCall, result: MethodChannel.Result) {
        try {
            val duration = call.argument<Int>("duration") ?: 120
            val intent = Intent(BluetoothAdapter.ACTION_REQUEST_DISCOVERABLE).apply {
                putExtra(BluetoothAdapter.EXTRA_DISCOVERABLE_DURATION, duration)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("BT_ERROR", e.message, null)
        }
    }

    // ──────────────────────────────────────────────
    // Hotspot (WiFi AP)
    // ──────────────────────────────────────────────

    private fun getHotspotStatus(result: MethodChannel.Result) {
        try {
            val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val isEnabled = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                // On Android 13+, use reflection for hotspot state
                try {
                    val method = wifiManager.javaClass.getMethod("isWifiApEnabled")
                    method.invoke(wifiManager) as Boolean
                } catch (_: Exception) { false }
            } else {
                @Suppress("DEPRECATION")
                wifiManager.isWifiApEnabled
            }
            result.success(hashMapOf(
                "enabled" to isEnabled,
                "available" to true,
            ))
        } catch (e: Exception) {
            result.success(hashMapOf("enabled" to false, "error" to e.message))
        }
    }

    private fun enableHotspot(call: MethodCall, result: MethodChannel.Result) {
        try {
            val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val ssid = call.argument<String>("ssid") ?: "OpenClaw-${System.currentTimeMillis() % 10000}"
            val password = call.argument<String>("password") ?: "openclaw123"

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                // Android 13+ — must open system hotspot settings
                val intent = Intent(Settings.ACTION_WIFI_TETHER_SETTINGS).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(intent)
                result.success(hashMapOf("enabled" to true, "note" to "Open hotspot settings manually"))
                return
            }

            @Suppress("DEPRECATION")
            val config = WifiConfiguration().apply {
                SSID = ssid
                preSharedKey = password
                allowedKeyManagement.set(WifiConfiguration.KeyMgmt.WPA2_PSK)
            }
            @Suppress("DEPRECATION")
            wifiManager.setWifiApEnabled(config, true)
            result.success(hashMapOf("enabled" to true, "ssid" to ssid))
        } catch (e: Exception) {
            result.error("HOTSPOT_ERROR", e.message, null)
        }
    }

    private fun disableHotspot(result: MethodChannel.Result) {
        try {
            val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                try {
                    val method = wifiManager.javaClass.getMethod("setWifiApEnabled", WifiConfiguration::class.java, Boolean::class.java)
                    method.invoke(wifiManager, null, false)
                } catch (_: Exception) {
                    result.success(false)
                    return
                }
            } else {
                @Suppress("DEPRECATION")
                wifiManager.setWifiApEnabled(null, false)
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("HOTSPOT_ERROR", e.message, null)
        }
    }

    private fun getHotspotClients(result: MethodChannel.Result) {
        // Hotspot client list requires system-level access or ARP table reading.
        // For now, return an empty list with guidance.
        result.success(emptyList<Map<String, Any>>())
    }

    // ──────────────────────────────────────────────
    // Telephony / Contacts
    // ──────────────────────────────────────────────

    private fun dialNumber(call: MethodCall, result: MethodChannel.Result) {
        try {
            val number = call.argument<String>("number") ?: return result.error("INVALID_ARGS", "number required", null)
            val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$number")).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("DIAL_ERROR", e.message, null)
        }
    }

    private fun sendSmsIntent(call: MethodCall, result: MethodChannel.Result) {
        try {
            val number = call.argument<String>("number") ?: return result.error("INVALID_ARGS", "number required", null)
            val body = call.argument<String>("body") ?: ""
            val intent = Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:$number")).apply {
                putExtra("sms_body", body)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("SMS_ERROR", e.message, null)
        }
    }

    private fun getContacts(result: MethodChannel.Result) {
        try {
            val cursor = context.contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                arrayOf(
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                    ContactsContract.CommonDataKinds.Phone.NUMBER,
                    ContactsContract.CommonDataKinds.Phone.PHOTO_THUMBNAIL_URI,
                ),
                null, null, "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} ASC"
            )
            val contacts = mutableListOf<Map<String, Any>>()
            cursor?.use { c ->
                val nameIdx = c.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                val numIdx = c.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                val photoIdx = c.getColumnIndex(ContactsContract.CommonDataKinds.Phone.PHOTO_THUMBNAIL_URI)
                while (c.moveToNext()) {
                    contacts.add(hashMapOf(
                        "name" to (if (nameIdx >= 0) c.getString(nameIdx) ?: "" else ""),
                        "number" to (if (numIdx >= 0) c.getString(numIdx) ?: "" else ""),
                        "photo" to (if (photoIdx >= 0 && c.getString(photoIdx) != null) c.getString(photoIdx) else ""),
                    ))
                }
            }
            result.success(contacts)
        } catch (e: Exception) {
            result.error("CONTACTS_ERROR", e.message, null)
        }
    }

    private fun searchContacts(call: MethodCall, result: MethodChannel.Result) {
        try {
            val query = call.argument<String>("query") ?: return result.success(emptyList<Map<String, Any>>())
            val cursor = context.contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                arrayOf(
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                    ContactsContract.CommonDataKinds.Phone.NUMBER,
                    ContactsContract.CommonDataKinds.Phone.PHOTO_THUMBNAIL_URI,
                ),
                "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} LIKE ? OR " +
                    "${ContactsContract.CommonDataKinds.Phone.NUMBER} LIKE ?",
                arrayOf("%$query%", "%$query%"),
                "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} ASC"
            )
            val contacts = mutableListOf<Map<String, Any>>()
            cursor?.use { c ->
                val nameIdx = c.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                val numIdx = c.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                val photoIdx = c.getColumnIndex(ContactsContract.CommonDataKinds.Phone.PHOTO_THUMBNAIL_URI)
                while (c.moveToNext()) {
                    contacts.add(hashMapOf(
                        "name" to (if (nameIdx >= 0) c.getString(nameIdx) ?: "" else ""),
                        "number" to (if (numIdx >= 0) c.getString(numIdx) ?: "" else ""),
                        "photo" to (if (photoIdx >= 0 && c.getString(photoIdx) != null) c.getString(photoIdx) else ""),
                    ))
                }
            }
            result.success(contacts)
        } catch (e: Exception) {
            result.error("CONTACTS_ERROR", e.message, null)
        }
    }

    private fun getCellularNetworkType(result: MethodChannel.Result) {
        try {
            val tm = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            result.success(tm.dataNetworkType.toString())
        } catch (e: Exception) {
            result.error("NETWORK_TYPE_ERROR", e.message, null)
        }
    }

    // ──────────────────────────────────────────────
    // Macros — Intent-based
    // ──────────────────────────────────────────────

    private fun isAccessibilityServiceEnabled(result: MethodChannel.Result) {
        result.success(OpenClawAccessibilityService.isServiceEnabled())
    }

    private fun openApp(call: MethodCall, result: MethodChannel.Result) {
        try {
            val packageName = call.argument<String>("package") ?: return result.error("INVALID_ARGS", "package required", null)
            val activityName = call.argument<String>("activity") ?: ""
            val intent = context.packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
                if (activityName.isNotEmpty()) {
                    intent.setClassName(packageName, activityName)
                }
                context.startActivity(intent)
                result.success(true)
            } else {
                // Open Play Store as fallback
                try {
                    val storeIntent = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$packageName")).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    context.startActivity(storeIntent)
                    result.success(hashMapOf("opened" to false, "notInstalled" to true, "package" to packageName))
                } catch (_: Exception) {
                    result.error("OPEN_APP_ERROR", "App not installed: $packageName", null)
                }
            }
        } catch (e: Exception) {
            result.error("OPEN_APP_ERROR", e.message, null)
        }
    }

    private fun webSearch(call: MethodCall, result: MethodChannel.Result) {
        try {
            val query = call.argument<String>("query") ?: return result.error("INVALID_ARGS", "query required", null)
            val intent = Intent(Intent.ACTION_WEB_SEARCH).apply {
                putExtra(android.provider.SearchManager.QUERY, query)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            // Fallback: use browser with search URL
            try {
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com/search?q=$query")).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(intent)
                result.success(true)
            } catch (e2: Exception) {
                result.error("SEARCH_ERROR", e2.message, null)
            }
        }
    }

    private fun openSettingsPanel(call: MethodCall, result: MethodChannel.Result) {
        try {
            val panel = call.argument<String>("panel") ?: "main"
            val intent = when (panel) {
                "wifi" -> Intent(Settings.ACTION_WIFI_SETTINGS)
                "bluetooth" -> Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
                "accessibility" -> Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                "data" -> Intent(Settings.ACTION_DATA_ROAMING_SETTINGS)
                "sound" -> Intent(Settings.ACTION_SOUND_SETTINGS)
                "display" -> Intent(Settings.ACTION_DISPLAY_SETTINGS)
                "apps" -> Intent(Settings.ACTION_APPLICATION_SETTINGS)
                "battery" -> Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS)
                "security" -> Intent(Settings.ACTION_SECURITY_SETTINGS)
                "location" -> Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
                "developer" -> Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS)
                "storage" -> Intent(Settings.ACTION_INTERNAL_STORAGE_SETTINGS)
                else -> Intent(Settings.ACTION_SETTINGS)
            }.apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK }
            context.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("SETTINGS_ERROR", e.message, null)
        }
    }

    // ──────────────────────────────────────────────
    // Macros — Screen interaction (Requires AccessibilityService)
    // ──────────────────────────────────────────────

    private fun macroTap(call: MethodCall, result: MethodChannel.Result) {
        val x = call.argument<Int>("x") ?: return result.error("INVALID_ARGS", "x required", null)
        val y = call.argument<Int>("y") ?: return result.error("INVALID_ARGS", "y required", null)
        if (!OpenClawAccessibilityService.isServiceEnabled()) {
            result.error("ACCESSIBILITY_REQUIRED", "AccessibilityService not enabled", null)
            return
        }
        OpenClawAccessibilityService.performTap(x, y)
        result.success(true)
    }

    private fun macroSwipe(call: MethodCall, result: MethodChannel.Result) {
        val x1 = call.argument<Int>("x1") ?: return result.error("INVALID_ARGS", "x1 required", null)
        val y1 = call.argument<Int>("y1") ?: return result.error("INVALID_ARGS", "y1 required", null)
        val x2 = call.argument<Int>("x2") ?: return result.error("INVALID_ARGS", "x2 required", null)
        val y2 = call.argument<Int>("y2") ?: return result.error("INVALID_ARGS", "y2 required", null)
        val durationMs = call.argument<Long>("durationMs") ?: 300L
        if (!OpenClawAccessibilityService.isServiceEnabled()) {
            result.error("ACCESSIBILITY_REQUIRED", "AccessibilityService not enabled", null)
            return
        }
        OpenClawAccessibilityService.performSwipe(x1, y1, x2, y2, durationMs)
        result.success(true)
    }

    private fun macroType(call: MethodCall, result: MethodChannel.Result) {
        val text = call.argument<String>("text") ?: return result.error("INVALID_ARGS", "text required", null)
        if (!OpenClawAccessibilityService.isServiceEnabled()) {
            result.error("ACCESSIBILITY_REQUIRED", "AccessibilityService not enabled", null)
            return
        }
        OpenClawAccessibilityService.typeText(text)
        result.success(true)
    }

    private fun macroBack(result: MethodChannel.Result) {
        if (!OpenClawAccessibilityService.isServiceEnabled()) {
            result.error("ACCESSIBILITY_REQUIRED", "AccessibilityService not enabled", null)
            return
        }
        OpenClawAccessibilityService.performGlobalAction(android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_BACK)
        result.success(true)
    }

    private fun macroHome(result: MethodChannel.Result) {
        if (!OpenClawAccessibilityService.isServiceEnabled()) {
            result.error("ACCESSIBILITY_REQUIRED", "AccessibilityService not enabled", null)
            return
        }
        OpenClawAccessibilityService.performGlobalAction(android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_HOME)
        result.success(true)
    }

    private fun macroRecents(result: MethodChannel.Result) {
        if (!OpenClawAccessibilityService.isServiceEnabled()) {
            result.error("ACCESSIBILITY_REQUIRED", "AccessibilityService not enabled", null)
            return
        }
        OpenClawAccessibilityService.performGlobalAction(android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_RECENTS)
        result.success(true)
    }

    private fun takeScreenshot(result: MethodChannel.Result) {
        if (!OpenClawAccessibilityService.isServiceEnabled()) {
            result.error("ACCESSIBILITY_REQUIRED", "AccessibilityService not enabled on Android 12+", null)
            return
        }
        OpenClawAccessibilityService.takeScreenshot()
        // Wait briefly for screenshot to be saved
        try { Thread.sleep(500) } catch (_: Exception) {}
        val path = OpenClawAccessibilityService.lastScreenshotPath
        if (path != null) {
            result.success(hashMapOf("path" to path, "mimeType" to "image/png"))
        } else {
            result.success(null)
        }
    }

    // ──────────────────────────────────────────────
    // Macros — Notifications
    // ──────────────────────────────────────────────

    private fun listNotifications(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val listener = android.service.notification.NotificationListenerService()
            // Simple approach: return empty list — full notification access requires
            // a dedicated NotificationListenerService.
            result.success(emptyList<Map<String, Any>>())
        } else {
            result.success(emptyList<Map<String, Any>>())
        }
    }

    private fun clickNotification(call: MethodCall, result: MethodChannel.Result) {
        result.error("NOTIFICATION_ERROR", "Notification interaction requires NotificationListenerService", null)
    }

    private fun clearNotification(call: MethodCall, result: MethodChannel.Result) {
        result.error("NOTIFICATION_ERROR", "Notification interaction requires NotificationListenerService", null)
    }

    // ──────────────────────────────────────────────
    // Clipboard
    // ──────────────────────────────────────────────

    private fun getClipboard(result: MethodChannel.Result) {
        try {
            val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            val clip = clipboard.primaryClip
            val text = if (clip != null && clip.itemCount > 0) {
                clip.getItemAt(0).coerceToText(context).toString()
            } else {
                ""
            }
            result.success(text)
        } catch (e: Exception) {
            result.success("")
        }
    }

    // ──────────────────────────────────────────────
    // Bluetooth scanning
    // ──────────────────────────────────────────────

    private fun bluetoothScan(call: MethodCall, result: MethodChannel.Result) {
        try {
            val btManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
            val adapter = btManager.adapter ?: return result.success(emptyList<Map<String, Any>>())
            if (!adapter.isEnabled) {
                result.success(emptyList<Map<String, Any>>())
                return
            }
            // Return already bonded devices since actual scanning requires a BroadcastReceiver
            // setup which is complex for a one-shot MethodChannel call.
            // For proper scanning, we'd need a foreground service with a ScanCallback.
            val knownDevices = adapter.bondedDevices.map { device ->
                hashMapOf<String, Any>(
                    "name" to (device.name ?: "Unknown"),
                    "address" to device.address,
                    "type" to when (device.type) {
                        BluetoothDevice.DEVICE_TYPE_CLASSIC -> "classic"
                        BluetoothDevice.DEVICE_TYPE_LE -> "le"
                        BluetoothDevice.DEVICE_TYPE_DUAL -> "dual"
                        else -> "unknown"
                    },
                    "bondState" to "bonded",
                )
            }
            result.success(knownDevices)
        } catch (e: Exception) {
            result.error("BT_SCAN_ERROR", e.message, null)
        }
    }

    private fun bluetoothConnect(call: MethodCall, result: MethodChannel.Result) {
        try {
            val address = call.argument<String>("address") ?:
                return result.error("INVALID_ARGS", "address required", null)
            val btManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
            val adapter = btManager.adapter
            if (adapter == null || !adapter.isEnabled) {
                result.error("BT_ERROR", "Bluetooth not enabled", null)
                return
            }
            val device = adapter.getRemoteDevice(address)
            if (device != null) {
                // Create a BOND if not already bonded
                if (device.bondState != BluetoothDevice.BOND_BONDED) {
                    device.createBond()
                }
                result.success(true)
            } else {
                result.error("BT_CONNECT_ERROR", "Device not found: $address", null)
            }
        } catch (e: Exception) {
            result.error("BT_CONNECT_ERROR", e.message, null)
        }
    }

    private fun bluetoothDisconnect(call: MethodCall, result: MethodChannel.Result) {
        try {
            val address = call.argument<String>("address")
            val btManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
            val adapter = btManager.adapter
            if (adapter != null && address != null) {
                try {
                    // Remove bond to disconnect
                    val device = adapter.getRemoteDevice(address)
                    if (device != null && device.bondState == BluetoothDevice.BOND_BONDED) {
                        // Use reflection to remove bond (no public API)
                        val method = device.javaClass.getMethod("removeBond")
                        method.invoke(device)
                    }
                } catch (_: Exception) {}
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("BT_DISCONNECT_ERROR", e.message, null)
        }
    }

    // ──────────────────────────────────────────────
    // NFC tag read/write
    // ──────────────────────────────────────────────

    private fun nfcReadTag(result: MethodChannel.Result) {
        // Reading NFC tags requires the Activity to handle NFC intents.
        // Since we route through MethodChannel, we need the Activity to have
        // captured an NFC intent first.
        result.error("NFC_NOT_READY",
            "Place the device near an NFC tag while the app is in foreground. " +
            "NFC tag data is received via system intents, not this channel.", null)
    }

    private fun nfcWriteTag(call: MethodCall, result: MethodChannel.Result) {
        val text = call.argument<String>("text") ?:
            return result.error("INVALID_ARGS", "text required", null)
        // Writing to an NFC tag also requires the Activity to handle the tag dispatch.
        // Use NfcAdapter.enableForegroundDispatch() from the Activity.
        result.error("NFC_NOT_READY",
            "NFC writing requires foreground dispatch from the Activity. " +
            "Open the app and hold near an NFC tag to use this feature.", null)
    }

    // ──────────────────────────────────────────────
    // Preferences
    // ──────────────────────────────────────────────

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