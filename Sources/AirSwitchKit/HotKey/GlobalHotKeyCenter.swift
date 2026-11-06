import AppKit
import Carbon

public final class GlobalHotKeyCenter {
    public static let shared = GlobalHotKeyCenter()

    private init() {}

    private struct Registration {
        weak var hotKey: HotKey?
    }

    private nonisolated(unsafe) var registrations: [UInt32: Registration] = [:]
    private let lock = NSLock()
    private var nextID: UInt32 = 0
    private var eventHandler: EventHandlerRef?

    public func register(_ hotKey: HotKey) {
        guard hotKey.carbonHotKey == nil else { return }
        installEventHandlerIfNeeded()

        lock.withLock {
            if hotKey.carbonID == 0 {
                nextID += 1
                hotKey.carbonID = nextID
            }
        }

        var carbonRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: airSwitchSignature, id: hotKey.carbonID)
        let status = RegisterEventHotKey(
            hotKey.keyCombo.carbonKeyCode,
            hotKey.keyCombo.carbonModifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &carbonRef
        )

        guard status == noErr, let carbonRef else {
            NSLog("[AirSwitch] Failed to register global hotkey (status: \(status))")
            return
        }

        hotKey.carbonHotKey = carbonRef
        lock.withLock {
            registrations[hotKey.carbonID] = Registration(hotKey: hotKey)
        }
    }

    public func unregister(_ hotKey: HotKey) {
        if let carbonRef = hotKey.carbonHotKey {
            UnregisterEventHotKey(carbonRef)
        }
        hotKey.carbonHotKey = nil
        removeRegistration(id: hotKey.carbonID)
    }

    internal func removeRegistration(id: UInt32) {
        lock.withLock {
            _ = registrations.removeValue(forKey: id)
        }
    }

    internal func handle(id: UInt32) -> Bool {
        let hotKey = lock.withLock { registrations[id]?.hotKey }
        guard let hotKey, let handler = hotKey.keyDownHandler else {
            return false
        }
        handler()
        return true
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetEventDispatcherTarget(),
            airSwitchHotKeyEventHandler,
            1,
            &eventType,
            nil,
            &eventHandler
        )
    }
}

private nonisolated let airSwitchSignature: FourCharCode = 0x4153_5754 // 'ASWT'

private nonisolated func airSwitchHotKeyEventHandler(
    _ handlerCall: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event else { return OSStatus(eventNotHandledErr) }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        UInt32(kEventParamDirectObject),
        UInt32(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )

    guard status == noErr, hotKeyID.signature == airSwitchSignature else {
        return OSStatus(eventNotHandledErr)
    }

    let handled = MainActor.assumeIsolated {
        GlobalHotKeyCenter.shared.handle(id: hotKeyID.id)
    }

    return handled ? noErr : OSStatus(eventNotHandledErr)
}
