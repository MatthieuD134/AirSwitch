import AppKit
import Foundation
@preconcurrency import IOBluetooth

@MainActor
public final class StatusBarController: NSObject {
    public static let shared = StatusBarController()

    private var statusItem: NSStatusItem!
    private var updateTimer: Timer?

    private lazy var menuBarIcon: NSImage? = {
        let urls = [
            Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
            URL(fileURLWithPath: "/Applications/AirSwitch.app/Contents/Resources/MenuBarIcon.png"),
            URL(fileURLWithPath: "Resources/MenuBarIcon.png")
        ].compactMap { $0 }

        for url in urls {
            if let img = NSImage(contentsOf: url) {
                img.size = NSSize(width: 18, height: 18)
                img.isTemplate = true
                return img
            }
        }
        return NSImage(systemSymbolName: "airpodspro", accessibilityDescription: AppConstants.appName)
    }()

    public override init() {
        super.init()
        setupStatusItem()
        startPeriodicUpdates()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleStatusItemClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        updateUI()
    }

    private func startPeriodicUpdates() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: AppConstants.statusPollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateUI()
            }
        }
    }

    public func updateUI() {
        guard let button = statusItem.button else { return }

        var isConnected = false
        var batteryInfo: BatteryInfo?

        if let target = BluetoothManager.shared.resolveTargetDevice() {
            isConnected = target.device.isConnected()
            if isConnected {
                batteryInfo = BluetoothManager.shared.readBattery(for: target.address, device: target.device)
            }
        }

        button.image = menuBarIcon
        button.imagePosition = .imageLeading
        button.appearsDisabled = !isConnected

        if isConnected, let percent = batteryInfo?.primaryPercent {
            button.title = " \(percent)%"
        } else {
            button.title = ""
        }
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        let isRightClick = event.type == .rightMouseUp || event.modifierFlags.contains(.control)
        let hasTarget = Preferences.shared.targetDeviceAddress != nil

        if isRightClick || !hasTarget {
            showMenu()
        } else {
            toggleConnection()
        }
    }

    public func toggleConnection() {
        guard let target = BluetoothManager.shared.resolveTargetDevice() else {
            showMenu()
            return
        }

        let targetAddr = target.address
        let targetName = target.name
        let willConnect = !target.device.isConnected()

        HUDWindowController.shared.show(
            title: targetName,
            subtitle: willConnect ? "Connecting..." : "Disconnecting...",
            connected: willConnect,
            battery: nil
        )

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let dev = BluetoothManager.shared.findDevice(by: targetAddr) else { return }
            let result = BluetoothManager.shared.toggle(device: dev)

            DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.toggleSettleDelay) { [weak self] in
                let actualConnected = dev.isConnected()
                let resolvedResult = ToggleResult(
                    action: result.action,
                    succeeded: result.action == .connect ? actualConnected : !actualConnected,
                    isConnected: actualConnected
                )
                let battery = actualConnected ? BluetoothManager.shared.readBattery(for: targetAddr, device: dev) : nil
                self?.updateUI()
                HUDWindowController.shared.show(
                    title: targetName,
                    subtitle: resolvedResult.hudSubtitle,
                    connected: actualConnected,
                    battery: battery
                )
            }
        }
    }

    private func showMenu() {
        let menu = buildMenu()
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil // detach so left-clicks keep firing action
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        // 1. Status Header
        let targetAddr = Preferences.shared.targetDeviceAddress

        if let target = BluetoothManager.shared.resolveTargetDevice() {
            let connected = target.device.isConnected()
            let battery = connected ? BluetoothManager.shared.readBattery(for: target.address, device: target.device) : nil
            let batterySuffix = battery.map { " (\($0.displayString))" } ?? ""
            let statusText = connected ? "Connected\(batterySuffix)" : "Disconnected"

            let headerItem = NSMenuItem(title: "\(target.name) — \(statusText)", action: nil, keyEquivalent: "")
            headerItem.isEnabled = false
            menu.addItem(headerItem)

            let toggleItem = NSMenuItem(
                title: connected ? "Disconnect" : "Connect",
                action: #selector(menuToggle),
                keyEquivalent: "a"
            )
            toggleItem.keyEquivalentModifierMask = [.control, .option]
            toggleItem.target = self
            menu.addItem(toggleItem)
        } else {
            let headerItem = NSMenuItem(title: "AirSwitch — No target device", action: nil, keyEquivalent: "")
            headerItem.isEnabled = false
            menu.addItem(headerItem)
        }

        menu.addItem(.separator())

        // 2. Device Picker Submenu
        let devicesItem = NSMenuItem(title: "Target Audio Device", action: nil, keyEquivalent: "")
        let devicesSubmenu = NSMenu()

        let paired = BluetoothManager.shared.getPairedAudioDevices()
        if paired.isEmpty {
            let emptyItem = NSMenuItem(title: "No paired audio devices found", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            devicesSubmenu.addItem(emptyItem)
        } else {
            for device in paired {
                let item = NSMenuItem(title: device.name, action: #selector(selectDevice(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = device.id
                if device.matchesAddress(targetAddr) {
                    item.state = .on
                }
                devicesSubmenu.addItem(item)
            }
        }

        devicesItem.submenu = devicesSubmenu
        menu.addItem(devicesItem)

        menu.addItem(.separator())

        // 3. Automation & UI Toggles
        addToggleItem(
            to: menu,
            title: "Auto-connect on Wake (Lid Open)",
            action: #selector(toggleAutoConnect),
            isOn: Preferences.shared.autoConnectOnWake
        )
        addToggleItem(
            to: menu,
            title: "Auto-disconnect on Sleep (Lid Close)",
            action: #selector(toggleAutoDisconnect),
            isOn: Preferences.shared.autoDisconnectOnSleep
        )
        addToggleItem(
            to: menu,
            title: "Show Floating Battery HUD",
            action: #selector(toggleShowHUD),
            isOn: Preferences.shared.showHUD
        )
        addToggleItem(
            to: menu,
            title: "HUD Animations",
            action: #selector(toggleHUDAnimations),
            isOn: Preferences.shared.hudAnimations
        )
        addToggleItem(
            to: menu,
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            isOn: LaunchAtLoginService.isEnabled
        )

        menu.addItem(.separator())

        // 4. Quit
        let quitItem = NSMenuItem(title: "Quit AirSwitch", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    private func addToggleItem(to menu: NSMenu, title: String, action: Selector, isOn: Bool) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.state = isOn ? .on : .off
        menu.addItem(item)
    }

    @objc private func menuToggle() {
        toggleConnection()
    }

    @objc private func selectDevice(_ sender: NSMenuItem) {
        guard let addr = sender.representedObject as? String else { return }
        Preferences.shared.setTargetDevice(address: addr, name: sender.title)
        updateUI()

        HUDWindowController.shared.show(
            title: sender.title,
            subtitle: "Selected as primary device",
            connected: false
        )
    }

    @objc private func toggleAutoConnect() {
        Preferences.shared.autoConnectOnWake.toggle()
    }

    @objc private func toggleAutoDisconnect() {
        Preferences.shared.autoDisconnectOnSleep.toggle()
    }

    @objc private func toggleShowHUD() {
        Preferences.shared.showHUD.toggle()
    }

    @objc private func toggleHUDAnimations() {
        Preferences.shared.hudAnimations.toggle()
    }

    @objc private func toggleLaunchAtLogin() {
        LaunchAtLoginService.toggle()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
