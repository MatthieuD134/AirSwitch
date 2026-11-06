import AppKit
import Foundation
@preconcurrency import IOBluetooth

public final class SleepWakeService {
    public static let shared = SleepWakeService()

    private var observers: [NSObjectProtocol] = []

    private init() {}

    public func start() {
        stop()

        let nc = NSWorkspace.shared.notificationCenter

        let sleepObs = nc.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleWillSleep()
        }
        observers.append(sleepObs)

        let wakeObs = nc.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleDidWake()
        }
        observers.append(wakeObs)

        NSLog("[AirSwitch] SleepWakeService active.")
    }

    public func stop() {
        for obs in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
        observers.removeAll()
    }

    private func handleWillSleep() {
        guard Preferences.shared.autoDisconnectOnSleep,
              let target = BluetoothManager.shared.resolveTargetDevice() else {
            return
        }

        if target.device.isConnected() {
            NSLog("[AirSwitch] Mac sleeping -> disconnecting \(target.name) to release to phone.")
            _ = BluetoothManager.shared.disconnect(device: target.device)
        }
    }

    private func handleDidWake() {
        guard Preferences.shared.autoConnectOnWake,
              Preferences.shared.targetDeviceAddress != nil else {
            return
        }

        NSLog("[AirSwitch] Mac woke up -> scheduling auto-connect to target device in \(AppConstants.wakeAutoConnectDelay)s...")

        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.wakeAutoConnectDelay) {
            guard let target = BluetoothManager.shared.resolveTargetDevice(),
                  !target.device.isConnected() else {
                return
            }

            NSLog("[AirSwitch] Attempting wake auto-connect to \(target.name)...")
            guard BluetoothManager.shared.connect(device: target.device) else { return }

            NSLog("[AirSwitch] Successfully auto-connected on wake!")
            DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.wakeBatteryReadDelay) {
                let battery = BluetoothManager.shared.readBattery(for: target.address, device: target.device)
                Task { @MainActor in
                    HUDWindowController.shared.show(
                        title: target.name,
                        subtitle: "Auto-connected on wake",
                        connected: true,
                        battery: battery
                    )
                }
            }
        }
    }
}
