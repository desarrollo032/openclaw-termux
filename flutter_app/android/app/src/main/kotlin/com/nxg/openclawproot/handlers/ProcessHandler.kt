package com.nxg.openclawproot.handlers

import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Environment
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.nxg.openclawproot.*
import java.util.concurrent.ExecutorService

class ProcessHandler(
    private val context: Context,
    private val activity: MainActivity,
    private val executor: ExecutorService,
    private val bootstrapManager: BootstrapManager,
    private val processManager: ProcessManager
) : BaseHandler {

    override fun handleMethodCall(call: MethodCall, result: MethodChannel.Result): Boolean {
        when (call.method) {
            "getProotPath" -> {
                result.success(processManager.getProotPath())
                return true
            }
            "getArch" -> {
                result.success(ArchUtils.getArch())
                return true
            }
            "getFilesDir" -> {
                result.success(context.filesDir.absolutePath)
                return true
            }
            "getNativeLibDir" -> {
                result.success(context.applicationInfo.nativeLibraryDir)
                return true
            }
            "isBootstrapComplete" -> {
                result.success(bootstrapManager.isBootstrapComplete())
                return true
            }
            "getBootstrapStatus" -> {
                result.success(bootstrapManager.getBootstrapStatus())
                return true
            }
            "extractRootfs" -> {
                val tarPath = call.argument<String>("tarPath")
                val sha256 = call.argument<String>("sha256")
                if (tarPath != null) {
                    executor.execute {
                        try {
                            bootstrapManager.extractRootfs(tarPath, sha256)
                            activity.runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            activity.runOnUiThread { result.error("EXTRACT_ERROR", e.message, null) }
                        }
                    }
                } else {
                    result.error("INVALID_ARGS", "tarPath required", null)
                }
                return true
            }
            "runInProot" -> {
                val command = call.argument<String>("command")
                val timeout = call.argument<Int>("timeout")?.toLong() ?: 900L
                if (command != null) {
                    executor.execute {
                        try {
                            val output = processManager.runInProotWithRecovery(command, timeout)
                            activity.runOnUiThread { result.success(output) }
                        } catch (e: Exception) {
                            activity.runOnUiThread { result.error("PROOT_ERROR", e.message, null) }
                        }
                    }
                } else {
                    result.error("INVALID_ARGS", "command required", null)
                }
                return true
            }
            "startGateway" -> {
                try {
                    GatewayService.start(context)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("SERVICE_ERROR", e.message, null)
                }
                return true
            }
            "stopGateway" -> {
                try {
                    GatewayService.stop(context)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("SERVICE_ERROR", e.message, null)
                }
                return true
            }
            "isGatewayRunning" -> {
                result.success(GatewayService.isProcessAlive())
                return true
            }
            "setRuntimeMode" -> {
                val mode = call.argument<String>("mode") ?: "IDLE"
                GatewayService.setRuntimeMode(mode)
                result.success(true)
                return true
            }
            "getRuntimeDiagnostics" -> {
                result.success(GatewayService.getRuntimeDiagnostics())
                return true
            }
            "startTerminalService" -> {
                try {
                    TerminalSessionService.start(context)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("SERVICE_ERROR", e.message, null)
                }
                return true
            }
            "stopTerminalService" -> {
                try {
                    TerminalSessionService.stop(context)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("SERVICE_ERROR", e.message, null)
                }
                return true
            }
            "isTerminalServiceRunning" -> {
                result.success(TerminalSessionService.isRunning)
                return true
            }
            "renewTerminalWakeLock" -> {
                TerminalSessionService.renewWakeLock(context)
                result.success(true)
                return true
            }
            "startNodeService" -> {
                try {
                    NodeForegroundService.start(context)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("SERVICE_ERROR", e.message, null)
                }
                return true
            }
            "stopNodeService" -> {
                try {
                    NodeForegroundService.stop(context)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("SERVICE_ERROR", e.message, null)
                }
                return true
            }
            "isNodeServiceRunning" -> {
                result.success(NodeForegroundService.isRunning)
                return true
            }
            "updateNodeNotification" -> {
                val text = call.argument<String>("text") ?: "Node connected"
                NodeForegroundService.updateStatus(text)
                result.success(true)
                return true
            }
            "startSshd" -> {
                val port = call.argument<Int>("port") ?: 8022
                try {
                    SshForegroundService.start(context, port)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("SERVICE_ERROR", e.message, null)
                }
                return true
            }
            "stopSshd" -> {
                try {
                    SshForegroundService.stop(context)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("SERVICE_ERROR", e.message, null)
                }
                return true
            }
            "isSshdRunning" -> {
                result.success(SshForegroundService.isRunning)
                return true
            }
            "getSshdPort" -> {
                result.success(SshForegroundService.currentPort)
                return true
            }
            "getDeviceIps" -> {
                result.success(SshForegroundService.getDeviceIps())
                return true
            }
            "setRootPassword" -> {
                val password = call.argument<String>("password")
                if (password != null) {
                    executor.execute {
                        try {
                            val escaped = password.replace("'", "'\\''")
                            processManager.runInProotSync("echo 'root:$escaped' | chpasswd", 15)
                            activity.runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            activity.runOnUiThread { result.error("SSH_ERROR", e.message, null) }
                        }
                    }
                } else {
                    result.error("INVALID_ARGS", "password required", null)
                }
                return true
            }
            "setupDirs" -> {
                executor.execute {
                    try {
                        bootstrapManager.setupDirectories()
                        activity.runOnUiThread { result.success(true) }
                    } catch (e: Exception) {
                        activity.runOnUiThread { result.error("SETUP_ERROR", e.message, null) }
                    }
                }
                return true
            }
            "installBionicBypass" -> {
                executor.execute {
                    try {
                        bootstrapManager.installBionicBypass()
                        activity.runOnUiThread { result.success(true) }
                    } catch (e: Exception) {
                        activity.runOnUiThread { result.error("BYPASS_ERROR", e.message, null) }
                    }
                }
                return true
            }
            "writeResolv" -> {
                executor.execute {
                    try {
                        bootstrapManager.writeResolvConf()
                        activity.runOnUiThread { result.success(true) }
                    } catch (e: Exception) {
                        activity.runOnUiThread { result.error("RESOLV_ERROR", e.message, null) }
                    }
                }
                return true
            }
            "extractDebPackages" -> {
                executor.execute {
                    try {
                        val count = bootstrapManager.extractDebPackages()
                        activity.runOnUiThread { result.success(count) }
                    } catch (e: Exception) {
                        activity.runOnUiThread { result.error("DEB_EXTRACT_ERROR", e.message, null) }
                    }
                }
                return true
            }
            "extractNodeTarball" -> {
                val tarPath = call.argument<String>("tarPath")
                if (tarPath != null) {
                    executor.execute {
                        try {
                            bootstrapManager.extractNodeTarball(tarPath)
                            activity.runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            activity.runOnUiThread { result.error("NODE_EXTRACT_ERROR", e.message, null) }
                        }
                    }
                } else {
                    result.error("INVALID_ARGS", "tarPath required", null)
                }
                return true
            }
            "createBinWrappers" -> {
                val packageName = call.argument<String>("packageName")
                if (packageName != null) {
                    executor.execute {
                        try {
                            bootstrapManager.createBinWrappers(packageName)
                            activity.runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            activity.runOnUiThread { result.error("BIN_WRAPPER_ERROR", e.message, null) }
                        }
                    }
                } else {
                    result.error("INVALID_ARGS", "packageName required", null)
                }
                return true
            }
            "startSetupService" -> {
                try {
                    SetupService.start(context)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("SERVICE_ERROR", e.message, null)
                }
                return true
            }
            "updateSetupNotification" -> {
                val text = call.argument<String>("text")
                val progress = call.argument<Int>("progress") ?: -1
                if (text != null) {
                    SetupService.updateNotification(text, progress)
                    result.success(true)
                } else {
                    result.error("INVALID_ARGS", "text required", null)
                }
                return true
            }
            "stopSetupService" -> {
                try {
                    SetupService.stop(context)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("SERVICE_ERROR", e.message, null)
                }
                return true
            }
            "requestScreenCapture" -> {
                val durationMs = call.argument<Int>("durationMs")?.toLong() ?: 5000L
                activity.setScreenCaptureResult(result, durationMs)
                val projectionManager = context.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                activity.startActivityForResult(projectionManager.createScreenCaptureIntent(), MainActivity.SCREEN_CAPTURE_REQUEST)
                return true
            }
            "stopScreenCapture" -> {
                try {
                    activity.stopService(Intent(context, ScreenCaptureService::class.java))
                    result.success(true)
                } catch (e: Exception) {
                    result.error("SERVICE_ERROR", e.message, null)
                }
                return true
            }
            "requestStoragePermission" -> {
                activity.requestStoragePermission(result)
                return true
            }
            "hasStoragePermission" -> {
                result.success(activity.hasStoragePermission())
                return true
            }
            "getExternalStoragePath" -> {
                result.success(Environment.getExternalStorageDirectory().absolutePath)
                return true
            }
            "readRootfsFile" -> {
                val path = call.argument<String>("path")
                if (path != null) {
                    executor.execute {
                        try {
                            val content = bootstrapManager.readRootfsFile(path)
                            activity.runOnUiThread { result.success(content) }
                        } catch (e: Exception) {
                            activity.runOnUiThread { result.error("ROOTFS_READ_ERROR", e.message, null) }
                        }
                    }
                } else {
                    result.error("INVALID_ARGS", "path required", null)
                }
                return true
            }
            "writeRootfsFile" -> {
                val path = call.argument<String>("path")
                val content = call.argument<String>("content")
                if (path != null && content != null) {
                    executor.execute {
                        try {
                            bootstrapManager.writeRootfsFile(path, content)
                            activity.runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            activity.runOnUiThread { result.error("ROOTFS_WRITE_ERROR", e.message, null) }
                        }
                    }
                } else {
                    result.error("INVALID_ARGS", "path and content required", null)
                }
                return true
            }
            "showUrlNotification" -> {
                val url = call.argument<String>("url")
                val title = call.argument<String>("title") ?: "URL Detected"
                if (url != null) {
                    activity.showUrlNotification(url, title)
                    result.success(true)
                } else {
                    result.error("INVALID_ARGS", "url required", null)
                }
                return true
            }
        }
        return false
    }
}
