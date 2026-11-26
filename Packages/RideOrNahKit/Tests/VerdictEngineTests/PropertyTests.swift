import Foundation
import Testing

@testable import VerdictEngine

/// Seeded random inputs checked against properties every evaluation must keep.
struct PropertyTests {
    static let iterations = 500

    /// SplitMix64, so every run sees the same inputs.
    struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    static func randomFixture(_ rng: inout SeededGenerator) -> Fixture {
        var fixture = Fixture(positions: Bool.random(using: &rng) ? Fixture.radius : [.center])
        fixture.now = Fixture.at(Int.random(in: 5...20, using: &rng))
        fixture.fetchedAt = fixture.now.addingTimeInterval(-Double(Int.random(in: 0...6, using: &rng)) * 3600)
        // Pre-draw the weather so the closure is deterministic for repeated evaluations.
        var table: [String: HourConditions] = [:]
        let input = fixture.input
        for sample in input.samples {
            for hour in sample.hours where Fixture.hour(hour.start) >= 4 {
                var conditions = hour
                conditions.temperature = Double.random(in: -2...38, using: &rng)
                conditions.feelsLike = conditions.temperature! + Double.random(in: -3...5, using: &rng)
                conditions.humidity = Double.random(in: 0.2...1, using: &rng)
                conditions.windSpeed = Double.random(in: 0...16, using: &rng)
                conditions.windGust =
                    Bool.random(using: &rng) ? conditions.windSpeed! + Double.random(in: 0...10, using: &rng) : nil
                conditions.uvIndex = Double.random(in: 0...11, using: &rng)
                conditions.visibility = Double.random(in: 100...20_000, using: &rng)
                conditions.precipitationChance = Double.random(in: 0...1, using: &rng)
                conditions.precipitationIntensity =
                    Double.random(in: 0...1, using: &rng) < 0.7 ? 0 : Double.random(in: 0...4, using: &rng)
                if Double.random(in: 0...1, using: &rng) < 0.05 { conditions.hazards = .thunderstorm }
                table["\(sample.position)-\(hour.start.timeIntervalSince1970)"] = conditions
            }
        }
        let frozen = table
        fixture.weather = { hour, position in
            if let drawn = frozen["\(position)-\(hour.start.timeIntervalSince1970)"] { hour = drawn }
        }
        return fixture
    }

    /// Moves one limit outward or turns its factor off.
    static func loosened(_ limits: Limits, _ rng: inout SeededGenerator) -> Limits {
        var limits = limits
        func loosen(_ limit: inout ThresholdLimit, by step: Double, lowerIsWorse: Bool = false) {
            if Bool.random(using: &rng) {
                limit.isEnabled = false
            } else {
                let delta = lowerIsWorse ? -step : step
                limit.soft = limit.soft.map { $0 + delta }
                limit.hard = limit.hard.map { $0 + delta }
            }
        }
        switch Int.random(in: 0..<8, using: &rng) {
        case 0: limits.precipitation.isEnabled = false
        case 1: loosen(&limits.cold, by: 3, lowerIsWorse: true)
        case 2: loosen(&limits.heat, by: 3)
        case 3: loosen(&limits.wind, by: 3)
        case 4: loosen(&limits.gusts, by: 3)
        case 5: loosen(&limits.uv, by: 2)
        case 6: loosen(&limits.visibility, by: 300, lowerIsWorse: true)
        default: limits.wetRoads.isEnabled = false
        }
        return limits
    }

    @Test func looseningALimitNeverMakesAVerdictWorse() {
        var rng = SeededGenerator(state: 1)
        for _ in 0..<Self.iterations {
            var fixture = Self.randomFixture(&rng)
            let before = fixture.outlook.map(\.verdict)
            fixture.limits = Self.loosened(fixture.limits, &rng)
            let after = fixture.outlook.map(\.verdict)
            for (old, new) in zip(before, after) {
                if let oldRank = old?.rank, let newRank = new?.rank { #expect(newRank <= oldRank) }
            }
        }
    }

    @Test func addingASamplePointNeverMakesAVerdictBetter() {
        var rng = SeededGenerator(state: 2)
        for _ in 0..<Self.iterations {
            var fixture = Self.randomFixture(&rng)
            fixture.positions = [.center, .ring(.n, .outer)]
            let before = fixture.outlook.map(\.verdict)
            fixture.positions.append(.ring(.s, .outer))
            var weather = fixture.weather
            let stormy = Bool.random(using: &rng)
            weather = { [weather] hour, position in
                weather(&hour, position)
                if position == .ring(.s, .outer) && stormy { hour.precipitationChance = 0.95 }
            }
            fixture.weather = weather
            let after = fixture.outlook.map(\.verdict)
            for (old, new) in zip(before, after) {
                if let oldRank = old?.rank, let newRank = new?.rank { #expect(newRank >= oldRank) }
            }
        }
    }

    // Scenario: ride-verdict: Repeat evaluation
    @Test("Repeat evaluation")
    func repeatEvaluation() {
        var rng = SeededGenerator(state: 3)
        for _ in 0..<Self.iterations {
            let input = Self.randomFixture(&rng).input
            #expect(VerdictEngine.outlook(for: input) == VerdictEngine.outlook(for: input))
        }
    }
}
