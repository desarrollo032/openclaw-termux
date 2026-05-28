package com.nxg.openclawproot

import android.content.Context
import android.content.Intent
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader

/**
 * Runtime mode for the OpenClaw application.
 * Controls which services/processes are allowed to run.
 */
enum class RuntimeMode {
    /** Default state — no restrictions */
    IDLE,
    /** Full resource availability for bootstrap/setup */
    INSTALL,
    /** Interactive terminal session */
    TERMINAL,
    /** OpenClaw Gateway active — minimal resource usage */
    GATEWAY
}

/**
 * Central runtime guard that manages resource allocation based on the
 * current [RuntimeMode]. Automatically stops non-essential services,
 * cleans stale/zombie processes, and reports diagnostics when entering
 * gateway mode.
 *
 * Usage:
 *   val guard = GatewayRuntimeGuard(context)
 *   guard.enterGatewayMode()  // cleans up everything before starting gateway
 *   guard.collectRuntimeDiagnostics()  // report to Flutter
 */
class GatewayRuntimeGuard(private val context: Context) {

    @Volatile
    var currentMode: RuntimeMode = RuntimeMode.IDLE
        private set

    // ── Mode transitions ──────────────────────────────────────────────────

    /** Enter install mode — no resource restrictions. */
    fun enterInstallMode() {
        currentMode = RuntimeMode.INSTALL
    }

    /** Enter terminal mode — keep terminal functional. */
    fun enterTerminalMode() {
        currentMode = RuntimeMode.TERMINAL
    }

    /** Reset to idle mode — no restrictions, no cleanup. */
    fun enterIdleMode() {
        currentMode = RuntimeMode.IDLE
    }

    /**
     * Enter gateway mode — the most restrictive mode.
     * Stops non-essential services, kills stale/zombie processes,
     * and frees RAM/CPU for the gateway.
     */
    fun enterGatewayMode() {
        currentMode = RuntimeMode.GATEWAY
        keepOnlyGatewayAndTerminal()
    }

    // ── Cleanup actions ───────────────────────────────────────────────────

    /**
     * Stop all Android Services and background tasks that are NOT needed
     * during gateway runtime:
     *
     *   - [SshForegroundService] — SSH daemon (only if user explicitly enables)
     *   - [NodeForegroundService] — node host foreground notification
     *   - [ScreenCaptureService] — screen recording (only on-demand)
     *   - [SetupService] — bootstrap/setup (only during install)
     */
    fun stopNonGatewayServices() {
        // SSH service — proot daemon, keep alive only if user explicitly started
        try {
            SshForegroundService.stop(context)
        } catch (_: Exception) {}

        // Node foreground service — not needed when gateway is the active mode
        if (!isTerminalSessionActive()) {
            try {
                NodeForegroundService.stop(context)
            } catch (_: Exception) {}
        }

        // Screen capture service — only on user demand
        try {
            val intent = Intent(context, ScreenCaptureService::class.java)
            context.stopService(intent)
        } catch (_: Exception) {}

        // Setup service — only needed during bootstrap
        try {
            SetupService.stop(context)
        } catch (_: Exception) {}
    }

    /**
     * Kill stale/zombie processes left over from install or previous crashes:
     *
     *   - `openclaw-doctor` — phantom zombie (~409 MB RSS observed)
     *   - `npm` — leftover from npm install / package builds
     *   - `apt`, `apt-get`, `dpkg` — leftover from apt operations
     *   - `git` — leftover from git clones during setup
     *
     * These run inside proot or as Android child processes. We try both
     * `kill` on the host and `pkill` inside proot.
     */
    fun cleanupStaleProcesses() {
        // Kill zombie openclaw-doctor (phantom process, ~409MB waste)
        killProcessByName("openclaw-doctor")

        // Kill leftover npm processes (from install/build)
        killProcessByName("npm")

        // Kill leftover apt/dpkg processes
        killProcessByName("apt")
        killProcessByName("apt-get")
        killProcessByName("dpkg")

        // Kill leftover git processes
        killProcessByName("git")

        // Kill inside proot too (for processes not visible on host)
        runInProot("pkill -9 -x openclaw-doctor npm apt apt-get dpkg git 2>/dev/null || true")

        // Clean stale PID files
        cleanupPidFiles()

        // Clean stale temp files from previous sessions
        cleanupStaleTempFiles()
    }

    /**
     * Kill duplicate Node.js processes.
     * Each Node instance uses ~50-100 MB. Only keep the one owned by
     * our process group (the current gateway).
     */
    fun killDuplicateNodeProcesses() {
        val nodePids = findProcessPids("node")
        if (nodePids.size <= 1) return

        // Keep only the Node process that belongs to the current gateway session.
        // Orphaned Node processes from previous sessions or installs are killed.
        val appPid = android.os.Process.myPid()
        val prootPids = findProcessPids("libproot.so")
        for (pid in nodePids) {
            val isChildOfApp = isChildOf(pid, appPid)
            val isChildOfProot = prootPids.any { isChildOf(pid, it) }
            if (!isChildOfApp && !isChildOfProot) {
                try {
                    android.os.Process.killProcess(pid)
                } catch (_: Exception) {
                    try {
                        Runtime.getRuntime().exec(arrayOf("kill", "-9", pid.toString()))
                    } catch (_: Exception) {}
                }
            }
        }
    }

    /**
     * Combined cleanup: stop services + kill stale processes + kill duplicates.
     * This is the single entry point called before starting the gateway.
     */
    fun keepOnlyGatewayAndTerminal() {
        stopNonGatewayServices()
        cleanupStaleProcesses()
        killDuplicateNodeProcesses()
        android.util.Log.i("RuntimeGuard", "Gateway resource cleanup complete — mode=GATEWAY")
    }

