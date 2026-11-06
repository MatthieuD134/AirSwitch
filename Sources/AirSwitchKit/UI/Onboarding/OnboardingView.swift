import AppKit

@MainActor
final class OnboardingView: NSVisualEffectView {
    struct Configuration {
        var selectedDevice: AudioDevice?
        var autoConnectOnWake: Bool
        var autoDisconnectOnSleep: Bool
        var launchAtLogin: Bool
    }

    private var devices: [AudioDevice] = []
    private var selectedDeviceID: String?
    private var rowViews: [OnboardingDeviceRowView] = []

    private let deviceListStack = NSStackView()
    private let autoConnectCheckbox = NSButton(checkboxWithTitle: "Auto-connect when Mac wakes (lid open)", target: nil, action: nil)
    private let autoDisconnectCheckbox = NSButton(checkboxWithTitle: "Auto-disconnect when Mac sleeps (lid close)", target: nil, action: nil)
    private let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch AirSwitch at login", target: nil, action: nil)
    private let confirmButton = NSButton(title: "Get Started", target: nil, action: nil)

    private let onRefreshRequested: () -> [AudioDevice]
    private let onComplete: (Configuration) -> Void

    init(
        initialDevices: [AudioDevice],
        initialTargetAddress: String?,
        autoConnectOnWake: Bool,
        autoDisconnectOnSleep: Bool,
        launchAtLogin: Bool,
        onRefreshRequested: @escaping () -> [AudioDevice],
        onComplete: @escaping (Configuration) -> Void
    ) {
        self.onRefreshRequested = onRefreshRequested
        self.onComplete = onComplete
        super.init(frame: NSRect(x: 0, y: 0, width: 440, height: 490))

        self.autoConnectCheckbox.state = autoConnectOnWake ? .on : .off
        self.autoDisconnectCheckbox.state = autoDisconnectOnSleep ? .on : .off
        self.launchAtLoginCheckbox.state = launchAtLogin ? .on : .off

        setupAppearance()
        setupLayout()
        updateDevices(initialDevices, preferredTargetAddress: initialTargetAddress)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupAppearance() {
        material = .hudWindow
        blendingMode = .behindWindow
        state = .active
        appearance = NSAppearance(named: .vibrantDark)
    }

    private func setupLayout() {
        let rootStack = NSStackView()
        rootStack.orientation = .vertical
        rootStack.alignment = .leading
        rootStack.spacing = 16
        rootStack.edgeInsets = NSEdgeInsets(top: 28, left: 26, bottom: 22, right: 26)
        rootStack.translatesAutoresizingMaskIntoConstraints = false

        rootStack.addArrangedSubview(buildHeaderView())
        rootStack.addArrangedSubview(buildDeviceSectionHeader())
        rootStack.addArrangedSubview(buildDeviceScrollView())
        rootStack.addArrangedSubview(buildOptionsSection())
        rootStack.addArrangedSubview(buildFooterSection())

        addSubview(rootStack)
        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            rootStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            rootStack.topAnchor.constraint(equalTo: topAnchor),
            rootStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func buildHeaderView() -> NSView {
        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: "airpodspro", accessibilityDescription: AppConstants.appName)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 30, weight: .semibold)
        iconView.contentTintColor = .controlAccentColor

        let titleLabel = NSTextField(labelWithString: "Welcome to AirSwitch")
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .labelColor

        let shortcut = HotKeyService.shared.currentKeyCombo.displayString
        let subtitleLabel = NSTextField(wrappingLabelWithString: "Select your primary headphones for one-click menu bar & \(shortcut) instant switching.")
        subtitleLabel.font = NSFont.systemFont(ofSize: 12.5, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor

        let textStack = NSStackView(views: [titleLabel, subtitleLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 4

        let headerStack = NSStackView(views: [iconView, textStack])
        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 14
        return headerStack
    }

    private func buildDeviceSectionHeader() -> NSView {
        let label = NSTextField(labelWithString: "PAIRED AUDIO DEVICES")
        label.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabelColor

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let refreshButton = NSButton(title: "Refresh", target: self, action: #selector(handleRefresh))
        refreshButton.bezelStyle = .inline
        refreshButton.font = NSFont.systemFont(ofSize: 11, weight: .medium)

        let row = NSStackView(views: [label, spacer, refreshButton])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalToConstant: 388).isActive = true
        return row
    }

    private func buildDeviceScrollView() -> NSView {
        deviceListStack.orientation = .vertical
        deviceListStack.alignment = .leading
        deviceListStack.spacing = 8
        deviceListStack.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = deviceListStack

        NSLayoutConstraint.activate([
            scrollView.widthAnchor.constraint(equalToConstant: 388),
            scrollView.heightAnchor.constraint(equalToConstant: 185),
            deviceListStack.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])
        return scrollView
    }

    private func buildOptionsSection() -> NSView {
        let stack = NSStackView(views: [autoConnectCheckbox, autoDisconnectCheckbox, launchAtLoginCheckbox])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        return stack
    }

    private func buildFooterSection() -> NSView {
        let shortcutHint = NSTextField(labelWithString: "Shortcut: \(HotKeyService.shared.currentKeyCombo.displayString)")
        shortcutHint.font = NSFont.monospacedSystemFont(ofSize: 11.5, weight: .medium)
        shortcutHint.textColor = .secondaryLabelColor

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        confirmButton.target = self
        confirmButton.action = #selector(handleConfirm)
        confirmButton.bezelStyle = .rounded
        confirmButton.controlSize = .large
        confirmButton.keyEquivalent = "\r"

        let footer = NSStackView(views: [shortcutHint, spacer, confirmButton])
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.translatesAutoresizingMaskIntoConstraints = false
        footer.widthAnchor.constraint(equalToConstant: 388).isActive = true
        return footer
    }

    func syncOptions(autoConnectOnWake: Bool, autoDisconnectOnSleep: Bool, launchAtLogin: Bool) {
        autoConnectCheckbox.state = autoConnectOnWake ? .on : .off
        autoDisconnectCheckbox.state = autoDisconnectOnSleep ? .on : .off
        launchAtLoginCheckbox.state = launchAtLogin ? .on : .off
    }

    func updateDevices(_ newDevices: [AudioDevice], preferredTargetAddress: String?) {
        self.devices = newDevices
        self.selectedDeviceID = OnboardingState.recommendedDeviceID(
            from: newDevices,
            currentTargetAddress: preferredTargetAddress ?? selectedDeviceID
        )

        deviceListStack.arrangedSubviews.forEach {
            deviceListStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        rowViews.removeAll()

        if newDevices.isEmpty {
            let emptyLabel = NSTextField(wrappingLabelWithString: "No paired Bluetooth headphones found.\nPair your AirPods or headphones in System Settings → Bluetooth, then click Refresh.")
            emptyLabel.font = NSFont.systemFont(ofSize: 12.5, weight: .regular)
            emptyLabel.textColor = .secondaryLabelColor
            emptyLabel.alignment = .center
            deviceListStack.addArrangedSubview(emptyLabel)
            confirmButton.title = "Continue Without Device"
        } else {
            for device in newDevices {
                let row = OnboardingDeviceRowView(
                    device: device,
                    isSelected: device.id == selectedDeviceID
                ) { [weak self] chosen in
                    self?.selectDevice(id: chosen.id)
                }
                rowViews.append(row)
                deviceListStack.addArrangedSubview(row)
                row.widthAnchor.constraint(equalTo: deviceListStack.widthAnchor).isActive = true
            }
            confirmButton.title = "Get Started"
        }
    }

    private func selectDevice(id: String) {
        selectedDeviceID = id
        for row in rowViews {
            row.isSelected = (row.device.id == id)
        }
    }

    @objc private func handleRefresh() {
        let refreshed = onRefreshRequested()
        updateDevices(refreshed, preferredTargetAddress: selectedDeviceID)
    }

    @objc private func handleConfirm() {
        let chosen = devices.first { $0.id == selectedDeviceID }
        onComplete(
            Configuration(
                selectedDevice: chosen,
                autoConnectOnWake: autoConnectCheckbox.state == .on,
                autoDisconnectOnSleep: autoDisconnectCheckbox.state == .on,
                launchAtLogin: launchAtLoginCheckbox.state == .on
            )
        )
    }
}
