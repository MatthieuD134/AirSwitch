import AppKit
import Carbon

public struct KeyCombo: Codable, Equatable, Sendable {
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

    public static func from(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) -> KeyCombo? {
        let combo = KeyCombo(
            carbonKeyCode: UInt32(keyCode),
            carbonModifiers: carbonModifiers(from: modifierFlags)
        )
        return combo.isValidShortcut ? combo : nil
    }

    public var isValidShortcut: Bool {
        let allowedMask = UInt32(controlKey | optionKey | shiftKey | cmdKey)
        let primaryMask = UInt32(controlKey | optionKey | cmdKey)
        guard !Self.modifierKeyCodes.contains(carbonKeyCode),
              carbonKeyCode != UInt32(kVK_Escape),
              Self.keySymbol(for: carbonKeyCode) != nil,
              (carbonModifiers & ~allowedMask) == 0,
              (carbonModifiers & primaryMask) != 0 else {
            return false
        }
        return true
    }

    public static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        let clean = flags.intersection(.deviceIndependentFlagsMask)
        var mods: UInt32 = 0
        if clean.contains(.control) { mods |= UInt32(controlKey) }
        if clean.contains(.option) { mods |= UInt32(optionKey) }
        if clean.contains(.shift) { mods |= UInt32(shiftKey) }
        if clean.contains(.command) { mods |= UInt32(cmdKey) }
        return mods
    }

    public var appKitModifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if (carbonModifiers & UInt32(controlKey)) != 0 { flags.insert(.control) }
        if (carbonModifiers & UInt32(optionKey)) != 0 { flags.insert(.option) }
        if (carbonModifiers & UInt32(shiftKey)) != 0 { flags.insert(.shift) }
        if (carbonModifiers & UInt32(cmdKey)) != 0 { flags.insert(.command) }
        return flags
    }

    public var modifierSymbols: String {
        var out = ""
        if (carbonModifiers & UInt32(controlKey)) != 0 { out += "⌃" }
        if (carbonModifiers & UInt32(optionKey)) != 0 { out += "⌥" }
        if (carbonModifiers & UInt32(shiftKey)) != 0 { out += "⇧" }
        if (carbonModifiers & UInt32(cmdKey)) != 0 { out += "⌘" }
        return out
    }

    public var keyDisplayName: String {
        Self.keySymbol(for: carbonKeyCode) ?? "Key(\(carbonKeyCode))"
    }

    public func displayString(layoutTranslator: ((UInt32) -> String?)? = nil) -> String {
        let keyName = Self.keySymbol(for: carbonKeyCode, layoutTranslator: layoutTranslator) ?? "Key(\(carbonKeyCode))"
        return "\(modifierSymbols)\(keyName)"
    }

    public var displayString: String {
        displayString(layoutTranslator: nil)
    }

    public func menuKeyEquivalent(layoutTranslator: ((UInt32) -> String?)? = nil) -> String {
        if let specialEquivalent = Self.specialMenuKeyEquivalentTable[carbonKeyCode] {
            return specialEquivalent
        }
        if let symbol = Self.keySymbol(for: carbonKeyCode, layoutTranslator: layoutTranslator),
           symbol.count == 1 {
            return symbol.lowercased()
        }
        return ""
    }

    public var menuKeyEquivalent: String {
        menuKeyEquivalent(layoutTranslator: nil)
    }

    private static let modifierKeyCodes: Set<UInt32> = [
        UInt32(kVK_Command),
        UInt32(kVK_RightCommand),
        UInt32(kVK_Shift),
        UInt32(kVK_RightShift),
        UInt32(kVK_Option),
        UInt32(kVK_RightOption),
        UInt32(kVK_Control),
        UInt32(kVK_RightControl),
        UInt32(kVK_CapsLock),
        UInt32(kVK_Function)
    ]

    public static func keySymbol(
        for keyCode: UInt32,
        layoutTranslator: ((UInt32) -> String?)? = nil
    ) -> String? {
        if let special = specialKeySymbolTable[keyCode] {
            return special
        }
        guard ansiKeySymbolTable[keyCode] != nil else {
            return nil
        }
        let translator = layoutTranslator ?? translateWithCurrentKeyboardLayout
        if let localized = translator(keyCode), !localized.isEmpty {
            return localized.uppercased()
        }
        return ansiKeySymbolTable[keyCode]
    }

    private static func translateWithCurrentKeyboardLayout(_ keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let rawPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let data = unsafeBitCast(rawPtr, to: CFData.self)
        guard let bytePtr = CFDataGetBytePtr(data) else { return nil }
        let layoutPtr = UnsafeRawPointer(bytePtr).assumingMemoryBound(to: UCKeyboardLayout.self)

        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var actualLength: Int = 0

        let status = UCKeyTranslate(
            layoutPtr,
            UInt16(keyCode),
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            chars.count,
            &actualLength,
            &chars
        )
        guard status == noErr, actualLength > 0 else { return nil }
        let string = String(utf16CodeUnits: chars, count: actualLength)
            .trimmingCharacters(in: .controlCharacters)
        return string.isEmpty ? nil : string
    }

    private static let specialKeySymbolTable: [UInt32: String] = [
        UInt32(kVK_Space): "Space",
        UInt32(kVK_Return): "↩",
        UInt32(kVK_Tab): "⇥",
        UInt32(kVK_Delete): "⌫",
        UInt32(kVK_ForwardDelete): "⌦",
        UInt32(kVK_LeftArrow): "←",
        UInt32(kVK_RightArrow): "→",
        UInt32(kVK_UpArrow): "↑",
        UInt32(kVK_DownArrow): "↓",
        UInt32(kVK_F1): "F1", UInt32(kVK_F2): "F2", UInt32(kVK_F3): "F3",
        UInt32(kVK_F4): "F4", UInt32(kVK_F5): "F5", UInt32(kVK_F6): "F6",
        UInt32(kVK_F7): "F7", UInt32(kVK_F8): "F8", UInt32(kVK_F9): "F9",
        UInt32(kVK_F10): "F10", UInt32(kVK_F11): "F11", UInt32(kVK_F12): "F12"
    ]

    private static let specialMenuKeyEquivalentTable: [UInt32: String] = [
        UInt32(kVK_Space): " ",
        UInt32(kVK_Return): "\r",
        UInt32(kVK_Tab): "\t",
        UInt32(kVK_Delete): "\u{08}",
        UInt32(kVK_ForwardDelete): "\u{7f}",
        UInt32(kVK_LeftArrow): String(UnicodeScalar(NSLeftArrowFunctionKey)!),
        UInt32(kVK_RightArrow): String(UnicodeScalar(NSRightArrowFunctionKey)!),
        UInt32(kVK_UpArrow): String(UnicodeScalar(NSUpArrowFunctionKey)!),
        UInt32(kVK_DownArrow): String(UnicodeScalar(NSDownArrowFunctionKey)!),
        UInt32(kVK_F1): String(UnicodeScalar(NSF1FunctionKey)!),
        UInt32(kVK_F2): String(UnicodeScalar(NSF2FunctionKey)!),
        UInt32(kVK_F3): String(UnicodeScalar(NSF3FunctionKey)!),
        UInt32(kVK_F4): String(UnicodeScalar(NSF4FunctionKey)!),
        UInt32(kVK_F5): String(UnicodeScalar(NSF5FunctionKey)!),
        UInt32(kVK_F6): String(UnicodeScalar(NSF6FunctionKey)!),
        UInt32(kVK_F7): String(UnicodeScalar(NSF7FunctionKey)!),
        UInt32(kVK_F8): String(UnicodeScalar(NSF8FunctionKey)!),
        UInt32(kVK_F9): String(UnicodeScalar(NSF9FunctionKey)!),
        UInt32(kVK_F10): String(UnicodeScalar(NSF10FunctionKey)!),
        UInt32(kVK_F11): String(UnicodeScalar(NSF11FunctionKey)!),
        UInt32(kVK_F12): String(UnicodeScalar(NSF12FunctionKey)!)
    ]

    private static let ansiKeySymbolTable: [UInt32: String] = [
        UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B", UInt32(kVK_ANSI_C): "C",
        UInt32(kVK_ANSI_D): "D", UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F",
        UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H", UInt32(kVK_ANSI_I): "I",
        UInt32(kVK_ANSI_J): "J", UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
        UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N", UInt32(kVK_ANSI_O): "O",
        UInt32(kVK_ANSI_P): "P", UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R",
        UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T", UInt32(kVK_ANSI_U): "U",
        UInt32(kVK_ANSI_V): "V", UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
        UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z",
        UInt32(kVK_ANSI_0): "0", UInt32(kVK_ANSI_1): "1", UInt32(kVK_ANSI_2): "2",
        UInt32(kVK_ANSI_3): "3", UInt32(kVK_ANSI_4): "4", UInt32(kVK_ANSI_5): "5",
        UInt32(kVK_ANSI_6): "6", UInt32(kVK_ANSI_7): "7", UInt32(kVK_ANSI_8): "8",
        UInt32(kVK_ANSI_9): "9",
        UInt32(kVK_ANSI_Minus): "-", UInt32(kVK_ANSI_Equal): "=",
        UInt32(kVK_ANSI_LeftBracket): "[", UInt32(kVK_ANSI_RightBracket): "]",
        UInt32(kVK_ANSI_Backslash): "\\", UInt32(kVK_ANSI_Semicolon): ";",
        UInt32(kVK_ANSI_Quote): "'", UInt32(kVK_ANSI_Comma): ",",
        UInt32(kVK_ANSI_Period): ".", UInt32(kVK_ANSI_Slash): "/",
        UInt32(kVK_ANSI_Grave): "`"
    ]
}
