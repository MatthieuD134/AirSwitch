import AppKit
import Foundation
@preconcurrency import IOBluetooth

public enum BluetoothConnectionEvent: Equatable, Sendable {
    case connected
    case disconnected
}

public final class BluetoothConnectionMonitor: NSObject, @unchecked Sendable {
    public static let shared = BluetoothConnectionMonitor()

    private static let postTransitionSuppressionWindow: TimeInterval = 2.5

    private let stateLock = NSLock()
    private var lastKnownConnectedByAddress: [String: Bool] = [:]
    private var activeAppTransitionCountByAddress: [String: Int] = [:]
    private var suppressionDeadlineByAddress: [String: Date] = [:]
    private var transitionGenerationByAddress: [String: UInt64] = [:]

    private var connectNotification: IOBluetoothUserNotification?
    private var disconnectNotificationsByAddress: [String: IOBluetoothUserNotification] = [:]

    public override init() {
        super.init()
    }

    @MainActor
    public func start() {
        stop()

        if let target = BluetoothManager.shared.resolveTargetDevice() {
            seedState(for: target.address, isConnected: target.device.isConnected())
            if target.device.isConnected() {
                registerDisconnectNotification(for: target.device, address: target.address)
            }
        }

        connectNotification = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(handleDeviceConnected(_:device:))
        )
    }

    @MainActor
    public func stop() {
        connectNotification?.unregister()
        connectNotification = nil

        for (_, notification) in disconnectNotificationsByAddress {
            notification.unregister()
        }
        disconnectNotificationsByAddress.removeAll()
    }

    public func resetState() {
        stateLock.withLock {
            for key in lastKnownConnectedByAddress.keys {
                transitionGenerationByAddress[key, default: 0] &+= 1
            }
            lastKnownConnectedByAddress.removeAll()
        }
    }

    public func invalidatePendingConnectionHUD(for address: String) {
        let key = address.normalizedBluetoothAddress
        guard !key.isEmpty else { return }
        stateLock.withLock {
            transitionGenerationByAddress[key, default: 0] &+= 1
        }
    }

    internal func currentGeneration(for address: String) -> UInt64 {
        let key = address.normalizedBluetoothAddress
        return stateLock.withLock {
            transitionGenerationByAddress[key] ?? 0
        }
    }

    public func seedState(for address: String, isConnected: Bool) {
        let key = address.normalizedBluetoothAddress
        guard !key.isEmpty else { return }
        stateLock.withLock {
            lastKnownConnectedByAddress[key] = isConnected
            transitionGenerationByAddress[key, default: 0] &+= 1
        }
    }

    public func beginAppInitiatedTransition(for address: String, now: Date = Date()) {
        let key = address.normalizedBluetoothAddress
        guard !key.isEmpty else { return }
        stateLock.withLock {
            activeAppTransitionCountByAddress[key, default: 0] += 1
            suppressionDeadlineByAddress[key] = now.addingTimeInterval(Self.postTransitionSuppressionWindow)
            transitionGenerationByAddress[key, default: 0] &+= 1
        }
    }

    public func endAppInitiatedTransition(
        for address: String,
        isConnected: Bool,
        now: Date = Date()
    ) {
        let key = address.normalizedBluetoothAddress
        guard !key.isEmpty else { return }
        stateLock.withLock {
            let remaining = max(0, (activeAppTransitionCountByAddress[key] ?? 1) - 1)
            if remaining == 0 {
                activeAppTransitionCountByAddress.removeValue(forKey: key)
            } else {
                activeAppTransitionCountByAddress[key] = remaining
            }
            lastKnownConnectedByAddress[key] = isConnected
            suppressionDeadlineByAddress[key] = now.addingTimeInterval(Self.postTransitionSuppressionWindow)
            transitionGenerationByAddress[key, default: 0] &+= 1
        }
    }

    public func recordObservedState(
        address: String,
        isConnected: Bool,
        targetAddress: String?,
        now: Date = Date()
    ) -> BluetoothConnectionEvent? {
        guard address.matchesBluetoothAddress(targetAddress) else {
            return nil
        }

        let key = address.normalizedBluetoothAddress
        guard !key.isEmpty else { return nil }

        return stateLock.withLock {
            let previous = lastKnownConnectedByAddress[key]
            lastKnownConnectedByAddress[key] = isConnected

            if previous != isConnected {
                transitionGenerationByAddress[key, default: 0] &+= 1
            }

            let isAppTransitionActive = (activeAppTransitionCountByAddress[key] ?? 0) > 0
            let isWithinSuppressionWindow = (suppressionDeadlineByAddress[key].map { now < $0 }) ?? false

            if isAppTransitionActive || isWithinSuppressionWindow {
                return nil
            }

            guard let previous else {
                // First observation seeds baseline without emitting an event
                return nil
            }

            guard previous != isConnected else {
                return nil
            }

            return isConnected ? .connected : .disconnected
        }
    }

    @MainActor
    @objc private func handleDeviceConnected(
        _ notification: IOBluetoothUserNotification?,
        device: IOBluetoothDevice?
    ) {
        guard let device, let rawAddress = device.addressString else { return }
        let targetAddr = Preferences.shared.targetDeviceAddress
        guard rawAddress.matchesBluetoothAddress(targetAddr) else { return }

        registerDisconnectNotification(for: device, address: rawAddress)
        let event = recordObservedState(
            address: rawAddress,
            isConnected: true,
            targetAddress: targetAddr
        )
        StatusBarController.shared.updateUI()

        guard event == .connected else { return }
        presentExternalConnectionHUD(for: rawAddress)
    }

    @MainActor
    @objc private func handleDeviceDisconnected(
        _ notification: IOBluetoothUserNotification?,
        device: IOBluetoothDevice?
    ) {
        guard let device, let rawAddress = device.addressString else { return }
        let key = rawAddress.normalizedBluetoothAddress
        disconnectNotificationsByAddress[key]?.unregister()
        disconnectNotificationsByAddress.removeValue(forKey: key)

        let targetAddr = Preferences.shared.targetDeviceAddress
        let event = recordObservedState(
            address: rawAddress,
            isConnected: false,
            targetAddress: targetAddr
        )
        LowBatteryMonitor.shared.reset(for: rawAddress)
        StatusBarController.shared.updateUI()

        guard event == .disconnected else { return }
        let displayName = Preferences.shared.targetDeviceName ?? device.name ?? "Headphones"
        HUDWindowController.shared.show(
            title: displayName,
            subtitle: "Disconnected",
            connected: false,
            battery: nil
        )
    }

    @MainActor
    public func handlePeriodicPoll(
        address: String,
        name: String,
        device: IOBluetoothDevice,
        isConnected: Bool,
        battery: BatteryInfo?
    ) {
        if isConnected {
            registerDisconnectNotification(for: device, address: address)
        }

        let event = recordObservedState(
            address: address,
            isConnected: isConnected,
            targetAddress: Preferences.shared.targetDeviceAddress
        )

        switch event {
        case .connected:
            presentExternalConnectionHUD(for: address)
        case .disconnected:
            LowBatteryMonitor.shared.reset(for: address)
            HUDWindowController.shared.show(
                title: name,
                subtitle: "Disconnected",
                connected: false,
                battery: nil
            )
        case .none:
            if let alert = LowBatteryMonitor.shared.evaluate(
                deviceAddress: address,
                isConnected: isConnected,
                battery: battery
            ) {
                invalidatePendingConnectionHUD(for: address)
                HUDWindowController.shared.show(
                    title: name,
                    subtitle: alert.hudSubtitle,
                    connected: true,
                    battery: battery
                )
            }
        }
    }

    @MainActor
    private func registerDisconnectNotification(for device: IOBluetoothDevice, address: String) {
        let key = address.normalizedBluetoothAddress
        guard !key.isEmpty, disconnectNotificationsByAddress[key] == nil else { return }
        if let notification = device.register(
            forDisconnectNotification: self,
            selector: #selector(handleDeviceDisconnected(_:device:))
        ) {
            disconnectNotificationsByAddress[key] = notification
        }
    }

    @MainActor
    private func presentExternalConnectionHUD(for address: String) {
        let key = address.normalizedBluetoothAddress
        let expectedGeneration = stateLock.withLock { transitionGenerationByAddress[key] ?? 0 }

        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.wakeBatteryReadDelay) { [weak self] in
            guard let self else { return }
            let currentGeneration = self.stateLock.withLock { self.transitionGenerationByAddress[key] ?? 0 }
            guard currentGeneration == expectedGeneration,
                  address.matchesBluetoothAddress(Preferences.shared.targetDeviceAddress),
                  let target = BluetoothManager.shared.resolveTargetDevice(),
                  target.device.isConnected() else {
                return
            }

            let battery = BluetoothManager.shared.readBattery(for: target.address, device: target.device)
            StatusBarController.shared.updateUI()
            HUDWindowController.shared.show(
                title: target.name,
                subtitle: "Connected",
                connected: true,
                battery: battery
            )
        }
    }
}
