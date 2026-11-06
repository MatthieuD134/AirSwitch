import Foundation

public enum OnboardingState {
    /// Determines whether the first-launch onboarding window should automatically appear.
    /// Shown once on the very first launch (`!hasCompletedOnboarding`).
    public static func shouldPresentOnLaunch(
        hasCompletedOnboarding: Bool,
        targetDeviceAddress: String? = nil
    ) -> Bool {
        _ = targetDeviceAddress
        return !hasCompletedOnboarding
    }

    /// Selects the best default device ID to pre-highlight in the onboarding device list.
    public static func recommendedDeviceID(
        from devices: [AudioDevice],
        currentTargetAddress: String?
    ) -> String? {
        guard !devices.isEmpty else { return nil }

        if let current = currentTargetAddress,
           let matching = devices.first(where: { $0.matchesAddress(current) }) {
            return matching.id
        }

        if let connectedAirPods = devices.first(where: { $0.isConnected && $0.name.lowercased().contains("airpods") }) {
            return connectedAirPods.id
        }

        if let anyAirPods = devices.first(where: { $0.name.lowercased().contains("airpods") }) {
            return anyAirPods.id
        }

        if let firstConnected = devices.first(where: { $0.isConnected }) {
            return firstConnected.id
        }

        return devices.first?.id
    }
}
