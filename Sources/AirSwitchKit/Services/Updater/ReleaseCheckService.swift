import Foundation

public struct ReleaseInfo: Equatable, Sendable {
    public let version: SemanticVersion
    public let tagName: String
    public let zipDownloadURL: URL
    public let htmlURL: URL
    public let body: String?

    public init(
        version: SemanticVersion,
        tagName: String,
        zipDownloadURL: URL,
        htmlURL: URL,
        body: String?
    ) {
        self.version = version
        self.tagName = tagName
        self.zipDownloadURL = zipDownloadURL
        self.htmlURL = htmlURL
        self.body = body
    }
}

public enum ReleaseCheckError: LocalizedError {
    case invalidVersionString(String)
    case invalidResponseStatus(Int)
    case insecureOrInvalidURL

    public var errorDescription: String? {
        switch self {
        case .invalidVersionString(let raw):
            return "Invalid version format: \(raw)"
        case .invalidResponseStatus(let code):
            return "GitHub Releases returned HTTP \(code)"
        case .insecureOrInvalidURL:
            return "Release download URL is invalid or insecure"
        }
    }
}

@MainActor
public final class ReleaseCheckService {
    public static let shared = ReleaseCheckService()

    private struct GitHubReleasePayload: Decodable {
        struct Asset: Decodable {
            let name: String
            let browserDownloadUrl: String

            enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadUrl = "browser_download_url"
            }
        }

