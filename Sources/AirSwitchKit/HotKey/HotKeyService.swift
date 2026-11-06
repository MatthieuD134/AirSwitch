import Foundation

@MainActor
public final class HotKeyService {
    public static let shared = HotKeyService()

    internal struct RegistrationHandle {
        let keyCombo: KeyCombo
        let isRegistered: Bool
        let unregister: () -> Void
    }

    private var activeHandle: RegistrationHandle?
    private var lastActiveCombo: KeyCombo?
    private var handler: (() -> Void)?
    private var isSuspended = false
    private let registrar: (KeyCombo, (() -> Void)?) -> RegistrationHandle

    public init() {
        self.registrar = { combo, callback in
            let hotKey = HotKey(keyCombo: combo, keyDownHandler: callback)
            return RegistrationHandle(
                keyCombo: combo,
                isRegistered: hotKey.isRegistered,
                unregister: { hotKey.unregister() }
            )
        }
    }

    internal init(registrar: @escaping (KeyCombo, (() -> Void)?) -> RegistrationHandle) {
        self.registrar = registrar
    }

    public var currentKeyCombo: KeyCombo {
        activeHandle?.keyCombo ?? lastActiveCombo ?? Preferences.shared.hotKeyCombo
    }

    public var isActive: Bool {
        activeHandle?.isRegistered == true
    }

    @discardableResult
    public func start(handler: @escaping () -> Void) -> Bool {
        self.handler = handler
        self.isSuspended = false
        return registerCurrentCombo()
    }

    public func suspend() {
        isSuspended = true
        activeHandle?.unregister()
        activeHandle = nil
    }

    public func resume() {
        guard isSuspended else { return }
        isSuspended = false
        _ = registerCurrentCombo()
    }

    @discardableResult
    public func applyAndResume(_ combo: KeyCombo) -> Bool {
        guard combo.isValidShortcut else { return false }

        activeHandle?.unregister()
        activeHandle = nil

        let candidate = registrar(combo, handler)
        guard candidate.isRegistered else {
            candidate.unregister()
            if !isSuspended {
                _ = registerCurrentCombo()
            }
            return false
        }

        isSuspended = false
        activeHandle = candidate
        lastActiveCombo = combo
        Preferences.shared.hotKeyCombo = combo
        return true
    }

    @discardableResult
    private func registerCurrentCombo() -> Bool {
        activeHandle?.unregister()
        activeHandle = nil

        let preferred = Preferences.shared.hotKeyCombo
        let candidate = registrar(preferred, handler)
        if candidate.isRegistered {
            activeHandle = candidate
            lastActiveCombo = preferred
            return true
        }

        candidate.unregister()
        if preferred != .defaultToggle {
            let fallback = registrar(.defaultToggle, handler)
            if fallback.isRegistered {
                activeHandle = fallback
                lastActiveCombo = .defaultToggle
                return true
            }
            fallback.unregister()
        }
        return false
    }
}
