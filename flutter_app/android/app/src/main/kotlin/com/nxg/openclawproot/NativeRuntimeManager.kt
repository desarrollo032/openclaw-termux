package com.nxg.openclawproot

import android.content.Context
import android.system.Os
import java.io.BufferedInputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.URL
import org.apache.commons.compress.archivers.ar.ArArchiveInputStream
import org.apache.commons.compress.archivers.tar.TarArchiveEntry
import org.apache.commons.compress.archivers.tar.TarArchiveInputStream
import org.apache.commons.compress.compressors.xz.XZCompressorInputStream
import org.apache.commons.compress.compressors.zstandard.ZstdCompressorInputStream
import java.util.zip.GZIPInputStream

class NativeRuntimeManager(private val context: Context) {
    private val paths = NativeRuntimePaths(context.filesDir)

    companion object {
        private const val TERMUX_REPO = "https://packages-cf.termux.dev/apt/termux-main"
        private const val GLIBC_PKG_NAME = "glibc-2.36-1-any.pkg.tar.xz"
        private const val GCC_LIBS_PKG_NAME = "gcc-libs-12.2.0-0-any.pkg.tar.xz"
        private const val GLIBC_ASSET_DIR = "native/glibc"
        private const val TERMUX_INNER = "data/data/com.termux/files/usr/"
        private const val TERMUX_ABS_PREFIX = "/data/data/com.termux/files/usr"
        private const val NODE_VERSION = "22.22.0"
        private val CORE_PACKAGES = listOf(
            "bash",
            "ca-certificates",
            "coreutils",
            "curl",
            "gawk",
            "git",
            "grep",
            "openssl",
            "procps",
            "sed",
            "tar",
            "which",
            "xz-utils",
        )
    }

    data class PackageEntry(
        val name: String,
        val filename: String,
        val depends: List<String>,
    )

    fun isInstalled(): Boolean =
        paths.markerFile.exists() &&
            paths.linkerFile.canExecute() &&
            File(paths.binDir, "node").canExecute() &&
            File(paths.prefixDir, "lib/node_modules/openclaw/package.json").exists()

    fun status(): Map<String, Any> = mapOf(
        "baseDir" to paths.baseDir.absolutePath,
        "prefix" to paths.prefixDir.absolutePath,
        "home" to paths.homeDir.absolutePath,
        "marker" to paths.markerFile.exists(),
        "failedMarker" to paths.failedMarkerFile.exists(),
        "bash" to File(paths.prefixDir, "bin/bash").exists(),
        "curl" to File(paths.prefixDir, "bin/curl").exists(),
        "git" to File(paths.prefixDir, "bin/git").exists(),
        "glibcLdso" to paths.linkerFile.exists(),
        "node" to File(paths.binDir, "node").exists(),
        "npm" to File(paths.binDir, "npm").exists(),
        "openclaw" to File(paths.prefixDir, "lib/node_modules/openclaw/package.json").exists(),
        "clawdhub" to File(paths.prefixDir, "lib/node_modules/clawdhub/package.json").exists(),
        "glibcDownloadUrl" to "embedded (APK asset)",
        "nodeDownloadUrl" to "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-arm64.tar.xz",
        "complete" to isInstalled(),
    )

    fun bootstrap(onLog: (String) -> Unit = {}): String {
        val out = StringBuilder()
        fun log(message: String) {
            out.appendLine(message)
            onLog(message)
        }

        try {
            paths.ensureDirectories()
            paths.failedMarkerFile.delete()
            copyAssets(log = ::log)
            installTermuxPackages(log = ::log)
            fixPermissions(log = ::log)
            installGlibc(log = ::log)
            fixPermissions(log = ::log)
            installNode(log = ::log)
            fixPermissions(log = ::log)
            runInstaller(log = ::log)
            paths.platformMarkerFile.writeText("openclaw\n")
            if (!isInstalled()) {
                throw RuntimeException("Native runtime marker was not created")
            }
            return out.toString()
        } catch (e: Exception) {
            paths.failedMarkerFile.parentFile?.mkdirs()
            paths.failedMarkerFile.writeText("${System.currentTimeMillis()}\n${e.message}\n")
            throw e
        }
    }

