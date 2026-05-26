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

    private var server: ApplicationEngine? = null
    private var job: Job? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val _isRunning = AtomicBoolean(false)

    val isRunning: Boolean get() = _isRunning.get()

    /** Port the server listens on. Default 18790 (next after gateway 18789). */
    const val DEFAULT_PORT = 18790

    /**
     * Start the embedded Ktor server on [host]:[port].
     * The server runs on IO dispatcher and does not block the calling thread.
     */
    fun start(
        host: String = "127.0.0.1",
        port: Int = DEFAULT_PORT,
    ) {
        if (_isRunning.get()) {
            return // Already running
        }

        job = scope.launch {
            try {
                val engine = embeddedServer(CIO, host = host, port = port) {
                    orbModule()
                }
                engine.start(wait = true) // Blocks this coroutine until server stops
                server = engine
            } catch (e: Exception) {
                // Server crashed — log or notify
                _isRunning.set(false)
                server = null
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
        server?.stop(1000, 2000)
        server = null
    }

    override fun close() {
        stop()
    }
}
