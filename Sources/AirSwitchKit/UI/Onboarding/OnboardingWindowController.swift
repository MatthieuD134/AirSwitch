import AppKit

@MainActor
public final class OnboardingWindowController: NSObject, NSWindowDelegate {
    public static let shared = OnboardingWindowController()

    private var window: NSWindow?
    private var onboardingView: OnboardingView?

    private override init() {
        super.init()
    }

    public func presentIfNeeded() {
        let prefs = Preferences.shared
        guard OnboardingState.shouldPresentOnLaunch(
            hasCompletedOnboarding: prefs.hasCompletedOnboarding,
            targetDeviceAddress: prefs.targetDeviceAddress
        ) else {
            return
        }
        show()
    }

    public func show() {
        let prefs = Preferences.shared
        let devices = BluetoothManager.shared.getPairedAudioDevices()

        if let existingWindow = window {
            onboardingView?.updateDevices(devices, preferredTargetAddress: prefs.targetDeviceAddress)
            NSApp.setActivationPolicy(.regular)
            existingWindow.center()
            existingWindow.makeKeyAndOrderFront(nil)
            existingWindow.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = OnboardingView(
            initialDevices: devices,
            initialTargetAddress: prefs.targetDeviceAddress,
            onRefreshRequested: {
                BluetoothManager.shared.getPairedAudioDevices()
            },
            onComplete: { [weak self] config in
                self?.applyConfigurationAndClose(config)
            }
        )
        self.onboardingView = contentView

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 410, height: 390),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "Welcome to AirSwitch"
        newWindow.titleVisibility = .hidden
        newWindow.titlebarAppearsTransparent = true
        newWindow.backgroundColor = NSColor(srgbRed: 0.086, green: 0.086, blue: 0.102, alpha: 1.0)
        newWindow.isOpaque = false
        newWindow.hasShadow = true
        newWindow.isMovableByWindowBackground = true
        newWindow.isReleasedWhenClosed = false
        newWindow.level = .floating
        newWindow.appearance = NSAppearance(named: .darkAqua)
        newWindow.contentView = contentView
        newWindow.delegate = self
        newWindow.center()

        self.window = newWindow
        NSApp.setActivationPolicy(.regular)
        newWindow.makeKeyAndOrderFront(nil)
        newWindow.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func applyConfigurationAndClose(_ config: OnboardingView.Configuration) {
        let prefs = Preferences.shared
        prefs.hasCompletedOnboarding = true

        if let selected = config.selectedDevice {
            prefs.setTargetDevice(address: selected.id, name: selected.name)
            StatusBarController.shared.updateUI()

            let liveDevice = BluetoothManager.shared.findDevice(by: selected.id)
            let isConnected = liveDevice?.isConnected() ?? selected.isConnected
            let battery = isConnected
                ? BluetoothManager.shared.readBattery(for: selected.id, device: liveDevice)
                : nil

            BluetoothConnectionMonitor.shared.seedState(for: selected.id, isConnected: isConnected)
            HUDWindowController.shared.show(
                title: selected.name,
                subtitle: "Selected as primary device",
                connected: isConnected,
                battery: battery
            )
        }

        window?.close()
    }

    public func windowWillClose(_ notification: Notification) {
        Preferences.shared.hasCompletedOnboarding = true
        onboardingView = nil
        window = nil
        NSApp.setActivationPolicy(.accessory)
    }
}
