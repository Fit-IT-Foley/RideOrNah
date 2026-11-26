import Foundation
import SharedContainer

/// One point's forecast and when it was fetched.
public struct CachedForecast: Sendable, Codable, Equatable {
    public var fetchedAt: Date
    public var forecast: PointForecast
}

/// Forecasts on disk, one JSON file per rounded point, in the app group's Caches directory so the
/// app and its extensions share them and they're never backed up. Each file carries its own
/// `fetchedAt`, so no file-timestamp APIs are needed.
public actor ForecastCache {
    /// Entries older than this are deleted.
    public static let retention: TimeInterval = 48 * 3600

    public nonisolated let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// `Library/Caches/Forecasts` inside the shared container.
    public init(container: SharedContainer) {
        self.init(
            directory: container.url.appending(path: "Library/Caches/Forecasts", directoryHint: .isDirectory))
    }

    public func read(_ coordinate: RoundedCoordinate) -> CachedForecast? {
        guard let data = try? Data(contentsOf: fileURL(for: coordinate)) else { return nil }
        return try? JSONDecoder().decode(CachedForecast.self, from: data)
    }

    public func write(_ entry: CachedForecast, for coordinate: RoundedCoordinate) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(entry) else { return }
        try? data.write(to: fileURL(for: coordinate), options: .atomic)
    }

    /// Deletes every entry fetched more than 48 hours before `now`, and unreadable files.
    public func purge(now: Date) {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.pathExtension == "json" {
            let entry = (try? Data(contentsOf: file)).flatMap {
                try? JSONDecoder().decode(CachedForecast.self, from: $0)
            }
            if entry.map({ now.timeIntervalSince($0.fetchedAt) > Self.retention }) ?? true {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    func fileURL(for coordinate: RoundedCoordinate) -> URL {
        directory.appending(path: "\(coordinate.key).json")
    }
}
