import Foundation
@preconcurrency import IOBluetooth
import IOKit

public enum BatteryReader {
    public typealias AudioAccessoryEntry = (name: String?, left: Int?, right: Int?, caseBatt: Int?)

    private static let audioAccessoryFrameworkLoaded: Bool = {
        Bundle(path: "/System/Library/PrivateFrameworks/AudioAccessoryServices.framework")?.load() ?? false
    }()

    private static let cacheLock = NSLock()
    private static nonisolated(unsafe) var cachedAccessoryMap: [String: AudioAccessoryEntry] = [:]
    private static nonisolated(unsafe) var cacheTimestamp: Date = .distantPast
    private static let cacheTTL: TimeInterval = 3.0

    public static func readBattery(for address: String, device: IOBluetoothDevice? = nil) -> BatteryInfo? {
        var info = BatteryInfo()
        var foundAny = false

        // 1. Direct native IOBluetoothDevice selectors (Left, Right, Case, Single)
        if let d = device {
            typealias Getter = @convention(c) (AnyObject, Selector) -> Int
            func readSel(_ name: String) -> Int? {
                let sel = Selector(name)
                guard d.responds(to: sel) else { return nil }
                let imp = unsafeBitCast(d.method(for: sel), to: Getter.self)
                let val = imp(d, sel) & 0xFF
                return (val > 0 && val <= 100) ? val : nil
            }

            if let l = readSel("batteryPercentLeft") {
                info.left = l
                foundAny = true
            }
            if let r = readSel("batteryPercentRight") {
                info.right = r
                foundAny = true
            }
            if let c = readSel("batteryPercentCase") {
                info.caseBattery = c
                foundAny = true
            }
            if let s = readSel("batteryPercentSingle") ?? readSel("batteryPercentCombined") {
                info.single = s
                foundAny = true
            }
        }

        // 2. AudioAccessoryServices supplement (fills in missing Left, Right, or Case when docked/closed)
        if let aa = readAudioAccessoryInfo(for: address) {
            if info.left == nil, let l = aa.left {
                info.left = l
                foundAny = true
            }
            if info.right == nil, let r = aa.right {
                info.right = r
                foundAny = true
            }
            if info.caseBattery == nil, let c = aa.caseBatt {
                info.caseBattery = c
                foundAny = true
            }
        }

        // 3. Fallback to IOKit AppleDeviceManagementHIDEventService
        if !foundAny, let services = fetchIOServices("AppleDeviceManagementHIDEventService") {
            for dict in services {
                guard let rawAddr = dict["DeviceAddress"] as? String,
                      rawAddr.matchesBluetoothAddress(address) else {
                    continue
                }
                if let single = dict["BatteryPercent"] as? Int, single > 0 {
                    info.single = single
                    foundAny = true
                }
                if let left = dict["BatteryPercentLeft"] as? Int, left > 0 {
                    info.left = left
                    foundAny = true
                }
                if let right = dict["BatteryPercentRight"] as? Int, right > 0 {
                    info.right = right
                    foundAny = true
                }
                if let c = dict["BatteryPercentCase"] as? Int, c > 0 {
                    info.caseBattery = c
                    foundAny = true
                }
                break
            }
        }

        return foundAny ? info : nil
    }

    public static func readAudioAccessoryInfo(
        for address: String
    ) -> AudioAccessoryEntry? {
        readAudioAccessoryInfo(for: address, now: Date(), loader: loadAudioAccessoryMapFromDisk)
    }

    internal static func readAudioAccessoryInfo(
        for address: String,
        now: Date,
        loader: () -> [String: AudioAccessoryEntry]
    ) -> AudioAccessoryEntry? {
        let normalizedKey = address.normalizedBluetoothAddress
        return cacheLock.withLock {
            if now.timeIntervalSince(cacheTimestamp) >= cacheTTL {
                cachedAccessoryMap = loader()
                cacheTimestamp = now
            }
            return cachedAccessoryMap[normalizedKey]
        }
    }

    internal static func resetCacheForTesting() {
        cacheLock.withLock {
            cachedAccessoryMap = [:]
            cacheTimestamp = .distantPast
        }
    }

    private static func loadAudioAccessoryMapFromDisk() -> [String: AudioAccessoryEntry] {
        _ = audioAccessoryFrameworkLoaded
        let path = ("~/Library/Preferences/com.apple.AudioAccessory.plist" as NSString).expandingTildeInPath
        guard let dict = NSDictionary(contentsOfFile: path),
              let data = dict["lastSeenBatteryInfosV2"] as? Data else {
            return [:]
        }

        do {
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
            unarchiver.requiresSecureCoding = false
            guard let map = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? [String: NSObject] else {
                return [:]
            }

            var result: [String: AudioAccessoryEntry] = [:]
            for (_, info) in map {
                guard let btAddr = info.value(forKey: "bluetoothAddress") as? String else {
                    continue
                }

                let name = info.value(forKey: "name") as? String

                func extractLevel(_ key: String) -> Int? {
                    guard let bObj = info.value(forKey: key) as? NSObject,
                          let level = bObj.value(forKey: "level") as? Double,
                          level > 0.0 else { return nil }
                    let pct = Int(round(level * 100))
                    return (pct > 0 && pct <= 100) ? pct : nil
                }

                result[btAddr.normalizedBluetoothAddress] = (
                    name: name,
                    left: extractLevel("batteryLeft"),
                    right: extractLevel("batteryRight"),
                    caseBatt: extractLevel("batteryCase")
                )
            }
            return result
        } catch {
            return [:]
        }
    }

    private static func fetchIOServices(_ name: String) -> [[String: Any]]? {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(name), &iterator)
        guard result == kIOReturnSuccess else { return nil }
        defer { IOObjectRelease(iterator) }

        var list: [[String: Any]] = []
        var entry = IOIteratorNext(iterator)
        while entry != 0 {
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(entry, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
               let dict = props?.takeRetainedValue() as? [String: Any] {
                list.append(dict)
            }
            IOObjectRelease(entry)
            entry = IOIteratorNext(iterator)
        }
        return list.isEmpty ? nil : list
    }
}
