import AppKit

@MainActor
final class OnboardingView: NSView {
    struct Configuration {
        var selectedDevice: AudioDevice?
    }

    private enum Palette {
        static let surfaceBg = NSColor(srgbRed: 0.086, green: 0.086, blue: 0.102, alpha: 1.0) // #16161A
        static let surfaceBorder = NSColor(white: 1.0, alpha: 0.09)
        static let heroBadgeBg = NSColor(srgbRed: 0.133, green: 0.133, blue: 0.161, alpha: 1.0) // #222229
        static let heroBadgeBorder = NSColor(white: 1.0, alpha: 0.10)
        static let accentBlue = NSColor(srgbRed: 0.278, green: 0.569, blue: 1.0, alpha: 1.0)
        static let primaryText = NSColor(srgbRed: 0.961, green: 0.961, blue: 0.969, alpha: 1.0)
        static let secondaryText = NSColor(srgbRed: 0.565, green: 0.565, blue: 0.616, alpha: 1.0)
        static let keycapBg = NSColor(srgbRed: 0.145, green: 0.145, blue: 0.173, alpha: 1.0)
        static let keycapBorder = NSColor(white: 1.0, alpha: 0.12)
    }

    private var devices: [AudioDevice] = []
    private var selectedDeviceID: String?
    private var rowViews: [OnboardingDeviceRowView] = []

    private let deviceListStack = NSStackView()
    private let confirmButton = NSButton(title: "Continue", target: nil, action: nil)

    private let onRefreshRequested: () -> [AudioDevice]
    private let onComplete: (Configuration) -> Void

