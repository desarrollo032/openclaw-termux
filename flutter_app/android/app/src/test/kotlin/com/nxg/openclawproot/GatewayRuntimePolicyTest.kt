package com.nxg.openclawproot

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GatewayRuntimePolicyTest {
    @Test
    fun startCommandUsesOptimizedScriptForNormalGatewayStart() {
        val command = GatewayRuntimePolicy.resolveGatewayCommand(
            requestedCommand = "openclaw gateway",
            optimizedScriptExists = true,
        )

        assertEquals("/root/.openclaw/start-gateway.sh", command)
    }

    @Test
    fun normalGatewayStartDoesNotEnableVerboseLogging() {
        val command = GatewayRuntimePolicy.resolveGatewayCommand(
            requestedCommand = "openclaw gateway",
            optimizedScriptExists = false,
        )

        assertEquals("openclaw gateway --no-color --no-emoji", command)
        assertFalse(command.contains("--verbose"))
    }

    @Test
    fun gatewayModeSkipsStdioBindsToAvoidProcFdWarnings() {
        assertFalse(GatewayRuntimePolicy.shouldBindStdio(isGatewayMode = true))
        assertTrue(GatewayRuntimePolicy.shouldBindStdio(isGatewayMode = false))
    }

    @Test
    fun nodeOptionsOnlyUseFlagsAllowedInNodeOptions() {
        val options = GatewayRuntimePolicy.nodeOptions()

        assertTrue(options.contains("--require /root/.openclaw/bionic-bypass.js"))
        assertTrue(options.contains("--max-old-space-size="))
        assertTrue(options.contains("--max-semi-space-size="))
        assertFalse(options.contains("--optimize-for-size"))
    }
}
