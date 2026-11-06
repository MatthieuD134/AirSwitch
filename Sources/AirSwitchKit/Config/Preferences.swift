import Foundation

public final class Preferences {
    public static let shared = Preferences()

    private let defaults = UserDefaults(suiteName: AppConstants.bundleIdentifier) ?? .standard

    private enum Keys {
        static let targetDeviceAddress = "targetDeviceAddress"
        static let targetDeviceName = "targetDeviceName"
        static let autoConnectOnWake = "autoConnectOnWake"
        static let autoDisconnectOnSleep = "autoDisconnectOnSleep"
        static let showHUD = "showHUD"
        static let hudAnimations = "hudAnimations"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let lastUpdateCheckTimestamp = "lastUpdateCheckTimestamp"
    }

    private init() {
        defaults.register(defaults: [
            Keys.autoConnectOnWake: true,
            Keys.autoDisconnectOnSleep: true,
            Keys.showHUD: true,
            Keys.hudAnimations: true,
            Keys.hasCompletedOnboarding: false
        ])
    }

    public var targetDeviceAddress: String? {
        get { defaults.string(forKey: Keys.targetDeviceAddress) }
        set { defaults.set(newValue, forKey: Keys.targetDeviceAddress) }
    }

    public var targetDeviceName: String? {
        get { defaults.string(forKey: Keys.targetDeviceName) }
        set { defaults.set(newValue, forKey: Keys.targetDeviceName) }
    }

    public var autoConnectOnWake: Bool {
        get { defaults.bool(forKey: Keys.autoConnectOnWake) }
        set { defaults.set(newValue, forKey: Keys.autoConnectOnWake) }
    }

    public var autoDisconnectOnSleep: Bool {
        get { defaults.bool(forKey: Keys.autoDisconnectOnSleep) }
        set { defaults.set(newValue, forKey: Keys.autoDisconnectOnSleep) }
    }

    public var showHUD: Bool {
        get { defaults.bool(forKey: Keys.showHUD) }
        set { defaults.set(newValue, forKey: Keys.showHUD) }
    }

    public var hudAnimations: Bool {
        get { defaults.bool(forKey: Keys.hudAnimations) }
        set { defaults.set(newValue, forKey: Keys.hudAnimations) }
    }

    public var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Keys.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: Keys.hasCompletedOnboarding) }
    }

    public var lastUpdateCheckTimestamp: TimeInterval {
        get { defaults.double(forKey: Keys.lastUpdateCheckTimestamp) }
        set { defaults.set(newValue, forKey: Keys.lastUpdateCheckTimestamp) }
    }

    public func setTargetDevice(address: String, name: String) {
        targetDeviceAddress = address
        targetDeviceName = name
        hasCompletedOnboarding = true
    }
}
