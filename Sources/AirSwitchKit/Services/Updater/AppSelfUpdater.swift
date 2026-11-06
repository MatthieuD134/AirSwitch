import AppKit
import Foundation

public enum AppSelfUpdateError: LocalizedError, Equatable {
    case downloadFailed(String)
    case extractionFailed(Int32)
    case invalidBundleStructure
    case bundleIdentifierMismatch(String?)
    case codeSignatureInvalid(Int32)
    case replacementFailed(String)

    public var errorDescription: String? {
        switch self {
        case .downloadFailed(let reason):
            return "Update download failed: \(reason)"
        case .extractionFailed(let code):
            return "Failed to extract update archive (exit \(code))"
        case .invalidBundleStructure:
            return "Extracted archive does not contain a valid AirSwitch.app bundle"
        case .bundleIdentifierMismatch(let found):
            return "Bundle identifier mismatch (\(found ?? "none"))"
        case .codeSignatureInvalid(let code):
            return "Extracted application failed code signature verification (exit \(code))"
        case .replacementFailed(let reason):
            return "Could not replace app bundle: \(reason)"
        }
    }
}

@MainActor
public final class AppSelfUpdater {
    public static let shared = AppSelfUpdater()
    public private(set) var isInstalling = false

    private init() {}

    public nonisolated static func canInstallInPlace(bundleURL: URL = Bundle.main.bundleURL) -> Bool {
        guard bundleURL.pathExtension.lowercased() == "app" else {
            return false
        }
        let parentDir = bundleURL.deletingLastPathComponent().path
        return FileManager.default.isWritableFile(atPath: parentDir)
    }

    public nonisolated static func validateExtractedBundle(
        at appURL: URL,
        expectedBundleID: String = AppConstants.bundleIdentifier,
        verifySignature: Bool = true
    ) throws {
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        let infoPlistURL = contentsURL.appendingPathComponent("Info.plist", isDirectory: false)

        guard let plistData = try? Data(contentsOf: infoPlistURL),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            throw AppSelfUpdateError.invalidBundleStructure
        }

        let bundleID = plist["CFBundleIdentifier"] as? String
        guard bundleID == expectedBundleID else {
            throw AppSelfUpdateError.bundleIdentifierMismatch(bundleID)
        }

        guard let executableName = plist["CFBundleExecutable"] as? String,
              !executableName.isEmpty,
              !executableName.contains("/"),
              !executableName.contains("..") else {
            throw AppSelfUpdateError.invalidBundleStructure
        }

        let executableURL = contentsURL
            .appendingPathComponent("MacOS", isDirectory: true)
            .appendingPathComponent(executableName, isDirectory: false)

        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw AppSelfUpdateError.invalidBundleStructure
        }

        if verifySignature {
            let codesign = Process()
            codesign.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
            codesign.arguments = ["--verify", "--deep", "--strict", appURL.path]
            try codesign.run()
            codesign.waitUntilExit()
            guard codesign.terminationStatus == 0 else {
                throw AppSelfUpdateError.codeSignatureInvalid(codesign.terminationStatus)
            }
        }
    }

    public func install(_ release: ReleaseInfo) {
        guard !isInstalling else { return }

        let targetBundleURL = Bundle.main.bundleURL
        guard Self.canInstallInPlace(bundleURL: targetBundleURL) else {
            NSWorkspace.shared.open(release.htmlURL)
            return
        }

        isInstalling = true
        HUDWindowController.shared.show(
            title: "\(AppConstants.appName) \(release.tagName)",
            subtitle: L10n.installUpdate(release.tagName),
            connected: true,
            battery: nil
        )

        URLSession.shared.downloadTask(with: release.zipDownloadURL) { [weak self] tempZipURL, response, error in
            if let error {
                Task { @MainActor [weak self] in
                    self?.finishWithFailure(error.localizedDescription)
                }
                return
            }

            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                Task { @MainActor [weak self] in
                    self?.finishWithFailure("HTTP \(http.statusCode)")
                }
                return
            }

            guard let tempZipURL else {
                Task { @MainActor [weak self] in
                    self?.finishWithFailure("Missing archive")
                }
                return
            }

            do {
                let stagedContext = try Self.performStagedReplacement(fromZip: tempZipURL, targetBundleURL: targetBundleURL)
                Task { @MainActor [weak self] in
                    self?.relaunchApplication(
                        at: targetBundleURL,
                        backupURL: stagedContext.backupURL,
                        stagingDir: stagedContext.stagingDir
                    )
                }
            } catch {
                Task { @MainActor [weak self] in
                    self?.finishWithFailure(error.localizedDescription)
                }
            }
        }.resume()
    }

    private nonisolated static func performStagedReplacement(
        fromZip zipURL: URL,
        targetBundleURL: URL
    ) throws -> (backupURL: URL, stagingDir: URL) {
        let fm = FileManager.default
        let stagingDir = fm.temporaryDirectory.appendingPathComponent("AirSwitchUpdate-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: stagingDir, withIntermediateDirectories: true)

        do {
            let ditto = Process()
            ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            ditto.arguments = ["-x", "-k", zipURL.path, stagingDir.path]
            try ditto.run()
            ditto.waitUntilExit()
            guard ditto.terminationStatus == 0 else {
                throw AppSelfUpdateError.extractionFailed(ditto.terminationStatus)
            }

            let stagedAppURL = stagingDir.appendingPathComponent("\(AppConstants.appName).app", isDirectory: true)
            stripQuarantineAttribute(at: stagedAppURL)
            try validateExtractedBundle(at: stagedAppURL)

            let backupURL = stagingDir.appendingPathComponent("Backup-\(AppConstants.appName).app", isDirectory: true)
            try fm.copyItem(at: targetBundleURL, to: backupURL)

            do {
                _ = try fm.replaceItemAt(targetBundleURL, withItemAt: stagedAppURL)
            } catch {
                throw AppSelfUpdateError.replacementFailed(error.localizedDescription)
            }

            return (backupURL: backupURL, stagingDir: stagingDir)
        } catch {
            try? fm.removeItem(at: stagingDir)
            throw error
        }
    }

    public nonisolated static func stripQuarantineAttribute(at url: URL) {
        let xattr = Process()
        xattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        xattr.arguments = ["-dr", "com.apple.quarantine", url.path]
        xattr.standardOutput = Pipe()
        xattr.standardError = Pipe()
        do {
            try xattr.run()
            xattr.waitUntilExit()
        } catch {
            // Best-effort cleanup
        }
    }

    private func relaunchApplication(at bundleURL: URL, backupURL: URL, stagingDir: URL) {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: config) { [weak self] runningApp, error in
            Task { @MainActor [weak self] in
                defer { try? FileManager.default.removeItem(at: stagingDir) }

                if runningApp != nil && error == nil {
                    NSApplication.shared.terminate(nil)
                } else {
                    try? _ = FileManager.default.replaceItemAt(bundleURL, withItemAt: backupURL)
                    self?.finishWithFailure(error?.localizedDescription ?? "Failed to launch updated application")
                }
            }
        }
    }

    private func finishWithFailure(_ message: String) {
        isInstalling = false
        NSLog("[AirSwitch] Self-update failed: \(message)")
        HUDWindowController.shared.show(
            title: AppConstants.appName,
            subtitle: L10n.updateFailed,
            connected: false,
            battery: nil
        )
    }
}
