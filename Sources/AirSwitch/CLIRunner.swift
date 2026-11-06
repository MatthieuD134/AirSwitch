import Foundation
@preconcurrency import IOBluetooth
import AirSwitchKit

enum CLIRunner {
    static func printHelp() {
        print("""
        AirSwitch v\(AppConstants.version) — Native macOS Bluetooth Switcher & Battery HUD

        USAGE:
            airswitch                   Run as background menu bar app with hotkey & HUD
            airswitch --list            List all paired Bluetooth audio devices
            airswitch --connect <query> Connect to a device by name or MAC address
            airswitch --disconnect <q>  Disconnect a device by name or MAC address
            airswitch --toggle          Toggle connection of primary/saved device
            airswitch --select <query>  Set primary device for hotkey and auto-switch
            airswitch --version         Print version
            airswitch --help            Show this help message

        DEFAULT SHORTCUT:
            ⌃⌥A (Control + Option + A) toggles connection anywhere on macOS.
        """)
    }

    static func handle(arguments args: [String] = CommandLine.arguments) -> Bool {
        guard args.count > 1 else { return false }

        if args.contains("--help") || args.contains("-h") {
            printHelp()
            return true
        }

        if args.contains("--version") || args.contains("-v") {
            print("AirSwitch \(AppConstants.version)")
            return true
        }

        if args.contains("--list") {
            listDevices()
            return true
        }

        if let idx = args.firstIndex(of: "--connect"), idx + 1 < args.count {
            connectDevice(matching: args[idx + 1])
            return true
        }

        if let idx = args.firstIndex(of: "--disconnect"), idx + 1 < args.count {
            disconnectDevice(matching: args[idx + 1])
            return true
        }

        if args.contains("--toggle") {
            toggleTargetDevice()
            return true
        }

        if let idx = args.firstIndex(of: "--select"), idx + 1 < args.count {
            selectTargetDevice(matching: args[idx + 1])
            return true
        }

        return false
    }

    private static func listDevices() {
        let devices = BluetoothManager.shared.getPairedAudioDevices()
        if devices.isEmpty {
            print("No paired Bluetooth audio devices found.")
            return
        }
        print("Paired Audio Devices:")
        let targetAddr = Preferences.shared.targetDeviceAddress
        for device in devices {
            let isTarget = device.matchesAddress(targetAddr)
            let status = device.isConnected ? "CONNECTED" : "DISCONNECTED"
            let battery = device.battery.map { "(\($0.displayString))" } ?? ""
            let marker = isTarget ? " ★ [TARGET]" : ""
            print("  \(marker) [\(status)] \(device.name) — \(device.id) \(battery)")
        }
    }

    private static func connectDevice(matching query: String) {
        let (device, name) = requireDevice(matching: query)
        print("Connecting to \(name)...")
        let ok = BluetoothManager.shared.connect(device: device)
        print(ok ? "Connected successfully." : "Connection failed.")
    }

    private static func disconnectDevice(matching query: String) {
        let (device, name) = requireDevice(matching: query)
        print("Disconnecting from \(name)...")
        let ok = BluetoothManager.shared.disconnect(device: device)
        print(ok ? "Disconnected successfully." : "Disconnection failed.")
    }

    private static func toggleTargetDevice() {
        guard let target = BluetoothManager.shared.resolveTargetDevice() else {
            print("Error: No target device set. Run 'airswitch --select <device>' or select one in the menu bar.")
            exit(1)
        }
        let wasConnected = target.device.isConnected()
        print("Toggling \(target.name) (currently \(wasConnected ? "connected" : "disconnected"))...")
        let result = BluetoothManager.shared.toggle(device: target.device)
        if result.succeeded {
            print(result.isConnected ? "Now CONNECTED." : "Now DISCONNECTED.")
        } else {
            print("Error: \(result.hudSubtitle).")
            exit(1)
        }
    }

    private static func selectTargetDevice(matching query: String) {
        let (device, name) = requireDevice(matching: query)
        let addr = device.addressString ?? ""
        Preferences.shared.setTargetDevice(address: addr, name: name)
        print("Primary target device set to: \(name) (\(addr))")
    }

    private static func requireDevice(matching query: String) -> (device: IOBluetoothDevice, name: String) {
        guard let device = BluetoothManager.shared.findDevice(by: query) else {
            print("Error: Device matching '\(query)' not found.")
            exit(1)
        }
        let addr = device.addressString ?? query
        let name = BluetoothManager.shared.resolveDeviceName(for: addr, device: device)
        return (device, name)
    }
}
