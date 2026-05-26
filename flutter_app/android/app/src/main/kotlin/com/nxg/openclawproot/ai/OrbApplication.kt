package com.nxg.openclawproot.ai

import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.cio.*
import io.ktor.server.engine.*
import io.ktor.server.plugins.contentnegotiation.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import io.ktor.server.websocket.*
import io.ktor.serialization.kotlinx.json.*
import io.ktor.websocket.*
import kotlinx.coroutines.*
import kotlinx.serialization.json.Json
import java.time.Instant

/**
 * Ktor application module defining all orb-related routes.
 *
 * Endpoints:
 *  - GET /health                    → simple health check
 *  - WS  /orb-events               → WebSocket streaming orb states
 *  - POST /orb/emotion             → set orb emotion
 *  - POST /orb/audio               → set orb audio level
 */
fun Application.orbModule() {
    install(ContentNegotiation) {
        json(Json {
            ignoreUnknownKeys = true
            prettyPrint = false
            isLenient = true
        })
    }

    install(WebSockets)

    routing {
        // ── Health check ──
        get("/health") {
            call.respondText("OK", ContentType.Text.Plain)
        }

        // ── WebSocket: real-time orb state stream ──
        webSocket("/orb-events") {
            val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
            // Subscribe to state changes
            val job = CoroutineScope(Dispatchers.Default).launch {
                AiStateManager.orbState.collect { event ->
                    try {
                        val text = json.encodeToString(OrbEvent.serializer(), event)
                        send(Frame.Text(text))
                    } catch (_: Exception) {
                        // If send fails, client likely disconnected
                    }
                }
            }

            try {
                // Send initial state immediately
                val initial = AiStateManager.current
                send(Frame.Text(json.encodeToString(OrbEvent.serializer(), initial)))

                // Keep the connection alive (wait for close)
                for (frame in incoming) {
                    if (frame is Frame.Text) {
                        val text = frame.readText()
                        if (text == "ping") {
                            send(Frame.Text("pong"))
                        }
                    }
                }
            } catch (_: Exception) {
                // Client disconnected
            } finally {
                job.cancel()
            }
        }

        // ── POST /orb/emotion — update emotion externally ──
        post("/orb/emotion") {
            try {
                val body = call.receive<OrbEvent>()
                AiStateManager.update(
                    emotion = body.emotion,
                    audioLevel = body.audioLevel,
                    message = body.message
                )
                call.respondText(
                    """{"ok":true,"emotion":"${body.emotion}"}""",
                    ContentType.Application.Json
                )
            } catch (e: Exception) {
                call.respondText(
                    """{"ok":false,"error":"${e.message?.replace("\"", "\\\"") ?: "unknown"}"""",
                    ContentType.Application.Json,
                    HttpStatusCode.BadRequest
                )
            }
        }

        // ── POST /orb/audio — update audio level ──
        post("/orb/audio") {
            try {
                val body = call.receive<Map<String, Double>>()
                val level = body["level"] ?: 0.0
                AiStateManager.setAudioLevel(level)
                call.respondText(
                    """{"ok":true,"audioLevel":$level}""",
                    ContentType.Application.Json
                )
            } catch (e: Exception) {
                call.respondText(
                    """{"ok":false,"error":"${e.message?.replace("\"", "\\\"") ?: "unknown"}"""",
                    ContentType.Application.Json,
                    HttpStatusCode.BadRequest
                )
            }
        }

        // ── POST /orb/sentiment — analyze text and set emotion ──
        post("/orb/sentiment") {
            try {
                val body = call.receive<Map<String, String>>()
                val text = body["text"] ?: ""
                val message = body["message"] ?: text.take(120)
                val sentiment = SentimentToEmotion.analyze(text)
                AiStateManager.setFromSentiment(sentiment, message)
                call.respondText(
                    """{"ok":true,"emotion":"${AiStateManager.current.emotion}"}""",
                    ContentType.Application.Json
                )
            } catch (e: Exception) {
                call.respondText(
                    """{"ok":false,"error":"${e.message?.replace("\"", "\\\"") ?: "unknown"}"""",
                    ContentType.Application.Json,
                    HttpStatusCode.BadRequest
                )
            }
        }
    }
}
