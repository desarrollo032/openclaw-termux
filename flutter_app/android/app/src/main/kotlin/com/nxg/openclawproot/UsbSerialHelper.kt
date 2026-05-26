package com.nxg.openclawproot

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbManager
import androidx.core.content.ContextCompat
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.CompletableFuture
import java.util.concurrent.TimeUnit

class UsbSerialHelper(private val context: Context) {

    private val usbManager: UsbManager =
        context.getSystemService(Context.USB_SERVICE) as UsbManager

    data class UsbDeviceInfo(
        val deviceId: Int,
        val name: String,
        val vendorId: Int,
        val productId: Int
    )

    data class UsbConnection(
        val device: UsbDevice,
        val connection: UsbDeviceConnection,
        val readEndpoint: UsbEndpoint?,
        val writeEndpoint: UsbEndpoint?
    )

    private val connections = mutableMapOf<Int, UsbConnection>()

    companion object {
        const val ACTION_USB_PERMISSION = "com.nxg.openclawproot.USB_PERMISSION"
        // Known serial adapter vendor IDs
        const val VENDOR_FTDI = 0x0403
        const val VENDOR_SILABS = 0x10C4  // CP210x
        const val VENDOR_CH340 = 0x1A86   // CH340/CH341
        const val VENDOR_PROLIFIC = 0x067B  // PL2303
    }

    /** List USB serial devices. */
    fun listDevices(): List<UsbDeviceInfo> {
        val devices = mutableListOf<UsbDeviceInfo>()
        for ((_, device) in usbManager.deviceList) {
            if (isSerialDevice(device)) {
                devices.add(UsbDeviceInfo(
                    deviceId = device.deviceId,
                    name = device.productName ?: "USB Serial Device",
                    vendorId = device.vendorId,
                    productId = device.productId
                ))
            }
        }
        return devices
    }

    private fun isSerialDevice(device: UsbDevice): Boolean {
        if (device.vendorId in setOf(VENDOR_FTDI, VENDOR_SILABS, VENDOR_CH340, VENDOR_PROLIFIC)) return true
        for (i in 0 until device.interfaceCount) {
            val intf = device.getInterface(i)
            if (intf.interfaceClass == UsbConstants.USB_CLASS_CDC_DATA) return true
            if (intf.interfaceClass == 0x02 && intf.interfaceSubclass == 0x02) return true
        }
        return false
    }

