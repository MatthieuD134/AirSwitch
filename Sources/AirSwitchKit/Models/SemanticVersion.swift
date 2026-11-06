import Foundation

public struct SemanticVersion: Comparable, Equatable, Sendable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let prerelease: String?

    public init(major: Int, minor: Int, patch: Int, prerelease: String? = nil) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.prerelease = prerelease
    }

    public init?(parsing raw: String) {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("v") || cleaned.hasPrefix("V") {
            cleaned.removeFirst()
        }

        // Strip build metadata (+...)
        let withoutBuild = cleaned.split(separator: "+", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? cleaned
        let parts = withoutBuild.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let corePart = String(parts[0])
        let prereleasePart: String? = parts.count > 1 && !parts[1].isEmpty ? String(parts[1]) : nil

        let numbers = corePart.split(separator: ".", omittingEmptySubsequences: false)
        guard numbers.count == 3,
              let major = Int(numbers[0]), major >= 0,
              let minor = Int(numbers[1]), minor >= 0,
              let patch = Int(numbers[2]), patch >= 0 else {
            return nil
        }

        self.major = major
        self.minor = minor
        self.patch = patch
        self.prerelease = prereleasePart
    }

    public var description: String {
        if let prerelease {
            return "\(major).\(minor).\(patch)-\(prerelease)"
        }
        return "\(major).\(minor).\(patch)"
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }

        switch (lhs.prerelease, rhs.prerelease) {
        case (nil, nil):
            return false
        case (.some, nil):
            return true // prerelease < stable
        case (nil, .some):
            return false
        case let (.some(lPre), .some(rPre)):
            return comparePrerelease(lPre, rPre)
        }
    }

    private static func comparePrerelease(_ lhs: String, _ rhs: String) -> Bool {
        let lParts = lhs.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        let rParts = rhs.split(separator: ".", omittingEmptySubsequences: false).map(String.init)

        for (lToken, rToken) in zip(lParts, rParts) {
            if lToken == rToken { continue }
            let lInt = Int(lToken)
            let rInt = Int(rToken)
            switch (lInt, rInt) {
            case let (.some(li), .some(ri)):
                return li < ri
            case (.some, nil):
                return true // SemVer 2.0.0: numeric identifiers have lower precedence than non-numeric
            case (nil, .some):
                return false
            case (nil, nil):
                return lToken < rToken
            }
        }
        return lParts.count < rParts.count
    }
}