    // ── Diagnostics ──────────────────────────────────────────────────────

    /**
     * Collect runtime diagnostics for reporting to Flutter.
     */
    fun collectRuntimeDiagnostics(): Map<String, Any> {
        val prootPids = findProcessPids("libproot.so")
        val gatewayPid = findProcessPids("openclaw").firstOrNull { pid ->
            // Filter out openclaw-doctor (it contains "openclaw" too)
            val cmdline = readCmdline(pid)
            cmdline != null && "openclaw" in cmdline && "doctor" !in cmdline
        } ?: -1
        val nodePids = findProcessPids("node")
        val nodeCount = nodePids.count { pid ->
            val cmdline = readCmdline(pid)
            cmdline != null && "node" in cmdline && "doctor" !in cmdline
        }

        return mapOf(
            "mode" to currentMode.name,
            "gatewayRunning" to (gatewayPid > 0),
            "pidGateway" to gatewayPid,
            "pidProot" to (prootPids.firstOrNull() ?: -1),
            "port18789Active" to isTcpPortInUse(18789),
            "terminalActive" to isTerminalSessionActive(),
            "servicesActive" to listOfNotNull(
                "gateway",
                if (NodeForegroundService.isRunning) "node-foreground" else null,
                if (SshForegroundService.isRunning) "ssh" else null,
                if (isTerminalSessionActive()) "terminal" else null,
            ),
            "nodeProcessesActive" to nodeCount,
        )
    }

    // ── Helpers: process management ──────────────────────────────────────

    private fun findProcessPids(name: String): List<Int> {
        return try {
            val process = Runtime.getRuntime().exec(arrayOf("ps", "-A"))
            val reader = BufferedReader(InputStreamReader(process.inputStream))
            val output = reader.readText()
            process.waitFor()

            output.lines()
                .filter { it.contains(name, ignoreCase = true) }
                .mapNotNull { line ->
                    val parts = line.trim().split(Regex("\\s+"))
                    // PID is the first numeric field
                    parts.firstOrNull { it.all { c -> c.isDigit() } }?.toIntOrNull()
                }
                .filter { it > 0 }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun killProcessByName(name: String) {
        try {
            val pids = findProcessPids(name)
            for (pid in pids) {
                if (pid > 0) {
                    android.os.Process.killProcess(pid)
                }
            }
        } catch (_: Exception) {}
    }

    private fun readCmdline(pid: Int): String? {
        return try {
            File("/proc/$pid/cmdline").readText().replace('\u0000', ' ').trim()
        } catch (_: Exception) {
            null
        }
    }

    private fun isChildOf(pid: Int, parentPid: Int): Boolean {
        return try {
            val status = File("/proc/$pid/status")
            if (!status.exists()) return false
            val content = status.readText()
            val ppidLine = content.lines().firstOrNull { it.startsWith("PPid:") } ?: return false
            val ppid = ppidLine.split(Regex("\\s+")).getOrNull(1)?.toIntOrNull() ?: return false
            ppid == parentPid
        } catch (_: Exception) {
            false
        }
    }

    private fun isTcpPortInUse(port: Int): Boolean {
        return try {
            val hexPort = String.format("%04X", port)
            val process = Runtime.getRuntime().exec(arrayOf(
                "sh", "-c", "cat /proc/net/tcp 2>/dev/null | grep -qi \"$hexPort\""
            ))
            process.waitFor() == 0
        } catch (_: Exception) {
            false
        }
    }

    private fun isTerminalSessionActive(): Boolean {
        return try {
            TerminalSessionService.isRunning
        } catch (_: Exception) {
            false
        }
    }

    private fun runInProot(commands: String) {
        try {
            val filesDir = context.filesDir.absolutePath
            val libDir = context.applicationInfo.nativeLibraryDir
            val pm = ProcessManager(filesDir, libDir)
            pm.runInProotSync(commands, 15)
        } catch (_: Exception) {}
    }

    private fun cleanupPidFiles() {
        try {
            val pidDir = File(context.filesDir, "rootfs/ubuntu/root/.openclaw")
            val pidFile = File(pidDir, "gateway.pid")
            if (pidFile.exists()) {
                val oldPid = pidFile.readText().trim().toIntOrNull()
                if (oldPid != null && !isProcessAlive(oldPid)) {
                    pidFile.delete()
                }
            }
            // Remove backup files from config repairs
            pidDir.listFiles()?.forEach { file ->
                if (file.name.endsWith(".bak") || file.name.endsWith(".bak.1")) {
                    file.delete()
                }
            }
        } catch (_: Exception) {}
    }

    private fun cleanupStaleTempFiles() {
        try {
            val tmpDir = File(context.filesDir, "rootfs/ubuntu/tmp")
            if (!tmpDir.exists()) return
            tmpDir.listFiles()?.forEach { file ->
                val name = file.name
                if (name.startsWith("openclaw-") || name.startsWith("npm-") ||
                    name.startsWith("node-") || name == "npm-cache") {
                    // Only delete files older than 1 hour (might still be in use)
                    if (System.currentTimeMillis() - file.lastModified() > 3_600_000) {
                        file.deleteRecursively()
                    }
                }
            }
        } catch (_: Exception) {}
    }

    private fun isProcessAlive(pid: Int): Boolean {
        return try {
            File("/proc/$pid").exists()
        } catch (_: Exception) {
            false
        }
    }
}
