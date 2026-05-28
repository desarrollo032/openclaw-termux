package com.nxg.openclawproot

import android.util.Log
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BasicMessageChannel
import io.flutter.plugin.common.JSONMessageCodec
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
 * OutputChannel (BasicMessageChannel): com.nxg.openclawproot/pty/output/{sessionId}
 *   Messages: { type: "output", text: "..." }  (pre-decoded UTF-8 string)
 *            { type: "exit", exitCode: int }
 *            { type: "error", message: "..." }
 *
 * Optimisations:
 *   - BasicMessageChannel.send() is thread-safe → eliminates mainHandler.post() overhead
 *   - UTF-8 decode runs on the background thread, not Flutter UI thread
 *   - System.nanoTime() for sub-millisecond flush threshold (500 μs)
 */
class OpenClawPtyBridge(private val flutterEngine: FlutterEngine) {

    companion object {
        private const val TAG = "OpenClawPty"
        private const val METHOD_CHANNEL = "com.nxg.openclawproot/pty"
        private const val OUTPUT_CHANNEL_PREFIX = "com.nxg.openclawproot/pty/output/"

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
     * Background reader that polls nativeReadPty and pushes output to Flutter
     * via BasicMessageChannel, posting to the main thread for thread-safety.
     *
     * Note: BasicMessageChannel.send() must run on the main thread (FlutterJNI requires it),
     * so we use mainHandler.post() to bridge from this background thread to the UI thread.
     *
     * Optimisations:
     * 1. UTF-8 decode runs on this background thread, not Flutter UI thread
     * 2. System.nanoTime() enables sub-millisecond flush threshold (500 μs)
     * 3. Buffer threshold reduced to 2048 bytes for more responsive small-output commands
     */
    private inner class SessionReader(private val sessionId: Int) : Runnable {
        private val active = AtomicBoolean(true)
        private val outputChannel: BasicMessageChannel<Any>
        private val mainHandler = Handler(Looper.getMainLooper())

        init {
            outputChannel = BasicMessageChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                "$OUTPUT_CHANNEL_PREFIX$sessionId",
                JSONMessageCodec.INSTANCE
            )
        }

        fun cancel() {
            active.set(false)
        }

        override fun run() {
            val outputBuffer = java.io.ByteArrayOutputStream()
            var lastFlushNanos = System.nanoTime()

            while (active.get()) {
                try {
                    // Check exit status
                    val exitCode = nativeGetExitCode(sessionId)
                    if (exitCode >= 0) {
                        // Process exited — flush remaining, notify, drain
                        flushToDart(outputBuffer)
                        // Drain any last output from the PTY buffer
                        drainRemaining { decoded ->
                            mainHandler.post { outputChannel.send(mapOf("type" to "output", "text" to decoded)) }
                        }
                        mainHandler.post { outputChannel.send(mapOf("type" to "exit", "exitCode" to exitCode)) }
                        cancel()
                        sessionReaders.remove(sessionId)
                        return
                    } else if (exitCode < -1) {
                        // Session error
                        mainHandler.post {
                            outputChannel.send(
                                mapOf("type" to "error", "message" to "Session terminated unexpectedly")
                            )
                        }
                        cancel()
                        sessionReaders.remove(sessionId)
                        return
                    }

                    // Read available data (non-blocking, epoll + O_NONBLOCK)
                    val data = nativeReadPty(sessionId)
                    if (data != null && data.isNotEmpty()) {
                        outputBuffer.write(data)

                        val nowNanos = System.nanoTime()
                        // Flush if buffer > 2 KB or > 500 μs elapsed
                        // 2048 bytes @ ~2 MB/s = ~1ms of terminal output
                        // 500 μs threshold is imperceptible to humans
                        if (outputBuffer.size() > 2048 || (nowNanos - lastFlushNanos) > 500_000) {
                            flushToDart(outputBuffer)
                            lastFlushNanos = nowNanos
                        }
                        // Data flowing → read again immediately, no sleep
                        continue
                    } else {
                        // No data right now — flush whatever we have
                        if (outputBuffer.size() > 0) {
                            flushToDart(outputBuffer)
                            lastFlushNanos = System.nanoTime()
                        }
                        // Idle sleep: 2 ms — balances responsiveness & battery
                        Thread.sleep(2)
                    }
                } catch (e: Exception) {
                    if (active.get()) {
                        Log.e(TAG, "Reader error for session $sessionId: ${e.message}")
                        mainHandler.post {
                            outputChannel.send(
                                mapOf("type" to "error", "message" to (e.message ?: "Unknown error"))
                            )
                        }
                    }
                    cancel()
                    sessionReaders.remove(sessionId)
                    return
                }
            }
        }

        /**
         * Decode buffered bytes to UTF-8 string on this background thread
         * and send the pre-decoded text to Flutter via BasicMessageChannel
         * on the main thread.
         */
        private fun flushToDart(buffer: java.io.ByteArrayOutputStream) {
            val data = buffer.toByteArray()
            buffer.reset()
            val text = data.toString(Charsets.UTF_8)
            if (text.isNotEmpty()) {
                mainHandler.post { outputChannel.send(mapOf("type" to "output", "text" to text)) }
            }
        }

        /**
         * Drain any remaining PTY output after the process exits.
         */
        private fun drainRemaining(onOutput: (String) -> Unit) {
            try {
                Thread.sleep(50)
                var data = nativeReadPty(sessionId)
                while (data != null && data.isNotEmpty()) {
                    val text = data.toString(Charsets.UTF_8)
                    if (text.isNotEmpty()) onOutput(text)
                    Thread.sleep(10)
                    data = nativeReadPty(sessionId)
                }
            } catch (_: Exception) {}
        }
    }
}