    fun runCommand(command: String, timeoutSeconds: Long = 900): String {
        val shell = File(paths.prefixDir, "bin/bash")
        if (!shell.canExecute()) {
            throw RuntimeException("Native bash is not installed at ${shell.absolutePath}")
        }
        val process = processBuilder(listOf(shell.absolutePath, "-lc", command)).start()
        val output = process.inputStream.bufferedReader().readText()
        val error = process.errorStream.bufferedReader().readText()
        val exited = process.waitFor(timeoutSeconds, java.util.concurrent.TimeUnit.SECONDS)
        if (!exited) {
            process.destroyForcibly()
            throw RuntimeException("Native command timed out after ${timeoutSeconds}s")
        }
        if (process.exitValue() != 0) {
            throw RuntimeException((output + error).takeLast(4000))
        }
        return output + error
    }

    fun startGateway(): Process {
        if (!isInstalled()) {
            throw RuntimeException("Native runtime is not installed")
        }
        return processBuilder(listOf(paths.gatewayFile.absolutePath)).start()
    }

    fun terminalEnvironment(): Map<String, String> = paths.environment()

    fun getNativeTerminalConfig(): Map<String, Any> = mapOf(
        "shell" to File(paths.prefixDir, "bin/bash").absolutePath,
        "homeDir" to paths.homeDir.absolutePath,
        "prefix" to paths.prefixDir.absolutePath,
        "binDir" to paths.binDir.absolutePath,
        "environment" to paths.environment(),
    )

    fun isExecAllowed(): Boolean {
        return try {
            val systemTrue = File("/system/bin/true")
            if (!systemTrue.exists()) return false

            val testBin = File(context.filesDir, "native/.exec_test")
            testBin.parentFile?.mkdirs()
            systemTrue.inputStream().use { input ->
                testBin.outputStream().use { output -> input.copyTo(output) }
            }
            testBin.setExecutable(true, false)

            val process = ProcessBuilder(testBin.absolutePath).start()
            val exited = process.waitFor(5, java.util.concurrent.TimeUnit.SECONDS)
            testBin.delete()
            if (!exited) {
                process.destroyForcibly()
                return false
            }
            process.exitValue() == 0
        } catch (e: Exception) {
            // IOException with error=13 (Permission denied) = W^X blocked
            try { File(context.filesDir, "native/.exec_test").delete() } catch (_: Exception) {}
            false
        }
    }

    fun cleanupProotRootfs(): Boolean {
        val rootfsDir = File(context.filesDir, "rootfs")
        return if (rootfsDir.exists()) {
            rootfsDir.deleteRecursively()
            true
        } else {
            false
        }
    }

    private fun processBuilder(command: List<String>): ProcessBuilder {
        val pb = ProcessBuilder(command)
        pb.directory(paths.homeDir)
        pb.environment().clear()
        pb.environment().putAll(paths.environment())
        return pb
    }

    private fun copyAssets(log: (String) -> Unit) {
        copyAsset("native/post-setup-app.sh", paths.installerFile)
        copyAsset("native/start-gateway.sh", paths.gatewayFile)
        copyAsset("native/patches/glibc-compat.js", File(paths.patchesDir, "glibc-compat.js"))
        copyAsset("native/patches/systemctl", File(paths.prefixDir, "bin/systemctl"))

        // Copy glibc packages from embedded APK assets (no network download)
        listOf(GLIBC_PKG_NAME, GCC_LIBS_PKG_NAME).forEach { name ->
            val target = File(paths.tmpDir, name)
            if (!target.exists() || target.length() == 0L) {
                copyAsset("$GLIBC_ASSET_DIR/$name", target)
            }
        }

        rewritePlaceholders(paths.gatewayFile)
        listOf(paths.installerFile, paths.gatewayFile, File(paths.prefixDir, "bin/systemctl"))
            .forEach { it.setExecutable(true, false) }
        log("[OK] Native OpenClaw scripts prepared")
    }

    private fun copyAsset(assetPath: String, target: File) {
        target.parentFile?.mkdirs()
        context.assets.open(assetPath).use { input ->
            FileOutputStream(target).use { output -> input.copyTo(output) }
        }
        target.setReadable(true, false)
        target.setWritable(true, false)
    }

    private fun rewritePlaceholders(file: File) {
        val content = file.readText()
            .replace("__PREFIX__", paths.prefixDir.absolutePath)
            .replace("__HOME__", paths.homeDir.absolutePath)
        file.writeText(content)
    }

