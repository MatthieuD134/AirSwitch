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

    @MainActor
    func testHUDResolveDisplayContentPreservesCustomSubtitlesAndFailures() {
        let battery = BatteryInfo(single: 80)

        let selectedDisconnected = HUDWindowController.resolveDisplayContent(
            title: "Sony XM5",
            subtitle: "Selected as primary device",
            connected: false,
            battery: nil
        )
        XCTAssertEqual(selectedDisconnected.statusText, "Sony XM5 · Selected as primary device")
        XCTAssertNil(selectedDisconnected.batteryText)
        XCTAssertFalse(selectedDisconnected.isTransitioning)

        let selectedConnected = HUDWindowController.resolveDisplayContent(
            title: "AirPods Pro",
            subtitle: "Selected as primary device",
            connected: true,
            battery: battery
        )
        XCTAssertEqual(selectedConnected.statusText, "AirPods Pro · Selected as primary device")
        XCTAssertEqual(selectedConnected.batteryText, "􀛨 80%")

        let failed = HUDWindowController.resolveDisplayContent(
            title: "AirPods Pro",
            subtitle: "Connection Failed",
            connected: false,
            battery: battery
        )
        XCTAssertEqual(failed.statusText, "Connection Failed")
        XCTAssertNil(failed.batteryText)

        let normalConnected = HUDWindowController.resolveDisplayContent(
            title: "AirPods Pro",
            subtitle: "Connected",
            connected: true,
            battery: battery
        )
        XCTAssertEqual(normalConnected.statusText, "AirPods Pro")
        XCTAssertEqual(normalConnected.batteryText, "􀛨 80%")

        let normalDisconnected = HUDWindowController.resolveDisplayContent(
            title: "AirPods Pro",
            subtitle: "Disconnected",
            connected: false,
            battery: nil
        )
        XCTAssertEqual(normalDisconnected.statusText, "Disconnected")
        XCTAssertNil(normalDisconnected.batteryText)
    }

    func testOnboardingStateShouldPresentOnLaunch() {
        XCTAssertTrue(OnboardingState.shouldPresentOnLaunch(hasCompletedOnboarding: false, targetDeviceAddress: nil))
        XCTAssertTrue(OnboardingState.shouldPresentOnLaunch(hasCompletedOnboarding: false, targetDeviceAddress: "   "))
        XCTAssertFalse(OnboardingState.shouldPresentOnLaunch(hasCompletedOnboarding: true, targetDeviceAddress: nil))
        XCTAssertFalse(OnboardingState.shouldPresentOnLaunch(hasCompletedOnboarding: false, targetDeviceAddress: "aa-bb-cc-dd-ee-ff"))
        XCTAssertFalse(OnboardingState.shouldPresentOnLaunch(hasCompletedOnboarding: true, targetDeviceAddress: "aa-bb-cc-dd-ee-ff"))
    }

    func testOnboardingStateRecommendedDeviceSelection() {
        let speaker = AudioDevice(id: "11-22-33-44-55-66", name: "Bose Speaker", isConnected: true, battery: nil)
        let airpods = AudioDevice(id: "aa-bb-cc-dd-ee-ff", name: "Matthieu’s AirPods Pro", isConnected: false, battery: nil)
        let xm5 = AudioDevice(id: "77-88-99-aa-bb-cc", name: "Sony WH-1000XM5", isConnected: false, battery: nil)

        // Prefers AirPods when no current target is set
        XCTAssertEqual(
            OnboardingState.recommendedDeviceID(from: [speaker, airpods, xm5], currentTargetAddress: nil),
            "aa-bb-cc-dd-ee-ff"
        )

        // Respects existing target address even with colon formatting
        XCTAssertEqual(
            OnboardingState.recommendedDeviceID(from: [speaker, airpods, xm5], currentTargetAddress: "77:88:99:AA:BB:CC"),
            "77-88-99-aa-bb-cc"
        )

        // Falls back to connected device when no AirPods are present
        XCTAssertEqual(
            OnboardingState.recommendedDeviceID(from: [xm5, speaker], currentTargetAddress: nil),
            "11-22-33-44-55-66"
        )
    }

    func testSemanticVersionParsingAndComparison() {
        let v010 = SemanticVersion(parsing: "v0.1.0")
        let v011 = SemanticVersion(parsing: "0.1.1")
        let v020Beta = SemanticVersion(parsing: "v0.2.0-beta.1")
        let v020 = SemanticVersion(parsing: "v0.2.0")

        XCTAssertNotNil(v010)
        XCTAssertNotNil(v011)
        XCTAssertNotNil(v020Beta)
        XCTAssertNotNil(v020)
        XCTAssertNil(SemanticVersion(parsing: "invalid"))
        XCTAssertNil(SemanticVersion(parsing: "1.2"))

        XCTAssertTrue(v010! < v011!)
        XCTAssertTrue(v011! < v020Beta!)
        XCTAssertTrue(v020Beta! < v020!)

        // SemVer 2.0.0 §11: alphanumeric identifiers compare lexically, dot-separated numeric compare numerically
        let alpha10 = SemanticVersion(parsing: "1.0.0-alpha10")!
        let alpha2 = SemanticVersion(parsing: "1.0.0-alpha2")!
        XCTAssertTrue(alpha10 < alpha2)

        let alphaDot2 = SemanticVersion(parsing: "1.0.0-alpha.2")!
        let alphaDot10 = SemanticVersion(parsing: "1.0.0-alpha.10")!
        XCTAssertTrue(alphaDot2 < alphaDot10)
    }

    func testReleaseCheckServicePayloadEvaluation() throws {
        let current = SemanticVersion(major: 0, minor: 1, patch: 1)

        let newerJSON = """
        {
          "tag_name": "v0.2.0",
          "html_url": "https://github.com/MatthieuD134/AirSwitch/releases/tag/v0.2.0",
          "draft": false,
          "prerelease": false,
          "body": "### Features\\n- Added onboarding",
          "assets": [
            {
              "name": "AirSwitch.dmg",
              "browser_download_url": "https://github.com/MatthieuD134/AirSwitch/releases/download/v0.2.0/AirSwitch.dmg"
            },
            {
              "name": "AirSwitch.app.zip",
              "browser_download_url": "https://github.com/MatthieuD134/AirSwitch/releases/download/v0.2.0/AirSwitch.app.zip"
            }
          ]
        }
        """.data(using: .utf8)!

        let update = try ReleaseCheckService.evaluateReleasePayload(newerJSON, currentVersion: current)
        XCTAssertEqual(update?.version, SemanticVersion(major: 0, minor: 2, patch: 0))
        XCTAssertEqual(
            update?.zipDownloadURL.absoluteString,
            "https://github.com/MatthieuD134/AirSwitch/releases/download/v0.2.0/AirSwitch.app.zip"
        )

        // Same version returns nil
        let upToDate = try ReleaseCheckService.evaluateReleasePayload(
            newerJSON,
            currentVersion: SemanticVersion(major: 0, minor: 2, patch: 0)
        )
        XCTAssertNil(upToDate)

        // Insecure http URL is rejected
        let insecureJSON = """
        {
          "tag_name": "v0.3.0",
          "html_url": "https://github.com/MatthieuD134/AirSwitch/releases/tag/v0.3.0",
          "draft": false,
          "prerelease": false,
          "assets": [
            {
              "name": "AirSwitch.app.zip",
              "browser_download_url": "http://example.com/AirSwitch.app.zip"
            }
          ]
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try ReleaseCheckService.evaluateReleasePayload(insecureJSON, currentVersion: current))
    }

    func testReleaseCheckServiceAutomaticCheckSchedule() {
        XCTAssertTrue(ReleaseCheckService.shouldPerformAutomaticCheck(lastCheckTimestamp: 0, now: 10_000, interval: 86_400))
        XCTAssertFalse(ReleaseCheckService.shouldPerformAutomaticCheck(lastCheckTimestamp: 10_000, now: 50_000, interval: 86_400))
        XCTAssertTrue(ReleaseCheckService.shouldPerformAutomaticCheck(lastCheckTimestamp: 10_000, now: 96_400, interval: 86_400))
    }

    func testAppSelfUpdaterBundleValidation() throws {
        let fm = FileManager.default
        let tempRoot = fm.temporaryDirectory.appendingPathComponent("AirSwitchTestBundle-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: tempRoot) }

        let appURL = tempRoot.appendingPathComponent("AirSwitch.app", isDirectory: true)
        let macOSURL = appURL.appendingPathComponent("Contents/MacOS", isDirectory: true)
        try fm.createDirectory(at: macOSURL, withIntermediateDirectories: true)

        let execURL = macOSURL.appendingPathComponent("airswitch", isDirectory: false)
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: execURL)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: execURL.path)

        let plistURL = appURL.appendingPathComponent("Contents/Info.plist", isDirectory: false)
        let validPlist: [String: Any] = [
            "CFBundleIdentifier": AppConstants.bundleIdentifier,
            "CFBundleExecutable": "airswitch"
        ]
        let plistData = try PropertyListSerialization.data(fromPropertyList: validPlist, format: .xml, options: 0)
        try plistData.write(to: plistURL)

        // Structural validation with lowercase 'airswitch' executable succeeds
        XCTAssertNoThrow(try AppSelfUpdater.validateExtractedBundle(at: appURL, verifySignature: false))

        // Mismatched bundle identifier fails
        XCTAssertThrowsError(
            try AppSelfUpdater.validateExtractedBundle(at: appURL, expectedBundleID: "com.other.app", verifySignature: false)
        )

        // Unsigned bundle fails when signature verification is enabled
        XCTAssertThrowsError(try AppSelfUpdater.validateExtractedBundle(at: appURL, verifySignature: true))
    }
}
