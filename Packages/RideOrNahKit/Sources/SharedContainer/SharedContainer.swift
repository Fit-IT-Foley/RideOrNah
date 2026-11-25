import Foundation

/// Where the app and its extensions keep data they share, such as cached forecasts.
///
/// Normally this is the app-group container. When the group isn't available (unit tests,
/// SwiftUI previews, a simulator build without the entitlement) it falls back to a
/// temporary directory unique to the process, so callers can always read and write.
public struct SharedContainer: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case appGroup
        case temporary
    }

    /// Info.plist key holding the app-group identifier, set from `APP_GROUP_IDENTIFIER`.
    public static let infoPlistKey = "RideOrNahAppGroup"

    public let url: URL
    public let kind: Kind

    /// The shared container for the running app or extension.
    public static func current(bundle: Bundle = .main) -> SharedContainer {
        resolve(groupIdentifier: bundle.object(forInfoDictionaryKey: infoPlistKey) as? String)
    }

    /// Resolves the container for `groupIdentifier`. `lookup` is injectable for tests.
    public static func resolve(
        groupIdentifier: String?,
        lookup: (String) -> URL? = {
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0)
        }
    ) -> SharedContainer {
        if let groupIdentifier, !groupIdentifier.isEmpty, let url = lookup(groupIdentifier) {
            return SharedContainer(url: url, kind: .appGroup)
        }
        return SharedContainer(url: fallbackURL(), kind: .temporary)
    }

    private static func fallbackURL() -> URL {
        let pid = ProcessInfo.processInfo.processIdentifier
        let url = FileManager.default.temporaryDirectory
            .appending(path: "RideOrNah-\(pid)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
