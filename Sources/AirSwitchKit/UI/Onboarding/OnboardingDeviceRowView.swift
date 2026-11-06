import AppKit

@MainActor
final class OnboardingDeviceRowView: NSView {
    let device: AudioDevice
    private let onSelect: (AudioDevice) -> Void

    private let iconBadgeView = NSView()
    private let iconView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let radioIconView = NSImageView()
    private var trackingArea: NSTrackingArea?
    private var isHovered = false {
        didSet { updateAppearance() }
    }
    private var isFocused = false {
        didSet { updateAppearance() }
    }

    var isSelected: Bool = false {
        didSet { updateAppearance() }
    }

    private enum Palette {
        static let unselectedBg = NSColor(srgbRed: 0.125, green: 0.125, blue: 0.149, alpha: 1.0) // #202026
        static let hoveredBg = NSColor(srgbRed: 0.153, green: 0.153, blue: 0.180, alpha: 1.0)    // #27272E
        static let selectedBg = NSColor(srgbRed: 0.133, green: 0.176, blue: 0.255, alpha: 1.0)   // #222D41
        static let unselectedBorder = NSColor(white: 1.0, alpha: 0.07)
        static let hoveredBorder = NSColor(white: 1.0, alpha: 0.14)
        static let focusedBorder = NSColor(srgbRed: 0.450, green: 0.720, blue: 1.0, alpha: 0.85)
        static let selectedBorder = NSColor(srgbRed: 0.278, green: 0.569, blue: 1.0, alpha: 0.90)
        static let unselectedBadgeBg = NSColor(srgbRed: 0.173, green: 0.173, blue: 0.204, alpha: 1.0)
        static let selectedBadgeBg = NSColor(srgbRed: 0.200, green: 0.290, blue: 0.440, alpha: 1.0)
        static let accentBlue = NSColor(srgbRed: 0.345, green: 0.651, blue: 1.0, alpha: 1.0)
        static let primaryText = NSColor(srgbRed: 0.961, green: 0.961, blue: 0.969, alpha: 1.0)
        static let mutedText = NSColor(srgbRed: 0.600, green: 0.600, blue: 0.640, alpha: 1.0)
        static let connectedGreen = NSColor(srgbRed: 0.204, green: 0.827, blue: 0.600, alpha: 1.0)
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
        layer?.borderWidth = 1.25
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 48).isActive = true

        iconBadgeView.wantsLayer = true
        iconBadgeView.layer?.cornerRadius = 8
        iconBadgeView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconBadgeView.widthAnchor.constraint(equalToConstant: 32),
            iconBadgeView.heightAnchor.constraint(equalToConstant: 32)
        ])

        let symbolName = Self.symbolName(for: device.name)
        iconView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: device.name)
            ?? NSImage(systemSymbolName: "headphones", accessibilityDescription: device.name)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14.5, weight: .semibold)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBadgeView.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: iconBadgeView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBadgeView.centerYAnchor)
        ])

        nameLabel.stringValue = device.name
        nameLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        nameLabel.textColor = Palette.primaryText
        nameLabel.lineBreakMode = .byTruncatingTail

        statusLabel.stringValue = Self.statusText(for: device)
        statusLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        statusLabel.textColor = device.isConnected ? Palette.connectedGreen : Palette.mutedText

        let textStack = NSStackView(views: [nameLabel, statusLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 1

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        radioIconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        radioIconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            radioIconView.widthAnchor.constraint(equalToConstant: 18),
            radioIconView.heightAnchor.constraint(equalToConstant: 18)
        ])

        let rowStack = NSStackView(views: [iconBadgeView, textStack, spacer, radioIconView])
        rowStack.orientation = .horizontal
        rowStack.alignment = .centerY
        rowStack.spacing = 10
        rowStack.edgeInsets = NSEdgeInsets(top: 7, left: 11, bottom: 7, right: 12)
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(rowStack)
        NSLayoutConstraint.activate([
            rowStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            rowStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            rowStack.topAnchor.constraint(equalTo: topAnchor),
            rowStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }

    private func updateAppearance() {
        if isSelected {
            layer?.backgroundColor = Palette.selectedBg.cgColor
            layer?.borderColor = (isFocused ? Palette.focusedBorder : Palette.selectedBorder).cgColor
            layer?.borderWidth = isFocused ? 2.0 : 1.25
            iconBadgeView.layer?.backgroundColor = Palette.selectedBadgeBg.cgColor
            iconView.contentTintColor = Palette.accentBlue
            radioIconView.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Selected")
            radioIconView.contentTintColor = Palette.accentBlue
        } else {
            layer?.backgroundColor = (isHovered || isFocused ? Palette.hoveredBg : Palette.unselectedBg).cgColor
            let border = isFocused ? Palette.focusedBorder : (isHovered ? Palette.hoveredBorder : Palette.unselectedBorder)
            layer?.borderColor = border.cgColor
            layer?.borderWidth = isFocused ? 1.75 : 1.25
            iconBadgeView.layer?.backgroundColor = Palette.unselectedBadgeBg.cgColor
            iconView.contentTintColor = Palette.mutedText
            radioIconView.image = NSImage(systemSymbolName: "circle", accessibilityDescription: "Not selected")
            radioIconView.contentTintColor = NSColor(white: 1.0, alpha: 0.22)
        }
        setAccessibilityElement(true)
        setAccessibilityRole(.radioButton)
        setAccessibilityLabel("\(device.name), \(Self.statusText(for: device))")
        setAccessibilityValue(isSelected)
    }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted {
            isFocused = true
            scrollToVisible(bounds)
        }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            isFocused = false
        }
        return resigned
    }

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
