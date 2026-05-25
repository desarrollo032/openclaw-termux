package com.nxg.openclawproot

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.BatteryManager
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import android.app.Activity
import android.content.Context
import android.os.Environment
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.LocationManager
import android.media.projection.MediaProjectionManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.util.concurrent.ExecutorService
import java.io.File
import androidx.core.content.FileProvider

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.nxg.openclawproot/native"
    private val EVENT_CHANNEL = "com.nxg.openclawproot/gateway_logs"

    private lateinit var bootstrapManager: BootstrapManager
    private lateinit var processManager: ProcessManager
    private lateinit var cameraHelper: CameraHelper
    private lateinit var locationHelper: LocationHelper
    private lateinit var bleHelper: BleHelper
    private lateinit var usbSerialHelper: UsbSerialHelper
    private lateinit var ptyBridge: OpenClawPtyBridge
    private var screenCaptureResult: MethodChannel.Result? = null
    private var screenCaptureDurationMs: Long = 5000L
    private var cameraPhotoResult: MethodChannel.Result? = null
    private var cameraVideoResult: MethodChannel.Result? = null
    private var cameraOutputPath: String? = null
    private var setupDone = false
    private val executor = Executors.newCachedThreadPool()

    override fun onDestroy() {
        ptyBridge.destroy()
        executor.shutdownNow()
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val filesDir = applicationContext.filesDir.absolutePath
        val nativeLibDir = applicationContext.applicationInfo.nativeLibraryDir

        bootstrapManager = BootstrapManager(applicationContext, filesDir, nativeLibDir)
        processManager = ProcessManager(filesDir, nativeLibDir)
        cameraHelper = CameraHelper(applicationContext)
        locationHelper = LocationHelper(applicationContext)
        bleHelper = BleHelper(applicationContext)
        usbSerialHelper = UsbSerialHelper(applicationContext)
        ptyBridge = OpenClawPtyBridge(flutterEngine).register()

        // Ensure directories and resolv.conf exist on every app start.
        // Android may clear filesDir during APK update (#40).
        if (!setupDone) {
            setupDone = true
            executor.execute {
                try { bootstrapManager.setupDirectories() } catch (_: Exception) {}
                try { bootstrapManager.writeResolvConf() } catch (_: Exception) {}
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getProotPath" -> {
                    result.success(processManager.getProotPath())
                }
                "getArch" -> {
                    result.success(ArchUtils.getArch())
                }
                "getFilesDir" -> {
                    result.success(filesDir)
                }
                "getNativeLibDir" -> {
                    result.success(nativeLibDir)
                }
                "isBootstrapComplete" -> {
                    result.success(bootstrapManager.isBootstrapComplete())
                }
                "getBootstrapStatus" -> {
                    result.success(bootstrapManager.getBootstrapStatus())
                }
                "extractRootfs" -> {
                    val tarPath = call.argument<String>("tarPath")
                    if (tarPath != null) {
                        executor.execute {
                            try {
                                bootstrapManager.extractRootfs(tarPath)
                                runOnUiThread { result.success(true) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("EXTRACT_ERROR", e.message, null) }
                            }
                        }
                    } else {
                        result.error("INVALID_ARGS", "tarPath required", null)
                    }
                }
                "runInProot" -> {
                    val command = call.argument<String>("command")
                    val timeout = call.argument<Int>("timeout")?.toLong() ?: 900L
                    if (command != null) {
                        executor.execute {
                            try {
                                // Use recovery-aware execution with automatic
                                // dpkg/apt error detection and retry
                                val output = processManager.runInProotWithRecovery(command, timeout)
                                runOnUiThread { result.success(output) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("PROOT_ERROR", e.message, null) }
                            }
                        }
                    } else {
                        result.error("INVALID_ARGS", "command required", null)
                    }
                }
                "startGateway" -> {
                    try {
                        GatewayService.start(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "stopGateway" -> {
                    try {
                        GatewayService.stop(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "isGatewayRunning" -> {
                    result.success(GatewayService.isProcessAlive())
                }
                "startTerminalService" -> {
                    try {
                        TerminalSessionService.start(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "stopTerminalService" -> {
                    try {
                        TerminalSessionService.stop(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "isTerminalServiceRunning" -> {
                    result.success(TerminalSessionService.isRunning)
                }
                "startNodeService" -> {
                    try {
                        NodeForegroundService.start(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "stopNodeService" -> {
                    try {
                        NodeForegroundService.stop(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "isNodeServiceRunning" -> {
                    result.success(NodeForegroundService.isRunning)
                }
                "updateNodeNotification" -> {
                    val text = call.argument<String>("text") ?: "Node connected"
                    NodeForegroundService.updateStatus(text)
                    result.success(true)
                }
                "startSshd" -> {
                    val port = call.argument<Int>("port") ?: 8022
                    try {
                        SshForegroundService.start(applicationContext, port)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "stopSshd" -> {
                    try {
                        SshForegroundService.stop(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "isSshdRunning" -> {
                    result.success(SshForegroundService.isRunning)
                }
                "getSshdPort" -> {
                    result.success(SshForegroundService.currentPort)
                }
                "getDeviceIps" -> {
                    result.success(SshForegroundService.getDeviceIps())
                }
                "setRootPassword" -> {
                    val password = call.argument<String>("password")
                    if (password != null) {
                        executor.execute {
                            try {
                                val escaped = password.replace("'", "'\\''")
                                processManager.runInProotSync(
                                    "echo 'root:$escaped' | chpasswd", 15
                                )
                                runOnUiThread { result.success(true) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("SSH_ERROR", e.message, null) }
                            }
                        }
                    } else {
                        result.error("INVALID_ARGS", "password required", null)
                    }
                }
                "requestBatteryOptimization" -> {
                    try {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = Uri.parse("package:${packageName}")
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("BATTERY_ERROR", e.message, null)
                    }
                }
                "isBatteryOptimized" -> {
                    val pm = getSystemService(POWER_SERVICE) as PowerManager
                    result.success(!pm.isIgnoringBatteryOptimizations(packageName))
                }
                "getBatteryStatus" -> {
                    try {
                        val batteryIntent =
                            registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
                        if (batteryIntent == null) {
                            result.error("BATTERY_ERROR", "Battery status unavailable", null)
                            return@setMethodCallHandler
                        }

                        val level = batteryIntent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
                        val scale = batteryIntent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
                        val temperature =
                            batteryIntent.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, -1)
                        val voltage = batteryIntent.getIntExtra(BatteryManager.EXTRA_VOLTAGE, -1)
                        val status = batteryIntent.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
                        val plugged = batteryIntent.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0)

                        val percentage =
                            if (level >= 0 && scale > 0) ((level * 100f) / scale).toInt() else -1

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
                "setupDirs" -> {
                    executor.execute {
                        try {
                            bootstrapManager.setupDirectories()
                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("SETUP_ERROR", e.message, null) }
                        }
                    }
                }
                "installBionicBypass" -> {
                    executor.execute {
                        try {
                            bootstrapManager.installBionicBypass()
                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("BYPASS_ERROR", e.message, null) }
                        }
                    }
                }
                "writeResolv" -> {
                    executor.execute {
                        try {
                            bootstrapManager.writeResolvConf()
                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("RESOLV_ERROR", e.message, null) }
                        }
                    }
                }
                "extractDebPackages" -> {
                    executor.execute {
                        try {
                            val count = bootstrapManager.extractDebPackages()
                            runOnUiThread { result.success(count) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("DEB_EXTRACT_ERROR", e.message, null) }
                        }
                    }
                }
                "extractNodeTarball" -> {
                    val tarPath = call.argument<String>("tarPath")
                    if (tarPath != null) {
                        executor.execute {
                            try {
                                bootstrapManager.extractNodeTarball(tarPath)
                                runOnUiThread { result.success(true) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("NODE_EXTRACT_ERROR", e.message, null) }
                            }
                        }
                    } else {
                        result.error("INVALID_ARGS", "tarPath required", null)
                    }
                }
                "createBinWrappers" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        executor.execute {
                            try {
                                bootstrapManager.createBinWrappers(packageName)
                                runOnUiThread { result.success(true) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("BIN_WRAPPER_ERROR", e.message, null) }
                            }
                        }
                    } else {
                        result.error("INVALID_ARGS", "packageName required", null)
                    }
                }
                "startSetupService" -> {
                    try {
                        SetupService.start(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "updateSetupNotification" -> {
                    val text = call.argument<String>("text")
                    val progress = call.argument<Int>("progress") ?: -1
                    if (text != null) {
                        SetupService.updateNotification(text, progress)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "text required", null)
                    }
                }
                "stopSetupService" -> {
                    try {
                        SetupService.stop(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "showUrlNotification" -> {
                    val url = call.argument<String>("url")
                    val title = call.argument<String>("title") ?: "URL Detected"
                    if (url != null) {
                        showUrlNotification(url, title)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "url required", null)
                    }
                }
                "copyToClipboard" -> {
                    val text = call.argument<String>("text")
                    if (text != null) {
                        val clipboard = getSystemService(CLIPBOARD_SERVICE) as ClipboardManager
                        clipboard.setPrimaryClip(ClipData.newPlainText("URL", text))
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "text required", null)
                    }
                }
                "requestScreenCapture" -> {
                    val durationMs = call.argument<Int>("durationMs")?.toLong() ?: 5000L
                    screenCaptureResult = result
                    screenCaptureDurationMs = durationMs
                    ScreenCaptureService.clearResult()
                    val projectionManager =
                        getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                    startActivityForResult(
                        projectionManager.createScreenCaptureIntent(),
                        SCREEN_CAPTURE_REQUEST
                    )
                }
                "stopScreenCapture" -> {
                    try {
                        stopService(Intent(applicationContext, ScreenCaptureService::class.java))
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "vibrate" -> {
                    val durationMs = call.argument<Int>("durationMs")?.toLong() ?: 200L
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val vibratorManager =
                                getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                            val vibrator = vibratorManager.defaultVibrator
                            vibrator.vibrate(
                                VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE)
                            )
                        } else {
                            @Suppress("DEPRECATION")
                            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                vibrator.vibrate(
                                    VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE)
                                )
                            } else {
                                @Suppress("DEPRECATION")
                                vibrator.vibrate(durationMs)
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("VIBRATE_ERROR", e.message, null)
                    }
                }
                "requestStoragePermission" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            // Android 11+: MANAGE_EXTERNAL_STORAGE
                            if (!Environment.isExternalStorageManager()) {
                                val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                                startActivity(intent)
                            }
                        } else {
                            // Android 10 and below: READ/WRITE_EXTERNAL_STORAGE
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(
                                    Manifest.permission.READ_EXTERNAL_STORAGE,
                                    Manifest.permission.WRITE_EXTERNAL_STORAGE
                                ),
                                STORAGE_PERMISSION_REQUEST
                            )
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("STORAGE_ERROR", e.message, null)
                    }
                }
                "hasStoragePermission" -> {
                    val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        Environment.isExternalStorageManager()
                    } else {
                        ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
                    }
                    result.success(hasPermission)
                }
                "getExternalStoragePath" -> {
                    result.success(Environment.getExternalStorageDirectory().absolutePath)
                }
                "readRootfsFile" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        executor.execute {
                            try {
                                val content = bootstrapManager.readRootfsFile(path)
                                runOnUiThread { result.success(content) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("ROOTFS_READ_ERROR", e.message, null) }
                            }
                        }
                    } else {
                        result.error("INVALID_ARGS", "path required", null)
                    }
                }
                "writeRootfsFile" -> {
                    val path = call.argument<String>("path")
                    val content = call.argument<String>("content")
                    if (path != null && content != null) {
                        executor.execute {
                            try {
                                bootstrapManager.writeRootfsFile(path, content)
                                runOnUiThread { result.success(true) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("ROOTFS_WRITE_ERROR", e.message, null) }
                            }
                        }
                    } else {
                        result.error("INVALID_ARGS", "path and content required", null)
                    }
                }
                "bringToForeground" -> {
                    try {
                        val intent = Intent(applicationContext, MainActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                        }
                        applicationContext.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("FOREGROUND_ERROR", e.message, null)
                    }
                }
                "readSensor" -> {
                    val sensorType = call.argument<String>("sensor") ?: "accelerometer"
                    executor.execute {
                        try {
                            val sensorManager =
                                getSystemService(Context.SENSOR_SERVICE) as SensorManager
                            val type = when (sensorType) {
                                "accelerometer" -> Sensor.TYPE_ACCELEROMETER
                                "gyroscope" -> Sensor.TYPE_GYROSCOPE
                                "magnetometer" -> Sensor.TYPE_MAGNETIC_FIELD
                                "barometer" -> Sensor.TYPE_PRESSURE
                                else -> Sensor.TYPE_ACCELEROMETER
                            }
                            val sensor = sensorManager.getDefaultSensor(type)
                            if (sensor == null) {
                                runOnUiThread {
                                    result.error("SENSOR_ERROR", "Sensor $sensorType not available", null)
                                }
                                return@execute
                            }
                            var received = false
                            val listener = object : SensorEventListener {
                                override fun onSensorChanged(event: SensorEvent?) {
                                    if (received || event == null) return
                                    received = true
                                    sensorManager.unregisterListener(this)
                                    val data = hashMapOf<String, Any>(
                                        "sensor" to sensorType,
                                        "timestamp" to event.timestamp,
                                        "accuracy" to event.accuracy
                                    )
                                    when (sensorType) {
                                        "accelerometer", "gyroscope", "magnetometer" -> {
                                            data["x"] = event.values[0].toDouble()
                                            data["y"] = event.values[1].toDouble()
                                            data["z"] = event.values[2].toDouble()
                                        }
                                        "barometer" -> {
                                            data["pressure"] = event.values[0].toDouble()
                                        }
                                    }
                                    runOnUiThread { result.success(data) }
                                }
                                override fun onAccuracyChanged(s: Sensor?, accuracy: Int) {}
                            }
                            sensorManager.registerListener(
                                listener, sensor, SensorManager.SENSOR_DELAY_NORMAL
                            )
                            // Timeout after 3 seconds
                            Thread.sleep(3000)
                            if (!received) {
                                sensorManager.unregisterListener(listener)
                                runOnUiThread {
                                    result.error("SENSOR_ERROR", "Sensor read timed out", null)
                                }
                            }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("SENSOR_ERROR", e.message, null) }
                        }
                    }
                }
                // ──────────────────────────────────────────────
                // Native replacements for Flutter plugins
                // ──────────────────────────────────────────────
                "getAppInfo" -> {
                    try {
                        val pkgInfo = packageManager.getPackageInfo(packageName, 0)
                        val info = hashMapOf<String, Any>(
                            "packageName" to packageName,
                            "versionName" to (pkgInfo.versionName ?: ""),
                            "versionCode" to (
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
                                    pkgInfo.longVersionCode
                                else
                                    pkgInfo.versionCode.toLong()
                                )
                        )
                        result.success(info)
                    } catch (e: Exception) {
                        result.error("APP_INFO_ERROR", e.message, null)
                    }
                }
                "openUrl" -> {
                    val url = call.argument<String>("url")
                    if (url != null) {
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("URL_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGS", "url required", null)
                    }
                }
                "getString" -> {
                    val key = call.argument<String>("key")
                    if (key != null) {
                        val prefs = getSharedPreferences("openclaw_prefs", Context.MODE_PRIVATE)
                        result.success(prefs.getString(key, null))
                    } else {
                        result.error("INVALID_ARGS", "key required", null)
                    }
                }
                "saveString" -> {
                    val key = call.argument<String>("key")
                    val value = call.argument<String>("value")
                    if (key != null && value != null) {
                        getSharedPreferences("openclaw_prefs", Context.MODE_PRIVATE)
                            .edit()
                            .putString(key, value)
                            .apply()
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "key and value required", null)
                    }
                }
                "getBool" -> {
                    val key = call.argument<String>("key")
                    if (key != null) {
                        val prefs = getSharedPreferences("openclaw_prefs", Context.MODE_PRIVATE)
                        result.success(prefs.getBoolean(key, false))
                    } else {
                        result.error("INVALID_ARGS", "key required", null)
                    }
                }
                "saveBool" -> {
                    val key = call.argument<String>("key")
                    val value = call.argument<Boolean>("value")
                    if (key != null && value != null) {
                        getSharedPreferences("openclaw_prefs", Context.MODE_PRIVATE)
                            .edit()
                            .putBoolean(key, value)
                            .apply()
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "key and value required", null)
                    }
                }
                "getInt" -> {
                    val key = call.argument<String>("key")
                    if (key != null) {
                        val prefs = getSharedPreferences("openclaw_prefs", Context.MODE_PRIVATE)
                        val value = prefs.getInt(key, Int.MIN_VALUE)
                        result.success(if (value == Int.MIN_VALUE) null else value)
                    } else {
                        result.error("INVALID_ARGS", "key required", null)
                    }
                }
                "saveInt" -> {
                    val key = call.argument<String>("key")
                    val value = call.argument<Int?>("value")
                    if (key != null && value != null) {
                        getSharedPreferences("openclaw_prefs", Context.MODE_PRIVATE)
                            .edit()
                            .putInt(key, value)
                            .apply()
                        result.success(true)
                    } else if (key != null) {
                        getSharedPreferences("openclaw_prefs", Context.MODE_PRIVATE)
                            .edit()
                            .remove(key)
                            .apply()
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "key required", null)
                    }
                }
                "removeKey" -> {
                    val key = call.argument<String>("key")
                    if (key != null) {
                        getSharedPreferences("openclaw_prefs", Context.MODE_PRIVATE)
                            .edit()
                            .remove(key)
                            .apply()
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "key required", null)
                    }
                }
                "clearPrefs" -> {
                    getSharedPreferences("openclaw_prefs", Context.MODE_PRIVATE)
                        .edit()
                        .clear()
                        .apply()
                    result.success(true)
                }
                "checkPermission" -> {
                    val permission = call.argument<String>("permission")
                    if (permission != null) {
                        val granted = ContextCompat.checkSelfPermission(this, permission) ==
                                PackageManager.PERMISSION_GRANTED
                        result.success(granted)
                    } else {
                        result.error("INVALID_ARGS", "permission required", null)
                    }
                }
                "requestPermission" -> {
                    val permission = call.argument<String>("permission")
                    if (permission != null) {
                        ActivityCompat.requestPermissions(
                            this, arrayOf(permission), GENERAL_PERMISSION_REQUEST
                        )
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "permission required", null)
                    }
                }
                // ──────────────────────────────────────────────
                // WebView (native Activity)
                // ──────────────────────────────────────────────
                "openWebDashboard" -> {
                    val url = call.argument<String>("url") ?: "http://localhost:9090"
                    val intent = Intent(this, WebViewActivity::class.java).apply {
                        putExtra(WebViewActivity.EXTRA_URL, url)
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    }
                    startActivity(intent)
                    result.success(true)
                }

                // ──────────────────────────────────────────────
                // Camera — torch/flash (via CameraManager)
                // ──────────────────────────────────────────────
                "getCameraList" -> {
                    executor.execute {
                        try {
                            val cameras = cameraHelper.listCameras()
                            val list = cameras.map { c ->
                                hashMapOf<String, Any>("id" to c.id, "facing" to c.facing)
                            }
                            runOnUiThread { result.success(list) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("CAMERA_ERROR", e.message, null) }
                        }
                    }
                }
                "toggleTorch" -> {
                    val on = call.argument<Boolean>("on") ?: false
                    try {
                        val success = cameraHelper.setTorch(on)
                        result.success(success)
                    } catch (e: Exception) {
                        result.error("TORCH_ERROR", e.message, null)
                    }
                }
                "isTorchAvailable" -> {
                    result.success(cameraHelper.isTorchAvailable())
                }
                "cameraSnap" -> {
                    try {
                        val facing = call.argument<String>("facing")
                        val (intent, filePath) = cameraHelper.createPhotoIntent(facing)
                        cameraPhotoResult = result
                        cameraOutputPath = filePath
                        startActivityForResult(intent, CAMERA_PHOTO_REQUEST)
                    } catch (e: Exception) {
                        result.error("CAMERA_ERROR", e.message, null)
                    }
                }
                "cameraClip" -> {
                    val durationMs = call.argument<Int>("durationMs") ?: 5000
                    try {
                        val (intent, filePath) = cameraHelper.createVideoIntent(durationMs)
                        cameraVideoResult = result
                        cameraOutputPath = filePath
                        startActivityForResult(intent, CAMERA_VIDEO_REQUEST)
                    } catch (e: Exception) {
                        result.error("CAMERA_ERROR", e.message, null)
                    }
                }

                // ──────────────────────────────────────────────
                // Location (via LocationManager)
                // ──────────────────────────────────────────────
                "isLocationServiceEnabled" -> {
                    result.success(locationHelper.isLocationServiceEnabled())
                }
                "getCurrentLocation" -> {
                    executor.execute {
                        try {
                            val loc = locationHelper.getCurrentLocation()
                            if (loc != null) {
                                val data = hashMapOf<String, Any>(
                                    "latitude" to loc.latitude,
                                    "longitude" to loc.longitude,
                                    "accuracy" to loc.accuracy.toDouble(),
                                    "altitude" to loc.altitude,
                                    "timestamp" to loc.timestamp
                                )
                                runOnUiThread { result.success(data) }
                            } else {
                                runOnUiThread { result.error("LOCATION_ERROR", "Could not determine location", null) }
                            }
                        } catch (e: SecurityException) {
                            runOnUiThread { result.error("PERMISSION_DENIED", "Location permission not granted", null) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("LOCATION_ERROR", e.message, null) }
                        }
                    }
                }

                // ──────────────────────────────────────────────
                // BLE (via BluetoothLeScanner + BluetoothGatt)
                // ──────────────────────────────────────────────
                "bleScan" -> {
                    val timeoutMs = call.argument<Int>("timeoutMs")?.toLong() ?: 3000L
                    executor.execute {
                        try {
                            val devices = bleHelper.scan(timeoutMs)
                            val list = devices.map { d ->
                                hashMapOf<String, Any>(
                                    "id" to d.id,
                                    "name" to d.name,
                                    "rssi" to d.rssi
                                )
                            }
                            runOnUiThread { result.success(list) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("BLE_ERROR", e.message, null) }
                        }
                    }
                }
                "bleConnect" -> {
                    val deviceId = call.argument<String>("deviceId")
                    if (deviceId != null) {
                        executor.execute {
                            try {
                                val success = bleHelper.connect(deviceId)
                                runOnUiThread { result.success(success) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("BLE_ERROR", e.message, null) }
                            }
                        }
                    } else {
                        result.error("INVALID_ARGS", "deviceId required", null)
                    }
                }
                "bleDisconnect" -> {
                    val deviceId = call.argument<String>("deviceId")
                    if (deviceId != null) {
                        executor.execute {
                            try {
                                bleHelper.disconnect(deviceId)
                                runOnUiThread { result.success(true) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("BLE_ERROR", e.message, null) }
                            }
                        }
                    } else {
                        bleHelper.disconnectAll()
                        result.success(true)
                    }
                }
                "bleWrite" -> {
                    val deviceId = call.argument<String>("deviceId")
                    val data = call.argument<ByteArray>("data")
                    if (deviceId != null && data != null) {
                        executor.execute {
                            try {
                                val success = bleHelper.write(deviceId, data)
                                runOnUiThread { result.success(success) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("BLE_ERROR", e.message, null) }
                            }
                        }
                    } else {
                        result.error("INVALID_ARGS", "deviceId and data required", null)
                    }
                }
                "bleRead" -> {
                    val deviceId = call.argument<String>("deviceId")
                    val timeoutMs = call.argument<Int>("timeoutMs") ?: 2000
                    if (deviceId != null) {
                        executor.execute {
                            try {
                                val data = bleHelper.read(deviceId, timeoutMs.toLong())
                                if (data != null) {
                                    runOnUiThread { result.success(data) }
                                } else {
                                    runOnUiThread { result.success(null) }
                                }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("BLE_ERROR", e.message, null) }
                            }
                        }
                    } else {
                        result.error("INVALID_ARGS", "deviceId required", null)
                    }
                }
                "bleListServices" -> {
                    val deviceId = call.argument<String>("deviceId")
                    if (deviceId != null) {
                        executor.execute {
                            try {
                                val services = bleHelper.discoverServices(deviceId)
                                val list = services.map { s ->
                                    hashMapOf<String, Any>(
                                        "uuid" to s.uuid,
                                        "characteristics" to s.characteristics.map { c ->
                                            hashMapOf<String, Any>(
                                                "uuid" to c.uuid,
                                                "properties" to c.properties
                                            )
                                        }
                                    )
                                }
                                runOnUiThread { result.success(list) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("BLE_ERROR", e.message, null) }
                            }
                        }
                    } else {
                        result.error("INVALID_ARGS", "deviceId required", null)
                    }
                }

                // ──────────────────────────────────────────────
                // USB Serial (via UsbManager)
                // ──────────────────────────────────────────────
                "usbList" -> {
                    executor.execute {
                        try {
                            val devices = usbSerialHelper.listDevices()
                            val list = devices.map { d ->
                                hashMapOf<String, Any>(
                                    "deviceId" to d.deviceId,
                                    "name" to d.name,
                                    "vendorId" to d.vendorId,
                                    "productId" to d.productId
                                )
                            }
                            runOnUiThread { result.success(list) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("USB_ERROR", e.message, null) }
                        }
                    }
                }
                "usbConnect" -> {
                    val deviceId = call.argument<Int>("deviceId")
                    val baudRate = call.argument<Int>("baudRate") ?: 115200
                    if (deviceId != null) {
                        executor.execute {
                            try {
                                val success = usbSerialHelper.connect(deviceId, baudRate)
                                runOnUiThread { result.success(success) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("USB_ERROR", e.message, null) }
                            }
                        }
                    } else {
                        result.error("INVALID_ARGS", "deviceId required", null)
                    }
                }
                "usbDisconnect" -> {
                    val deviceId = call.argument<Int>("deviceId")
                    if (deviceId != null) {
                        usbSerialHelper.disconnect(deviceId)
                        result.success(true)
                    } else {
                        usbSerialHelper.disconnectAll()
                        result.success(true)
                    }
                }
                "usbWrite" -> {
                    val deviceId = call.argument<Int>("deviceId")
                    val data = call.argument<ByteArray>("data")
                    if (deviceId != null && data != null) {
                        executor.execute {
                            try {
                                val success = usbSerialHelper.write(deviceId, data)
                                runOnUiThread { result.success(success) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("USB_ERROR", e.message, null) }
                            }
                        }
                    } else {
                        result.error("INVALID_ARGS", "deviceId and data required", null)
                    }
                }
                "usbRead" -> {
                    val deviceId = call.argument<Int>("deviceId")
                    val timeoutMs = call.argument<Int>("timeoutMs") ?: 2000
                    if (deviceId != null) {
                        executor.execute {
                            try {
                                val data = usbSerialHelper.read(deviceId, timeoutMs)
                                if (data != null) {
                                    runOnUiThread { result.success(data) }
                                } else {
                                    runOnUiThread { result.success(null) }
                                }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("USB_ERROR", e.message, null) }
                            }
                        }
                    } else {
                        result.error("INVALID_ARGS", "deviceId required", null)
                    }
                }

                "isPermissionPermanentlyDenied" -> {
                    val permission = call.argument<String>("permission")
                    if (permission != null) {
                        val denied = !ActivityCompat.shouldShowRequestPermissionRationale(this, permission)
                        // If permission hasn't been requested yet, shouldShowRequestPermissionRationale
                        // also returns false. Check if it's actually denied first.
                        val isGranted = ContextCompat.checkSelfPermission(this, permission) ==
                                PackageManager.PERMISSION_GRANTED
                        result.success(!isGranted && denied)
                    } else {
                        result.error("INVALID_ARGS", "permission required", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        createUrlNotificationChannel()
        requestNotificationPermission()

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    GatewayService.logSink = events
                }
                override fun onCancel(arguments: Any?) {
                    GatewayService.logSink = null
                }
            }
        )
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    NOTIFICATION_PERMISSION_REQUEST
                )
            }
        }
    }

    private fun createUrlNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                URL_CHANNEL_ID,
                "OpenClaw URLs",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for detected URLs"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private var urlNotificationId = 100

    private fun showUrlNotification(url: String, title: String) {
        val openIntent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
        val openPending = PendingIntent.getActivity(
            this, urlNotificationId, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, URL_CHANNEL_ID)
                .setContentTitle(title)
                .setContentText(url)
                .setSmallIcon(android.R.drawable.ic_menu_share)
                .setContentIntent(openPending)
                .setAutoCancel(true)
                .setStyle(Notification.BigTextStyle().bigText(url))
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle(title)
                .setContentText(url)
                .setSmallIcon(android.R.drawable.ic_menu_share)
                .setContentIntent(openPending)
                .setAutoCancel(true)
                .build()
        }

        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(urlNotificationId++, notification)
    }

    /** Returns the file path of the camera output for Dart to read directly. */

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == CAMERA_PHOTO_REQUEST) {
            val photoResult = cameraPhotoResult
            cameraPhotoResult = null
            if (resultCode == Activity.RESULT_OK) {
                runOnUiThread { photoResult?.success(cameraOutputPath) }
            } else {
                photoResult?.success(null)
            }
            cameraOutputPath = null
            return
        }
        if (requestCode == CAMERA_VIDEO_REQUEST) {
            val videoResult = cameraVideoResult
            cameraVideoResult = null
            if (resultCode == Activity.RESULT_OK) {
                runOnUiThread { videoResult?.success(cameraOutputPath) }
            } else {
                videoResult?.success(null)
            }
            cameraOutputPath = null
            return
        }
        if (requestCode == SCREEN_CAPTURE_REQUEST) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val intent = Intent(applicationContext, ScreenCaptureService::class.java).apply {
                    putExtra("resultCode", resultCode)
                    putExtra("data", data)
                    putExtra("durationMs", screenCaptureDurationMs)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(intent)
                } else {
                    startService(intent)
                }
                // Poll for result
                executor.execute {
                    val startTime = System.currentTimeMillis()
                    val timeout = screenCaptureDurationMs + 5000L
                    while (ScreenCaptureService.resultPath == null &&
                        System.currentTimeMillis() - startTime < timeout
                    ) {
                        Thread.sleep(200)
                    }
                    val path = ScreenCaptureService.resultPath
                    runOnUiThread {
                        screenCaptureResult?.success(path)
                        screenCaptureResult = null
                    }
                }
            } else {
                screenCaptureResult?.success(null)
                screenCaptureResult = null
            }
        }
    }

    companion object {
        const val URL_CHANNEL_ID = "openclaw_urls"
        const val NOTIFICATION_PERMISSION_REQUEST = 1001
        const val SCREEN_CAPTURE_REQUEST = 1002
        const val STORAGE_PERMISSION_REQUEST = 1003
        const val GENERAL_PERMISSION_REQUEST = 1004
        const val CAMERA_PHOTO_REQUEST = 1005
        const val CAMERA_VIDEO_REQUEST = 1006
    }
}
