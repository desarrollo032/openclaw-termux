package com.nxg.openclawproot

import android.content.Context
import android.content.Intent
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.net.Uri
import androidx.core.content.FileProvider
import java.io.File

class CameraHelper(private val context: Context) {

    private val cameraManager: CameraManager =
        context.getSystemService(Context.CAMERA_SERVICE) as CameraManager

    data class CameraDevice(val id: String, val facing: String)

    /** List available cameras and their facing direction. */
    fun listCameras(): List<CameraDevice> {
        val cameras = mutableListOf<CameraDevice>()
        for (cameraId in cameraManager.cameraIdList) {
            val characteristics = cameraManager.getCameraCharacteristics(cameraId)
            val facing = characteristics.get(CameraCharacteristics.LENS_FACING)
            val facingStr = when (facing) {
                CameraCharacteristics.LENS_FACING_FRONT -> "front"
                CameraCharacteristics.LENS_FACING_BACK -> "back"
                else -> "external"
            }
            cameras.add(CameraDevice(cameraId, facingStr))
        }
        return cameras
    }

    /** Create an Intent for capturing a photo via the system camera.
     *  Returns (Intent, outputFilePath) */
    fun createPhotoIntent(facing: String?): Pair<Intent, String> {
        val dir = File(context.cacheDir, "camera")
        dir.mkdirs()
        val photoFile = File(dir, "snap_${System.currentTimeMillis()}.jpg")
        val photoUri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            photoFile
        )
        val intent = Intent(android.provider.MediaStore.ACTION_IMAGE_CAPTURE).apply {
            putExtra(android.provider.MediaStore.EXTRA_OUTPUT, photoUri)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        }
        return Pair(intent, photoFile.absolutePath)
    }

    /** Create an Intent for recording a video via the system camera.
     *  Returns (Intent, outputFilePath) */
    fun createVideoIntent(durationMs: Int): Pair<Intent, String> {
        val dir = File(context.cacheDir, "camera")
        dir.mkdirs()
        val videoFile = File(dir, "clip_${System.currentTimeMillis()}.mp4")
        val videoUri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            videoFile
        )
        val intent = Intent(android.provider.MediaStore.ACTION_VIDEO_CAPTURE).apply {
            putExtra(android.provider.MediaStore.EXTRA_OUTPUT, videoUri)
            putExtra(android.provider.MediaStore.EXTRA_DURATION_LIMIT, durationMs / 1000)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        }
        return Pair(intent, videoFile.absolutePath)
    }

    /** Read a camera output file as bytes. */
    fun readCameraFile(filePath: String): ByteArray? {
        return try {
            File(filePath).takeIf { it.exists() }?.readBytes()
        } catch (e: Exception) {
            null
        }
    }

    /** Delete a camera output file. */
    fun deleteCameraFile(filePath: String) {
        try {
            File(filePath).delete()
        } catch (_: Exception) {}
    }

    /** Toggle torch mode on/off on the first back-facing camera. */
    fun setTorch(on: Boolean): Boolean {
        try {
            val backCameraId = cameraManager.cameraIdList.firstOrNull { cameraId ->
                val facing = cameraManager.getCameraCharacteristics(cameraId)
                    .get(CameraCharacteristics.LENS_FACING)
                facing == CameraCharacteristics.LENS_FACING_BACK
            } ?: return false
            cameraManager.setTorchMode(backCameraId, on)
            return true
        } catch (e: Exception) {
            return false
        }
    }

    /** Check if torch is available (any back camera supports flash). */
    fun isTorchAvailable(): Boolean {
        return cameraManager.cameraIdList.any { cameraId ->
            val characteristics = cameraManager.getCameraCharacteristics(cameraId)
            val facing = characteristics.get(CameraCharacteristics.LENS_FACING)
            facing == CameraCharacteristics.LENS_FACING_BACK &&
                characteristics.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
        }
    }
}
