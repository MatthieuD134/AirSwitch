import AppKit

@MainActor
final class HUDPillView: NSView {
    static let pillHeight: CGFloat = 36
    static let initialWidth: CGFloat = 165

    let iconImageView = NSImageView()
    let statusDot = NSBox()
    let statusLabel = NSTextField(labelWithString: "")
    let batteryLabel = NSTextField(labelWithString: "")

    private var stackWidthConstraint: NSLayoutConstraint?

    init(origin: CGPoint) {
        let initialFrame = NSRect(
            x: origin.x,
            y: origin.y,
            width: Self.initialWidth,
            height: Self.pillHeight
        )
        super.init(frame: initialFrame)
        setupView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        wantsLayer = true
        layer?.masksToBounds = false
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.35
        layer?.shadowOffset = CGSize(width: 0, height: -3)
        layer?.shadowRadius = 12
        updateShadowPath(width: Self.initialWidth)

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 13, bottom: 0, right: 13)
        stack.setClippingResistancePriority(.defaultLow, for: .horizontal)
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Icon
        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        iconImageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        iconImageView.contentTintColor = .labelColor
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: 18),
            iconImageView.heightAnchor.constraint(equalToConstant: 18)
        ])
        stack.addArrangedSubview(iconImageView)

        // Status Dot
        statusDot.wantsLayer = true
        statusDot.boxType = .custom
        statusDot.borderWidth = 0
        statusDot.cornerRadius = 3
        statusDot.fillColor = .systemGray
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statusDot.widthAnchor.constraint(equalToConstant: 6),
            statusDot.heightAnchor.constraint(equalToConstant: 6)
        ])
        stack.addArrangedSubview(statusDot)

        // Status / Device Name Label
        statusLabel.wantsLayer = true
        statusLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        statusLabel.textColor = .labelColor
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        statusLabel.setContentHuggingPriority(.required, for: .horizontal)
        stack.addArrangedSubview(statusLabel)

        // Flexible spacer
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(spacer)

        // Battery badge
        batteryLabel.wantsLayer = true
        batteryLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        batteryLabel.textColor = .secondaryLabelColor
        batteryLabel.alignment = .right
        batteryLabel.alphaValue = 0.0
        batteryLabel.isHidden = true
        batteryLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        batteryLabel.setContentHuggingPriority(.required, for: .horizontal)
        stack.addArrangedSubview(batteryLabel)

        let widthConstraint = stack.widthAnchor.constraint(equalToConstant: Self.initialWidth)
        self.stackWidthConstraint = widthConstraint

        if let glassClass = NSClassFromString("NSGlassEffectView") as? NSView.Type {
            let glassView = glassClass.init(frame: bounds)
            glassView.appearance = NSAppearance(named: .vibrantDark)
            (glassView as AnyObject).setValue(Self.pillHeight / 2, forKey: "cornerRadius")
            (glassView as AnyObject).setValue(1, forKey: "style")
            (glassView as AnyObject).setValue(1, forKey: "_contentLensing")
            (glassView as AnyObject).setValue(true, forKey: "clipsToBounds")
            glassView.autoresizingMask = [.width, .height]

            let contentHolder = NSView(frame: bounds)
            contentHolder.translatesAutoresizingMaskIntoConstraints = false
            contentHolder.addSubview(stack)
            (glassView as AnyObject).setValue(contentHolder, forKey: "contentView")

            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: contentHolder.leadingAnchor),
                widthConstraint,
                stack.topAnchor.constraint(equalTo: contentHolder.topAnchor),
                stack.bottomAnchor.constraint(equalTo: contentHolder.bottomAnchor)
            ])

            addSubview(glassView)
        } else {
            let visualEffect = NSVisualEffectView(frame: bounds)
            visualEffect.material = .fullScreenUI
            visualEffect.blendingMode = .behindWindow
            visualEffect.state = .active
            visualEffect.appearance = NSAppearance(named: .vibrantDark)
            visualEffect.wantsLayer = true
            visualEffect.layer?.cornerRadius = Self.pillHeight / 2
            visualEffect.layer?.masksToBounds = true
            visualEffect.layer?.borderWidth = 0.5
            visualEffect.layer?.borderColor = NSColor(white: 1.0, alpha: 0.18).cgColor
            visualEffect.autoresizingMask = [.width, .height]

            visualEffect.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
                widthConstraint,
                stack.topAnchor.constraint(equalTo: visualEffect.topAnchor),
                stack.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor)
            ])

            addSubview(visualEffect)
        }
    }

    func configureIcon(forDeviceTitle title: String) {
        let lower = title.lowercased()
        let symbolName: String
        if lower.contains("max") {
            symbolName = "headphones"
        } else if lower.contains("airpods") {
            symbolName = "airpodspro"
        } else {
            symbolName = "headphones"
        }
        iconImageView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
            ?? NSImage(systemSymbolName: "headphones", accessibilityDescription: nil)
    }

    func setPulseAnimation(active: Bool) {
        if active {
            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.fromValue = 0.35
            pulse.toValue = 1.0
            pulse.duration = 0.52
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            statusDot.layer?.add(pulse, forKey: "dotPulse")
        } else {
            statusDot.layer?.removeAnimation(forKey: "dotPulse")
            statusDot.layer?.opacity = 1.0
        }
    }

    func triggerConnectedBounce() {
        let bounce = CASpringAnimation(keyPath: "transform.scale")
        bounce.fromValue = 0.5
        bounce.toValue = 1.0
        bounce.damping = 12
        bounce.initialVelocity = 3
        bounce.duration = 0.35
        statusDot.layer?.add(bounce, forKey: "snap")
    }

    func calculateAndApplyWidth(statusText: String, batteryText: String?, minWidth: CGFloat) -> CGFloat {
        let statusFont = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        let statusTextWidth = (statusText as NSString).size(withAttributes: [.font: statusFont]).width

        let batteryTextWidth: CGFloat
        if let batteryText {
            let batteryFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            batteryTextWidth = (batteryText as NSString).size(withAttributes: [.font: batteryFont]).width
        } else {
            batteryTextWidth = 0
        }

        // Insets: left (13) + icon (18) + spacing (8) + dot (6) + spacing (8) + text + (spacer (14) + battery) + right (13) + cushion (12)
        let naturalWidth = 13 + 18 + 8 + 6 + 8 + statusTextWidth + (batteryTextWidth > 0 ? (14 + batteryTextWidth) : 0) + 13 + 12
        let targetWidth = max(minWidth, ceil(naturalWidth))
        stackWidthConstraint?.constant = targetWidth
        return targetWidth
    }

    func updateLabels(statusText: String, batteryText: String?, crossFade: Bool) {
        if statusLabel.stringValue != statusText {
            if crossFade {
                let fade = CATransition()
                fade.type = .fade
                fade.duration = 0.2
                fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                statusLabel.layer?.add(fade, forKey: "textFade")
            }
            statusLabel.stringValue = statusText
        }

        if let batteryText {
            batteryLabel.stringValue = batteryText
        }
    }

    func updateShadowPath(width: CGFloat) {
        layer?.shadowPath = CGPath(
            roundedRect: CGRect(x: 0, y: 0, width: width, height: Self.pillHeight),
            cornerWidth: Self.pillHeight / 2,
            cornerHeight: Self.pillHeight / 2,
            transform: nil
        )
    }
}
