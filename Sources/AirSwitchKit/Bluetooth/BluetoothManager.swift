import Foundation
@preconcurrency import IOBluetooth

public final class BluetoothManager {
    public static let shared = BluetoothManager()

    public let operationQueue = DispatchQueue(
        label: "io.github.airswitch.bluetooth-ops",
        qos: .userInitiated
    )

    private init() {}

    public func getPairedAudioDevices() -> [AudioDevice] {
        guard let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return []
        }

        // Major 4 = Audio/Video (Headphones, Headsets, Speakers). Major 0 = Uncategorized (often BLE earbuds).
        let audioDevices = devices.filter { device in
            let major = device.deviceClassMajor
            let minor = device.deviceClassMinor
            return major == 4 || (major == 0 && minor == 0)
        }

        return audioDevices.map { device in
            let addr = device.addressString ?? ""
            let name = resolveDeviceName(for: addr, device: device)
            let connected = device.isConnected()
            let battery = connected ? readBattery(for: addr, device: device) : nil

            return AudioDevice(
                id: addr,
                name: name,
                isConnected: connected,
                battery: battery,
                rawDevice: device
            )
        }
    }

    public func resolveDeviceName(for address: String, device: IOBluetoothDevice? = nil) -> String {
        if let aa = BatteryReader.readAudioAccessoryInfo(for: address),
           let name = aa.name,
           !name.isEmpty {
            return name
        }
        let dev = device ?? findDevice(by: address)
        if let name = dev?.name, !name.isEmpty {
            return name
        }
        return dev?.nameOrAddress ?? address
    }

    public func findDevice(by addressOrName: String) -> IOBluetoothDevice? {
        let cleanQuery = addressOrName.normalizedBluetoothAddress
        let devices = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []

        if let exactAddressMatch = devices.first(where: { ($0.addressString ?? "").matchesBluetoothAddress(cleanQuery) }) {
            return exactAddressMatch
        }

        if cleanQuery.contains("-"),
           let directDevice = IOBluetoothDevice(addressString: cleanQuery),
           directDevice.isPaired() {
            return directDevice
        }

        return devices.first { device in
            let addr = device.addressString ?? ""
            let rawName = (device.nameOrAddress ?? "").lowercased()
            if rawName.contains(cleanQuery) {
                return true
            }
            let customName = resolveDeviceName(for: addr, device: device).lowercased()
            return customName.contains(cleanQuery)
        }
    }

    public func resolveTargetDevice() -> (address: String, name: String, device: IOBluetoothDevice)? {
        guard let targetAddr = Preferences.shared.targetDeviceAddress,
              let device = findDevice(by: targetAddr) else {
            return nil
        }
        let name = Preferences.shared.targetDeviceName ?? resolveDeviceName(for: targetAddr, device: device)
        return (address: targetAddr, name: name, device: device)
    }

    public func ensureDefaultTargetDevice() {
        guard Preferences.shared.targetDeviceAddress == nil else { return }
        let paired = getPairedAudioDevices()
        guard let best = paired.first(where: { $0.name.lowercased().contains("airpods") }) ?? paired.first else {
            return
        }
        Preferences.shared.setTargetDevice(address: best.id, name: best.name)
        NSLog("[AirSwitch] Auto-selected default device: \(best.name) (\(best.id))")
    }

    @discardableResult
    public func connect(device: IOBluetoothDevice) -> Bool {
        if device.isConnected() {
            return true
        }
        let addr = device.addressString ?? ""
        BluetoothConnectionMonitor.shared.beginAppInitiatedTransition(for: addr)
        defer {
            BluetoothConnectionMonitor.shared.endAppInitiatedTransition(
                for: addr,
                isConnected: device.isConnected()
            )
        }

        if attemptConnect(device: device) {
            return true
        }

        Thread.sleep(forTimeInterval: 0.3)
        if device.isConnected() {
            return true
        }
        return attemptConnect(device: device)
    }

    @discardableResult
    public func disconnect(device: IOBluetoothDevice) -> Bool {
        if !device.isConnected() {
            return true
        }
        let addr = device.addressString ?? ""
        BluetoothConnectionMonitor.shared.beginAppInitiatedTransition(for: addr)
        defer {
            BluetoothConnectionMonitor.shared.endAppInitiatedTransition(
                for: addr,
                isConnected: device.isConnected()
            )
        }

        let status = device.closeConnection()
        if !device.isConnected() {
            return true
        }
        let timeout: TimeInterval = status == kIOReturnSuccess ? 1.5 : 0.5
        return waitForConnectionState(of: device, targetConnected: false, timeout: timeout)
    }

    private func attemptConnect(device: IOBluetoothDevice) -> Bool {
        let status = device.openConnection()
        if device.isConnected() {
            return true
        }
        let timeout: TimeInterval = status == kIOReturnSuccess ? 1.5 : 0.5
        return waitForConnectionState(of: device, targetConnected: true, timeout: timeout)
    }

    private func waitForConnectionState(
        of device: IOBluetoothDevice,
        targetConnected: Bool,
        timeout: TimeInterval,
        pollInterval: TimeInterval = 0.1
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if device.isConnected() == targetConnected {
                return true
            }
            Thread.sleep(forTimeInterval: pollInterval)
        }
        return device.isConnected() == targetConnected
    }

    public func toggle(device: IOBluetoothDevice) -> ToggleResult {
        let wasConnected = device.isConnected()
        let transportSucceeded = wasConnected ? disconnect(device: device) : connect(device: device)
        return ToggleResult.evaluate(
            wasConnected: wasConnected,
            transportSucceeded: transportSucceeded,
            isConnectedNow: device.isConnected()
        )
    }

    public func readBattery(for address: String, device: IOBluetoothDevice? = nil) -> BatteryInfo? {
        BatteryReader.readBattery(for: address, device: device ?? findDevice(by: address))
    }
}
