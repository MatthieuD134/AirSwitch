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

    func testLowBatteryMonitorThresholdsHysteresisAndReset() {
        let monitor = LowBatteryMonitor(thresholds: [20, 10])
        let address = "AA:BB:CC:DD:EE:FF"

        // Above 20% produces no alert
        XCTAssertNil(monitor.evaluate(deviceAddress: address, isConnected: true, battery: BatteryInfo(single: 55)))

        // Dropping to 18% fires the 20% threshold once
        let first20 = monitor.evaluate(deviceAddress: address, isConnected: true, battery: BatteryInfo(single: 18))
        XCTAssertEqual(first20, LowBatteryAlert(threshold: 20, currentPercent: 18))
        XCTAssertEqual(first20?.hudSubtitle, "Low Battery (18%)")

        // Subsequent polls <= 20% and > 10% do not repeat the 20% alert, even with 1-2% upward jitter
        XCTAssertNil(monitor.evaluate(deviceAddress: address, isConnected: true, battery: BatteryInfo(single: 16)))
        XCTAssertNil(monitor.evaluate(deviceAddress: address, isConnected: true, battery: BatteryInfo(single: 21)))
        XCTAssertNil(monitor.evaluate(deviceAddress: address, isConnected: true, battery: BatteryInfo(single: 19)))

        // Dropping to 9% fires the 10% threshold once
        let first10 = monitor.evaluate(deviceAddress: address, isConnected: true, battery: BatteryInfo(single: 9))
        XCTAssertEqual(first10, LowBatteryAlert(threshold: 10, currentPercent: 9))
        XCTAssertNil(monitor.evaluate(deviceAddress: address, isConnected: true, battery: BatteryInfo(single: 8)))
        XCTAssertNil(monitor.evaluate(deviceAddress: address, isConnected: true, battery: BatteryInfo(single: 12)))

        // Disconnecting resets session state so reconnecting at 15% alerts again
        XCTAssertNil(monitor.evaluate(deviceAddress: address, isConnected: false, battery: nil))
        let afterReconnect = monitor.evaluate(deviceAddress: address, isConnected: true, battery: BatteryInfo(single: 15))
        XCTAssertEqual(afterReconnect, LowBatteryAlert(threshold: 20, currentPercent: 15))
    }

    func testLowBatteryMonitorConnectingDirectlyAtCriticalLevelSuppressesHigherThreshold() {
        let monitor = LowBatteryMonitor(thresholds: [20, 10])
        let address = "11-22-33-44-55-66"

        let critical = monitor.evaluate(deviceAddress: address, isConnected: true, battery: BatteryInfo(left: 8, right: 15))
        XCTAssertEqual(critical, LowBatteryAlert(threshold: 10, currentPercent: 8))

        // If reading fluctuates to 14% while still below 20%, the 20% alert must not fire retroactively
        XCTAssertNil(monitor.evaluate(deviceAddress: address, isConnected: true, battery: BatteryInfo(left: 14, right: 15)))
    }

    func testBluetoothConnectionMonitorTransitionsAndAppSuppression() {
        let monitor = BluetoothConnectionMonitor()
        let target = "aa-bb-cc-dd-ee-ff"
        let other = "11-22-33-44-55-66"
        let t0 = Date(timeIntervalSince1970: 5_000)

        // First observation seeds state without emitting an event
        XCTAssertNil(monitor.recordObservedState(address: target, isConnected: false, targetAddress: target, now: t0))

        // Non-target device transitions are ignored
        XCTAssertNil(monitor.recordObservedState(address: other, isConnected: true, targetAddress: target, now: t0))

        // External connect emits .connected once
        XCTAssertEqual(
            monitor.recordObservedState(address: target, isConnected: true, targetAddress: target, now: t0.addingTimeInterval(1)),
            .connected
        )
        XCTAssertNil(
            monitor.recordObservedState(address: target, isConnected: true, targetAddress: target, now: t0.addingTimeInterval(2))
        )

        // External disconnect emits .disconnected once
        XCTAssertEqual(
            monitor.recordObservedState(address: target, isConnected: false, targetAddress: target, now: t0.addingTimeInterval(3)),
            .disconnected
        )

        // App-initiated transition suppresses external event both while active and during post-transition settle window
        let tApp = t0.addingTimeInterval(10)
        monitor.beginAppInitiatedTransition(for: target, now: tApp)
        XCTAssertNil(
            monitor.recordObservedState(address: target, isConnected: true, targetAddress: target, now: tApp.addingTimeInterval(0.5))
        )
        monitor.endAppInitiatedTransition(for: target, isConnected: true, now: tApp.addingTimeInterval(1.0))

        // Observation after suppression window sees state is already true -> no duplicate event
        XCTAssertNil(
            monitor.recordObservedState(address: target, isConnected: true, targetAddress: target, now: tApp.addingTimeInterval(5.0))
        )

        // Resetting state while an app transition is active preserves suppression for the in-flight operation
        let tReset = t0.addingTimeInterval(20)
        monitor.beginAppInitiatedTransition(for: target, now: tReset)
        monitor.resetState()
        monitor.seedState(for: target, isConnected: false)
        XCTAssertNil(
            monitor.recordObservedState(address: target, isConnected: true, targetAddress: target, now: tReset.addingTimeInterval(0.5))
        )
        monitor.endAppInitiatedTransition(for: target, isConnected: true, now: tReset.addingTimeInterval(1.0))

        // Invalidating pending connection HUD advances generation so delayed callback will not overwrite low-battery HUD
        let genBefore = monitor.currentGeneration(for: target)
        monitor.invalidatePendingConnectionHUD(for: target)
        XCTAssertNotEqual(monitor.currentGeneration(for: target), genBefore)
    }

    func testKeyComboFormattingValidationAndCodable() throws {
        let defaultCombo = KeyCombo.defaultToggle
        XCTAssertEqual(defaultCombo.displayString, "⌃⌥A")
        XCTAssertEqual(defaultCombo.menuKeyEquivalent, "a")
        XCTAssertEqual(defaultCombo.appKitModifierFlags, [.control, .option])
        XCTAssertTrue(defaultCombo.isValidShortcut)

        // Recording a valid Command + Shift + K shortcut
        let cmdShiftK = KeyCombo.from(keyCode: 40, modifierFlags: [.command, .shift]) // 40 = kVK_ANSI_K
        XCTAssertNotNil(cmdShiftK)
        XCTAssertEqual(cmdShiftK?.displayString, "⇧⌘K")
        XCTAssertEqual(cmdShiftK?.menuKeyEquivalent, "k")

        // Special keys map to AppKit control/function characters rather than display glyphs
        let ctrlReturn = KeyCombo.from(keyCode: 36, modifierFlags: [.control]) // 36 = kVK_Return
        XCTAssertEqual(ctrlReturn?.displayString, "⌃↩")
        XCTAssertEqual(ctrlReturn?.menuKeyEquivalent, "\r")

        let ctrlTab = KeyCombo.from(keyCode: 48, modifierFlags: [.control]) // 48 = kVK_Tab
        XCTAssertEqual(ctrlTab?.displayString, "⌃⇥")
        XCTAssertEqual(ctrlTab?.menuKeyEquivalent, "\t")

        let optLeftArrow = KeyCombo.from(keyCode: 123, modifierFlags: [.option]) // 123 = kVK_LeftArrow
        XCTAssertEqual(optLeftArrow?.displayString, "⌥←")
        XCTAssertEqual(optLeftArrow?.menuKeyEquivalent, String(UnicodeScalar(NSLeftArrowFunctionKey)!))

        let cmdF1 = KeyCombo.from(keyCode: 122, modifierFlags: [.command]) // 122 = kVK_F1
        XCTAssertEqual(cmdF1?.displayString, "⌘F1")
        XCTAssertEqual(cmdF1?.menuKeyEquivalent, String(UnicodeScalar(NSF1FunctionKey)!))

        // QWERTZ layout translator swaps physical ANSI-Z (keyCode 6) to 'Y'
        let qwertzTranslator: (UInt32) -> String? = { code in
            if code == 6 { return "y" } // kVK_ANSI_Z physical key produces 'y' on QWERTZ
            if code == 16 { return "z" } // kVK_ANSI_Y physical key produces 'z' on QWERTZ
            return nil
        }
        let physicalZCombo = KeyCombo.from(keyCode: 6, modifierFlags: [.control, .option])!
        XCTAssertEqual(physicalZCombo.displayString(layoutTranslator: qwertzTranslator), "⌃⌥Y")
        XCTAssertEqual(physicalZCombo.menuKeyEquivalent(layoutTranslator: qwertzTranslator), "y")

        // Rejects unmodified keys, Shift-only keys, and Escape
        XCTAssertNil(KeyCombo.from(keyCode: 0, modifierFlags: []))
        XCTAssertNil(KeyCombo.from(keyCode: 0, modifierFlags: [.shift]))
        XCTAssertNil(KeyCombo.from(keyCode: 53, modifierFlags: [.command])) // 53 = kVK_Escape

        // Codable round-trip
        let data = try JSONEncoder().encode(cmdShiftK)
        let decoded = try JSONDecoder().decode(KeyCombo.self, from: data)
        XCTAssertEqual(decoded, cmdShiftK)
    }

    @MainActor
    func testHotKeyServiceFallbackAndInactiveRecorderWindow() {
        let originalCombo = Preferences.shared.hotKeyCombo
        defer { Preferences.shared.hotKeyCombo = originalCombo }

        let customCombo = KeyCombo.from(keyCode: 40, modifierFlags: [.command, .shift])! // ⇧⌘K
        Preferences.shared.hotKeyCombo = customCombo

        // 1. Preferred shortcut fails registration, fallback (.defaultToggle) succeeds
        let fallbackService = HotKeyService { combo, _ in
            HotKeyService.RegistrationHandle(
                keyCombo: combo,
                isRegistered: combo == .defaultToggle,
                unregister: {}
            )
        }
        XCTAssertTrue(fallbackService.start(handler: {}))
        XCTAssertTrue(fallbackService.isActive)
        XCTAssertEqual(fallbackService.currentKeyCombo, .defaultToggle)

        // 2. Both preferred and fallback fail registration
        let failingService = HotKeyService { combo, _ in
            HotKeyService.RegistrationHandle(
                keyCombo: combo,
                isRegistered: false,
                unregister: {}
            )
        }
        XCTAssertFalse(failingService.start(handler: {}))
        XCTAssertFalse(failingService.isActive)

        // 3. Inactive recorder window ignores key events and leaves saved shortcut unchanged
        Preferences.shared.hotKeyCombo = .defaultToggle
        let handledWhenInactive = ShortcutRecorderWindowController.shared.handleKeyInput(
            keyCode: 40,
            modifiers: [.command, .shift],
            isKeyWindow: false
        )
        XCTAssertFalse(handledWhenInactive)
        XCTAssertEqual(Preferences.shared.hotKeyCombo, .defaultToggle)
    }

    func testGenerateChangelogScriptProducesCategorizedReleaseNotesAndChangelog() throws {
        let fm = FileManager.default
        let tempRepo = fm.temporaryDirectory.appendingPathComponent("AirSwitchChangelogTest-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tempRepo, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempRepo) }

        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let scriptPath = repoRoot.appendingPathComponent("scripts/generate-changelog.sh").path

        @discardableResult
        func run(_ args: [String], expectSuccess: Bool = true) throws -> Int32 {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            proc.arguments = args
            proc.currentDirectoryURL = tempRepo
            var env = ProcessInfo.processInfo.environment
            env["GIT_CONFIG_NOSYSTEM"] = "1"
            env["GIT_CONFIG_GLOBAL"] = "/dev/null"
            proc.environment = env
            proc.standardOutput = Pipe()
            proc.standardError = Pipe()
            try proc.run()
            proc.waitUntilExit()
            if expectSuccess {
                XCTAssertEqual(proc.terminationStatus, 0, "Command failed: \(args.joined(separator: " "))")
            }
            return proc.terminationStatus
        }

        try run(["git", "init", "-q"])
        try run(["git", "config", "user.email", "test@example.com"])
        try run(["git", "config", "user.name", "Test User"])
        try run(["git", "config", "commit.gpgsign", "false"])
        try run(["git", "config", "tag.gpgSign", "false"])
        try run(["git", "config", "core.hooksPath", "/dev/null"])

        try Data("v1\n".utf8).write(to: tempRepo.appendingPathComponent("file.txt"))
        try run(["git", "add", "file.txt"])
        try run(["git", "commit", "-q", "-m", "feat: initial release"])
        try run(["git", "tag", "v0.1.0"])

        try Data("v2\n".utf8).write(to: tempRepo.appendingPathComponent("file.txt"))
        try run(["git", "add", "file.txt"])
        try run(["git", "commit", "-q", "-m", "feat(onboarding): add first-launch window"])
        try run(["git", "tag", "v0.2.0-beta.1"])

        try Data("v3\n".utf8).write(to: tempRepo.appendingPathComponent("file.txt"))
        try run(["git", "add", "file.txt"])
        try run(["git", "commit", "-q", "-m", "fix(bluetooth): verify connection state"])
        try run(["git", "commit", "--allow-empty", "-q", "-m", "chore(release): v0.2.0"])
        try run(["git", "tag", "v0.2.0"])

        let releaseNotesURL = tempRepo.appendingPathComponent("build/RELEASE_NOTES.md")
        let changelogURL = tempRepo.appendingPathComponent("build/CHANGELOG.md")

        try run([
            "bash", scriptPath,
            "--tag", "v0.2.0",
            "--release-notes", releaseNotesURL.path,
            "--changelog", changelogURL.path,
            "--repo", "MatthieuD134/AirSwitch"
        ])

        let releaseNotes = try String(contentsOf: releaseNotesURL, encoding: .utf8)
        let changelog = try String(contentsOf: changelogURL, encoding: .utf8)

        // Stable release v0.2.0 compares against previous stable tag v0.1.0 (including v0.2.0-beta.1 commits)
        XCTAssertTrue(releaseNotes.contains("## v0.2.0"))
        XCTAssertTrue(releaseNotes.contains("### ✨ Features"))
        XCTAssertTrue(releaseNotes.contains("- **onboarding**: add first-launch window"))
        XCTAssertTrue(releaseNotes.contains("### 🐛 Bug Fixes"))
        XCTAssertTrue(releaseNotes.contains("- **bluetooth**: verify connection state"))
        XCTAssertFalse(releaseNotes.contains("chore(release): v0.2.0"))
        XCTAssertTrue(releaseNotes.contains("https://github.com/MatthieuD134/AirSwitch/compare/v0.1.0...v0.2.0"))

        // Cumulative CHANGELOG.md orders v0.2.0 before v0.2.0-beta.1 before v0.1.0
        let v020Range = try XCTUnwrap(changelog.range(of: "## v0.2.0 "))
        let v020BetaRange = try XCTUnwrap(changelog.range(of: "## v0.2.0-beta.1 "))
        let v010Range = try XCTUnwrap(changelog.range(of: "## v0.1.0 "))
        XCTAssertLessThan(v020Range.lowerBound, v020BetaRange.lowerBound)
        XCTAssertLessThan(v020BetaRange.lowerBound, v010Range.lowerBound)

        // Future tag at already-tagged HEAD uses v0.2.0 as baseline rather than repeating v0.2.0 changes
        let futureNotesURL = tempRepo.appendingPathComponent("build/FUTURE_NOTES.md")
        try run([
            "bash", scriptPath,
            "--tag", "v0.3.0",
            "--release-notes", futureNotesURL.path,
            "--repo", "MatthieuD134/AirSwitch"
        ])
        let futureNotes = try String(contentsOf: futureNotesURL, encoding: .utf8)
        XCTAssertTrue(futureNotes.contains("https://github.com/MatthieuD134/AirSwitch/compare/v0.2.0...v0.3.0"))
        XCTAssertTrue(futureNotes.contains("- Maintenance and version bump updates."))

        // Rejects tag containing shell metacharacters
        let badStatus = try run(["bash", scriptPath, "--tag", "v0.2.0;$(id)"], expectSuccess: false)
        XCTAssertNotEqual(badStatus, 0)
    }
}
