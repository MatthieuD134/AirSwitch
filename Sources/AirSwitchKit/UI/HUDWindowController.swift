import AppKit
import Foundation

@MainActor
public final class HUDWindowController {
    public static let shared = HUDWindowController()

    internal private(set) var window: NSPanel?
    internal private(set) var pillView: HUDPillView?
    private var dismissTimer: Timer?
    private var dismissGeneration: UInt64 = 0

    internal let shadowPadding: CGFloat = 16

    private var animationsEnabled: Bool {
        Preferences.shared.hudAnimations && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private init() {
        setupWindow()
    }

    private func setupWindow() {
        let pillHeight = HUDPillView.pillHeight
        let windowWidth = HUDPillView.initialWidth + (shadowPadding * 2)
        let windowHeight = pillHeight + (shadowPadding * 2)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.hasShadow = false
        panel.appearance = NSAppearance(named: .vibrantDark)

        let rootContentView = NSView(frame: panel.contentView?.bounds ?? .zero)
        rootContentView.wantsLayer = true
        rootContentView.autoresizingMask = [.width, .height]

        let pill = HUDPillView(origin: CGPoint(x: shadowPadding, y: shadowPadding))
        rootContentView.addSubview(pill)
        panel.contentView = rootContentView

        self.window = panel
        self.pillView = pill
    }

    public func show(
        title: String,
        subtitle: String,
        connected: Bool,
        battery: BatteryInfo? = nil
    ) {
        guard Preferences.shared.showHUD else { return }
        guard let window, let pill = pillView else { return }
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            dismissImmediate()
            return
        }

        let resolved = Self.resolveDisplayContent(
            title: title,
            subtitle: subtitle,
            connected: connected,
            battery: battery
        )
        let isTransitioning = resolved.isTransitioning
        let displayLabelText = resolved.statusText
        let batteryText = resolved.batteryText
        let isAlreadyVisible = window.isVisible && window.alphaValue > 0 && dismissTimer != nil

        dismissTimer?.invalidate()
        dismissTimer = nil
        dismissGeneration &+= 1

        pill.configureIcon(forDeviceTitle: title)
        pill.setPulseAnimation(active: animationsEnabled && isTransitioning)

        let minWidth: CGFloat = isTransitioning ? 190 : (connected ? 200 : 175)
        let targetWidth = pill.calculateAndApplyWidth(
            statusText: displayLabelText,
            batteryText: batteryText,
            minWidth: minWidth
        )
        pill.updateLabels(
            statusText: displayLabelText,
            batteryText: batteryText,
            crossFade: isAlreadyVisible
        )

        let pillHeight = HUDPillView.pillHeight
        let totalWidth = targetWidth + (shadowPadding * 2)
        let totalHeight = pillHeight + (shadowPadding * 2)
        let screenFrame = screen.frame
        let targetX = screenFrame.origin.x + (screenFrame.width - totalWidth) / 2
        let targetY = screenFrame.origin.y + screenFrame.height - totalHeight - 8 + shadowPadding
        let newWindowRect = NSRect(x: targetX, y: targetY, width: totalWidth, height: totalHeight)
        let newPillRect = NSRect(x: shadowPadding, y: shadowPadding, width: targetWidth, height: pillHeight)

        window.setFrame(newWindowRect, display: true)
        window.contentView?.frame = NSRect(x: 0, y: 0, width: totalWidth, height: totalHeight)
        pill.frame = newPillRect
        pill.needsLayout = true
        pill.layoutSubtreeIfNeeded()
        pill.updateShadowPath(width: targetWidth)

        if connected {
            pill.statusDot.fillColor = .systemGreen
            if isAlreadyVisible && animationsEnabled {
                pill.triggerConnectedBounce()
            }
            if batteryText != nil {
                pill.batteryLabel.isHidden = false
                pill.batteryLabel.alphaValue = 1.0
            } else {
                pill.batteryLabel.isHidden = true
                pill.batteryLabel.alphaValue = 0.0
            }
        } else {
            pill.statusDot.fillColor = .systemGray
            pill.batteryLabel.isHidden = true
            pill.batteryLabel.alphaValue = 0.0
        }

        if !isAlreadyVisible {
            window.alphaValue = animationsEnabled ? 0.0 : 1.0
            window.orderFrontRegardless()
        }

        if isAlreadyVisible || !animationsEnabled {
            window.alphaValue = 1.0
        } else {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.20
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1.0, 0.36, 1.0)
                window.animator().alphaValue = 1.0
            }
        }

        let dismissDelay = isTransitioning ? 12.0 : 1.8
        let expectedGeneration = dismissGeneration
        let timer = Timer(timeInterval: dismissDelay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.dismissGeneration == expectedGeneration else { return }
                self.dismiss()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        dismissTimer = timer
    }

    public static func resolveDisplayContent(
        title: String,
        subtitle: String,
        connected: Bool,
        battery: BatteryInfo? = nil
    ) -> (statusText: String, batteryText: String?, isTransitioning: Bool) {
        let trimmedSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let isTransitioning = L10n.isTransitioningSubtitle(trimmedSubtitle)

        if isTransitioning {
            return (trimmedSubtitle, nil, true)
        }

        if L10n.isFailureSubtitle(trimmedSubtitle) {
            return (trimmedSubtitle, nil, false)
        }

        let isDefaultConnected = L10n.isDefaultConnectedSubtitle(trimmedSubtitle)
        if connected && isDefaultConnected {
            return (cleanDeviceName(title), battery?.hudDisplayString, false)
        }

        let isDefaultDisconnected = L10n.isDefaultDisconnectedSubtitle(trimmedSubtitle)
        if !connected && isDefaultDisconnected {
            return (L10n.disconnected, nil, false)
        }

        let combined = "\(cleanDeviceName(title)) · \(trimmedSubtitle)"
        return (combined, connected ? battery?.hudDisplayString : nil, false)
    }

    public static func cleanDeviceName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return L10n.headphones }
        if trimmed.count > 32 {
            return String(trimmed.prefix(30)) + "…"
        }
        return trimmed
    }

    public func dismissImmediate() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        dismissGeneration &+= 1
        pillView?.setPulseAnimation(active: false)
        guard let window else { return }
        window.alphaValue = 0.0
        window.orderOut(nil)
    }

    public func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        guard let window else { return }
        guard window.isVisible && window.alphaValue > 0 && animationsEnabled else {
            dismissImmediate()
            return
        }

        dismissGeneration &+= 1
        let expectedGeneration = dismissGeneration

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 1.0, 1.0)
            window.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.dismissGeneration == expectedGeneration else { return }
                self.window?.alphaValue = 0.0
                self.window?.orderOut(nil)
            }
        })
    }
}
