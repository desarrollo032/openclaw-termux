package com.nxg.openclawproot.ai

import kotlinx.serialization.Serializable

@Serializable
data class OrbEvent(
    val type: String = "orb_state",
    val emotion: String,
    val audioLevel: Double = 0.0,
    val message: String? = null
)
