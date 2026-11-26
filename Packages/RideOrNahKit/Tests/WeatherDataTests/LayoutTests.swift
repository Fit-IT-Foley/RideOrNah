import Foundation
import Testing
import VerdictEngine

@testable import WeatherData

struct LayoutTests {
    static func ringDistancesAreWithinOnePercent(_ points: [SamplePoint], ring: SamplePosition.Ring, of radius: Double)
        -> Bool
    {
        points.filter { if case .ring(_, ring) = $0.position { true } else { false } }
            .allSatisfy { abs($0.exact.distance(to: TestTime.newYork) - radius) <= radius * 0.01 }
    }

    // Scenario: weather-data: Default radius
    @Test("Default radius")
    func defaultRadius() {
        let points = SampleLayout.points(center: TestTime.newYork, radius: 40_000)
        #expect(points.count == 9)
        #expect(points.map(\.position) == [.center] + CompassDirection.allCases.map { .ring($0, .outer) })
        #expect(Self.ringDistancesAreWithinOnePercent(points, ring: .outer, of: 40_000))
    }

    // Scenario: weather-data: Large radius
    @Test("Large radius")
    func largeRadius() {
        let points = SampleLayout.points(center: TestTime.newYork, radius: 160_000)
        #expect(points.count == 17)
        #expect(Self.ringDistancesAreWithinOnePercent(points, ring: .inner, of: 80_000))
        #expect(Self.ringDistancesAreWithinOnePercent(points, ring: .outer, of: 160_000))
    }

    @Test func innerRingStartsAt80Kilometres() {
        #expect(SampleLayout.points(center: TestTime.newYork, radius: 80_000).count == 17)
        #expect(SampleLayout.points(center: TestTime.newYork, radius: 79_999).count == 9)
    }

    // Scenario: weather-data: Local radius
    @Test("Local radius")
    func localRadius() {
        #expect(SampleLayout.points(center: TestTime.newYork, radius: 0).map(\.position) == [.center])
    }

    // Scenario: weather-data: Rounded request
    @Test("Rounded request")
    func roundedRequest() {
        let center = SampleLayout.points(center: TestTime.newYork, radius: 0)[0].coordinate
        #expect(center.latitude == 40.71)
        #expect(center.longitude == -74.01)
        #expect(center.key == "40.71_-74.01")
    }

    @Test func northPointIsDueNorth() {
        let north = SampleLayout.points(center: TestTime.newYork, radius: 40_000)[1]
        #expect(north.position == .ring(.n, .outer))
        #expect(north.exact.latitude > TestTime.newYork.latitude)
        #expect(abs(north.exact.longitude - TestTime.newYork.longitude) < 1e-9)
    }
}
