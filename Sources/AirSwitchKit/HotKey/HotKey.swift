import Carbon

public final class HotKey {
    public let keyCombo: KeyCombo
    public var keyDownHandler: (() -> Void)?

    nonisolated(unsafe) internal var carbonHotKey: EventHotKeyRef?
    nonisolated(unsafe) internal var carbonID: UInt32 = 0

    public init(keyCombo: KeyCombo, keyDownHandler: (() -> Void)? = nil) {
        self.keyCombo = keyCombo
        self.keyDownHandler = keyDownHandler
        GlobalHotKeyCenter.shared.register(self)
    }

    deinit {
        if let carbonHotKey {
            UnregisterEventHotKey(carbonHotKey)
        }
        GlobalHotKeyCenter.shared.removeRegistration(id: carbonID)
    }
}
