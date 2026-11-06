import Foundation

public enum AppConstants {
    public static let appName = "AirSwitch"
    public static let fallbackVersion = "0.2.0"
    public static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? fallbackVersion
    }
    public static let bundleIdentifier = "io.github.airswitch"
    public static let githubRepository = "MatthieuD134/AirSwitch"

    public static let statusPollInterval: TimeInterval = 5.0
    public static let toggleSettleDelay: TimeInterval = 0.6
    public static let wakeAutoConnectDelay: TimeInterval = 1.5
    public static let wakeBatteryReadDelay: TimeInterval = 1.0
    public static let updateCheckInterval: TimeInterval = 24 * 60 * 60
}
