package com.nxg.openclawproot

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.Build
import java.util.concurrent.CompletableFuture
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class BleHelper(private val context: Context) {

    private val bluetoothManager: BluetoothManager? =
        context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
    private val bluetoothAdapter: BluetoothAdapter? = bluetoothManager?.adapter

    data class BleDevice(
        val id: String,
        val name: String,
        val rssi: Int
    )

    data class BleService(
        val uuid: String,
        val characteristics: List<BleCharacteristic>
    )

    data class BleCharacteristic(
        val uuid: String,
        val properties: Int
    )

    // Active connections: device address -> GattConnection
    private val connections = mutableMapOf<String, GattConnection>()

    /** Wraps a BluetoothGatt and its callback for notification handling. */
    private class GattConnection(
        val gatt: BluetoothGatt,
        val callback: GattCallbackWrapper
    )

    /**
     * Wraps BluetoothGattCallback and provides notification listeners.
     * Only one listener is active at a time for reads.
     */
    private class GattCallbackWrapper : BluetoothGattCallback() {
        @Volatile
        var notificationListener: ((ByteArray) -> Unit)? = null

        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            // Handled by CompletableFuture in connect()
        }

        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic
        ) {
            val listener = notificationListener
            if (listener != null) {
                val value = characteristic.value ?: return
                listener(value)
            }
        }
    }

    /** Scan for BLE devices (blocking, run on background thread). */
    fun scan(timeoutMs: Long = 3000): List<BleDevice> {
        if (bluetoothAdapter?.isEnabled != true) return emptyList()

        val scanner = bluetoothAdapter.bluetoothLeScanner ?: return emptyList()
        val results = mutableListOf<BleDevice>()
        val latch = CountDownLatch(1)

        val scanCallback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult?) {
                if (result != null) {
                    val device = result.device
                    if (device != null && !results.any { it.id == device.address }) {
                        results.add(BleDevice(
                            id = device.address,
                            name = device.name ?: "Unknown",
                            rssi = result.rssi
                        ))
                    }
                }
            }

            override fun onScanFailed(errorCode: Int) {
                latch.countDown()
            }
        }

        try {
            val settings = ScanSettings.Builder()
                .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                .build()
            scanner.startScan(null, settings, scanCallback)
            latch.await(timeoutMs, TimeUnit.MILLISECONDS)
        } catch (_: InterruptedException) {
        } finally {
            scanner.stopScan(scanCallback)
        }

        return results
    }

    /** Connect to a BLE device by MAC address (blocking, run on background thread). */
    fun connect(deviceAddress: String, timeoutMs: Long = 10_000): Boolean {
        if (bluetoothAdapter?.isEnabled != true) return false

        val device = bluetoothAdapter.getRemoteDevice(deviceAddress) ?: return false

        // Already connected
        if (connections.containsKey(deviceAddress)) return true

        val future = CompletableFuture<Boolean>()
        val callback = GattCallbackWrapper()

        val gattCallback = object : BluetoothGattCallback() {
            override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                if (status != BluetoothGatt.GATT_SUCCESS) {
                    gatt.close()
                    future.complete(false)
                    return
                }
                if (newState == BluetoothProfile.STATE_CONNECTED) {
                    gatt.discoverServices()
                } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                    connections.remove(deviceAddress)
                    future.complete(false)
                }
            }

            override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    // Enable NUS TX notifications automatically
                    enableNusNotification(gatt, callback)
                    connections[deviceAddress] = GattConnection(gatt, callback)
                    future.complete(true)
                } else {
                    gatt.close()
                    future.complete(false)
                }
            }
        }

        // connectGatt must be called on the main thread
        val connectFuture = CompletableFuture<BluetoothGatt>()
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            val gatt = device.connectGatt(context, false, gattCallback)
            connectFuture.complete(gatt)
        }
        val gatt = try { connectFuture.get(5, TimeUnit.SECONDS) } catch (_: Exception) { null }
        if (gatt == null) return false

        return try {
            future.get(timeoutMs, TimeUnit.MILLISECONDS)
        } catch (e: Exception) {
            gatt.close()
            false
        }
    }

    /** Enable notifications on NUS TX characteristic for incoming data. */
    private fun enableNusNotification(gatt: BluetoothGatt, callback: GattCallbackWrapper) {
        val nusUuid = java.util.UUID.fromString("6e400001-b5a3-f393-e0a9-e50e24dcca9e")
        val txUuid = java.util.UUID.fromString("6e400003-b5a3-f393-e0a9-e50e24dcca9e")
        val cccdUuid = java.util.UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

        for (service in gatt.services) {
            if (service.uuid == nusUuid) {
                for (char in service.characteristics) {
                    if (char.uuid == txUuid) {
                        val cccd = char.getDescriptor(cccdUuid)
                        if (cccd != null) {
                            gatt.setCharacteristicNotification(char, true)
                            cccd.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                            gatt.writeDescriptor(cccd)
                        }
                        gatt.setCharacteristicNotification(char, true)
                    }
                }
            }
        }
    }

    /** Disconnect from a BLE device. */
    fun disconnect(deviceAddress: String) {
        val conn = connections.remove(deviceAddress)
        conn?.let {
            it.callback.notificationListener = null
            try {
                it.gatt.disconnect()
            } catch (_: Exception) {}
            try {
                it.gatt.close()
            } catch (_: Exception) {}
        }
    }

    /** Discover services on a connected device. */
    fun discoverServices(deviceAddress: String): List<BleService> {
        val conn = connections[deviceAddress] ?: return emptyList()
        val services = mutableListOf<BleService>()

        for (service in conn.gatt.services) {
            val chars = service.characteristics.map { c ->
                BleCharacteristic(
                    uuid = c.uuid.toString(),
                    properties = c.properties
                )
            }
            services.add(BleService(
                uuid = service.uuid.toString(),
                characteristics = chars
            ))
        }
        return services
    }

    /** Find NUS RX characteristic for writing data. */
    private fun findNusRxChar(gatt: BluetoothGatt): BluetoothGattCharacteristic? {
        val nusUuid = java.util.UUID.fromString("6e400001-b5a3-f393-e0a9-e50e24dcca9e")
        val rxUuid = java.util.UUID.fromString("6e400002-b5a3-f393-e0a9-e50e24dcca9e")

        for (service in gatt.services) {
            if (service.uuid == nusUuid) {
                for (c in service.characteristics) {
                    if (c.uuid == rxUuid) return c
                }
            }
        }
        return null
    }

    /** Write data to a BLE device (using NUS RX characteristic). Blocking. */
    fun write(deviceAddress: String, data: ByteArray): Boolean {
        val conn = connections[deviceAddress] ?: return false
        val char = findNusRxChar(conn.gatt) ?: return false

        val mtu = 20
        var i = 0
        while (i < data.size) {
            val end = minOf(i + mtu, data.size)
            val chunk = data.copyOfRange(i, end)
            char.value = chunk
            val written = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                val future = CompletableFuture<Boolean>()
                val executor = java.util.concurrent.Executors.newSingleThreadExecutor()
                conn.gatt.writeCharacteristic(chunk, char, BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE, executor) { status ->
                    future.complete(status == BluetoothGatt.GATT_SUCCESS)
                }
                try { future.get(5, TimeUnit.SECONDS) } catch (_: Exception) { false }
            } else {
                @Suppress("DEPRECATION")
                conn.gatt.writeCharacteristic(char)
            }
            if (!written) return false
            i += mtu
            Thread.sleep(20)
        }
        return true
    }

    /** Read data from BLE device notifications. Returns null on timeout. */
    fun read(deviceAddress: String, timeoutMs: Long = 2000): ByteArray? {
        val conn = connections[deviceAddress] ?: return null

        val future = CompletableFuture<ByteArray?>()

        // Set up one-shot notification listener
        conn.callback.notificationListener = { data ->
            future.complete(data)
        }

        // Timeout
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            if (!future.isDone) {
                conn.callback.notificationListener = null
                future.complete(null)
            }
        }, timeoutMs)

        return try {
            future.get(timeoutMs + 1000, TimeUnit.MILLISECONDS)
        } catch (e: Exception) {
            conn.callback.notificationListener = null
            null
        }
    }

    /** Get list of connected device addresses. */
    fun getConnectedDevices(): List<String> {
        return connections.keys.toList()
    }

    /** Disconnect all devices. */
    fun disconnectAll() {
        for (addr in connections.keys.toList()) {
            disconnect(addr)
        }
    }
}