    private fun installTermuxPackages(log: (String) -> Unit) {
        val packageIndex = File(paths.tmpDir, "termux-Packages")
        if (!packageIndex.exists() || packageIndex.length() == 0L) {
            log("[DOWNLOAD] Termux package index")
            download(listOf("$TERMUX_REPO/dists/stable/main/binary-aarch64/Packages"), packageIndex, log)
        }

        val entries = parsePackageIndex(packageIndex.readText())
        val selected = linkedSetOf<String>()
        fun visit(pkg: String) {
            if (!selected.add(pkg)) return
            entries[pkg]?.depends?.forEach { dep -> if (entries.containsKey(dep)) visit(dep) }
        }
        CORE_PACKAGES.forEach(::visit)

        for (pkg in selected) {
            val entry = entries[pkg] ?: continue
            val deb = File(paths.tmpDir, entry.filename.substringAfterLast('/'))
            if (!deb.exists() || deb.length() == 0L) {
                log("[DOWNLOAD] $pkg")
                download(listOf("$TERMUX_REPO/${entry.filename}"), deb, log)
            }
            log("[EXTRACT] $pkg")
            extractDebToPrefix(deb)
        }
        log("[OK] Native bash/curl/git/tar/xz/coreutils installed")
    }

    private fun parsePackageIndex(index: String): Map<String, PackageEntry> {
        val result = mutableMapOf<String, PackageEntry>()
        index.split("\n\n").forEach { block ->
            val lines = block.lines()
            val name = lines.firstOrNull { it.startsWith("Package: ") }
                ?.removePrefix("Package: ")?.trim() ?: return@forEach
            val filename = lines.firstOrNull { it.startsWith("Filename: ") }
                ?.removePrefix("Filename: ")?.trim() ?: return@forEach
            val depends = lines.firstOrNull { it.startsWith("Depends: ") }
                ?.removePrefix("Depends: ")
                ?.split(',')
                ?.map { it.trim().substringBefore(' ').substringBefore('|').trim() }
                ?.filter { it.isNotEmpty() }
                ?: emptyList()
            result[name] = PackageEntry(name, filename, depends)
        }
        return result
    }

    private fun installGlibc(log: (String) -> Unit) {
        if (paths.linkerFile.canExecute()) {
            log("[SKIP] glibc already installed")
            return
        }
        File(paths.prefixDir, "glibc").mkdirs()

        // Extract glibc packages from embedded APK assets (no download needed)
        listOf(GLIBC_PKG_NAME, GCC_LIBS_PKG_NAME).forEach { name ->
            val pkg = File(paths.tmpDir, name)
            if (!pkg.exists() || pkg.length() == 0L) {
                throw RuntimeException("Embedded glibc package $name not found — rebuild APK after running prepare-glibc-assets.sh")
            }
            log("[EXTRACT] $name (from APK asset)")
            extractPacmanToPrefix(pkg)
        }
        paths.linkerFile.setExecutable(true, false)
        val hosts = File(paths.prefixDir, "glibc/etc/hosts")
        hosts.parentFile?.mkdirs()
        if (!hosts.exists()) {
            hosts.writeText("127.0.0.1 localhost localhost.localdomain\n::1 localhost ip6-localhost ip6-loopback\n")
        }
        val resolv = File(paths.prefixDir, "etc/resolv.conf")
        resolv.parentFile?.mkdirs()
        resolv.writeText("nameserver 8.8.8.8\nnameserver 8.8.4.4\nnameserver 1.1.1.1\n")
        val glibcResolv = File(paths.prefixDir, "glibc/etc/resolv.conf")
        glibcResolv.parentFile?.mkdirs()
        glibcResolv.writeText(resolv.readText())
        log("[OK] glibc dynamic linker installed")
    }

    private fun installNode(log: (String) -> Unit) {
        val nodeReal = File(paths.nodeDir, "bin/node.real")
        if (nodeReal.canExecute() && File(paths.binDir, "node").canExecute()) {
            log("[SKIP] Node.js already extracted")
            return
        }
        val tarName = "node-v$NODE_VERSION-linux-arm64.tar.xz"
        val tarFile = File(paths.tmpDir, tarName)
        if (!tarFile.exists() || tarFile.length() == 0L) {
            log("[DOWNLOAD] Node.js v$NODE_VERSION")
            download(listOf("https://nodejs.org/dist/v$NODE_VERSION/$tarName"), tarFile, log)
        }
        if (paths.nodeDir.exists()) paths.nodeDir.deleteRecursively()
        paths.nodeDir.mkdirs()
        extractTarXz(tarFile, paths.nodeDir, stripComponents = 1)
        val node = File(paths.nodeDir, "bin/node")
        if (node.exists() && !nodeReal.exists()) {
            node.renameTo(nodeReal)
        }
        nodeReal.setExecutable(true, false)
        log("[OK] Node.js extracted")
    }

