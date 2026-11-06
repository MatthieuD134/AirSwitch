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
                self?.pollStatus()
            }
        }
    }

    private func pollStatus() {
        if let target = BluetoothManager.shared.resolveTargetDevice() {
            let isConnected = target.device.isConnected()
            let batteryInfo = isConnected
                ? BluetoothManager.shared.readBattery(for: target.address, device: target.device)
                : nil
            applyStatusItemState(isConnected: isConnected, batteryInfo: batteryInfo)
            BluetoothConnectionMonitor.shared.handlePeriodicPoll(
                address: target.address,
                name: target.name,
                device: target.device,
                isConnected: isConnected,
                battery: batteryInfo
            )
        } else {
            applyStatusItemState(isConnected: false, batteryInfo: nil)
        }
        ReleaseCheckService.shared.checkInBackgroundIfNeeded()
    }

    public func updateUI() {
        var isConnected = false
        var batteryInfo: BatteryInfo?

        if let target = BluetoothManager.shared.resolveTargetDevice() {
            isConnected = target.device.isConnected()
            if isConnected {
                batteryInfo = BluetoothManager.shared.readBattery(for: target.address, device: target.device)
            }
        }

        applyStatusItemState(isConnected: isConnected, batteryInfo: batteryInfo)
    }

    private func applyStatusItemState(isConnected: Bool, batteryInfo: BatteryInfo?) {
        guard let button = statusItem.button else { return }

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
            subtitle: willConnect ? L10n.connecting : L10n.disconnecting,
            connected: willConnect,
            battery: nil
        )

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let dev = BluetoothManager.shared.findDevice(by: targetAddr) else { return }
            let result = BluetoothManager.shared.toggle(device: dev)

            DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.toggleSettleDelay) { [weak self] in
                let actualConnected = dev.isConnected()
                BluetoothConnectionMonitor.shared.seedState(for: targetAddr, isConnected: actualConnected)
                if !actualConnected {
                    LowBatteryMonitor.shared.reset(for: targetAddr)
                }
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
            let statusText = connected ? "\(L10n.connected)\(batterySuffix)" : L10n.disconnected

            let headerItem = NSMenuItem(title: "\(target.name) — \(statusText)", action: nil, keyEquivalent: "")
            headerItem.isEnabled = false
            menu.addItem(headerItem)

            let hotKey = HotKeyService.shared.currentKeyCombo
            let toggleItem = NSMenuItem(
                title: connected ? L10n.disconnect : L10n.connect,
                action: #selector(menuToggle),
                keyEquivalent: hotKey.menuKeyEquivalent
            )
            toggleItem.keyEquivalentModifierMask = hotKey.appKitModifierFlags
            toggleItem.target = self
            menu.addItem(toggleItem)
        } else {
            let headerItem = NSMenuItem(title: L10n.noTargetDeviceHeader, action: nil, keyEquivalent: "")
            headerItem.isEnabled = false
            menu.addItem(headerItem)
        }

        menu.addItem(.separator())

        // 2. Device Picker Submenu
        let devicesItem = NSMenuItem(title: L10n.targetAudioDevice, action: nil, keyEquivalent: "")
        let devicesSubmenu = NSMenu()

        let paired = BluetoothManager.shared.getPairedAudioDevices()
        if paired.isEmpty {
            let emptyItem = NSMenuItem(title: L10n.noPairedAudioDevicesFound, action: nil, keyEquivalent: "")
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

        let shortcutItem = NSMenuItem(
            title: L10n.globalShortcutMenu(HotKeyService.shared.currentKeyCombo.displayString),
            action: #selector(openShortcutRecorder),
            keyEquivalent: ""
        )
        shortcutItem.target = self
        menu.addItem(shortcutItem)

        menu.addItem(.separator())

        // 3. Automation & UI Toggles
        addToggleItem(
            to: menu,
            title: L10n.autoConnectOnWake,
            action: #selector(toggleAutoConnect),
            isOn: Preferences.shared.autoConnectOnWake
        )
        addToggleItem(
            to: menu,
            title: L10n.autoDisconnectOnSleep,
            action: #selector(toggleAutoDisconnect),
            isOn: Preferences.shared.autoDisconnectOnSleep
        )
        addToggleItem(
            to: menu,
            title: L10n.showFloatingBatteryHUD,
            action: #selector(toggleShowHUD),
            isOn: Preferences.shared.showHUD
        )
        addToggleItem(
            to: menu,
            title: L10n.hudAnimations,
            action: #selector(toggleHUDAnimations),
            isOn: Preferences.shared.hudAnimations
        )
        addToggleItem(
            to: menu,
            title: L10n.launchAtLogin,
            action: #selector(toggleLaunchAtLogin),
            isOn: LaunchAtLoginService.isEnabled
        )

        // Language Picker Submenu
        let languageItem = NSMenuItem(title: L10n.languageMenu, action: nil, keyEquivalent: "")
        let languageSubmenu = NSMenu()
        let savedLanguage = Preferences.shared.appLanguage
        let systemResolved = AppLanguage.resolveSystemLanguage()

        let systemItem = NSMenuItem(
            title: L10n.systemDefaultLanguage(systemResolved.nativeName),
            action: #selector(selectLanguage(_:)),
            keyEquivalent: ""
        )
        systemItem.target = self
        systemItem.representedObject = nil
        if savedLanguage == nil {
            systemItem.state = .on
        }
        languageSubmenu.addItem(systemItem)
        languageSubmenu.addItem(.separator())

        for lang in AppLanguage.allCases {
            let item = NSMenuItem(
                title: lang.nativeName,
                action: #selector(selectLanguage(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = lang.rawValue
            if savedLanguage == lang.rawValue {
                item.state = .on
            }
            languageSubmenu.addItem(item)
        }

        languageItem.submenu = languageSubmenu
        menu.addItem(languageItem)

        menu.addItem(.separator())

        // 4. Updates & Quit
        if let update = ReleaseCheckService.shared.availableUpdate {
            let installItem = NSMenuItem(
                title: L10n.installUpdate(update.tagName),
                action: #selector(installAvailableUpdate),
                keyEquivalent: ""
            )
            installItem.target = self
            menu.addItem(installItem)
        } else {
            let checkUpdatesItem = NSMenuItem(
                title: L10n.checkForUpdates,
                action: #selector(checkForUpdatesManually),
                keyEquivalent: ""
            )
            checkUpdatesItem.target = self
            menu.addItem(checkUpdatesItem)
        }

        let quitItem = NSMenuItem(title: L10n.quitAirSwitch, action: #selector(quitApp), keyEquivalent: "q")
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

    @objc private func openShortcutRecorder() {
        ShortcutRecorderWindowController.shared.show()
    }

    @objc private func selectDevice(_ sender: NSMenuItem) {
        guard let addr = sender.representedObject as? String else { return }
        Preferences.shared.setTargetDevice(address: addr, name: sender.title)
        updateUI()

        let device = BluetoothManager.shared.findDevice(by: addr)
        let isConnected = device?.isConnected() ?? false
        let battery = isConnected ? BluetoothManager.shared.readBattery(for: addr, device: device) : nil

        BluetoothConnectionMonitor.shared.seedState(for: addr, isConnected: isConnected)
        HUDWindowController.shared.show(
            title: sender.title,
            subtitle: L10n.selectedAsPrimaryDevice,
            connected: isConnected,
            battery: battery
        )
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        Preferences.shared.appLanguage = sender.representedObject as? String
        OnboardingWindowController.shared.refreshLocalization()
        ShortcutRecorderWindowController.shared.refreshLocalization()
        HUDWindowController.shared.show(
            title: L10n.languageMenu,
            subtitle: L10n.currentLanguage.nativeName,
            connected: true,
            battery: nil
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

    @objc private func installAvailableUpdate() {
        guard let update = ReleaseCheckService.shared.availableUpdate else { return }
        AppSelfUpdater.shared.install(update)
    }

    @objc private func checkForUpdatesManually() {
        ReleaseCheckService.shared.checkForUpdates { result in
            switch result {
            case .success(let update):
                if let update {
                    AppSelfUpdater.shared.install(update)
                } else {
                    HUDWindowController.shared.show(
                        title: "AirSwitch v\(AppConstants.version)",
                        subtitle: L10n.upToDate,
                        connected: true,
                        battery: nil
                    )
                }
            case .failure:
                HUDWindowController.shared.show(
                    title: AppConstants.appName,
                    subtitle: L10n.updateCheckFailed,
                    connected: false,
                    battery: nil
                )
            }
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
