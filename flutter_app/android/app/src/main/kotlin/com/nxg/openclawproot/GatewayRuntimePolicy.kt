package com.nxg.openclawproot

object GatewayRuntimePolicy {
    const val HEAP_MB = 384
    const val SEMI_SPACE_MB = 32

    fun resolveGatewayCommand(
        requestedCommand: String,
        optimizedScriptExists: Boolean
    ): String {
        val normalized = requestedCommand.trim()
        if (normalized == "openclaw gateway" ||
            normalized == "openclaw gateway --verbose") {
            return if (optimizedScriptExists) {
                "/root/.openclaw/start-gateway.sh"
            } else {
                "openclaw gateway --no-color --no-emoji"
            }
        }
        return requestedCommand
    }

    fun nodeOptions(): String =
        "--require /root/.openclaw/bionic-bypass.js " +
            "--max-old-space-size=$HEAP_MB " +
            "--max-semi-space-size=$SEMI_SPACE_MB"

    fun shouldBindStdio(isGatewayMode: Boolean): Boolean = !isGatewayMode
}