    private fun runInstaller(log: (String) -> Unit) {
        if (paths.markerFile.exists()) {
            log("[SKIP] Native post setup already complete")
            return
        }
        log("[RUN] post-setup-app.sh")
        val process = processBuilder(listOf(File(paths.prefixDir, "bin/bash").absolutePath, paths.installerFile.absolutePath)).start()
        val stdout = StringBuilder()
        val outThread = Thread {
            process.inputStream.bufferedReader().forEachLine {
                stdout.appendLine(it)
                log(it)
            }
        }.apply { start() }
        val errThread = Thread {
            process.errorStream.bufferedReader().forEachLine {
                stdout.appendLine(it)
                log(it)
            }
        }.apply { start() }
        val exited = process.waitFor(30, java.util.concurrent.TimeUnit.MINUTES)
        outThread.join(1000)
        errThread.join(1000)
        if (!exited) {
            process.destroyForcibly()
            throw RuntimeException("Native OpenClaw setup timed out")
        }
        if (process.exitValue() != 0) {
            throw RuntimeException("Native OpenClaw setup failed: ${stdout.toString().takeLast(4000)}")
        }
    }

    private fun download(url: String, target: File, log: (String) -> Unit = {}) {
        download(listOf(url), target, log)
    }

    private fun download(urls: List<String>, target: File, log: (String) -> Unit = {}) {
        target.parentFile?.mkdirs()
        var lastError: Exception? = null
        for (url in urls) {
            if (target.exists()) target.delete()
            try {
                val conn = URL(url).openConnection()
                conn.connectTimeout = 30_000
                conn.readTimeout = 120_000
                val contentLength = conn.contentLengthLong
                conn.getInputStream().use { input ->
                    FileOutputStream(target).use { output ->
                        val buffer = ByteArray(8192)
                        var bytesRead: Int
                        var totalRead = 0L
                        var lastLogged = 0L
                        while (input.read(buffer).also { bytesRead = it } != -1) {
                            output.write(buffer, 0, bytesRead)
                            totalRead += bytesRead
                            if (contentLength > 0 && totalRead - lastLogged > 2_000_000) {
                                val pct = totalRead * 100 / contentLength
                                log("[DOWNLOAD] ${totalRead / 1_000_000}MB / ${contentLength / 1_000_000}MB ($pct%)")
                                lastLogged = totalRead
                            }
                        }
                    }
                }
                if (target.length() == 0L) {
                    throw RuntimeException("Downloaded file is empty")
                }
                return // success
            } catch (e: Exception) {
                lastError = e
                if (target.exists()) target.delete()
                log("[WARN] ${url.substringAfterLast('/').take(40)} failed: ${e.message?.take(80)}")
                if (urls.size > 1) log("[RETRY] Trying next mirror...")
            }
        }
        throw lastError ?: RuntimeException("All download URLs failed for ${target.name}")
    }

    private fun extractDebToPrefix(debFile: File) {
        FileInputStream(debFile).use { fis ->
            BufferedInputStream(fis).use { bis ->
                ArArchiveInputStream(bis).use { ar ->
                    var entry = ar.nextEntry
                    while (entry != null) {
                        if (entry.name.startsWith("data.tar")) {
                            val stream = when {
                                entry.name.endsWith(".xz") -> XZCompressorInputStream(ar)
                                entry.name.endsWith(".gz") -> GZIPInputStream(ar)
                                entry.name.endsWith(".zst") -> ZstdCompressorInputStream(ar)
                                else -> ar
                            }
                            TarArchiveInputStream(stream).use { tar -> extractRelocatedTar(tar) }
                            return
                        }
                        entry = ar.nextEntry
                    }
                }
            }
        }
    }

    private fun extractPacmanToPrefix(pkgFile: File) {
        FileInputStream(pkgFile).use { fis ->
            BufferedInputStream(fis).use { bis ->
                XZCompressorInputStream(bis).use { xz ->
                    TarArchiveInputStream(xz).use { tar -> extractRelocatedTar(tar) }
                }
            }
        }
    }

