import Foundation
import ServiceManagement

public enum LaunchAtLoginService {
    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public static func toggle() {
        do {
            if isEnabled {
                try SMAppService.mainApp.unregister()
                NSLog("[AirSwitch] Unregistered launch at login.")
            } else {
                try SMAppService.mainApp.register()
                NSLog("[AirSwitch] Registered launch at login.")
            }
        } catch {
            NSLog("[AirSwitch] Error toggling launch at login: \(error)")
        }
    }
}
