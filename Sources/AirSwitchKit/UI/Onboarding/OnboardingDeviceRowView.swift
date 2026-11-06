import AppKit

@MainActor
final class OnboardingDeviceRowView: NSView {
    let device: AudioDevice
    private let onSelect: (AudioDevice) -> Void

    private let iconView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let radioIconView = NSImageView()

    var isSelected: Bool = false {
        didSet { updateAppearance() }
    }

    init(device: AudioDevice, isSelected: Bool, onSelect: @escaping (AudioDevice) -> Void) {
        self.device = device
        self.isSelected = isSelected
        self.onSelect = onSelect
        super.init(frame: .zero)
        setupView()
        updateAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.borderWidth = 1
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 52).isActive = true

        let symbolName = Self.symbolName(for: device.name)
        iconView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: device.name)
            ?? NSImage(systemSymbolName: "headphones", accessibilityDescription: device.name)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 26),
            iconView.heightAnchor.constraint(equalToConstant: 26)
        ])

        nameLabel.stringValue = device.name
        nameLabel.font = NSFont.systemFont(ofSize: 13.5, weight: .semibold)
        nameLabel.textColor = .labelColor
        nameLabel.lineBreakMode = .byTruncatingTail

        statusLabel.stringValue = Self.statusText(for: device)
        statusLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .regular)
        statusLabel.textColor = device.isConnected ? .systemGreen : .secondaryLabelColor

        let textStack = NSStackView(views: [nameLabel, statusLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        radioIconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        radioIconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            radioIconView.widthAnchor.constraint(equalToConstant: 20),
            radioIconView.heightAnchor.constraint(equalToConstant: 20)
        ])

        let rowStack = NSStackView(views: [iconView, textStack, spacer, radioIconView])
        rowStack.orientation = .horizontal
        rowStack.alignment = .centerY
        rowStack.spacing = 12
        rowStack.edgeInsets = NSEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(rowStack)
        NSLayoutConstraint.activate([
            rowStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            rowStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            rowStack.topAnchor.constraint(equalTo: topAnchor),
            rowStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func updateAppearance() {
        if isSelected {
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.18).cgColor
            layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.75).cgColor
            iconView.contentTintColor = .controlAccentColor
            radioIconView.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Selected")
            radioIconView.contentTintColor = .controlAccentColor
        } else {
            layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.05).cgColor
            layer?.borderColor = NSColor(white: 1.0, alpha: 0.10).cgColor
            iconView.contentTintColor = .secondaryLabelColor
            radioIconView.image = NSImage(systemSymbolName: "circle", accessibilityDescription: "Not selected")
            radioIconView.contentTintColor = .tertiaryLabelColor
        }
        setAccessibilityElement(true)
        setAccessibilityRole(.radioButton)
        setAccessibilityLabel("\(device.name), \(Self.statusText(for: device))")
        setAccessibilityValue(isSelected)
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        onSelect(device)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 49 || event.keyCode == 36 { // Space or Return
            onSelect(device)
        } else {
            super.keyDown(with: event)
        }
    }

    override func accessibilityPerformPress() -> Bool {
        onSelect(device)
        return true
    }

    static func symbolName(for deviceName: String) -> String {
        let lower = deviceName.lowercased()
        if lower.contains("max") {
            return "headphones"
        } else if lower.contains("airpods") {
            return "airpodspro"
        }
        return "headphones"
    }

    static func statusText(for device: AudioDevice) -> String {
        guard device.isConnected else { return "Paired" }
        if let battery = device.battery?.displayString, !battery.isEmpty {
            return "Connected • \(battery)"
        }
        return "Connected"
    }
}
