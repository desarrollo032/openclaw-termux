package com.nxg.openclawproot

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Bridge between Flutter and the native PTY (C++ via JNI).
 *
 * MethodChannel: com.nxg.openclawproot/pty
 *   - startPty(shell, args, env, cwd, rows, cols) → sessionId (int)
 *   - writePty(sessionId, data) → bool
 *   - resizePty(sessionId, rows, cols) → bool
 *   - killPty(sessionId) → bool
 *   - closePty(sessionId) → bool
 *
 * EventChannel: com.nxg.openclawproot/pty/events/{sessionId}
 *   Events: { type: "output", data: byte[] }
 *          { type: "exit", exitCode: int }
 */
class OpenClawPtyBridge(private val flutterEngine: FlutterEngine) {

    companion object {
        private const val TAG = "OpenClawPty"
        private const val METHOD_CHANNEL = "com.nxg.openclawproot/pty"
        private const val EVENT_CHANNEL_PREFIX = "com.nxg.openclawproot/pty/events/"

        // Load native library
        init {
            try {
                System.loadLibrary("openclaw_pty")
                Log.i(TAG, "Native library openclaw_pty loaded")
            } catch (e: UnsatisfiedLinkError) {
                Log.e(TAG, "Failed to load native library: ${e.message}")
            }
        }
    }

    // JNI native methods
    private external fun nativeStartPty(
        shell: String,
        args: Array<String>,
        envVars: Array<String>,
        cwd: String?,
        rows: Int,
        cols: Int
    ): Int

    private external fun nativeWritePty(sessionId: Int, data: ByteArray): Boolean
    private external fun nativeResizePty(sessionId: Int, rows: Int, cols: Int): Boolean
    private external fun nativeKillPty(sessionId: Int): Boolean
    private external fun nativeClosePty(sessionId: Int): Boolean
    private external fun nativeReadPty(sessionId: Int): ByteArray?
    private external fun nativeGetExitCode(sessionId: Int): Int

    // Track active sessions and their event sinks
    private val sessionReaders = ConcurrentHashMap<Int, SessionReader>()
    private val readerExecutor = Executors.newCachedThreadPool()

