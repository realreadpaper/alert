package com.deviceguard.core.bluetooth

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.pm.PackageManager
import android.os.ParcelUuid
import androidx.core.content.ContextCompat
import java.nio.charset.StandardCharsets
import java.util.UUID

/**
 * Minimal BLE prototype for validating local guard advertising and scanning.
 *
 * This class deliberately keeps policy out of the prototype: callers decide
 * whether it runs from an Activity or a foreground service during real-device
 * tests. Production code should replace the plain rollingId with a rolling
 * HMAC-derived identifier.
 */
class BlePrototype(
    private val context: Context,
    private val rollingId: String,
    private val onEvent: (Event) -> Unit,
    serviceUuid: UUID = UUID.fromString("75b9d2b7-7d40-4b10-9f4b-9d3592d4e101")
) {
    sealed interface Event {
        data object BluetoothUnavailable : Event
        data object MissingPermission : Event
        data object AdvertisingStarted : Event
        data class AdvertisingFailed(val errorCode: Int) : Event
        data object ScanningStarted : Event
        data class PeerDiscovered(val rollingId: String, val rssi: Int, val timestampMillis: Long) : Event
        data class ScanFailed(val errorCode: Int) : Event
    }

    private val serviceParcelUuid = ParcelUuid(serviceUuid)
    private val bluetoothAdapter: BluetoothAdapter? by lazy {
        context.getSystemService(BluetoothManager::class.java)?.adapter
    }

    private val advertiser by lazy { bluetoothAdapter?.bluetoothLeAdvertiser }
    private val scanner by lazy { bluetoothAdapter?.bluetoothLeScanner }

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
            onEvent(Event.AdvertisingStarted)
        }

        override fun onStartFailure(errorCode: Int) {
            onEvent(Event.AdvertisingFailed(errorCode))
        }
    }

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val serviceData = result.scanRecord?.getServiceData(serviceParcelUuid)
            val discoveredId = serviceData?.toString(StandardCharsets.UTF_8) ?: return
            onEvent(
                Event.PeerDiscovered(
                    rollingId = discoveredId,
                    rssi = result.rssi,
                    timestampMillis = System.currentTimeMillis()
                )
            )
        }

        override fun onScanFailed(errorCode: Int) {
            onEvent(Event.ScanFailed(errorCode))
        }
    }

    @SuppressLint("MissingPermission")
    fun start() {
        if (!hasBluetoothPermission()) {
            onEvent(Event.MissingPermission)
            return
        }

        val adapter = bluetoothAdapter
        if (adapter == null || !adapter.isEnabled || advertiser == null || scanner == null) {
            onEvent(Event.BluetoothUnavailable)
            return
        }

        startAdvertising()
        startScanning()
    }

    @SuppressLint("MissingPermission")
    fun stop() {
        if (!hasBluetoothPermission()) return
        advertiser?.stopAdvertising(advertiseCallback)
        scanner?.stopScan(scanCallback)
    }

    @SuppressLint("MissingPermission")
    private fun startAdvertising() {
        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
            .setConnectable(false)
            .build()

        val data = AdvertiseData.Builder()
            .addServiceUuid(serviceParcelUuid)
            .addServiceData(serviceParcelUuid, rollingId.toByteArray(StandardCharsets.UTF_8))
            .setIncludeDeviceName(false)
            .build()

        advertiser?.startAdvertising(settings, data, advertiseCallback)
    }

    @SuppressLint("MissingPermission")
    private fun startScanning() {
        val filter = ScanFilter.Builder()
            .setServiceUuid(serviceParcelUuid)
            .build()

        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()

        scanner?.startScan(listOf(filter), settings, scanCallback)
        onEvent(Event.ScanningStarted)
    }

    private fun hasBluetoothPermission(): Boolean {
        val scanGranted = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.BLUETOOTH_SCAN
        ) == PackageManager.PERMISSION_GRANTED
        val advertiseGranted = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.BLUETOOTH_ADVERTISE
        ) == PackageManager.PERMISSION_GRANTED
        return scanGranted && advertiseGranted
    }
}
