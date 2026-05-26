package com.nxg.openclawproot.handlers

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.nxg.openclawproot.MainActivity
import com.nxg.openclawproot.CameraHelper
import com.nxg.openclawproot.BleHelper
import com.nxg.openclawproot.UsbSerialHelper
import com.nxg.openclawproot.LocationHelper
import java.util.concurrent.ExecutorService

class HardwareHandler(
    private val context: Context,
    private val activity: MainActivity,
    private val executor: ExecutorService,
    private val cameraHelper: CameraHelper,
    private val locationHelper: LocationHelper,
    private val bleHelper: BleHelper,
    private val usbSerialHelper: UsbSerialHelper
) : BaseHandler {

    override fun handleMethodCall(call: MethodCall, result: MethodChannel.Result): Boolean {
        when (call.method) {
            "readSensor" -> {
                readSensor(call, result)
                return true
            }
            "getCameraList" -> {
                executor.execute {
                    try {
                        val cameras = cameraHelper.listCameras()
                        val list = cameras.map { c ->
                            hashMapOf<String, Any>("id" to c.id, "facing" to c.facing)
                        }
                        activity.runOnUiThread { result.success(list) }
                    } catch (e: Exception) {
                        activity.runOnUiThread { result.error("CAMERA_ERROR", e.message, null) }
                    }
                }
                return true
            }
            "toggleTorch" -> {
                val on = call.argument<Boolean>("on") ?: false
                try {
                    val success = cameraHelper.setTorch(on)
                    result.success(success)
                } catch (e: Exception) {
                    result.error("TORCH_ERROR", e.message, null)
                }
                return true
            }
            "isTorchAvailable" -> {
                result.success(cameraHelper.isTorchAvailable())
                return true
            }
            "cameraSnap" -> {
                try {
                    val facing = call.argument<String>("facing")
                    val (intent, filePath) = cameraHelper.createPhotoIntent(facing)
                    activity.setCameraPhotoResult(result, filePath)
                    activity.startActivityForResult(intent, MainActivity.CAMERA_PHOTO_REQUEST)
                } catch (e: Exception) {
                    result.error("CAMERA_ERROR", e.message, null)
                }
                return true
            }
            "cameraClip" -> {
                val durationMs = call.argument<Int>("durationMs") ?: 5000
                try {
                    val (intent, filePath) = cameraHelper.createVideoIntent(durationMs)
                    activity.setCameraVideoResult(result, filePath)
                    activity.startActivityForResult(intent, MainActivity.CAMERA_VIDEO_REQUEST)
                } catch (e: Exception) {
                    result.error("CAMERA_ERROR", e.message, null)
                }
                return true
            }
            "isLocationServiceEnabled" -> {
                result.success(locationHelper.isLocationServiceEnabled())
                return true
            }
            "getCurrentLocation" -> {
                executor.execute {
                    try {
                        val loc = locationHelper.getCurrentLocation()
                        if (loc != null) {
                            val data = hashMapOf<String, Any>(
                                "latitude" to loc.latitude,
                                "longitude" to loc.longitude,
                                "accuracy" to loc.accuracy.toDouble(),
                                "altitude" to loc.altitude,
                                "timestamp" to loc.timestamp
                            )
                            activity.runOnUiThread { result.success(data) }
                        } else {
                            activity.runOnUiThread { result.error("LOCATION_ERROR", "Could not determine location", null) }
                        }
                    } catch (e: SecurityException) {
                        activity.runOnUiThread { result.error("PERMISSION_DENIED", "Location permission not granted", null) }
                    } catch (e: Exception) {
                        activity.runOnUiThread { result.error("LOCATION_ERROR", e.message, null) }
                    }
                }
                return true
            }
            "bleScan" -> {
                val timeoutMs = call.argument<Int>("timeoutMs")?.toLong() ?: 3000L
                executor.execute {
                    try {
                        val devices = bleHelper.scan(timeoutMs)
                        val list = devices.map { d ->
                            hashMapOf<String, Any>(
                                "id" to d.id,
                                "name" to d.name,
                                "rssi" to d.rssi
                            )
                        }
                        activity.runOnUiThread { result.success(list) }
                    } catch (e: Exception) {
                        activity.runOnUiThread { result.error("BLE_ERROR", e.message, null) }
                    }
                }
                return true
            }
            "bleConnect" -> {
                val deviceId = call.argument<String>("deviceId")
                if (deviceId != null) {
                    executor.execute {
                        try {
                            val success = bleHelper.connect(deviceId)
                            activity.runOnUiThread { result.success(success) }
                        } catch (e: Exception) {
                            activity.runOnUiThread { result.error("BLE_ERROR", e.message, null) }
                        }
                    }
                } else {
                    result.error("INVALID_ARGS", "deviceId required", null)
                }
                return true
            }
            "bleDisconnect" -> {
                val deviceId = call.argument<String>("deviceId")
                if (deviceId != null) {
                    executor.execute {
                        try {
                            bleHelper.disconnect(deviceId)
                            activity.runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            activity.runOnUiThread { result.error("BLE_ERROR", e.message, null) }
                        }
                    }
                } else {
                    bleHelper.disconnectAll()
                    result.success(true)
                }
                return true
            }
            "bleWrite" -> {
                val deviceId = call.argument<String>("deviceId")
                val data = call.argument<ByteArray>("data")
                if (deviceId != null && data != null) {
                    executor.execute {
                        try {
                            val success = bleHelper.write(deviceId, data)
                            activity.runOnUiThread { result.success(success) }
                        } catch (e: Exception) {
                            activity.runOnUiThread { result.error("BLE_ERROR", e.message, null) }
                        }
                    }
                } else {
                    result.error("INVALID_ARGS", "deviceId and data required", null)
                }
                return true
            }
            "bleRead" -> {
                val deviceId = call.argument<String>("deviceId")
                val timeoutMs = call.argument<Int>("timeoutMs") ?: 2000
                if (deviceId != null) {
                    executor.execute {
                        try {
                            val data = bleHelper.read(deviceId, timeoutMs.toLong())
                            activity.runOnUiThread { result.success(data) }
                        } catch (e: Exception) {
                            activity.runOnUiThread { result.error("BLE_ERROR", e.message, null) }
                        }
                    }
                } else {
                    result.error("INVALID_ARGS", "deviceId required", null)
                }
                return true
            }
            "bleListServices" -> {
                val deviceId = call.argument<String>("deviceId")
                if (deviceId != null) {
                    executor.execute {
                        try {
                            val services = bleHelper.discoverServices(deviceId)
                            val list = services.map { s ->
                                hashMapOf<String, Any>(
                                    "uuid" to s.uuid,
                                    "characteristics" to s.characteristics.map { c ->
                                        hashMapOf<String, Any>(
                                            "uuid" to c.uuid,
                                            "properties" to c.properties
                                        )
                                    }
                                )
                            }
                            activity.runOnUiThread { result.success(list) }
                        } catch (e: Exception) {
                            activity.runOnUiThread { result.error("BLE_ERROR", e.message, null) }
                        }
                    }
                } else {
                    result.error("INVALID_ARGS", "deviceId required", null)
                }
                return true
            }
            "usbList" -> {
                executor.execute {
                    try {
                        val devices = usbSerialHelper.listDevices()
                        val list = devices.map { d ->
                            hashMapOf<String, Any>(
                                "deviceId" to d.deviceId,
                                "name" to d.name,
                                "vendorId" to d.vendorId,
                                "productId" to d.productId
                            )
                        }
                        activity.runOnUiThread { result.success(list) }
                    } catch (e: Exception) {
                        activity.runOnUiThread { result.error("USB_ERROR", e.message, null) }
                    }
                }
                return true
            }
            "usbConnect" -> {
                val deviceId = call.argument<Int>("deviceId")
                val baudRate = call.argument<Int>("baudRate") ?: 115200
                if (deviceId != null) {
                    executor.execute {
                        try {
                            val success = usbSerialHelper.connect(deviceId, baudRate)
                            activity.runOnUiThread { result.success(success) }
                        } catch (e: Exception) {
                            activity.runOnUiThread { result.error("USB_ERROR", e.message, null) }
                        }
                    }
                } else {
                    result.error("INVALID_ARGS", "deviceId required", null)
                }
                return true
            }
            "usbDisconnect" -> {
                val deviceId = call.argument<Int>("deviceId")
                if (deviceId != null) {
                    usbSerialHelper.disconnect(deviceId)
                    result.success(true)
                } else {
                    usbSerialHelper.disconnectAll()
                    result.success(true)
                }
                return true
            }
            "usbWrite" -> {
                val deviceId = call.argument<Int>("deviceId")
                val data = call.argument<ByteArray>("data")
                if (deviceId != null && data != null) {
                    executor.execute {
                        try {
                            val success = usbSerialHelper.write(deviceId, data)
                            activity.runOnUiThread { result.success(success) }
                        } catch (e: Exception) {
                            activity.runOnUiThread { result.error("USB_ERROR", e.message, null) }
                        }
                    }
                } else {
                    result.error("INVALID_ARGS", "deviceId and data required", null)
                }
                return true
            }
            "usbRead" -> {
                val deviceId = call.argument<Int>("deviceId")
                val timeoutMs = call.argument<Int>("timeoutMs") ?: 2000
                if (deviceId != null) {
                    executor.execute {
                        try {
                            val data = usbSerialHelper.read(deviceId, timeoutMs)
                            activity.runOnUiThread { result.success(data) }
                        } catch (e: Exception) {
                            activity.runOnUiThread { result.error("USB_ERROR", e.message, null) }
                        }
                    }
                } else {
                    result.error("INVALID_ARGS", "deviceId required", null)
                }
                return true
            }
        }
        return false
    }

    private fun readSensor(call: MethodCall, result: MethodChannel.Result) {
        val sensorType = call.argument<String>("sensor") ?: "accelerometer"
        executor.execute {
            try {
                val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
                val type = when (sensorType) {
                    "accelerometer" -> Sensor.TYPE_ACCELEROMETER
                    "gyroscope" -> Sensor.TYPE_GYROSCOPE
                    "magnetometer" -> Sensor.TYPE_MAGNETIC_FIELD
                    "barometer" -> Sensor.TYPE_PRESSURE
                    else -> Sensor.TYPE_ACCELEROMETER
                }
                val sensor = sensorManager.getDefaultSensor(type)
                if (sensor == null) {
                    activity.runOnUiThread {
                        result.error("SENSOR_ERROR", "Sensor $sensorType not available", null)
                    }
                    return@execute
                }
                var received = false
                val listener = object : SensorEventListener {
                    override fun onSensorChanged(event: SensorEvent?) {
                        if (received || event == null) return
                        received = true
                        sensorManager.unregisterListener(this)
                        val data = hashMapOf<String, Any>(
                            "sensor" to sensorType,
                            "timestamp" to event.timestamp,
                            "accuracy" to event.accuracy
                        )
                        when (sensorType) {
                            "accelerometer", "gyroscope", "magnetometer" -> {
                                data["x"] = event.values[0].toDouble()
                                data["y"] = event.values[1].toDouble()
                                data["z"] = event.values[2].toDouble()
                            }
                            "barometer" -> {
                                data["pressure"] = event.values[0].toDouble()
                            }
                        }
                        activity.runOnUiThread { result.success(data) }
                    }
                    override fun onAccuracyChanged(s: Sensor?, accuracy: Int) {}
                }
                sensorManager.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_NORMAL)
                // Timeout after 3 seconds
                Thread.sleep(3000)
                if (!received) {
                    sensorManager.unregisterListener(listener)
                    activity.runOnUiThread {
                        result.error("SENSOR_ERROR", "Sensor read timed out", null)
                    }
                }
            } catch (e: Exception) {
                activity.runOnUiThread { result.error("SENSOR_ERROR", e.message, null) }
            }
        }
    }
}