    /** Request permission and connect to a USB serial device. */
    fun connect(deviceId: Int, baudRate: Int = 115200): Boolean {
        val device = findDevice(deviceId) ?: return false
        if (connections.containsKey(deviceId)) return true

        // Request permission
        if (!usbManager.hasPermission(device)) {
            val future = CompletableFuture<Boolean>()
            val permissionReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    if (intent.action == ACTION_USB_PERMISSION) {
                        future.complete(intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false))
                    }
                }
            }
            ContextCompat.registerReceiver(
                context, permissionReceiver,
                IntentFilter(ACTION_USB_PERMISSION),
                ContextCompat.RECEIVER_NOT_EXPORTED
            )
            val pendingIntent = PendingIntent.getBroadcast(
                context, 0, Intent(ACTION_USB_PERMISSION),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            usbManager.requestPermission(device, pendingIntent)
            try {
                val granted = future.get(10, TimeUnit.SECONDS)
                context.unregisterReceiver(permissionReceiver)
                if (!granted) return false
            } catch (e: Exception) {
                return false
            }
        }

        val connection = usbManager.openDevice(device) ?: return false

        var readEndpoint: UsbEndpoint? = null
        var writeEndpoint: UsbEndpoint? = null

        for (i in 0 until device.interfaceCount) {
            val intf = device.getInterface(i)
            connection.claimInterface(intf, true)
            for (j in 0 until intf.endpointCount) {
                val ep = intf.getEndpoint(j)
                if (ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK) {
                    if (ep.direction == UsbConstants.USB_DIR_IN) readEndpoint = ep
                    else if (ep.direction == UsbConstants.USB_DIR_OUT) writeEndpoint = ep
                }
            }
        }

        if (readEndpoint == null && writeEndpoint == null) {
            connection.close()
            return false
        }

        // Configure serial port baud rate (vendor-specific)
        configureSerial(connection, device, baudRate)

        connections[deviceId] = UsbConnection(device, connection, readEndpoint, writeEndpoint)
        return true
    }

    /** Configure serial port baud rate based on vendor. */
    private fun configureSerial(connection: UsbDeviceConnection, device: UsbDevice, baudRate: Int) {
        when (device.vendorId) {
            VENDOR_FTDI -> configureFtdi(connection, device, baudRate)
            VENDOR_SILABS -> configureCp210x(connection, device, baudRate)
            VENDOR_CH340 -> configureCh340(connection, device, baudRate)
        }
    }

    /** FTDI: Set baud rate via SIO_SET_BAUD_RATE request. */
    private fun configureFtdi(connection: UsbDeviceConnection, device: UsbDevice, baudRate: Int) {
        // FTDI SIO_SET_BAUD_RATE = 0x03, SIO_SET_DATA_REQUEST = 0x0B
        val divisor = 3000000 / baudRate
        val baudValue = divisor shl 14 or divisor

        // Reset
        connection.controlTransfer(0x40, 0x00, 0x0000, 0x0000, null, 0, 100)

        // Set baud rate
        val baudBytes = ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN).putInt(baudRate).array()
        connection.controlTransfer(0x40, 0x03, baudRate, 0x0000, baudBytes, 4, 100)

        // Set line format: 8 data bits, 1 stop bit, no parity
        connection.controlTransfer(0x40, 0x0B, 0x0008, 0x0000, null, 0, 100)

        // Set flow control: none
        connection.controlTransfer(0x40, 0x02, 0x0000, 0x0000, null, 0, 100)
    }

    /** Silicon Labs CP210x: Set baud rate via vendor request. */
    private fun configureCp210x(connection: UsbDeviceConnection, device: UsbDevice, baudRate: Int) {
        // CP210x SET_BAUD_DIV = 0x01, SET_LINE_CTL = 0x03
        val baudBytes = ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN).putInt(baudRate).array()

        // Set baud rate
        connection.controlTransfer(0x41, 0x01, 0x0000, 0x0000, baudBytes, 4, 100)

        // Set line control: 8N1 (0x0800 = 8 data, 0x0000 = no parity, 0x0000 = 1 stop)
        connection.controlTransfer(0x41, 0x03, 0x0800, 0x0000, null, 0, 100)
    }

    /** CH340/CH341: Configure via specific control sequence. */
    private fun configureCh340(connection: UsbDeviceConnection, device: UsbDevice, baudRate: Int) {
        // CH340 SET_BAUD = 0x9A, SET_LINE = 0xA1
        val factor = 6000000 / baudRate
        val baudLow = factor and 0xFF
        val baudHigh = (factor shr 8) and 0xFF

        // Set baud rate
        connection.controlTransfer(0x40, 0x9A, 0x1312, 0xD982.toInt(), byteArrayOf(baudLow.toByte(), baudHigh.toByte()), 2, 100)

        // Set line format: 8N1
        connection.controlTransfer(0x40, 0xA1, 0x0000, 0x0000, null, 0, 100)

        // Enable
        connection.controlTransfer(0x40, 0xA4, 0xDF28.toInt(), 0x0000, null, 0, 100)
    }

    fun disconnect(deviceId: Int) {
        val conn = connections.remove(deviceId)
        conn?.let {
            try {
                for (i in 0 until it.device.interfaceCount) {
                    it.connection.releaseInterface(it.device.getInterface(i))
                }
            } catch (_: Exception) {}
            it.connection.close()
        }
    }

    fun write(deviceId: Int, data: ByteArray): Boolean {
        val conn = connections[deviceId] ?: return false
        val ep = conn.writeEndpoint ?: return false
        val transferred = conn.connection.bulkTransfer(ep, data, data.size, 1000)
        return transferred >= 0
    }

    fun read(deviceId: Int, timeoutMs: Int = 2000): ByteArray? {
        val conn = connections[deviceId] ?: return null
        val ep = conn.readEndpoint ?: return null
        val buffer = ByteArray(1024)
        val transferred = conn.connection.bulkTransfer(ep, buffer, buffer.size, timeoutMs)
        return if (transferred > 0) buffer.copyOf(transferred) else null
    }

    fun disconnectAll() {
        for (deviceId in connections.keys.toList()) disconnect(deviceId)
    }

    private fun findDevice(deviceId: Int): UsbDevice? {
        for ((_, device) in usbManager.deviceList) {
            if (device.deviceId == deviceId) return device
        }
        return null
    }
}