    private fun extractTarXz(tarFile: File, target: File, stripComponents: Int) {
        FileInputStream(tarFile).use { fis ->
            BufferedInputStream(fis).use { bis ->
                XZCompressorInputStream(bis).use { xz ->
                    TarArchiveInputStream(xz).use { tar ->
                        var entry = tar.nextEntry
                        while (entry != null) {
                            val stripped = entry.name.split('/').drop(stripComponents).joinToString("/")
                            if (stripped.isNotEmpty()) extractTarEntry(tar, entry, File(target, stripped))
                            entry = tar.nextEntry
                        }
                    }
                }
            }
        }
    }

    private fun extractRelocatedTar(tar: TarArchiveInputStream) {
        var entry = tar.nextEntry
        while (entry != null) {
            val name = entry.name.removePrefix("./").removePrefix("/")
            val target = when {
                name.startsWith(TERMUX_INNER) -> File(paths.prefixDir, name.removePrefix(TERMUX_INNER))
                name.startsWith("glibc/") -> File(paths.prefixDir, name)
                name.startsWith("data/data/com.termux/files/usr/glibc/") ->
                    File(paths.prefixDir, name.removePrefix("data/data/com.termux/files/usr/"))
                else -> null
            }
            if (target != null) extractTarEntry(tar, entry, target)
            entry = tar.nextEntry
        }
    }

    private fun extractTarEntry(tar: TarArchiveInputStream, entry: TarArchiveEntry, target: File) {
        when {
            entry.isDirectory -> target.mkdirs()
            entry.isSymbolicLink -> {
                target.parentFile?.mkdirs()
                if (target.exists()) target.delete()
                val linkName = relocateLinkTarget(entry.linkName)
                try { Os.symlink(linkName, target.absolutePath) } catch (_: Exception) {}
            }
            entry.isLink -> {
                val linkTarget = File(paths.prefixDir, entry.linkName.removePrefix(TERMUX_INNER))
                if (linkTarget.exists()) {
                    target.parentFile?.mkdirs()
                    linkTarget.copyTo(target, overwrite = true)
                }
            }
            else -> {
                target.parentFile?.mkdirs()
                FileOutputStream(target).use { output -> tar.copyTo(output) }
                target.setReadable(true, false)
                target.setWritable(true, false)
                if (entry.mode and 0b001_001_001 != 0 ||
                    target.path.contains("/bin/") ||
                    target.path.contains("/glibc/") ||
                    target.name.endsWith(".sh") ||
                    target.name.endsWith(".so")) {
                    target.setExecutable(true, false)
                }
            }
        }
    }

    private fun relocateLinkTarget(linkName: String): String =
        if (linkName.startsWith(TERMUX_ABS_PREFIX)) {
            paths.prefixDir.absolutePath + linkName.removePrefix(TERMUX_ABS_PREFIX)
        } else {
            linkName
        }

    private fun fixPermissions(log: (String) -> Unit) {
        log("[FIX] Applying execute permissions...")
        // All executables in usr/bin/, usr/glibc/bin/, usr/libexec/
        listOf(
            File(paths.prefixDir, "bin"),
            File(paths.prefixDir, "glibc/bin"),
            File(paths.prefixDir, "libexec"),
        ).forEach { dir ->
            if (dir.exists()) {
                dir.walkTopDown().forEach { file ->
                    if (file.isFile) file.setExecutable(true, false)
                }
            }
        }
        // All .so files in glibc/lib (needed for dlopen)
        File(paths.prefixDir, "glibc/lib").let { libDir ->
            if (libDir.exists()) {
                libDir.listFiles()?.forEach { file ->
                    if (file.isFile && file.name.endsWith(".so")) {
                        file.setExecutable(true, false)
                    }
                }
            }
        }
        // Node.js binaries
        listOf(
            paths.binDir,
            paths.nodeDir,
            File(paths.nodeDir, "bin"),
        ).forEach { dir ->
            if (dir.exists()) {
                dir.listFiles()?.forEach { file ->
                    if (file.isFile) file.setExecutable(true, false)
                }
            }
        }
        // glibc linker
        if (paths.linkerFile.exists()) {
            paths.linkerFile.setExecutable(true, false)
        }
        // Scripts
        listOf(paths.installerFile, paths.gatewayFile).forEach { file ->
            if (file.exists()) file.setExecutable(true, false)
        }
        log("[OK] Permissions fixed")
    }
}
