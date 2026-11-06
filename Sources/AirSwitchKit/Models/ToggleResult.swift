import Foundation

public struct ToggleResult: Equatable, Sendable {
    public enum Action: Equatable, Sendable {
        case connect
        case disconnect
    }

    public let action: Action
    public let succeeded: Bool
    public let isConnected: Bool

    public init(action: Action, succeeded: Bool, isConnected: Bool) {
        self.action = action
        self.succeeded = succeeded
        self.isConnected = isConnected
    }

    public static func evaluate(
        wasConnected: Bool,
        transportSucceeded: Bool,
        isConnectedNow: Bool
    ) -> ToggleResult {
        if wasConnected {
            return ToggleResult(
                action: .disconnect,
                succeeded: transportSucceeded && !isConnectedNow,
                isConnected: isConnectedNow
            )
        } else {
            return ToggleResult(
                action: .connect,
                succeeded: transportSucceeded && isConnectedNow,
                isConnected: isConnectedNow
            )
        }
    }

    public var hudSubtitle: String {
        switch (action, succeeded) {
        case (.connect, true):
            return "Connected"
        case (.connect, false):
            return "Connection Failed"
        case (.disconnect, true):
            return "Disconnected"
        case (.disconnect, false):
            return "Disconnection Failed"
        }
    }
}
