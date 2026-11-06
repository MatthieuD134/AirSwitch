import AppKit

@MainActor
private final class FlippedStackContainerView: NSView {
    override var isFlipped: Bool { true }
}

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

    private let scrollView = NSScrollView()
    private let documentContainer = FlippedStackContainerView()
    private let deviceListStack = NSStackView()
    private let confirmButton = NSButton(title: L10n.continueButton, target: nil, action: nil)

    private let onRefreshRequested: () -> [AudioDevice]
    private let onComplete: (Configuration) -> Void

    var currentConfiguration: Configuration {
        let chosen = devices.first { $0.id == selectedDeviceID }
        return Configuration(selectedDevice: chosen)
    }

    init(
        initialDevices: [AudioDevice],
        initialTargetAddress: String?,
        onRefreshRequested: @escaping () -> [AudioDevice],
        onComplete: @escaping (Configuration) -> Void
    ) {
        self.onRefreshRequested = onRefreshRequested
        self.onComplete = onComplete
        super.init(frame: NSRect(x: 0, y: 0, width: 410, height: 440))

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
        refreshButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: L10n.refreshDevices)
        refreshButton.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        refreshButton.bezelStyle = .inline
        refreshButton.isBordered = false
        refreshButton.contentTintColor = Palette.secondaryText
        refreshButton.toolTip = L10n.refreshPairedDevices
        refreshButton.target = self
        refreshButton.action = #selector(handleRefresh)
        refreshButton.translatesAutoresizingMaskIntoConstraints = false

        let rootStack = NSStackView()
        rootStack.orientation = .vertical
        rootStack.alignment = .centerX
        rootStack.spacing = 16
        rootStack.edgeInsets = NSEdgeInsets(top: 26, left: 26, bottom: 20, right: 26)
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
        badgeContainer.layer?.cornerRadius = 13
        badgeContainer.layer?.borderWidth = 1
        badgeContainer.layer?.borderColor = Palette.heroBadgeBorder.cgColor
        badgeContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            badgeContainer.widthAnchor.constraint(equalToConstant: 46),
            badgeContainer.heightAnchor.constraint(equalToConstant: 46)
        ])

        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: "airpodspro", accessibilityDescription: AppConstants.appName)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 21, weight: .semibold)
        iconView.contentTintColor = Palette.accentBlue
        iconView.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: badgeContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: badgeContainer.centerYAnchor)
        ])

        let titleLabel = NSTextField(labelWithString: L10n.welcomeToAirSwitch)
        titleLabel.font = NSFont.systemFont(ofSize: 18.5, weight: .bold)
        titleLabel.textColor = Palette.primaryText
        titleLabel.alignment = .center

        let subtitleLabel = NSTextField(labelWithString: L10n.choosePrimaryHeadphones)
        subtitleLabel.font = NSFont.systemFont(ofSize: 12.5, weight: .regular)
        subtitleLabel.textColor = Palette.secondaryText
        subtitleLabel.alignment = .center

        let textStack = NSStackView(views: [titleLabel, subtitleLabel])
        textStack.orientation = .vertical
        textStack.alignment = .centerX
        textStack.spacing = 3

        let headerStack = NSStackView(views: [badgeContainer, textStack])
        headerStack.orientation = .vertical
        headerStack.alignment = .centerX
        headerStack.spacing = 10
        return headerStack
    }

    private func buildDeviceScrollView() -> NSView {
        deviceListStack.orientation = .vertical
        deviceListStack.alignment = .leading
        deviceListStack.spacing = 6
        deviceListStack.translatesAutoresizingMaskIntoConstraints = false

        documentContainer.translatesAutoresizingMaskIntoConstraints = false
        documentContainer.addSubview(deviceListStack)

        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentContainer

        NSLayoutConstraint.activate([
            scrollView.widthAnchor.constraint(equalToConstant: 358),
            scrollView.heightAnchor.constraint(equalToConstant: 210),
            documentContainer.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            documentContainer.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            documentContainer.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            deviceListStack.topAnchor.constraint(equalTo: documentContainer.topAnchor),
            deviceListStack.leadingAnchor.constraint(equalTo: documentContainer.leadingAnchor),
            deviceListStack.trailingAnchor.constraint(equalTo: documentContainer.trailingAnchor),
            deviceListStack.bottomAnchor.constraint(equalTo: documentContainer.bottomAnchor)
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

        let hintText = NSTextField(labelWithString: L10n.toggleConnectionAnytime)
        hintText.font = NSFont.systemFont(ofSize: 11.5, weight: .regular)
        hintText.textColor = Palette.secondaryText

        let hintRow = NSStackView(views: [keycapView, hintText])
        hintRow.orientation = .horizontal
        hintRow.alignment = .centerY
        hintRow.spacing = 6

        let footerStack = NSStackView(views: [confirmButton, hintRow])
        footerStack.orientation = .vertical
        footerStack.alignment = .centerX
        footerStack.spacing = 10
        return footerStack
    }

    func updateDevices(_ newDevices: [AudioDevice], preferredTargetAddress: String?) {
        let recommendedID = OnboardingState.recommendedDeviceID(
            from: newDevices,
            currentTargetAddress: preferredTargetAddress ?? selectedDeviceID
        )
        let ordered = OnboardingState.orderedDevices(newDevices, recommendedID: recommendedID)
        self.devices = ordered
        self.selectedDeviceID = recommendedID

        deviceListStack.arrangedSubviews.forEach {
            deviceListStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        rowViews.removeAll()

        if ordered.isEmpty {
            let emptyLabel = NSTextField(wrappingLabelWithString: L10n.emptyPairedDevicesMessage)
            emptyLabel.font = NSFont.systemFont(ofSize: 12.5, weight: .regular)
            emptyLabel.textColor = Palette.secondaryText
            emptyLabel.alignment = .center
            deviceListStack.addArrangedSubview(emptyLabel)
            confirmButton.title = L10n.continueWithoutDevice
        } else {
            for device in ordered {
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
            confirmButton.title = L10n.continueButton
        }

        layoutSubtreeIfNeeded()
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
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
        onComplete(currentConfiguration)
    }
}
