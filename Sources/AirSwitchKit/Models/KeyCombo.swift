import Carbon

public struct KeyCombo: Equatable, Sendable {
    public var carbonKeyCode: UInt32
    public var carbonModifiers: UInt32

    public init(carbonKeyCode: UInt32, carbonModifiers: UInt32 = 0) {
        self.carbonKeyCode = carbonKeyCode
        self.carbonModifiers = carbonModifiers
    }

    /// Default shortcut: ⌃⌥A (Control + Option + A)
    public static let defaultToggle = KeyCombo(
        carbonKeyCode: UInt32(kVK_ANSI_A),
        carbonModifiers: UInt32(controlKey | optionKey)
    )
}
