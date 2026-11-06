import Carbon

public final class HotKey {
    public let keyCombo: KeyCombo
    public var keyDownHandler: (() -> Void)?

    nonisolated(unsafe) internal var carbonHotKey: EventHotKeyRef?
    nonisolated(unsafe) internal var carbonID: UInt32 = 0

    public var isRegistered: Bool {
        carbonHotKey != nil
    }

    public init(keyCombo: KeyCombo, keyDownHandler: (() -> Void)? = nil) {
        self.keyCombo = keyCombo
        self.keyDownHandler = keyDownHandler
        GlobalHotKeyCenter.shared.register(self)
    }

    public func unregister() {
        GlobalHotKeyCenter.shared.unregister(self)
    }

    deinit {
        unregister()
    }
}
