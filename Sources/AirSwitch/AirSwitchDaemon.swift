import AppKit
import Foundation
import AirSwitchKit

@MainActor
enum AirSwitchDaemon {
    private static var globalHotKey: HotKey?

    static func run() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory) // No dock icon, menu bar only

        _ = StatusBarController.shared
        SleepWakeService.shared.start()

        globalHotKey = HotKey(keyCombo: .defaultToggle) {
            Task { @MainActor in
                StatusBarController.shared.toggleConnection()
            }
        }

        OnboardingWindowController.shared.presentIfNeeded()

        NSLog("[AirSwitch] Daemon started. Hotkey ⌃⌥A registered.")
        app.run()
    }
}