    init(
        initialDevices: [AudioDevice],
        initialTargetAddress: String?,
        onRefreshRequested: @escaping () -> [AudioDevice],
        onComplete: @escaping (Configuration) -> Void
    ) {
        self.onRefreshRequested = onRefreshRequested
        self.onComplete = onComplete
        super.init(frame: NSRect(x: 0, y: 0, width: 410, height: 390))

        setupAppearance()
        setupLayout()
        updateDevices(initialDevices, preferredTargetAddress: initialTargetAddress)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupAppearance() {
        wantsLayer = true
        layer?.backgroundColor = Palette.surfaceBg.cgColor
        layer?.cornerRadius = 14
        layer?.borderWidth = 1
        layer?.borderColor = Palette.surfaceBorder.cgColor
        appearance = NSAppearance(named: .darkAqua)
    }

    private func setupLayout() {
        let refreshButton = NSButton()
        refreshButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Refresh devices")
        refreshButton.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        refreshButton.bezelStyle = .inline
        refreshButton.isBordered = false
        refreshButton.contentTintColor = Palette.secondaryText
        refreshButton.toolTip = "Refresh paired devices"
        refreshButton.target = self
        refreshButton.action = #selector(handleRefresh)
        refreshButton.translatesAutoresizingMaskIntoConstraints = false

        let rootStack = NSStackView()
        rootStack.orientation = .vertical
        rootStack.alignment = .centerX
        rootStack.spacing = 18
        rootStack.edgeInsets = NSEdgeInsets(top: 30, left: 26, bottom: 22, right: 26)
        rootStack.translatesAutoresizingMaskIntoConstraints = false

        rootStack.addArrangedSubview(buildHeroHeader())
        rootStack.addArrangedSubview(buildDeviceScrollView())
        rootStack.addArrangedSubview(buildFooterSection())

        addSubview(rootStack)
        addSubview(refreshButton)

        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            rootStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            rootStack.topAnchor.constraint(equalTo: topAnchor),
            rootStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            refreshButton.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            refreshButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            refreshButton.widthAnchor.constraint(equalToConstant: 24),
            refreshButton.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    private func buildHeroHeader() -> NSView {
        let badgeContainer = NSView()
        badgeContainer.wantsLayer = true
        badgeContainer.layer?.backgroundColor = Palette.heroBadgeBg.cgColor
        badgeContainer.layer?.cornerRadius = 14
        badgeContainer.layer?.borderWidth = 1
        badgeContainer.layer?.borderColor = Palette.heroBadgeBorder.cgColor
        badgeContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            badgeContainer.widthAnchor.constraint(equalToConstant: 52),
            badgeContainer.heightAnchor.constraint(equalToConstant: 52)
        ])

        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: "airpodspro", accessibilityDescription: AppConstants.appName)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 23, weight: .semibold)
        iconView.contentTintColor = Palette.accentBlue
        iconView.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: badgeContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: badgeContainer.centerYAnchor)
        ])

        let titleLabel = NSTextField(labelWithString: "Welcome to AirSwitch")
        titleLabel.font = NSFont.systemFont(ofSize: 19, weight: .bold)
        titleLabel.textColor = Palette.primaryText
        titleLabel.alignment = .center

        let subtitleLabel = NSTextField(labelWithString: "Choose your primary headphones")
        subtitleLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = Palette.secondaryText
        subtitleLabel.alignment = .center

        let textStack = NSStackView(views: [titleLabel, subtitleLabel])
        textStack.orientation = .vertical
        textStack.alignment = .centerX
        textStack.spacing = 4

        let headerStack = NSStackView(views: [badgeContainer, textStack])
        headerStack.orientation = .vertical
        headerStack.alignment = .centerX
        headerStack.spacing = 12
        return headerStack
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
            scrollView.widthAnchor.constraint(equalToConstant: 358),
            scrollView.heightAnchor.constraint(equalToConstant: 140),
            deviceListStack.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])
        return scrollView
    }

    private func buildFooterSection() -> NSView {
        confirmButton.target = self
        confirmButton.action = #selector(handleConfirm)
        confirmButton.bezelStyle = .rounded
        confirmButton.controlSize = .large
        confirmButton.bezelColor = Palette.accentBlue
        confirmButton.keyEquivalent = "\r"
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        confirmButton.widthAnchor.constraint(equalToConstant: 358).isActive = true

        let keycapView = NSView()
        keycapView.wantsLayer = true
        keycapView.layer?.backgroundColor = Palette.keycapBg.cgColor
        keycapView.layer?.cornerRadius = 5
        keycapView.layer?.borderWidth = 1
        keycapView.layer?.borderColor = Palette.keycapBorder.cgColor
        keycapView.translatesAutoresizingMaskIntoConstraints = false

        let keycapLabel = NSTextField(labelWithString: HotKeyService.shared.currentKeyCombo.displayString)
        keycapLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
        keycapLabel.textColor = Palette.primaryText
        keycapLabel.translatesAutoresizingMaskIntoConstraints = false
        keycapView.addSubview(keycapLabel)
        NSLayoutConstraint.activate([
            keycapLabel.leadingAnchor.constraint(equalTo: keycapView.leadingAnchor, constant: 6),
            keycapLabel.trailingAnchor.constraint(equalTo: keycapView.trailingAnchor, constant: -6),
            keycapLabel.topAnchor.constraint(equalTo: keycapView.topAnchor, constant: 2),
            keycapLabel.bottomAnchor.constraint(equalTo: keycapView.bottomAnchor, constant: -2)
        ])

        let hintText = NSTextField(labelWithString: "Toggle connection anytime")
        hintText.font = NSFont.systemFont(ofSize: 11.5, weight: .regular)
        hintText.textColor = Palette.secondaryText

        let hintRow = NSStackView(views: [keycapView, hintText])
        hintRow.orientation = .horizontal
        hintRow.alignment = .centerY
        hintRow.spacing = 6

        let footerStack = NSStackView(views: [confirmButton, hintRow])
        footerStack.orientation = .vertical
        footerStack.alignment = .centerX
        footerStack.spacing = 12
        return footerStack
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
            let emptyLabel = NSTextField(wrappingLabelWithString: "No paired Bluetooth headphones found.\nPair your headphones in Bluetooth Settings, then click ↻.")
            emptyLabel.font = NSFont.systemFont(ofSize: 12.5, weight: .regular)
            emptyLabel.textColor = Palette.secondaryText
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
            confirmButton.title = "Continue"
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
        onComplete(Configuration(selectedDevice: chosen))
    }
}
