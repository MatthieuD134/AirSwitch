import Foundation

public struct LowBatteryAlert: Equatable, Sendable {
    public let threshold: Int
    public let currentPercent: Int

    public init(threshold: Int, currentPercent: Int) {
        self.threshold = threshold
        self.currentPercent = currentPercent
    }

    public var hudSubtitle: String {
        L10n.lowBattery(currentPercent)
    }
}

public final class LowBatteryMonitor {
    @MainActor public static let shared = LowBatteryMonitor()

    public static let defaultThresholds: [Int] = [20, 10]
    private static let recoveryHysteresis: Int = 3

    private let thresholds: [Int]
    private var triggeredThresholdsByDevice: [String: Set<Int>] = [:]

    public init(thresholds: [Int] = LowBatteryMonitor.defaultThresholds) {
        self.thresholds = thresholds.sorted(by: >)
    }

    public func evaluate(
        deviceAddress: String,
        isConnected: Bool,
        battery: BatteryInfo?
    ) -> LowBatteryAlert? {
        let key = deviceAddress.normalizedBluetoothAddress
        guard !key.isEmpty else { return nil }

        guard isConnected else {
            triggeredThresholdsByDevice.removeValue(forKey: key)
            return nil
        }

        guard let percent = battery?.primaryPercent, (1...100).contains(percent) else {
            return nil
        }

        var triggered = triggeredThresholdsByDevice[key] ?? []

        // Clear any threshold once battery has charged past threshold + hysteresis
        for threshold in thresholds where percent > threshold + Self.recoveryHysteresis {
            triggered.remove(threshold)
        }

        // Check from lowest (most critical) threshold upward so connecting at <= 10%
        // fires the 10% alert once and suppresses the higher 20% threshold.
        for threshold in thresholds.sorted(by: <) where percent <= threshold {
            guard !triggered.contains(threshold) else {
                triggeredThresholdsByDevice[key] = triggered
                return nil
            }
            for higherOrEqual in thresholds where higherOrEqual >= threshold {
                triggered.insert(higherOrEqual)
            }
            triggeredThresholdsByDevice[key] = triggered
            return LowBatteryAlert(threshold: threshold, currentPercent: percent)
        }

        triggeredThresholdsByDevice[key] = triggered
        return nil
    }

    public func reset(for deviceAddress: String? = nil) {
        if let deviceAddress {
            triggeredThresholdsByDevice.removeValue(forKey: deviceAddress.normalizedBluetoothAddress)
        } else {
            triggeredThresholdsByDevice.removeAll()
        }
    }
}
