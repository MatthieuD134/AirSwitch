import Foundation
@preconcurrency import IOBluetooth

public extension String {
    var normalizedBluetoothAddress: String {
        replacingOccurrences(of: ":", with: "-").lowercased()
    }

    func matchesBluetoothAddress(_ other: String?) -> Bool {
        guard let other else { return false }
        return normalizedBluetoothAddress == other.normalizedBluetoothAddress
    }
}

public struct AudioDevice: Identifiable {
    public let id: String
    public let name: String
    public let isConnected: Bool
    public let battery: BatteryInfo?
    public let rawDevice: IOBluetoothDevice?

    public init(
        id: String,
        name: String,
        isConnected: Bool,
        battery: BatteryInfo?,
        rawDevice: IOBluetoothDevice? = nil
    ) {
        self.id = id
        self.name = name
        self.isConnected = isConnected
        self.battery = battery
        self.rawDevice = rawDevice
    }

    public var normalizedAddress: String {
        id.normalizedBluetoothAddress
    }

    public func matchesAddress(_ address: String?) -> Bool {
        id.matchesBluetoothAddress(address)
    }
}
