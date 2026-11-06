import Foundation

public struct BatteryInfo: Equatable, Sendable {
    public var single: Int?
    public var left: Int?
    public var right: Int?
    public var caseBattery: Int?

    public init(single: Int? = nil, left: Int? = nil, right: Int? = nil, caseBattery: Int? = nil) {
        self.single = single
        self.left = left
        self.right = right
        self.caseBattery = caseBattery
    }

    public var hasMultiBattery: Bool {
        left != nil || right != nil
    }

    public var primaryPercent: Int? {
        if let l = left, let r = right { return min(l, r) }
        if let s = single, s > 0 { return s }
        return left ?? right ?? caseBattery
    }

    public var displayString: String {
        let lLabel = L10n.batteryLeftShort
        let rLabel = L10n.batteryRightShort
        let caseLabel = L10n.batteryCase
        if let l = left, let r = right {
            if let c = caseBattery, c > 0 {
                return "\(lLabel): \(l)% · \(rLabel): \(r)% · \(caseLabel): \(c)%"
            }
            return "\(lLabel): \(l)% · \(rLabel): \(r)%"
        }
        if let l = left {
            if let c = caseBattery, c > 0 { return "\(lLabel): \(l)% · \(caseLabel): \(c)%" }
            return "\(lLabel): \(l)%"
        }
        if let r = right {
            if let c = caseBattery, c > 0 { return "\(rLabel): \(r)% · \(caseLabel): \(c)%" }
            return "\(rLabel): \(r)%"
        }
        if let c = caseBattery, c > 0 {
            return "\(caseLabel): \(c)%"
        }
        if let s = single, s > 0 {
            return "\(s)%"
        }
        return "--%"
    }

    public var hudDisplayString: String? {
        let lLabel = L10n.batteryLeftShort
        let rLabel = L10n.batteryRightShort
        let caseLabel = L10n.batteryCase
        if let l = left, let r = right {
            if let c = caseBattery, c > 0 {
                return "\(lLabel) \(l)% · \(rLabel) \(r)% · \(caseLabel) \(c)%"
            }
            return "\(lLabel) \(l)% · \(rLabel) \(r)%"
        }
        if let l = left {
            if let c = caseBattery, c > 0 { return "\(lLabel) \(l)% · \(caseLabel) \(c)%" }
            return "\(lLabel) \(l)%"
        }
        if let r = right {
            if let c = caseBattery, c > 0 { return "\(rLabel) \(r)% · \(caseLabel) \(c)%" }
            return "\(rLabel) \(r)%"
        }
        if let s = single ?? primaryPercent, s > 0 {
            if let c = caseBattery, c > 0 { return "􀛨 \(s)% · \(caseLabel) \(c)%" }
            return "􀛨 \(s)%"
        }
        if let c = caseBattery, c > 0 {
            return "\(caseLabel) \(c)%"
        }
        return nil
    }
}
