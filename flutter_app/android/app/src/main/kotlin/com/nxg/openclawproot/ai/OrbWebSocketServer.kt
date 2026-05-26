package com.nxg.openclawproot.ai

import io.ktor.server.cio.*
import io.ktor.server.engine.*
import kotlinx.coroutines.*
import java.io.Closeable
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Manages the lifecycle of the embedded Ktor WebSocket server for orb events.
 *
 * Usage (from MainActivity or a foreground service):
 *   OrbWebSocketServer.start(port = 18790)
 *   OrbWebSocketServer.stop()
 */
object OrbWebSocketServer : Closeable {

    /** Port the server listens on. Default 18790 (next after gateway 18789). */
    const val DEFAULT_PORT = 18790

    private var job: Job? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val _isRunning = AtomicBoolean(false)

    val isRunning: Boolean get() = _isRunning.get()

    /**
     * Start the embedded Ktor server on [host]:[port].
     * The server runs on IO dispatcher and does not block the calling thread.
     */
    fun start(
        host: String = "127.0.0.1",
        port: Int = DEFAULT_PORT,
    ) {
        if (_isRunning.get()) return

        job = scope.launch {
            try {
                embeddedServer(CIO, host = host, port = port) {
                    orbModule()
                }.start(wait = true)
            } catch (_: Exception) {
                // Server crashed
            }
        }
        _isRunning.set(true)
    }

    /**
     * Gracefully stop the server and cancel the coroutine.
     */
    fun stop() {
        if (!_isRunning.get()) return
        _isRunning.set(false)
        job?.cancel()
        job = null
    }

    override fun close() {
        stop()
    }
}
