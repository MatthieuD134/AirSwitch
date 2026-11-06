import XCTest
@testable import AirSwitchKit

final class AirSwitchTests: XCTestCase {
    func testBatteryInfoSingle() {
        let info = BatteryInfo(single: 85, left: nil, right: nil, caseBattery: nil)
        XCTAssertEqual(info.displayString, "85%")
        XCTAssertEqual(info.hudDisplayString, "􀛨 85%")
        XCTAssertEqual(info.primaryPercent, 85)
        XCTAssertFalse(info.hasMultiBattery)
    }

    func testBatteryInfoAirPodsSplit() {
        let info = BatteryInfo(single: nil, left: 90, right: 80, caseBattery: 100)
        XCTAssertEqual(info.displayString, "L: 90% · R: 80% · Case: 100%")
        XCTAssertEqual(info.hudDisplayString, "L 90% · R 80% · Case 100%")
        XCTAssertEqual(info.primaryPercent, 80)
        XCTAssertTrue(info.hasMultiBattery)
    }

    func testBatteryInfoSingleEarbudWithCase() {
        let info = BatteryInfo(single: nil, left: nil, right: 75, caseBattery: 100)
        XCTAssertEqual(info.displayString, "R: 75% · Case: 100%")
        XCTAssertEqual(info.hudDisplayString, "R 75% · Case 100%")
        XCTAssertEqual(info.primaryPercent, 75)
        XCTAssertTrue(info.hasMultiBattery)
    }

    func testBatteryInfoLeftEarbudWithCase() {
        let info = BatteryInfo(single: nil, left: 80, right: nil, caseBattery: 100)
        XCTAssertEqual(info.displayString, "L: 80% · Case: 100%")
        XCTAssertEqual(info.hudDisplayString, "L 80% · Case 100%")
        XCTAssertEqual(info.primaryPercent, 80)
        XCTAssertTrue(info.hasMultiBattery)
    }

    func testAddressNormalization() {
        let rawColon = "F8:D3:F0:C2:FD:C3"
        XCTAssertEqual(rawColon.normalizedBluetoothAddress, "f8-d3-f0-c2-fd-c3")
        XCTAssertTrue(rawColon.matchesBluetoothAddress("f8-d3-f0-c2-fd-c3"))
        XCTAssertFalse(rawColon.matchesBluetoothAddress("00-11-22-33-44-55"))
        XCTAssertFalse(rawColon.matchesBluetoothAddress(nil))
    }

    @MainActor
    func testCleanDeviceName() {
        XCTAssertEqual(HUDWindowController.cleanDeviceName("   "), "Headphones")
        XCTAssertEqual(HUDWindowController.cleanDeviceName("AirPods Pro"), "AirPods Pro")
        let longName = String(repeating: "A", count: 40)
        XCTAssertEqual(HUDWindowController.cleanDeviceName(longName), String(repeating: "A", count: 30) + "…")
    }

    func testPreferencesDefaults() {
        XCTAssertTrue(Preferences.shared.autoConnectOnWake)
        XCTAssertTrue(Preferences.shared.autoDisconnectOnSleep)
        XCTAssertTrue(Preferences.shared.showHUD)
        XCTAssertTrue(Preferences.shared.hudAnimations)
    }

    @MainActor
    func testHUDShowAndDismissCycle() {
        HUDWindowController.shared.show(
            title: "AirPods Pro",
            subtitle: "Connecting...",
            connected: true,
            battery: nil
        )
        HUDWindowController.shared.show(
            title: "AirPods Pro",
            subtitle: "Connected",
            connected: true,
            battery: BatteryInfo(single: nil, left: 90, right: 85, caseBattery: 100)
        )
        HUDWindowController.shared.dismiss()
    }

    func testToggleResultEvaluationAndSubtitles() {
        let connected = ToggleResult.evaluate(wasConnected: false, transportSucceeded: true, isConnectedNow: true)
        XCTAssertTrue(connected.succeeded)
        XCTAssertTrue(connected.isConnected)
        XCTAssertEqual(connected.hudSubtitle, "Connected")

        let connectUnchangedState = ToggleResult.evaluate(wasConnected: false, transportSucceeded: true, isConnectedNow: false)
        XCTAssertFalse(connectUnchangedState.succeeded)
        XCTAssertFalse(connectUnchangedState.isConnected)
        XCTAssertEqual(connectUnchangedState.hudSubtitle, "Connection Failed")

        let disconnected = ToggleResult.evaluate(wasConnected: true, transportSucceeded: true, isConnectedNow: false)
        XCTAssertTrue(disconnected.succeeded)
        XCTAssertFalse(disconnected.isConnected)
        XCTAssertEqual(disconnected.hudSubtitle, "Disconnected")

        let disconnectUnchangedState = ToggleResult.evaluate(wasConnected: true, transportSucceeded: true, isConnectedNow: true)
        XCTAssertFalse(disconnectUnchangedState.succeeded)
        XCTAssertTrue(disconnectUnchangedState.isConnected)
        XCTAssertEqual(disconnectUnchangedState.hudSubtitle, "Disconnection Failed")
    }

    func testBatteryReaderCacheAvoidsRedundantLoadsWithinTTL() {
        BatteryReader.resetCacheForTesting()
        defer { BatteryReader.resetCacheForTesting() }

        var loadCount = 0
        let loader: () -> [String: BatteryReader.AudioAccessoryEntry] = {
            loadCount += 1
            return ["aa-bb-cc-dd-ee-ff": (name: "AirPods Pro", left: 90, right: 85, caseBatt: 100)]
        }

        let t0 = Date(timeIntervalSince1970: 1_000)
        let first = BatteryReader.readAudioAccessoryInfo(for: "AA:BB:CC:DD:EE:FF", now: t0, loader: loader)
        XCTAssertEqual(first?.name, "AirPods Pro")
        XCTAssertEqual(loadCount, 1)

        // Cached missing address within TTL must not trigger a reload
        let missing = BatteryReader.readAudioAccessoryInfo(
            for: "11:22:33:44:55:66",
            now: t0.addingTimeInterval(1.0),
            loader: loader
        )
        XCTAssertNil(missing)
        XCTAssertEqual(loadCount, 1)

        // Lookup after 3.0s TTL expires triggers exactly one reload
        let afterExpiry = BatteryReader.readAudioAccessoryInfo(
            for: "AA:BB:CC:DD:EE:FF",
            now: t0.addingTimeInterval(3.1),
            loader: loader
        )
        XCTAssertEqual(afterExpiry?.left, 90)
        XCTAssertEqual(loadCount, 2)
    }
}
