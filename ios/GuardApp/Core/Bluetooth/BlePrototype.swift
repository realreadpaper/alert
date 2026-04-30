import CoreBluetooth
import Foundation

/// Minimal BLE prototype for validating local guard advertising and scanning.
///
/// This file is intentionally framework-level and UI-free so it can be dropped
/// into a small iOS app target for real-device foreground/background tests.
final class BlePrototype: NSObject {
    enum Event: Equatable {
        case bluetoothStateChanged(CBManagerState)
        case advertisingStarted
        case advertisingFailed(String)
        case scanningStarted
        case peerDiscovered(rollingId: String, rssi: Int, date: Date)
    }

    private let serviceUUID: CBUUID
    private let rollingIdCharacteristicUUID: CBUUID
    private let rollingId: String
    private let onEvent: (Event) -> Void

    private var peripheralManager: CBPeripheralManager?
    private var centralManager: CBCentralManager?
    private var rollingIdCharacteristic: CBMutableCharacteristic?

    init(
        serviceUUID: CBUUID = CBUUID(string: "75B9D2B7-7D40-4B10-9F4B-9D3592D4E101"),
        rollingIdCharacteristicUUID: CBUUID = CBUUID(string: "75B9D2B8-7D40-4B10-9F4B-9D3592D4E101"),
        rollingId: String,
        onEvent: @escaping (Event) -> Void
    ) {
        self.serviceUUID = serviceUUID
        self.rollingIdCharacteristicUUID = rollingIdCharacteristicUUID
        self.rollingId = rollingId
        self.onEvent = onEvent
        super.init()
    }

    func start() {
        let queue = DispatchQueue(label: "com.deviceguard.ble-prototype")
        peripheralManager = CBPeripheralManager(delegate: self, queue: queue)
        centralManager = CBCentralManager(delegate: self, queue: queue)
    }

    func stop() {
        peripheralManager?.stopAdvertising()
        centralManager?.stopScan()
        peripheralManager = nil
        centralManager = nil
    }

    private func configurePeripheralIfNeeded(_ manager: CBPeripheralManager) {
        guard manager.state == .poweredOn else {
            onEvent(.bluetoothStateChanged(manager.state))
            return
        }

        let value = Data(rollingId.utf8)
        let characteristic = CBMutableCharacteristic(
            type: rollingIdCharacteristicUUID,
            properties: [.read],
            value: value,
            permissions: [.readable]
        )
        rollingIdCharacteristic = characteristic

        let service = CBMutableService(type: serviceUUID, primary: true)
        service.characteristics = [characteristic]
        manager.removeAllServices()
        manager.add(service)
    }

    private func startAdvertising(_ manager: CBPeripheralManager) {
        guard manager.state == .poweredOn else { return }
        manager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: "GuardProto"
        ])
    }

    private func startScanning(_ manager: CBCentralManager) {
        guard manager.state == .poweredOn else {
            onEvent(.bluetoothStateChanged(manager.state))
            return
        }

        manager.scanForPeripherals(
            withServices: [serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        onEvent(.scanningStarted)
    }
}

extension BlePrototype: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        onEvent(.bluetoothStateChanged(peripheral.state))
        configurePeripheralIfNeeded(peripheral)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error {
            onEvent(.advertisingFailed(error.localizedDescription))
            return
        }
        startAdvertising(peripheral)
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error {
            onEvent(.advertisingFailed(error.localizedDescription))
        } else {
            onEvent(.advertisingStarted)
        }
    }
}

extension BlePrototype: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        onEvent(.bluetoothStateChanged(central.state))
        startScanning(central)
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let discoveredId = localName == "GuardProto" ? "service:\(serviceUUID.uuidString)" : "unknown"
        onEvent(.peerDiscovered(rollingId: discoveredId, rssi: RSSI.intValue, date: Date()))
    }
}
