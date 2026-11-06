import AppKit
import Foundation
import AirSwitchKit

@MainActor
enum AirSwitchDaemon {
    static func run() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory) // No dock icon, menu bar only

        _ = StatusBarController.shared
        SleepWakeService.shared.start()
        BluetoothConnectionMonitor.shared.start()

        let registered = HotKeyService.shared.start {
            Task { @MainActor in
                StatusBarController.shared.toggleConnection()
            }
        }

        OnboardingWindowController.shared.presentIfNeeded()
        ReleaseCheckService.shared.checkInBackgroundIfNeeded()

        if registered {
            NSLog("[AirSwitch] Daemon started. Hotkey \(HotKeyService.shared.currentKeyCombo.displayString) registered.")
        } else {
            NSLog("[AirSwitch] Daemon started. Warning: failed to register global hotkey.")
        }
        app.run()
    }
}