        let tagName: String
        let htmlUrl: String
        let draft: Bool?
        let prerelease: Bool?
        let body: String?
        let assets: [Asset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlUrl = "html_url"
            case draft
            case prerelease
            case body
            case assets
        }
    }

    public private(set) var availableUpdate: ReleaseInfo?
    private var pendingCompletions: [@MainActor (Result<ReleaseInfo?, Error>) -> Void] = []

    private init() {}

    public nonisolated static func shouldPerformAutomaticCheck(
        lastCheckTimestamp: TimeInterval,
        now: TimeInterval = Date().timeIntervalSince1970,
        interval: TimeInterval = AppConstants.updateCheckInterval
    ) -> Bool {
        guard lastCheckTimestamp > 0 else { return true }
        return (now - lastCheckTimestamp) >= interval
    }

    public nonisolated static func isTrustedGitHubRepositoryURL(
        _ url: URL,
        repository: String = AppConstants.githubRepository
    ) -> Bool {
        guard url.scheme?.lowercased() == "https",
              url.host?.lowercased() == "github.com" else {
            return false
        }
        let expectedPrefix = "/\(repository.lowercased())/"
        return url.path.lowercased().hasPrefix(expectedPrefix)
    }

    public nonisolated static func evaluateReleasePayload(
        _ data: Data,
        currentVersion: SemanticVersion,
        repository: String = AppConstants.githubRepository
    ) throws -> ReleaseInfo? {
        let payload = try JSONDecoder().decode(GitHubReleasePayload.self, from: data)
        if payload.draft == true || payload.prerelease == true {
            return nil
        }

        guard let remoteVersion = SemanticVersion(parsing: payload.tagName) else {
            throw ReleaseCheckError.invalidVersionString(payload.tagName)
        }

        guard remoteVersion > currentVersion else {
            return nil
        }

        guard let htmlURL = URL(string: payload.htmlUrl),
              isTrustedGitHubRepositoryURL(htmlURL, repository: repository) else {
            throw ReleaseCheckError.insecureOrInvalidURL
        }

        let preferredAsset = payload.assets.first(where: { $0.name == "AirSwitch.app.zip" })
            ?? payload.assets.first(where: { $0.name.lowercased().hasSuffix(".zip") })

        guard let assetURLString = preferredAsset?.browserDownloadUrl,
              let zipURL = URL(string: assetURLString),
              isTrustedGitHubRepositoryURL(zipURL, repository: repository) else {
            throw ReleaseCheckError.insecureOrInvalidURL
        }

        return ReleaseInfo(
            version: remoteVersion,
            tagName: payload.tagName,
            zipDownloadURL: zipURL,
            htmlURL: htmlURL,
            body: payload.body
        )
    }

    public nonisolated static func evaluateRedirectedReleaseURL(
        _ finalURL: URL,
        currentVersion: SemanticVersion,
        repository: String = AppConstants.githubRepository
    ) throws -> ReleaseInfo? {
        guard isTrustedGitHubRepositoryURL(finalURL, repository: repository) else {
            throw ReleaseCheckError.insecureOrInvalidURL
        }

        let marker = "/releases/tag/"
        guard let range = finalURL.path.range(of: marker, options: [.caseInsensitive]) else {
            throw ReleaseCheckError.insecureOrInvalidURL
        }

        let tagName = String(finalURL.path[range.upperBound...]).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !tagName.isEmpty, !tagName.contains("/") else {
            throw ReleaseCheckError.insecureOrInvalidURL
        }

        guard let remoteVersion = SemanticVersion(parsing: tagName) else {
            throw ReleaseCheckError.invalidVersionString(tagName)
        }

        guard remoteVersion > currentVersion else {
            return nil
        }

        guard let encodedTag = tagName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let zipURL = URL(string: "https://github.com/\(repository)/releases/download/\(encodedTag)/AirSwitch.app.zip"),
              isTrustedGitHubRepositoryURL(zipURL, repository: repository) else {
            throw ReleaseCheckError.insecureOrInvalidURL
        }

        return ReleaseInfo(
            version: remoteVersion,
            tagName: tagName,
            zipDownloadURL: zipURL,
            htmlURL: finalURL,
            body: nil
        )
    }

    public func checkInBackgroundIfNeeded() {
        let now = Date().timeIntervalSince1970
        guard Self.shouldPerformAutomaticCheck(
            lastCheckTimestamp: Preferences.shared.lastUpdateCheckTimestamp,
            now: now
        ) else {
            return
        }

        // Record attempt immediately so transient failures or rate limits do not retry on every 5s poll
        Preferences.shared.lastUpdateCheckTimestamp = now

        checkForUpdates { result in
            if case .success(let update) = result, let update {
                NSLog("[AirSwitch] Update available: \(update.tagName)")
                HUDWindowController.shared.show(
                    title: "AirSwitch \(update.tagName)",
                    subtitle: "Update available in menu",
                    connected: true,
                    battery: nil
                )
            }
        }
    }

    public func checkForUpdates(
        completion: @escaping @MainActor (Result<ReleaseInfo?, Error>) -> Void
    ) {
        guard let currentVersion = SemanticVersion(parsing: AppConstants.version) else {
            completion(.failure(ReleaseCheckError.invalidVersionString(AppConstants.version)))
            return
        }
        guard let endpoint = URL(string: "https://api.github.com/repos/\(AppConstants.githubRepository)/releases/latest") else {
            return
        }

        pendingCompletions.append(completion)
        guard pendingCompletions.count == 1 else {
            return // Attach to in-flight check
        }

        var request = URLRequest(url: endpoint)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("\(AppConstants.appName)/\(AppConstants.version)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if let error {
                    self.checkViaRedirectFallback(currentVersion: currentVersion, primaryError: error)
                    return
                }

                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    self.checkViaRedirectFallback(
                        currentVersion: currentVersion,
                        primaryError: ReleaseCheckError.invalidResponseStatus(http.statusCode)
                    )
                    return
                }

                let result: Result<ReleaseInfo?, Error>
                if let data {
                    do {
                        let update = try Self.evaluateReleasePayload(data, currentVersion: currentVersion)
                        Preferences.shared.lastUpdateCheckTimestamp = Date().timeIntervalSince1970
                        self.availableUpdate = update
                        result = .success(update)
                    } catch {
                        result = .failure(error)
                    }
                } else {
                    result = .success(nil)
                }

                self.completePendingChecks(with: result)
            }
        }.resume()
    }

    private func checkViaRedirectFallback(
        currentVersion: SemanticVersion,
        primaryError: Error
    ) {
        guard let fallbackURL = URL(string: "https://github.com/\(AppConstants.githubRepository)/releases/latest") else {
            completePendingChecks(with: .failure(primaryError))
            return
        }

        var request = URLRequest(url: fallbackURL)
        request.httpMethod = "HEAD"
        request.setValue("\(AppConstants.appName)/\(AppConstants.version)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                let result: Result<ReleaseInfo?, Error>
                if error != nil {
                    result = .failure(primaryError)
                } else if let http = response as? HTTPURLResponse,
                          (200...299).contains(http.statusCode),
                          let finalURL = http.url {
                    do {
                        let update = try Self.evaluateRedirectedReleaseURL(finalURL, currentVersion: currentVersion)
                        Preferences.shared.lastUpdateCheckTimestamp = Date().timeIntervalSince1970
                        self.availableUpdate = update
                        result = .success(update)
                    } catch {
                        result = .failure(primaryError)
                    }
                } else {
                    result = .failure(primaryError)
                }

                self.completePendingChecks(with: result)
            }
        }.resume()
    }

    private func completePendingChecks(with result: Result<ReleaseInfo?, Error>) {
        let callbacks = pendingCompletions
        pendingCompletions.removeAll()
        for callback in callbacks {
            callback(result)
        }
    }
}
