package com.nxg.openclawproot

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.ComponentCallbacks2
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import io.flutter.plugin.common.EventChannel
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class GatewayService : Service() {
    companion object {
        const val CHANNEL_ID = "openclaw_services"
        const val NOTIFICATION_ID = 1
        var isRunning = false
            private set
        var logSink: EventChannel.EventSink? = null
        private var instance: GatewayService? = null
        private val mainHandler = Handler(Looper.getMainLooper())
        private var logHandlerThread: HandlerThread? = null
        private var logHandler: Handler? = null

        /** Runtime resource guard — manages cleanup and diagnostics. */
        private var runtimeGuard: GatewayRuntimeGuard? = null

        init {
            logHandlerThread = HandlerThread("gateway-log-emitter").apply { start() }
            logHandler = Handler(logHandlerThread!!.looper)
        }

        /** Set the runtime mode from Flutter. */
        fun setRuntimeMode(mode: String) {
            instance?.let { svc ->
                val guard = svc.runtimeGuard ?: GatewayRuntimeGuard(svc)
                when (mode.uppercase()) {
                    "INSTALL" -> guard.enterInstallMode()
                    "TERMINAL" -> guard.enterTerminalMode()
                    "GATEWAY" -> guard.enterGatewayMode()
                    else -> {}
                }
            }
        }

        /** Collect runtime diagnostics for Flutter. */
        fun getRuntimeDiagnostics(): Map<String, Any> {
            val inst = instance ?: return emptyMap()
            val guard = inst.runtimeGuard ?: GatewayRuntimeGuard(inst)
            return guard.collectRuntimeDiagnostics()
        }

        fun isProcessAlive(): Boolean {
            val inst = instance ?: return false
            if (!isRunning) return false
            val proc = inst.gatewayProcess
            if (proc != null) return proc.isAlive
            val thread = inst.gatewayThread
            if (thread != null && thread.isAlive) return true
            val elapsed = System.currentTimeMillis() - inst.startTime
            return elapsed < 120_000
        }

        fun start(context: Context) {
            val intent = Intent(context, GatewayService::class.java)
            context.startForegroundService(intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, GatewayService::class.java)
            context.stopService(intent)
        }

        fun releaseResources() {
            // Only release if the service is not running.
            // The logHandlerThread is shared across service lifetimes;
            // quitting it while the gateway is active will break log emission.
            if (!isRunning) {
                logHandlerThread?.quitSafely()
                logHandlerThread = null
                logHandler = null
            }
        }
    }

    private var gatewayProcess: Process? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var restartCount = 0
    private val maxRestarts = 5
    private var startTime: Long = 0
    private var processStartTime: Long = 0
    private var uptimeThread: Thread? = null
    private var watchdogThread: Thread? = null
    private var gatewayThread: Thread? = null
    private val lock = Object()
    @Volatile private var stopping = false

    /** Runtime resource guard — initialized lazily on first gateway start. */
    private val runtimeGuard: GatewayRuntimeGuard by lazy {
        GatewayRuntimeGuard(this)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, buildNotification("Starting..."))
        if (isRunning) {
            updateNotificationRunning()
            return START_STICKY
        }
        stopping = false
        acquireWakeLock()
        ensureDnsConfig()
        startGateway()
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        instance = null
        uptimeThread?.interrupt()
        uptimeThread = null
        watchdogThread?.interrupt()
        watchdogThread = null
        stopGateway(force = true)
        releaseWakeLock()
        super.onDestroy()
    }

    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        if (level >= ComponentCallbacks2.TRIM_MEMORY_RUNNING_CRITICAL) {
            // Android is under severe memory pressure — evict cached configs
            // but keep the gateway alive. The log buffer can be cleared first.
            android.util.Log.w("GatewayService", "TRIM_MEMORY_CRITICAL received")
        }
        if (level >= ComponentCallbacks2.TRIM_MEMORY_COMPLETE) {
            // Process is about to be killed — release all non-essential resources
            releaseWakeLock()
        }
    }

    private fun ensureDnsConfig() {
        try {
            val filesDir = applicationContext.filesDir.absolutePath
            val resolvContent = "nameserver 8.8.8.8\nnameserver 8.8.4.4\nnameserver 1.1.1.1\nnameserver 1.0.0.1\n"
            val resolvFile = File("$filesDir/config/resolv.conf")
            resolvFile.parentFile?.mkdirs()
            if (!resolvFile.exists() || resolvFile.length() == 0L) {
                resolvFile.writeText(resolvContent)
            }
            val rootfsResolv = File("$filesDir/rootfs/ubuntu/etc/resolv.conf")
            rootfsResolv.parentFile?.mkdirs()
            if (!rootfsResolv.exists() || rootfsResolv.length() == 0L) {
                rootfsResolv.writeText(resolvContent)
            }
        } catch (_: Exception) {}
    }

    private fun isPortInUse(port: Int = 18789): Boolean {
        return try {
            Socket().use { socket ->
                socket.connect(InetSocketAddress("127.0.0.1", port), 1000)
                true
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun startGateway() {
        synchronized(lock) {
            if (stopping) return
            if (gatewayProcess?.isAlive == true) return
            isRunning = true
            instance = this
            startTime = System.currentTimeMillis()
        }

        gatewayThread = Thread {
            try {
                if (isPortInUse()) {
                    emitLog("[INFO] Gateway already running on port 18789, adopting existing instance")
                    updateNotificationRunning()
                    startUptimeTicker()
                    startWatchdog()
                    return@Thread
                }

                emitLog("[gateway] starting")
                val filesDir = applicationContext.filesDir.absolutePath
                val nativeLibDir = applicationContext.applicationInfo.nativeLibraryDir
                val pm = ProcessManager(filesDir, nativeLibDir)

                val bootstrapManager = BootstrapManager(applicationContext, filesDir, nativeLibDir)
                try {
                    bootstrapManager.setupDirectories()
                    emitLog("[gateway] directories ready")
                } catch (e: Exception) {
                    emitLog("[gateway] WARN: setupDirectories failed: ${e.message}")
                }
                try {
                    bootstrapManager.writeResolvConf()
                } catch (e: Exception) {
                    emitLog("[WARN] writeResolvConf failed: ${e.message}")
                }
                try {
                    GatewayRuntimeFiles.ensure(filesDir)
                    emitLog("[gateway] runtime files ready")
                } catch (e: Exception) {
                    emitLog("[gateway] WARN: runtime optimization skipped: ${e.message}")
                }

                val resolvContent = "nameserver 8.8.8.8\nnameserver 8.8.4.4\n"
                try {
                    val resolvFile = File(filesDir, "config/resolv.conf")
                    if (!resolvFile.exists() || resolvFile.length() == 0L) {
                        resolvFile.parentFile?.mkdirs()
                        resolvFile.writeText(resolvContent)
                        emitLog("[INFO] resolv.conf created (inline fallback)")
                    }
                } catch (e: Exception) {
                    emitLog("[WARN] inline resolv.conf fallback failed: ${e.message}")
                }
                try {
                    val rootfsResolv = File(filesDir, "rootfs/ubuntu/etc/resolv.conf")
                    if (!rootfsResolv.exists() || rootfsResolv.length() == 0L) {
                        rootfsResolv.parentFile?.mkdirs()
                        rootfsResolv.writeText(resolvContent)
                    }
                } catch (_: Exception) {}

                if (stopping) return@Thread

                if (isPortInUse()) {
                    emitLog("Gateway already running on port 18789, skipping launch")
                    updateNotificationRunning()
                    startUptimeTicker()
                    startWatchdog()
                    return@Thread
                }

                // ── Runtime resource cleanup ─────────────────────────────────
                // Before spawning the gateway, stop non-essential services and
                // kill stale/zombie processes (openclaw-doctor, npm, apt, etc.).
                // This frees ~400+ MB RSS for the gateway.
                emitLog("[gateway] cleaning non-gateway services and processes")
                try {
                    runtimeGuard.keepOnlyGatewayAndTerminal()
                    emitLog("[gateway] resource cleanup complete")
                } catch (e: Exception) {
                    emitLog("[gateway] WARN: resource cleanup failed: ${e.message}")
                }

                emitLog("[gateway] cleaning stale temp files")
                try {
                    pm.cleanupGatewayTempFiles()
                } catch (_: Exception) {}

                // ── Verify cleanup ───────────────────────────────────────────
                // Check that openclaw-doctor zombie was killed
                try {
                    val remainingZombie = Runtime.getRuntime().exec(arrayOf("ps", "-A"))
                    val zombieCheck = remainingZombie.inputStream.bufferedReader().readText()
                    if ("openclaw-doctor" in zombieCheck) {
                        emitLog("[gateway] WARN: openclaw-doctor still alive, retrying kill")
                        Runtime.getRuntime().exec(arrayOf("kill", "-9", "\$(pgrep -x openclaw-doctor 2>/dev/null)"))
                    }
                } catch (_: Exception) {}

                emitLog("[gateway] spawning proot")
                synchronized(lock) {
                    if (stopping) return@Thread
                    processStartTime = System.currentTimeMillis()
                    gatewayProcess = pm.startProotProcess("openclaw gateway")
                }
                updateNotificationRunning()
                emitLog("[gateway] process spawned")

                // ── Post-start diagnostics ──────────────────────────────────
                // Verify gateway PID and port availability
                try {
                    val diag = runtimeGuard.collectRuntimeDiagnostics()
                    val pidGateway = diag["pidGateway"] ?: -1
                    val portActive = diag["port18789Active"] ?: false
                    emitLog("[gateway] PID=$pidGateway port=18789/$portActive")
                } catch (_: Exception) {}

                startUptimeTicker()
                startWatchdog()

                val proc = gatewayProcess!!

                // Read stdout — use ExecutorService to avoid raw Thread overhead
                val stdoutReader = BufferedReader(InputStreamReader(proc.inputStream))
                val stderrReader = BufferedReader(InputStreamReader(proc.errorStream))
                val currentRestartCount = restartCount

                // Filter patterns for repetitive proot/gateway warnings.
                // These are harmless but flood the log buffer:
                //   - "proot warning: can't sanitize ..." (proot internal)
                //   - "/proc/self/fd" (stdin/stdout bind mount noise)
                //   - "InsetsController", "ViewRootImpl" (Android UI — irrelevant)
                val filterPatterns = listOf(
                    "proot warning",
                    "can't sanitize",
                    "/proc/self/fd",
                    "InsetsController",
                    "ViewRootImpl",
                    "Sending viewport metrics",
                    "NotifHistoryProto",
                )

                val stdoutThread = Thread {
                    try {
                        var line: String?
                        while (stdoutReader.readLine().also { line = it } != null) {
                            val l = line ?: continue
                            if (filterPatterns.any { l.contains(it) }) continue
                            emitLog(l)
                        }
                    } catch (_: Exception) {}
                }.apply { name = "gateway-stdout-reader"; isDaemon = true }
                stdoutThread.start()

                val stderrThread = Thread {
                    try {
                        var line: String?
                        while (stderrReader.readLine().also { line = it } != null) {
                            val l = line ?: continue
                            if (filterPatterns.any { l.contains(it) }) continue
                            emitLog("[ERR] $l")
                        }
                    } catch (_: Exception) {}
                }.apply { name = "gateway-stderr-reader"; isDaemon = true }
                stderrThread.start()

                val exitCode = proc.waitFor()
                val uptimeMs = System.currentTimeMillis() - processStartTime
                val uptimeSec = uptimeMs / 1000
                emitLog("[gateway] exited code $exitCode (uptime: ${uptimeSec}s)")

                if (stopping) return@Thread

                if (uptimeMs > 60_000) {
                    restartCount = 0
                }

                if (isRunning && restartCount < maxRestarts) {
                    restartCount++
                    val delayMs = minOf(2000L * (1 shl (restartCount - 1)), 16000L)
                    emitLog("[gateway] auto-restart in ${delayMs / 1000}s (attempt $restartCount/$maxRestarts)")
                    updateNotification("Restarting in ${delayMs / 1000}s (attempt $restartCount)...")
                    Thread.sleep(delayMs)
                    if (!stopping) {
                        startTime = System.currentTimeMillis()
                        startGateway()
                    }
                } else if (restartCount >= maxRestarts) {
                    emitLog("[gateway] WARN: max restarts reached, stopped")
                    updateNotification("Gateway stopped (crashed)")
                    isRunning = false
                }
            } catch (e: Exception) {
                if (!stopping) {
                    emitLog("[gateway] ERROR: ${e.message}")
                    isRunning = false
                    updateNotification("Gateway error")
                }
            }
        }.also { it.start() }
    }

    private fun stopGateway(force: Boolean = false) {
        val procToStop: Process?
        synchronized(lock) {
            stopping = true
            if (!force) restartCount = maxRestarts
            uptimeThread?.interrupt()
            uptimeThread = null
            watchdogThread?.interrupt()
            watchdogThread = null
            gatewayThread?.interrupt()
            gatewayThread = null
            procToStop = gatewayProcess
            gatewayProcess = null
        }
        emitLog("[gateway] stopping")
        // Reset runtime mode back to IDLE
        try {
            runtimeGuard.enterIdleMode()
        } catch (_: Exception) {}
        procToStop?.let { proc ->
            Thread({
                try {
                    // First attempt: SIGTERM — lets proot --kill-on-exit clean up children
                    // This triggers proot's exit handler which sends SIGTERM to all
                    // tracked child PIDs (Node.js, openclaw, etc.)
                    proc.destroy()
                    if (!proc.waitFor(5, java.util.concurrent.TimeUnit.SECONDS)) {
                        // Second attempt: SIGKILL after grace period.
                        // proot is tracked as Android child process too, so if proot
                        // doesn't respond to SIGTERM within 5s, force-kill it.
                        // Note: this bypasses proot's --kill-on-exit handler, so
                        // Node.js may be orphaned — Android's process cgroup will
                        // eventually clean it up.
                        proc.destroyForcibly()
                        proc.waitFor(3, java.util.concurrent.TimeUnit.SECONDS)
                    }
                } catch (_: Exception) {
                    try { proc.destroyForcibly() } catch (_: Exception) {}
                }
                // Post-cleanup: remove stale temp files from previous session
                try {
                    val pm = ProcessManager(
                        applicationContext.filesDir.absolutePath,
                        applicationContext.applicationInfo.nativeLibraryDir
                    )
                    pm.runInProotSync("/bin/rm -rf /tmp/openclaw-* 2>/dev/null", 10)
                } catch (_: Exception) {}
            }, "gateway-stop").apply { isDaemon = true }.start()
        }
        emitLog("[gateway] stop complete — resources released")
    }

    private fun startWatchdog() {
        watchdogThread?.interrupt()
        watchdogThread = Thread {
            try {
                Thread.sleep(25_000)
                while (!Thread.interrupted() && isRunning && !stopping) {
                    val proc = gatewayProcess
                    if (proc != null && !proc.isAlive) {
                        emitLog("[gateway] WARN: watchdog - process not alive")
                        break
                    }
                    if (proc != null && !isPortInUse()) {
                        emitLog("[gateway] WARN: watchdog - port 18789 not responding")
                    }
                    Thread.sleep(15_000)
                }
            } catch (_: InterruptedException) {}
        }.apply { isDaemon = true; start() }
    }

    private fun startUptimeTicker() {
        uptimeThread?.interrupt()
        uptimeThread = Thread {
            try {
                while (!Thread.interrupted() && isRunning) {
                    Thread.sleep(60_000)
                    if (isRunning) {
                        updateNotificationRunning()
                    }
                }
            } catch (_: InterruptedException) {}
        }.apply { isDaemon = true; start() }
    }

    private fun formatUptime(): String {
        val elapsed = System.currentTimeMillis() - startTime
        val seconds = elapsed / 1000
        val minutes = seconds / 60
        val hours = minutes / 60
        return when {
            hours > 0 -> "${hours}h ${minutes % 60}m"
            minutes > 0 -> "${minutes}m"
            else -> "${seconds}s"
        }
    }

    private fun updateNotificationRunning() {
        updateNotification("Running on port 18789 \u2022 ${formatUptime()}")
    }

    private val logBuffer = mutableListOf<String>()
    private val logBufferLock = Any()
    private var logFlushPosted = false
    private val logFlushRunnable = Runnable { flushLogBuffer() }

    private fun emitLog(message: String) {
        try {
            val ts = java.time.Instant.now().toString()
            val formatted = "$ts $message"
            val h = logHandler
            if (h != null) {
                synchronized(logBufferLock) {
                    logBuffer.add(formatted)
                    if (!logFlushPosted && logBuffer.size < 50) {
                        logFlushPosted = true
                        h.postDelayed(logFlushRunnable, 100)
                    }
                    if (logBuffer.size >= 50) {
                        flushLogBuffer()
                    }
                }
            } else {
                mainHandler.post {
                    try {
                        logSink?.success(formatted)
                    } catch (_: Exception) {}
                }
            }
        } catch (_: Exception) {}
    }

    private fun flushLogBuffer() {
        val batch: List<String>
        synchronized(logBufferLock) {
            batch = logBuffer.toList()
            logBuffer.clear()
            logFlushPosted = false
        }
        if (batch.isEmpty()) return
        val sink = logSink ?: return
        for (line in batch) {
            try {
                sink.success(line)
            } catch (_: Exception) { break }
        }
    }

    private fun acquireWakeLock() {
        releaseWakeLock()
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "OpenClaw::GatewayWakeLock"
        )
        wakeLock?.acquire(24 * 60 * 60 * 1000L)
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "OpenClaw Services",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "OpenClaw background services"
            setShowBadge(false)
            lockscreenVisibility = Notification.VISIBILITY_PRIVATE
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(text: String): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = Notification.Builder(this, CHANNEL_ID)

        builder.setContentTitle("Gateway")
            .setContentText(text)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)

        return builder.build()
    }

    private fun updateNotification(text: String) {
        try {
            val manager = getSystemService(NotificationManager::class.java)
            manager.notify(NOTIFICATION_ID, buildNotification(text))
        } catch (_: Exception) {}
    }
}
