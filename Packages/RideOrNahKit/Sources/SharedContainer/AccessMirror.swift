import Foundation

/// Whether the rider had access when the app last checked, for widgets and the watch, which
/// can't ask StoreKit themselves in time.
public struct AccessMirror: Sendable, Codable, Equatable {
    public var isActive: Bool
    public var checkedAt: Date

    public init(isActive: Bool, checkedAt: Date) {
        self.isActive = isActive
        self.checkedAt = checkedAt
    }
}

extension SharedContainer {
    private var accessMirrorURL: URL { url.appending(path: "access.json") }

    /// The last mirror written, or nil if there's none (locked).
    public func readAccessMirror() -> AccessMirror? {
        guard let data = try? Data(contentsOf: accessMirrorURL) else { return nil }
        return try? JSONDecoder().decode(AccessMirror.self, from: data)
    }

    public func writeAccessMirror(_ mirror: AccessMirror) {
        guard let data = try? JSONEncoder().encode(mirror) else { return }
        try? data.write(to: accessMirrorURL, options: .atomic)
    }
}
