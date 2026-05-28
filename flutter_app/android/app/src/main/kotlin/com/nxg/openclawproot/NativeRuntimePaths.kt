package com.nxg.openclawproot

import java.io.File

class NativeRuntimePaths(filesDir: File) {
    val baseDir = File(filesDir, "native")
    val prefixDir = File(baseDir, "usr")
    val homeDir = File(baseDir, "home")
    val tmpDir = File(baseDir, "tmp")
    val projectDir = File(homeDir, ".openclaw-android")
    val binDir = File(projectDir, "bin")
    val nodeDir = File(projectDir, "node")
    val patchesDir = File(projectDir, "patches")
    val markerFile = File(projectDir, ".post-setup-done")
    val failedMarkerFile = File(projectDir, ".post-setup-failed")
    val platformMarkerFile = File(projectDir, ".platform")
    val linkerFile = File(prefixDir, "glibc/lib/ld-linux-aarch64.so.1")
    val installerFile = File(projectDir, "post-setup-app.sh")
    val gatewayFile = File(projectDir, "start-gateway.sh")
    val pidFile = File(projectDir, "gateway.pid")

    fun ensureDirectories() {
        listOf(
            baseDir,
            prefixDir,
            File(prefixDir, "bin"),
            homeDir,
            tmpDir,
            projectDir,
            binDir,
            nodeDir,
            patchesDir,
            File(homeDir, ".cache/node/compile_cache"),
            File(prefixDir, "tmp"),
        ).forEach { it.mkdirs() }
    }

    fun environment(): MutableMap<String, String> = mutableMapOf(
        "PREFIX" to prefixDir.absolutePath,
        "HOME" to homeDir.absolutePath,
        "TMPDIR" to tmpDir.absolutePath,
        "TMP" to tmpDir.absolutePath,
        "TEMP" to tmpDir.absolutePath,
        "OA_GLIBC" to "1",
        "CONTAINER" to "1",
        "OPENCLAW_NO_RESPAWN" to "1",
        "OPENCLAW_NO_WATCHDOG" to "1",
        "CLAWDHUB_WORKDIR" to File(homeDir, ".openclaw/workspace").absolutePath,
        "CPATH" to "${File(prefixDir, "include/glib-2.0").absolutePath}:${File(prefixDir, "lib/glib-2.0/include").absolutePath}",
        "NODE_COMPILE_CACHE" to File(homeDir, ".cache/node/compile_cache").absolutePath,
        "SSL_CERT_FILE" to File(prefixDir, "etc/tls/cert.pem").absolutePath,
        "CURL_CA_BUNDLE" to File(prefixDir, "etc/tls/cert.pem").absolutePath,
        "GIT_SSL_CAINFO" to File(prefixDir, "etc/tls/cert.pem").absolutePath,
        "GIT_CONFIG_NOSYSTEM" to "1",
        "GIT_EXEC_PATH" to File(prefixDir, "libexec/git-core").absolutePath,
        "GIT_TEMPLATE_DIR" to File(prefixDir, "share/git-core/templates").absolutePath,
        "PATH" to listOf(
            binDir.absolutePath,
            File(prefixDir, "bin").absolutePath,
            File(prefixDir, "glibc/bin").absolutePath,
            File(nodeDir, "bin").absolutePath,
            "/system/bin",
            "/system/xbin",
        ).joinToString(":"),
    )
}
