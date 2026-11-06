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
        if let l = left, let r = right {
            if let c = caseBattery, c > 0 {
                return "L: \(l)% · R: \(r)% · Case: \(c)%"
            }
            return "L: \(l)% · R: \(r)%"
        }
        if let l = left {
            if let c = caseBattery, c > 0 { return "L: \(l)% · Case: \(c)%" }
            return "L: \(l)%"
        }
        if let r = right {
            if let c = caseBattery, c > 0 { return "R: \(r)% · Case: \(c)%" }
            return "R: \(r)%"
        }
        if let c = caseBattery, c > 0 {
            return "Case: \(c)%"
        }
        if let s = single, s > 0 {
            return "\(s)%"
        }
        return "--%"
    }

    public var hudDisplayString: String? {
        if let l = left, let r = right {
            if let c = caseBattery, c > 0 {
                return "L \(l)% · R \(r)% · Case \(c)%"
            }
            return "L \(l)% · R \(r)%"
        }
        if let l = left {
            if let c = caseBattery, c > 0 { return "L \(l)% · Case \(c)%" }
            return "L \(l)%"
        }
        if let r = right {
            if let c = caseBattery, c > 0 { return "R \(r)% · Case \(c)%" }
            return "R \(r)%"
        }
        if let s = single ?? primaryPercent, s > 0 {
            if let c = caseBattery, c > 0 { return "􀛨 \(s)% · Case \(c)%" }
            return "􀛨 \(s)%"
        }
        if let c = caseBattery, c > 0 {
            return "Case \(c)%"
        }
        return nil
    }
}
