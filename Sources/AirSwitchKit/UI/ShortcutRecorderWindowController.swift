import AppKit
import Carbon

@MainActor
public final class ShortcutRecorderWindowController: NSObject, NSWindowDelegate {
    public static let shared = ShortcutRecorderWindowController()

    private var window: ShortcutRecorderWindow?
    private weak var badgeLabel: NSTextField?
    private weak var statusLabel: NSTextField?

    private override init() {
        super.init()
    }

    public func show() {
        HotKeyService.shared.suspend()

        if let existing = window {
            badgeLabel?.stringValue = HotKeyService.shared.currentKeyCombo.displayString
            statusLabel?.stringValue = "Press a new key combination (Esc to cancel)"
            statusLabel?.textColor = .secondaryLabelColor
            existing.center()
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let newWindow = ShortcutRecorderWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 220),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "Global Shortcut"
        newWindow.titleVisibility = .hidden
        newWindow.titlebarAppearsTransparent = true
        newWindow.isMovableByWindowBackground = true
        newWindow.isReleasedWhenClosed = false
        newWindow.level = .floating
        newWindow.delegate = self

        newWindow.onKeyDownEvent = { [weak self, weak newWindow] keyCode, modifiers in
            guard let self else { return false }
            return self.handleKeyInput(
                keyCode: keyCode,
                modifiers: modifiers,
                isKeyWindow: newWindow?.isKeyWindow ?? false
            )
        }

        newWindow.contentView = buildContentView()
        newWindow.center()

        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    internal func handleKeyInput(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags,
        isKeyWindow: Bool = true
    ) -> Bool {
        guard isKeyWindow else { return false }
        let cleanMods = modifiers.intersection([.control, .option, .shift, .command])

        if keyCode == UInt16(kVK_Escape), cleanMods.isEmpty {
            window?.close()
            return true
        }

        // Allow standard keyboard navigation (Tab, Space, Return) when no primary modifier is held
        let hasPrimaryModifier = !cleanMods.intersection([.control, .option, .command]).isEmpty
        if !hasPrimaryModifier {
            if keyCode == UInt16(kVK_Tab) || keyCode == UInt16(kVK_Space) || keyCode == UInt16(kVK_Return) {
                return false
            }
            statusLabel?.stringValue = "Include Control (⌃), Option (⌥), or Command (⌘)"
            statusLabel?.textColor = .systemOrange
            return true
        }

        guard let combo = KeyCombo.from(keyCode: keyCode, modifierFlags: cleanMods) else {
            return true
        }

        applyCombo(combo)
        return true
    }

    private func applyCombo(_ combo: KeyCombo) {
        guard HotKeyService.shared.applyAndResume(combo) else {
            statusLabel?.stringValue = "\(combo.displayString) is reserved by macOS — try another"
            statusLabel?.textColor = .systemRed
            return
        }

        badgeLabel?.stringValue = combo.displayString
        HUDWindowController.shared.show(
            title: "Shortcut Updated",
            subtitle: combo.displayString,
            connected: true,
            battery: nil
        )
        window?.close()
    }

    @objc private func resetToDefault() {
        applyCombo(.defaultToggle)
    }

    @objc private func cancelRecording() {
        window?.close()
    }

    public func windowDidBecomeKey(_ notification: Notification) {
        HotKeyService.shared.suspend()
    }

    public func windowDidResignKey(_ notification: Notification) {
        HotKeyService.shared.resume()
    }

    public func windowWillClose(_ notification: Notification) {
        HotKeyService.shared.resume()
        badgeLabel = nil
        statusLabel = nil
        window = nil
    }

    private func buildContentView() -> NSView {
        let effectView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 360, height: 220))
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.appearance = NSAppearance(named: .darkAqua)

        let title = NSTextField(labelWithString: "Global Toggle Shortcut")
        title.font = .systemFont(ofSize: 16, weight: .semibold)
        title.textColor = .labelColor

        let badgeContainer = NSView()
        badgeContainer.wantsLayer = true
        badgeContainer.layer?.cornerRadius = 10
        badgeContainer.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        badgeContainer.layer?.borderWidth = 1.5
        badgeContainer.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.75).cgColor
        badgeContainer.translatesAutoresizingMaskIntoConstraints = false

        let badge = NSTextField(labelWithString: HotKeyService.shared.currentKeyCombo.displayString)
        badge.font = .monospacedSystemFont(ofSize: 22, weight: .bold)
        badge.textColor = .labelColor
        badge.alignment = .center
        badge.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.addSubview(badge)
        self.badgeLabel = badge

        let status = NSTextField(labelWithString: "Press a new key combination (Esc to cancel)")
        status.font = .systemFont(ofSize: 12, weight: .regular)
        status.textColor = .secondaryLabelColor
        status.alignment = .center
        self.statusLabel = status

        let resetButton = NSButton(title: "Reset to Default (⌃⌥A)", target: self, action: #selector(resetToDefault))
        resetButton.bezelStyle = .rounded

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelRecording))
        cancelButton.bezelStyle = .rounded

        let buttonRow = NSStackView(views: [resetButton, cancelButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 10

        let stack = NSStackView(views: [title, badgeContainer, status, buttonRow])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(stack)

        NSLayoutConstraint.activate([
            badgeContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
            badgeContainer.heightAnchor.constraint(equalToConstant: 48),
            badge.centerXAnchor.constraint(equalTo: badgeContainer.centerXAnchor),
            badge.centerYAnchor.constraint(equalTo: badgeContainer.centerYAnchor),
            stack.centerXAnchor.constraint(equalTo: effectView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: effectView.centerYAnchor, constant: -4),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: effectView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: effectView.trailingAnchor, constant: -20)
        ])

        return effectView
    }
}

private final class ShortcutRecorderWindow: NSWindow {
    var onKeyDownEvent: ((UInt16, NSEvent.ModifierFlags) -> Bool)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isKeyWindow else {
            return super.performKeyEquivalent(with: event)
        }
        if let onKeyDownEvent, onKeyDownEvent(event.keyCode, event.modifierFlags) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown,
           isKeyWindow,
           let onKeyDownEvent,
           onKeyDownEvent(event.keyCode, event.modifierFlags) {
            return
        }
        super.sendEvent(event)
    }
}
