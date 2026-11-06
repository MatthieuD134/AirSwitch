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
            onboardingView?.syncOptions(
                autoConnectOnWake: prefs.autoConnectOnWake,
                autoDisconnectOnSleep: prefs.autoDisconnectOnSleep,
                launchAtLogin: LaunchAtLoginService.isEnabled
            )
            onboardingView?.updateDevices(devices, preferredTargetAddress: prefs.targetDeviceAddress)
            existingWindow.center()
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = OnboardingView(
            initialDevices: devices,
            initialTargetAddress: prefs.targetDeviceAddress,
            autoConnectOnWake: prefs.autoConnectOnWake,
            autoDisconnectOnSleep: prefs.autoDisconnectOnSleep,
            launchAtLogin: LaunchAtLoginService.isEnabled,
            onRefreshRequested: {
                BluetoothManager.shared.getPairedAudioDevices()
            },
            onComplete: { [weak self] config in
                self?.applyConfigurationAndClose(config)
            }
        )
        self.onboardingView = contentView

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 490),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "Welcome to AirSwitch"
        newWindow.titleVisibility = .hidden
        newWindow.titlebarAppearsTransparent = true
        newWindow.isMovableByWindowBackground = true
        newWindow.isReleasedWhenClosed = false
        newWindow.level = .floating
        newWindow.contentView = contentView
        newWindow.delegate = self
        newWindow.center()

        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func applyConfigurationAndClose(_ config: OnboardingView.Configuration) {
        let prefs = Preferences.shared
        prefs.autoConnectOnWake = config.autoConnectOnWake
        prefs.autoDisconnectOnSleep = config.autoDisconnectOnSleep
        prefs.hasCompletedOnboarding = true
        LaunchAtLoginService.setEnabled(config.launchAtLogin)

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
    }
}
