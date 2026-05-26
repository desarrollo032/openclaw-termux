package com.nxg.openclawproot.ai

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Singleton that holds the current AI orb state.
 * The Ktor server and any producer (TTS, LLM pipeline) read/write state here.
 */
object AiStateManager {

    private val _orbState = MutableStateFlow(
        OrbEvent(emotion = "idle", audioLevel = 0.0)
    )

    /** Observable stream of orb states emitted to WebSocket clients. */
    val orbState: StateFlow<OrbEvent> = _orbState.asStateFlow()

    /** Snapshot of the current event (non-suspending read). */
    val current: OrbEvent get() = _orbState.value

    /** Update emotion; audioLevel and message are preserved unless provided. */
    fun setEmotion(emotion: String, message: String? = null) {
        _orbState.value = current.copy(
            emotion = emotion,
            message = message ?: current.message
        )
    }

    /** Update audio level (0.0–1.0) for the orb's reactive wave animation. */
    fun setAudioLevel(level: Double) {
        _orbState.value = current.copy(audioLevel = level.coerceIn(0.0, 1.0))
    }

    /** Update emotion from a sentiment string e.g. "happy", "error" */
    fun setFromSentiment(sentiment: String, message: String? = null) {
        val emotion = when (sentiment) {
            "positive" -> "happy"
            "question" -> "thinking"
            "error" -> "error"
            "calm" -> "calm"
            "surprised" -> "surprised"
            else -> "speaking"
        }
        setEmotion(emotion, message)
    }

    /** Batch update — full state replacement from external POST or TTS callback. */
    fun update(emotion: String, audioLevel: Double = current.audioLevel, message: String? = null) {
        _orbState.value = OrbEvent(
            emotion = emotion,
            audioLevel = audioLevel.coerceIn(0.0, 1.0),
            message = message ?: current.message
        )
    }
}
