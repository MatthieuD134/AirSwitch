import AppKit
import Foundation
@preconcurrency import IOBluetooth

@MainActor
public final class SleepWakeService {
    public static let shared = SleepWakeService()

    private var observers: [NSObjectProtocol] = []
    private var wakeWorkItem: DispatchWorkItem?
    private var wakeGeneration: UInt64 = 0

    private init() {}

    public func start() {
        stop()

        let nc = NSWorkspace.shared.notificationCenter

        let sleepObs = nc.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleWillSleep()
            }
        }
        observers.append(sleepObs)

        let wakeObs = nc.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleDidWake()
            }
        }
        observers.append(wakeObs)

        NSLog("[AirSwitch] SleepWakeService active.")
    }

    public func stop() {
        wakeGeneration &+= 1
        wakeWorkItem?.cancel()
        wakeWorkItem = nil
        for obs in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
        observers.removeAll()
    }

    private func handleWillSleep() {
        wakeGeneration &+= 1
        wakeWorkItem?.cancel()
        wakeWorkItem = nil

        BluetoothConnectionMonitor.shared.handleWillSleep()
        HUDWindowController.shared.dismissImmediate()

        guard Preferences.shared.autoDisconnectOnSleep,
              let target = BluetoothManager.shared.resolveTargetDevice(),
              target.device.isConnected() else {
            return
        }

        let targetAddr = target.address
        let targetName = target.name
        let device = target.device
        NSLog("[AirSwitch] Mac sleeping -> disconnecting \(targetName) to release to phone.")
        BluetoothConnectionMonitor.shared.seedState(for: targetAddr, isConnected: false)
        BluetoothManager.shared.operationQueue.async {
            _ = BluetoothManager.shared.disconnect(device: device)
        }
    }

    private func handleDidWake() {
        wakeGeneration &+= 1
        wakeWorkItem?.cancel()
        wakeWorkItem = nil

        BluetoothConnectionMonitor.shared.handleDidWake()
        StatusBarController.shared.updateUI()

        guard Preferences.shared.autoConnectOnWake,
              Preferences.shared.targetDeviceAddress != nil else {
            return
        }

        let expectedGeneration = wakeGeneration
        NSLog("[AirSwitch] Mac woke up -> scheduling auto-connect to target device in \(AppConstants.wakeAutoConnectDelay)s...")

        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.wakeGeneration == expectedGeneration else { return }
                self.performWakeAutoConnect(expectedGeneration: expectedGeneration, remainingRetries: 1)
            }
        }
        wakeWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.wakeAutoConnectDelay, execute: item)
    }

    private func performWakeAutoConnect(expectedGeneration: UInt64, remainingRetries: Int) {
        guard wakeGeneration == expectedGeneration,
              let target = BluetoothManager.shared.resolveTargetDevice(),
              !target.device.isConnected() else {
            return
        }

        let targetName = target.name
        let device = target.device
        NSLog("[AirSwitch] Attempting wake auto-connect to \(targetName)...")

        BluetoothManager.shared.operationQueue.async { [weak self] in
            let connected = BluetoothManager.shared.connect(device: device)
            Task { @MainActor [weak self] in
                guard let self, self.wakeGeneration == expectedGeneration else { return }
                if connected {
                    NSLog("[AirSwitch] Successfully auto-connected on wake!")
                    StatusBarController.shared.updateUI()
                    DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.wakeBatteryReadDelay) { [weak self] in
                        Task { @MainActor [weak self] in
                            guard let self, self.wakeGeneration == expectedGeneration,
                                  let refreshed = BluetoothManager.shared.resolveTargetDevice(),
                                  refreshed.device.isConnected() else {
                                return
                            }
                            let battery = BluetoothManager.shared.readBattery(
                                for: refreshed.address,
                                device: refreshed.device
                            )
                            StatusBarController.shared.updateUI()
                            HUDWindowController.shared.show(
                                title: refreshed.name,
                                subtitle: L10n.autoConnectedOnWake,
                                connected: true,
                                battery: battery
                            )
                        }
                    }
                } else if remainingRetries > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        Task { @MainActor [weak self] in
                            self?.performWakeAutoConnect(
                                expectedGeneration: expectedGeneration,
                                remainingRetries: remainingRetries - 1
                            )
                        }
                    }
                }
            }
        }
    }
}
