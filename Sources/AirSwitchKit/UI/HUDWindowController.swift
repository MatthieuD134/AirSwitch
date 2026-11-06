import AppKit
import Foundation

@MainActor
public final class HUDWindowController {
    public static let shared = HUDWindowController()

    private var window: NSPanel?
    private var pillView: HUDPillView?
    private var dismissTimer: Timer?

    private let shadowPadding: CGFloat = 16

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

        let lowerSubtitle = subtitle.lowercased()
        let isTransitioning = lowerSubtitle.contains("connecting") || lowerSubtitle.contains("disconnecting")
        let isAlreadyVisible = dismissTimer != nil

        dismissTimer?.invalidate()
        dismissTimer = nil

        pill.configureIcon(forDeviceTitle: title)
        pill.setPulseAnimation(active: animationsEnabled && isTransitioning)

        let displayLabelText: String
        let batteryText: String?

        if isTransitioning {
            displayLabelText = subtitle
            batteryText = nil
        } else if !connected {
            displayLabelText = "Disconnected"
            batteryText = nil
        } else {
            displayLabelText = Self.cleanDeviceName(title)
            batteryText = battery?.hudDisplayString
        }

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

        guard let screen = NSScreen.main else { return }
        let pillHeight = HUDPillView.pillHeight
        let totalWidth = targetWidth + (shadowPadding * 2)
        let totalHeight = pillHeight + (shadowPadding * 2)
        let screenFrame = screen.frame
        let targetX = screenFrame.origin.x + (screenFrame.width - totalWidth) / 2
        let targetY = screenFrame.origin.y + screenFrame.height - totalHeight - 8 + shadowPadding
        let newWindowRect = NSRect(x: targetX, y: targetY, width: totalWidth, height: totalHeight)
        let newPillRect = NSRect(x: shadowPadding, y: shadowPadding, width: targetWidth, height: pillHeight)

        if !isAlreadyVisible {
            if !window.isVisible {
                window.setFrame(newWindowRect, display: true)
                window.alphaValue = 0.0
                if animationsEnabled {
                    let circleX = shadowPadding + (targetWidth - pillHeight) / 2
                    pill.frame = NSRect(x: circleX, y: shadowPadding, width: pillHeight, height: pillHeight)
                } else {
                    pill.frame = newPillRect
                }
                window.orderFront(nil)
            } else if !animationsEnabled {
                window.setFrame(newWindowRect, display: true)
                pill.frame = newPillRect
            }
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = isAlreadyVisible ? 0.30 : (animationsEnabled ? 0.24 : 0.18)
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1.0, 0.36, 1.0)
            context.allowsImplicitAnimation = true
            window.animator().alphaValue = 1.0

            if animationsEnabled {
                if isAlreadyVisible {
                    window.animator().setFrame(newWindowRect, display: true)
                }
                pill.animator().frame = newPillRect
            } else if isAlreadyVisible {
                window.setFrame(newWindowRect, display: true)
                pill.frame = newPillRect
            }

            pill.updateShadowPath(width: targetWidth)

            if connected {
                pill.statusDot.fillColor = .systemGreen
                if isAlreadyVisible && animationsEnabled {
                    pill.triggerConnectedBounce()
                }
                if batteryText != nil {
                    pill.batteryLabel.isHidden = false
                    pill.batteryLabel.animator().alphaValue = 1.0
                } else {
                    pill.batteryLabel.isHidden = true
                    pill.batteryLabel.alphaValue = 0.0
                }
            } else {
                pill.statusDot.fillColor = .systemGray
                pill.batteryLabel.isHidden = true
                pill.batteryLabel.alphaValue = 0.0
            }
        }

        let dismissDelay = isTransitioning ? 12.0 : 1.8
        dismissTimer = Timer.scheduledTimer(withTimeInterval: dismissDelay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.dismiss()
            }
        }
    }

    public static func cleanDeviceName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Headphones" }
        if trimmed.count > 32 {
            return String(trimmed.prefix(30)) + "…"
        }
        return trimmed
    }

    public func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        guard let window, window.isVisible, window.alphaValue > 0 else { return }
        let pillHeight = HUDPillView.pillHeight

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 1.0, 1.0)
            context.allowsImplicitAnimation = true
            window.animator().alphaValue = 0.0
            if animationsEnabled, let pill = self.pillView {
                let circleX = (window.frame.width - pillHeight) / 2
                pill.animator().frame = NSRect(x: circleX, y: shadowPadding, width: pillHeight, height: pillHeight)
            }
        }, completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.dismissTimer == nil else { return }
                window.orderOut(nil)
            }
        })
    }
}
