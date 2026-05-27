package com.nxg.openclawproot

import android.annotation.SuppressLint
import android.os.Build
import android.os.Environment
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader

/**
 * Manages proot process execution, matching Termux proot-distro as closely
 * as possible. Two command modes:
 *   - Install mode (buildInstallCommand): matches proot-distro's run_proot_cmd()
 *   - Gateway mode (buildGatewayCommand): matches proot-distro's command_login()
 */
class ProcessManager(
    private val filesDir: String,
    private val nativeLibDir: String
) {
    private val rootfsDir get() = "$filesDir/rootfs/ubuntu"
    private val tmpDir get() = "$filesDir/tmp"
    private val homeDir get() = "$filesDir/home"
    private val configDir get() = "$filesDir/config"
    private val libDir get() = "$filesDir/lib"

    companion object {
        // Match proot-distro v4.37.0 defaults
        const val FAKE_KERNEL_RELEASE = "6.17.0-PRoot-Distro"
        const val FAKE_KERNEL_VERSION =
            "#1 SMP PREEMPT_DYNAMIC Fri, 10 Oct 2025 00:00:00 +0000"
    }

    fun getProotPath(): String = "$nativeLibDir/libproot.so"

    // ================================================================
    // Host-side environment for proot binary itself.
    // ONLY proot-specific vars — guest env is set via `env -i` inside
    // the command line, matching proot-distro's approach.
    // ================================================================
    private fun prootEnv(): Map<String, String> = mapOf(
        // proot temp directory for its internal use
        "PROOT_TMP_DIR" to tmpDir,
        // Loader executables for proot's execve interception
        "PROOT_LOADER" to "$nativeLibDir/libprootloader.so",
        "PROOT_LOADER_32" to "$nativeLibDir/libprootloader32.so",
        // LD_LIBRARY_PATH: proot itself needs libtalloc.so.2
        // This does NOT leak into the guest (env -i cleans it)
        "LD_LIBRARY_PATH" to "$libDir:$nativeLibDir",
        // NOTE: Do NOT set PROOT_NO_SECCOMP. proot-distro does NOT set it.
        // Seccomp BPF filter provides efficient syscall interception AND
        // proper fork/clone child process tracking.
        //
        // NOTE: Do NOT set PROOT_L2S_DIR. We extract with Java, not
        // `proot --link2symlink tar`, so no L2S metadata exists.
    )

    // ================================================================
    // Common proot flags shared by both install and gateway modes.
    // Matches proot-distro's bind mounts exactly.
    // ================================================================
    /**
     * Ensure resolv.conf exists before any proot invocation.
     * This is the single chokepoint — every proot operation flows through
     * commonProotFlags(), so resolv.conf is guaranteed for all callers.
     */
    private fun ensureResolvConf() {
        val content = "nameserver 8.8.8.8\nnameserver 8.8.4.4\n"

        // Primary: host-side file used by --bind mount
        try {
            File(configDir).mkdirs()
            val resolvFile = File(configDir, "resolv.conf")
            if (!resolvFile.exists() || resolvFile.length() == 0L) {
                resolvFile.writeText(content)
            }
        } catch (_: Exception) {}

        // Fallback: write directly into rootfs /etc/resolv.conf
        // so DNS works even if the bind-mount fails
        try {
            val rootfsResolv = File(rootfsDir, "etc/resolv.conf")
            if (!rootfsResolv.exists() || rootfsResolv.length() == 0L) {
                rootfsResolv.parentFile?.mkdirs()
                rootfsResolv.writeText(content)
            }
        } catch (_: Exception) {}
    }

    @SuppressLint("SdCardPath")
    private fun commonProotFlags(): List<String> {
        // Guarantee resolv.conf exists before building the bind-mount list
        ensureResolvConf()
        ensureAndroidSupplementalGroups()

        val prootPath = getProotPath()
        val procFakes = "$configDir/proc_fakes"
        val sysFakes = "$configDir/sys_fakes"

        val stdioBinds = listOf(
            0 to "/dev/stdin",
            1 to "/dev/stdout",
            2 to "/dev/stderr",
        ).mapNotNull { (fd, target) ->
            val source = File("/proc/self/fd/$fd")
            if (source.exists()) "--bind=/proc/self/fd/$fd:$target" else null
        }

        return listOf(
            prootPath,
            "--link2symlink",
            "-L",
            "--kill-on-exit",
            "--rootfs=$rootfsDir",
            "--cwd=/root",
            // Core device binds (matching proot-distro)
            "--bind=/dev",
            "--bind=/dev/urandom:/dev/random",
            "--bind=/proc",
            "--bind=/proc/self/fd:/dev/fd",
            "--bind=/sys",
            // Fake /proc entries — Android restricts most /proc access.
            // proot-distro's run_proot_cmd() binds these unconditionally.
            "--bind=$procFakes/loadavg:/proc/loadavg",
            "--bind=$procFakes/stat:/proc/stat",
            "--bind=$procFakes/uptime:/proc/uptime",
            "--bind=$procFakes/version:/proc/version",
            "--bind=$procFakes/vmstat:/proc/vmstat",
            "--bind=$procFakes/cap_last_cap:/proc/sys/kernel/cap_last_cap",
            "--bind=$procFakes/max_user_watches:/proc/sys/fs/inotify/max_user_watches",
            // Extra: libgcrypt reads this; missing causes apt SIGABRT
            "--bind=$procFakes/fips_enabled:/proc/sys/crypto/fips_enabled",
            // Shared memory — proot-distro binds rootfs/tmp to /dev/shm
            "--bind=$rootfsDir/tmp:/dev/shm",
            // SELinux override — empty dir disables SELinux checks
            "--bind=$sysFakes/empty:/sys/fs/selinux",
            // App-specific binds
            *stdioBinds.toTypedArray(),
            "--bind=$configDir/resolv.conf:/etc/resolv.conf",
            "--bind=$homeDir:/root/home",
        ).let { flags ->
            // Bind-mount shared storage into proot (Termux proot-distro style).
            // Bind the whole /storage tree so symlinks and sub-mounts resolve.
            // Then create /sdcard symlink inside rootfs pointing to the right path.
            val hasAccess = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                Environment.isExternalStorageManager()
            } else {
                val sdcard = Environment.getExternalStorageDirectory()
                sdcard.exists() && sdcard.canRead()
            }

            if (hasAccess) {
                val storageDir = File("$rootfsDir/storage")
                storageDir.mkdirs()
                // Create /sdcard symlink → /storage/emulated/0 inside rootfs
                val sdcardLink = File("$rootfsDir/sdcard")
                if (!sdcardLink.exists()) {
                    try {
                        Runtime.getRuntime().exec(
                            arrayOf("ln", "-sf", "/storage/emulated/0", "$rootfsDir/sdcard")
                        ).waitFor()
                    } catch (_: Exception) {
                        // Fallback: create as directory if symlink fails
                        sdcardLink.mkdirs()
                    }
                }
                flags + listOf(
                    "--bind=/storage:/storage",
                    "--bind=/storage/emulated/0:/sdcard"
                )
            } else {
                flags
            }
        }
    }


    private fun guestPath(): String {
        val base = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        val brewBin = File(rootfsDir, "home/linuxbrew/.linuxbrew/bin")
        val brewSbin = File(rootfsDir, "home/linuxbrew/.linuxbrew/sbin")
        return if (brewBin.exists()) {
            "/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$base"
        } else {
            base
        }
    }

    private fun ensureAndroidSupplementalGroups() {
        val groupsFile = File("/proc/self/status")
        if (!groupsFile.exists()) return

        val groupsLine = groupsFile.readLines().firstOrNull { it.startsWith("Groups:") } ?: return
        val gids = groupsLine.removePrefix("Groups:").trim().split(Regex("\\s+"))
            .mapNotNull { it.toIntOrNull() }
            .filter { it > 0 }
            .distinct()

        if (gids.isEmpty()) return

        val group = File("$rootfsDir/etc/group")
        if (group.exists()) {
            val content = group.readText()
            for (gid in gids) {
                if (!Regex("^.+:x:$gid:", RegexOption.MULTILINE).containsMatchIn(content)) {
                    group.appendText("aid_gid_$gid:x:$gid:root\n")
                }
            }
        }

        val gshadow = File("$rootfsDir/etc/gshadow")
        if (gshadow.exists()) {
            val content = gshadow.readText()
            for (gid in gids) {
                val name = "aid_gid_$gid"
                if (!Regex("^$name:", RegexOption.MULTILINE).containsMatchIn(content)) {
                    gshadow.appendText("$name:*::root\n")
                }
            }
        }
    }

    // ================================================================
    // INSTALL MODE — matches proot-distro's run_proot_cmd()
    // Used for: apt-get, dpkg, npm install, chmod, etc.
    // Simpler: no --sysvipc, simple kernel-release, minimal guest env.
    // ================================================================
    fun buildInstallCommand(command: String): List<String> {
        val flags = commonProotFlags().toMutableList()

        // --root-id: fake root identity (same as proot-distro run_proot_cmd)
        flags.add(1, "--root-id")
        // Simple kernel-release (proot-distro run_proot_cmd uses plain string)
        flags.add(2, "--kernel-release=$FAKE_KERNEL_RELEASE")
        // NOTE: --sysvipc is NOT used during install (matches proot-distro).
        // It causes SIGABRT when dpkg forks child processes.

        // Guest environment via env -i (matching proot-distro's run_proot_cmd)
        flags.addAll(listOf(
            "/usr/bin/env", "-i",
            "HOME=/root",
            "LANG=C.UTF-8",
            "PATH=${guestPath()}",
            "TERM=xterm-256color",
            "TMPDIR=/tmp",
            "DEBIAN_FRONTEND=noninteractive",
            // npm cache location (mkdir broken in proot, pre-created by Java)
            "npm_config_cache=/tmp/npm-cache",
            "/bin/bash", "-c",
            command,
        ))

        return flags
    }

    // ================================================================
    // GATEWAY MODE — matches proot-distro's command_login()
    // Used for: running openclaw gateway (long-lived Node.js process).
    // Full featured: --sysvipc, full uname struct, more guest env vars.
    // ================================================================
    fun buildGatewayCommand(command: String): List<String> {
        val flags = commonProotFlags().toMutableList()
        val arch = ArchUtils.getArch()
        // Map to uname -m format
        val machine = when (arch) {
            "arm" -> "armv7l"
            else -> arch // aarch64, x86_64, x86
        }

        // --change-id=0:0 (proot-distro command_login uses this for root)
        flags.add(1, "--change-id=0:0")
        // --sysvipc: enable SysV IPC (proot-distro enables for login sessions)
        flags.add(2, "--sysvipc")
        // Full uname struct format (matching proot-distro command_login)
        // Format: \sysname\nodename\release\version\machine\domainname\personality\
        val kernelRelease = "\\Linux\\localhost\\$FAKE_KERNEL_RELEASE" +
            "\\$FAKE_KERNEL_VERSION\\$machine\\localdomain\\-1\\"
        flags.add(3, "--kernel-release=$kernelRelease")

        // Guest environment via env -i (matching proot-distro command_login)
        // The command launches the optimized start-gateway.sh script, which
        // sets NODE_OPTIONS, NODE_COMPILE_CACHE, OPENCLAW_NO_RESPAWN, etc.
        val startScript = "$rootfsDir/root/.openclaw/start-gateway.sh"
        val resolvedCommand = if (File(startScript).exists()) {
            // Use optimized startup script if it exists
            if (command == "openclaw gateway --verbose") {
                "/root/.openclaw/start-gateway.sh"
            } else {
                command
            }
        } else {
            // Fallback: use inline env vars (pre-optimized bootstrap)
            command
        }

        val nodeOptions = "--require /root/.openclaw/bionic-bypass.js --max-old-space-size=400 --optimize-for-size --max-semi-space-size=32"

        flags.addAll(listOf(
            "/usr/bin/env", "-i",
            "HOME=/root",
            "USER=root",
            "LANG=C.UTF-8",
            "PATH=${guestPath()}",
            "TERM=xterm-256color",
            "TMPDIR=/tmp",
            "NODE_OPTIONS=$nodeOptions",
            "NODE_COMPILE_CACHE=/root/.cache/node/compile_cache",
            "OPENCLAW_NO_RESPAWN=1",
            "OPENCLAW_NO_WATCHDOG=1",
            "UV_THREADPOOL_SIZE=4",
            "CHOKIDAR_USEPOLLING=false",
            "CHOKIDAR_INTERVAL=2000",
            "NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt",
            "UV_USE_IO_URING=0",
            "/bin/bash", "-c",
            resolvedCommand,
        ))

        return flags
    }

    // Backward compatibility alias
    fun buildProotCommand(command: String): List<String> = buildInstallCommand(command)

    // ================================================================
    // Execute a command in proot (install mode) and return output.
    // Used during bootstrap for apt, npm, chmod, etc.
    // ================================================================
    fun runInProotSync(command: String, timeoutSeconds: Long = 900): String {
        val cmd = buildInstallCommand(command)
        val env = prootEnv()

        val pb = ProcessBuilder(cmd)
        // CRITICAL: Clear inherited Android JVM environment.
        // Without this, LD_PRELOAD, CLASSPATH, DEX2OAT vars leak into
        // proot and break fork+exec. proot-distro uses `env -i` on the
        // guest side AND runs from a clean Termux shell on the host side.
        // We must explicitly clear() since Android's ProcessBuilder
        // inherits the full JVM environment.
        pb.environment().clear()
        pb.environment().putAll(env)
        pb.redirectErrorStream(true)

        val process = pb.start()
        val output = StringBuilder()
        val errorLines = StringBuilder()
        val reader = BufferedReader(InputStreamReader(process.inputStream))

        var line: String?
        while (reader.readLine().also { line = it } != null) {
            val l = line ?: continue
            if (l.contains("proot warning") || l.contains("can't sanitize")) {
                continue
            }
            output.appendLine(l)
            // Collect error-relevant lines (skip apt download noise)
            if (!l.startsWith("Get:") && !l.startsWith("Fetched ") &&
                !l.startsWith("Hit:") && !l.startsWith("Ign:") &&
                !l.contains(" kB]") && !l.contains(" MB]") &&
                !l.startsWith("Reading package") && !l.startsWith("Building dependency") &&
                !l.startsWith("Reading state") && !l.startsWith("The following") &&
                !l.startsWith("Need to get") && !l.startsWith("After this") &&
                l.trim().isNotEmpty()) {
                errorLines.appendLine(l)
            }
        }

        val exited = process.waitFor(timeoutSeconds, java.util.concurrent.TimeUnit.SECONDS)
        if (!exited) {
            process.destroyForcibly()
            throw RuntimeException("Command timed out after ${timeoutSeconds}s")
        }

        val exitCode = process.exitValue()
        if (exitCode != 0) {
            val errorOutput = errorLines.toString().takeLast(3000).ifEmpty {
                output.toString().takeLast(3000)
            }
            throw RuntimeException(
                "Command failed (exit code $exitCode): $errorOutput"
            )
        }

        return output.toString()
    }

    // ================================================================
    // NEW: Run command with automatic dpkg/apt error recovery
    // ================================================================

    /**
     * Checks if a [RuntimeException] message indicates a dpkg/apt interruption
     * that can be automatically recovered.
     */
    private fun isDpkgInterruptionError(message: String?): Boolean {
        if (message == null) return false
        val msg = message.lowercase()
        return            msg.contains("dpkg was interrupted") ||
            msg.contains("exit code 100") ||
            msg.contains("dpkg --configure -a") ||
            msg.contains("could not exec dpkg") ||
            msg.contains("unable to lock the administration directory") ||
            msg.contains("could not get lock") ||
            msg.contains("lock is held by") ||
            msg.contains("package is in a very bad inconsistent state") ||
            msg.contains("sub-process /usr/bin/dpkg returned an error code") ||
            msg.contains("status database area is locked")
    }

    /**
     * Run dpkg/apt recovery commands inside proot.
     * 1. Remove lock files
     * 2. Reconfigure interrupted packages
     * 3. Fix broken dependencies
     * 4. Update package lists & upgrade
     */
    private fun runDpkgRecovery() {
        val lockCleanup = listOf(
            "/bin/rm -f /var/lib/dpkg/lock-frontend 2>/dev/null",
            "/bin/rm -f /var/lib/dpkg/lock 2>/dev/null",
            "/bin/rm -f /var/cache/apt/archives/lock 2>/dev/null",
            "/bin/rm -f /var/lib/apt/lists/lock 2>/dev/null",
        )
        for (cmd in lockCleanup) {
            try {
                runInProotSync(cmd, 30)
            } catch (_: Exception) {}
        }

        // Step 2: Configure interrupted packages
        try {
            runInProotSync("DEBIAN_FRONTEND=noninteractive dpkg --configure -a", 300)
        } catch (_: Exception) {}

        // Step 3: Fix broken dependencies
        try {
            runInProotSync("DEBIAN_FRONTEND=noninteractive apt --fix-broken install -y -q 2>/dev/null", 300)
        } catch (_: Exception) {}

        // Step 4: Update and upgrade package lists (matches user requirement #2)
        try {
            runInProotSync("DEBIAN_FRONTEND=noninteractive apt update -y -q 2>/dev/null", 300)
        } catch (_: Exception) {}
        try {
            runInProotSync("DEBIAN_FRONTEND=noninteractive apt upgrade -y -q 2>/dev/null", 300)
        } catch (_: Exception) {}
    }

    /**
     * Quick audit: check if dpkg reports any problems.
     * Returns true if recovery is needed.
     */
    private fun isDpkgAuditNeeded(): Boolean {
        return try {
            val audit = runInProotSync(
                "dpkg --audit 2>&1 || /bin/echo audit_failed", 60
            )
            audit.contains("problem") ||
                audit.contains("error") ||
                audit.contains("inconsistent") ||
                audit.contains("interrupted")
        } catch (_: Exception) {
            false // Can't check, assume OK
        }
    }

    /**
     * Run a command inside proot with pre-flight dpkg audit (no retry).
     *
     * Features:
     * - Pre-flight check: runs dpkg audit before apt-related commands
     * - Auto-recovery: if audit finds problems, runs full recovery first
     * - No retry: Dart-side orchestrator handles retry + corrupt env detection
     *
     * This is a lightweight wrapper around [runInProotSync] that only adds
     * pre-flight recovery for apt/dpkg commands. The Dart layer
     * ([BootstrapService._runProotWithRecovery]) handles retry, logging,
     * and corrupt environment detection.
     *
     * @param command The shell command to run inside proot
     * @param timeoutSeconds Maximum execution time
     * @return Command output on success
     * @throws RuntimeException on any non-zero exit code
     */
    fun runInProotWithRecovery(command: String, timeoutSeconds: Long = 900): String {
        // Only apt/dpkg commands need pre-flight recovery
        val isAptCommand = command.contains("apt") || command.contains("dpkg")

        // Pre-flight: run quick dpkg audit before apt commands
        if (isAptCommand && isDpkgAuditNeeded()) {
            runDpkgRecovery()
        }

        return runInProotSync(command, timeoutSeconds)
    }

    // ================================================================
    // Start a long-lived gateway process (gateway mode).
    // Uses full proot-distro command_login() style configuration.
    // ================================================================
    fun startProotProcess(command: String): Process {
        val cmd = buildGatewayCommand(command)
        val env = prootEnv()

        val pb = ProcessBuilder(cmd)
        pb.environment().clear()
        pb.environment().putAll(env)
        pb.redirectErrorStream(false)

        return pb.start()
    }
}
