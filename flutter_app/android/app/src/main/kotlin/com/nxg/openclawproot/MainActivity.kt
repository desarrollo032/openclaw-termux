package com.nxg.openclawproot

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import android.Manifest
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.nxg.openclawproot.handlers.*
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

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

    private val handlers = mutableListOf<BaseHandler>()

    override fun onDestroy() {
        ptyBridge.destroy()
        executor.shutdownNow()
        super.onDestroy()
    }

    fun setCameraPhotoResult(result: MethodChannel.Result, path: String) {
        cameraPhotoResult = result
        cameraOutputPath = path
    }

    fun setCameraVideoResult(result: MethodChannel.Result, path: String) {
        cameraVideoResult = result
        cameraOutputPath = path
    }

    fun setScreenCaptureResult(result: MethodChannel.Result, durationMs: Long) {
        screenCaptureResult = result
        screenCaptureDurationMs = durationMs
        ScreenCaptureService.clearResult()
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

        handlers.add(SystemHandler(applicationContext, this))
        handlers.add(HardwareHandler(applicationContext, this, executor, cameraHelper, locationHelper, bleHelper, usbSerialHelper))
        handlers.add(ProcessHandler(applicationContext, this, executor, bootstrapManager, processManager))

        if (!setupDone) {
            setupDone = true
            executor.execute {
                try { bootstrapManager.setupDirectories() } catch (_: Exception) {}
                try { bootstrapManager.writeResolvConf() } catch (_: Exception) {}
            }
        }

        // MethodChannel calls arrive on the main thread (Flutter's default).
        // Heavy operations (proot, I/O) are internally dispatched to executor
        // by each handler. Lightweight ops (flag checks, getters) run inline.
        // Android APIs like startActivity() and requestPermissions() require
        // the main thread, so we must NOT dispatch the handler to a bg thread.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            var handled = false
            for (handler in handlers) {
                if (handler.handleMethodCall(call, result)) {
                    handled = true
                    break
                }
            }
            if (!handled) {
                result.notImplemented()
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

    fun requestStoragePermission(result: MethodChannel.Result) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                if (!Environment.isExternalStorageManager()) {
                    val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                    startActivity(intent)
                }
            } else {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE, Manifest.permission.WRITE_EXTERNAL_STORAGE),
                    STORAGE_PERMISSION_REQUEST
                )
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("STORAGE_ERROR", e.message, null)
        }
    }

    fun hasStoragePermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
        }
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
        val channel = NotificationChannel(
            URL_CHANNEL_ID,
            "URLs",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Detected URL notifications"
            setShowBadge(false)
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    private var urlNotificationId = 100

    fun showUrlNotification(url: String, title: String) {
        val openIntent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
        val openPending = PendingIntent.getActivity(
            this, urlNotificationId, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = Notification.Builder(this, URL_CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(url)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(openPending)
            .setAutoCancel(true)
            .setStyle(Notification.BigTextStyle().bigText(url))
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .build()

        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(urlNotificationId++, notification)
    }

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
                startForegroundService(intent)
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
