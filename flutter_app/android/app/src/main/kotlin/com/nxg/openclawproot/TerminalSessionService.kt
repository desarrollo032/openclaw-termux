package com.nxg.openclawproot

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.os.PowerManager

class TerminalSessionService : Service() {
    companion object {
        const val NOTIFICATION_ID = 2
        var isRunning = false
            private set

        // Shared wake lock reference accessible from MethodChannel.
        // Owned by companion so both instance and static renewWakeLock() can use it.
        private var _wakeLock: PowerManager.WakeLock? = null

        fun start(context: Context) {
            val intent = Intent(context, TerminalSessionService::class.java)
            context.startForegroundService(intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, TerminalSessionService::class.java)
            context.stopService(intent)
        }

        /**
         * Renew the terminal wake lock with a fresh 30-second timeout.
         * Called from the MethodChannel on each PTY output event.
         * If there's no activity for 30s, the wake lock auto-releases
         * and the CPU can enter deep sleep.
         */
        @JvmStatic
        fun renewWakeLock(context: Context) {
            _wakeLock?.let { if (it.isHeld) it.release() }
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val wl = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "OpenClaw::TerminalWakeLock"
            )
            wl.acquire(30_000L) // 30 seconds, renewable on activity
            _wakeLock = wl
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, buildNotification())
        if (isRunning) {
            return START_STICKY
        }
        isRunning = true
        acquireWakeLock()
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        releaseWakeLock()
        super.onDestroy()
    }

    private fun acquireWakeLock() {
        releaseWakeLock()
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        val wl = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "OpenClaw::TerminalWakeLock"
        )
        wl.acquire(30_000L) // 30 seconds — renewable on PTY activity
        _wakeLock = wl
    }

    private fun releaseWakeLock() {
        _wakeLock?.let { if (it.isHeld) it.release() }
        _wakeLock = null
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            "openclaw_services",
            "Services",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "OpenClaw background services"
            setShowBadge(false)
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return Notification.Builder(this, "openclaw_services")
            .setContentTitle("Terminal")
            .setContentText("Session active")
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .build()
    }
}