    /**
     * Register method call handler and return the bridge instance.
     */
    fun register(): OpenClawPtyBridge {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startPty" -> {
                        val shell = call.argument<String>("shell") ?: "/system/bin/sh"
                        val args = call.argument<List<String>>("args")?.toTypedArray() ?: emptyArray()
                        val envVars = call.argument<List<String>>("envVars")?.toTypedArray() ?: emptyArray()
                        val cwd = call.argument<String>("cwd")
                        val rows = call.argument<Int>("rows") ?: 24
                        val cols = call.argument<Int>("cols") ?: 80
                        try {
                            val sessionId = nativeStartPty(shell, args, envVars, cwd, rows, cols)
                            if (sessionId >= 0) {
                                startReader(sessionId)
                                result.success(sessionId)
                            } else {
                                result.error("PTY_ERROR", "Failed to start PTY session", null)
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "startPty error: ${e.message}", e)
                            result.error("PTY_ERROR", e.message, null)
                        }
                    }
                    "writePty" -> {
                        val sessionId = call.argument<Int>("sessionId")
                        val data = call.argument<ByteArray>("data")
                        if (sessionId != null && data != null) {
                            try {
                                result.success(nativeWritePty(sessionId, data))
                            } catch (e: Exception) {
                                result.error("PTY_ERROR", e.message, null)
                            }
                        } else {
                            result.error("INVALID_ARGS", "sessionId and data required", null)
                        }
                    }
                    "resizePty" -> {
                        val sessionId = call.argument<Int>("sessionId")
                        val rows = call.argument<Int>("rows") ?: 24
                        val cols = call.argument<Int>("cols") ?: 80
                        if (sessionId != null) {
                            try {
                                result.success(nativeResizePty(sessionId, rows, cols))
                            } catch (e: Exception) {
                                result.error("PTY_ERROR", e.message, null)
                            }
                        } else {
                            result.error("INVALID_ARGS", "sessionId required", null)
                        }
                    }
                    "killPty" -> {
                        val sessionId = call.argument<Int>("sessionId")
                        if (sessionId != null) {
                            try {
                                result.success(nativeKillPty(sessionId))
                            } catch (e: Exception) {
                                result.error("PTY_ERROR", e.message, null)
                            }
                        } else {
                            result.error("INVALID_ARGS", "sessionId required", null)
                        }
                    }
                    "closePty" -> {
                        val sessionId = call.argument<Int>("sessionId")
                        if (sessionId != null) {
                            try {
                                stopReader(sessionId)
                                result.success(nativeClosePty(sessionId))
                            } catch (e: Exception) {
                                result.error("PTY_ERROR", e.message, null)
                            }
                        } else {
                            result.error("INVALID_ARGS", "sessionId required", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        return this
    }

    /**
     * Start a background reader thread for a session, pushing output to EventChannel.
     */
    private fun startReader(sessionId: Int) {
        val reader = SessionReader(sessionId)
        sessionReaders[sessionId] = reader
        readerExecutor.execute(reader)
    }

    /**
     * Stop the reader thread for a session.
     */
    private fun stopReader(sessionId: Int) {
        sessionReaders.remove(sessionId)?.cancel()
    }

    /**
     * Stop all readers (called on destroy).
     */
    fun destroy() {
        for ((sessionId, _) in sessionReaders.toMap()) {
            try {
                stopReader(sessionId)
                nativeKillPty(sessionId)
                nativeClosePty(sessionId)
            } catch (_: Exception) {}
        }
        sessionReaders.clear()
        readerExecutor.shutdownNow()
    }

    /**
     * Background reader that polls nativeReadPty and pushes to EventChannel.
     */
    private inner class SessionReader(private val sessionId: Int) : Runnable {
        private val active = AtomicBoolean(true)
        private val eventChannel: EventChannel
        private var eventSink: EventChannel.EventSink? = null
        private val mainHandler = Handler(Looper.getMainLooper())

        init {
            eventChannel = EventChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                "$EVENT_CHANNEL_PREFIX$sessionId"
            )
            eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
        }

        fun cancel() {
            active.set(false)
            mainHandler.post { eventSink?.endOfStream() }
            eventSink = null
        }

        override fun run() {
            val outputBuffer = java.io.ByteArrayOutputStream()
            var lastPostTime = 0L

            while (active.get()) {
                try {
                    // Check exit status
                    val exitCode = nativeGetExitCode(sessionId)
                    if (exitCode >= 0) {
                        // Process exited
                        val sink = eventSink
                        if (sink != null) {
                            val event = HashMap<String, Any>()
                            event["type"] = "exit"
                            event["exitCode"] = exitCode
                            mainHandler.post { sink.success(event) }
                        }
                        // Drain remaining output
                        drainRemaining()
                        cancel()
                        sessionReaders.remove(sessionId)
                        return
                    } else if (exitCode < -1) {
                        // Session error
                        val sink = eventSink
                        if (sink != null) {
                            val event = HashMap<String, Any>()
                            event["type"] = "error"
                            event["message"] = "Session terminated unexpectedly"
                            mainHandler.post { sink.success(event) }
                        }
                        cancel()
                        sessionReaders.remove(sessionId)
                        return
                    }

                    // Read available data (non-blocking)
                    val data = nativeReadPty(sessionId)
                    if (data != null && data.isNotEmpty()) {
                        outputBuffer.write(data)
                        
                        val now = System.currentTimeMillis()
                        // Real-time batching: flush if buffer > 4KB or > 1ms elapsed
                        // Higher buffer threshold reduces main-thread posts (expensive),
                        // lower time threshold keeps latency <2ms for responsiveness.
                        // Flutter side writes immediately (no batch timer) so no double-buffering.
                        if (outputBuffer.size() > 4096 || (now - lastPostTime) > 1) {
                            flushToSink(outputBuffer)
                            lastPostTime = now
                        }
                        // If data is flowing, don't sleep, read again immediately
                        continue
                    } else {
                        // No data available right now, flush any remaining bytes
                        if (outputBuffer.size() > 0) {
                            flushToSink(outputBuffer)
                            lastPostTime = System.currentTimeMillis()
                        }
                        // Idle sleep: 2ms — low latency but saves battery
                        Thread.sleep(2)
                    }
                } catch (e: Exception) {
                    if (active.get()) {
                        Log.e(TAG, "Reader error for session $sessionId: ${e.message}")
                        val sink = eventSink
                        if (sink != null) {
                            val event = HashMap<String, Any>()
                            event["type"] = "error"
                            event["message"] = e.message ?: "Unknown error"
                            mainHandler.post { sink.success(event) }
                        }
                    }
                    cancel()
                    sessionReaders.remove(sessionId)
                    return
                }
            }
        }

        private fun flushToSink(buffer: java.io.ByteArrayOutputStream) {
            val data = buffer.toByteArray()
            buffer.reset()
            val sink = eventSink
            if (sink != null) {
                val event = HashMap<String, Any>()
                event["type"] = "output"
                event["data"] = data
                mainHandler.post { sink.success(event) }
            }
        }

        private fun drainRemaining() {
            try {
                // Sleep a bit to let any final output arrive
                Thread.sleep(50)
                var data = nativeReadPty(sessionId)
                while (data != null && data.isNotEmpty()) {
                    val sink = eventSink
                    if (sink != null) {
                        val event = HashMap<String, Any>()
                        event["type"] = "output"
                        event["data"] = data
                        mainHandler.post { sink.success(event) }
                    }
                    Thread.sleep(10)
                    data = nativeReadPty(sessionId)
                }
            } catch (_: Exception) {}
        }
    }
}
