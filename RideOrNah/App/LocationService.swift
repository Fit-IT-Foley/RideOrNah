import CoreLocation
import MapKit
import RiderSettings
import WeatherData

enum LocationAuthorization {
    case notDetermined, granted, denied
}

/// Current location for the app. Only When-In-Use permission is ever requested, and accuracy is
/// approximate by default (`NSLocationDefaultAccuracyReduced`).
protocol LocationProviding: AnyObject {
    var authorization: LocationAuthorization { get }
    /// Shows the system prompt if needed; true when permission is granted.
    func requestPermission() async -> Bool
    func currentReading() async -> LocationReading?
}

final class LocationService: NSObject, LocationProviding, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var permissionContinuation: CheckedContinuation<Bool, Never>?
    private var readingContinuation: CheckedContinuation<LocationReading?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var authorization: LocationAuthorization {
        switch manager.authorizationStatus {
        case .notDetermined: .notDetermined
        case .authorizedWhenInUse, .authorizedAlways: .granted
        default: .denied
        }
    }

    func requestPermission() async -> Bool {
        guard authorization == .notDetermined else { return authorization == .granted }
        return await withCheckedContinuation { continuation in
            permissionContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    func currentReading() async -> LocationReading? {
        guard authorization == .granted else { return nil }
        return await withCheckedContinuation { continuation in
            readingContinuation = continuation
            manager.requestLocation()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard status != .notDetermined, let continuation = self.permissionContinuation else { return }
            self.permissionContinuation = nil
            continuation.resume(returning: status == .authorizedWhenInUse || status == .authorizedAlways)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let reading = LocationReading(
            coordinate: GeoCoordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude),
            isApproximate: manager.accuracyAuthorization == .reducedAccuracy)
        Task { @MainActor in
            self.readingContinuation?.resume(returning: reading)
            self.readingContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        Task { @MainActor in
            self.readingContinuation?.resume(returning: nil)
            self.readingContinuation = nil
        }
    }
}

struct PlaceResult: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var subtitle: String
    var coordinate: GeoCoordinate
}

/// Looks up places by name. Search text goes to Apple Maps.
protocol PlaceSearching {
    func search(_ query: String) async -> [PlaceResult]
}

struct MapPlaceSearch: PlaceSearching {
    func search(_ query: String) async -> [PlaceResult] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        guard let response = try? await MKLocalSearch(request: request).start() else { return [] }
        return response.mapItems.prefix(8).map { item in
            let coordinate = item.location.coordinate
            return PlaceResult(
                name: item.name ?? query, subtitle: item.address?.shortAddress ?? "",
                coordinate: GeoCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude))
        }
    }
}

#if DEBUG
    /// For UI tests: answers the permission prompt without the system dialog.
    final class StubLocationService: LocationProviding {
        let grants: Bool
        private(set) var authorization: LocationAuthorization
        init(grants: Bool) {
            self.grants = grants
            authorization = grants ? .granted : .notDetermined
        }
        func requestPermission() async -> Bool {
            authorization = grants ? .granted : .denied
            return grants
        }
        func currentReading() async -> LocationReading? {
            authorization == .granted
                ? LocationReading(coordinate: GeoCoordinate(latitude: 40.7128, longitude: -74.006), isApproximate: true)
                : nil
        }
    }

    /// For UI tests: canned search results, no Apple Maps request.
    struct StubPlaceSearch: PlaceSearching {
        func search(_ query: String) async -> [PlaceResult] {
            [
                PlaceResult(
                    name: "\(query) Street", subtitle: "Brooklyn, NY",
                    coordinate: GeoCoordinate(latitude: 40.6782, longitude: -73.9442))
            ]
        }
    }
#endif
