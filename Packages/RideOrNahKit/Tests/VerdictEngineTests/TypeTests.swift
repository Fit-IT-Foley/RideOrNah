import Foundation
import Testing

@testable import VerdictEngine

struct TypeTests {
    @Test func verdictsRankRideMaybeNah() {
        #expect(Verdict.ride.rank! < Verdict.maybe.rank!)
        #expect(Verdict.maybe.rank! < Verdict.nah.rank!)
        #expect(Verdict.unknown.rank == nil)
        #expect(Severity.soft < Severity.hard)
    }

    @Test func combiningPutsNahFirstThenUnknown() {
        #expect(Verdict.combining([.ride, .maybe]) == .maybe)
        #expect(Verdict.combining([.ride, .unknown, .maybe]) == .unknown)
        #expect(Verdict.combining([.unknown, .nah]) == .nah)
        #expect(Verdict.combining([]) == .ride)
    }

    @Test func positionsSortCenterFirstThenClockwise() {
        let shuffled: [SamplePosition] = [.ring(.w, .outer), .center, .ring(.n, .outer), .ring(.n, .inner)]
        #expect(shuffled.sorted() == [.center, .ring(.n, .inner), .ring(.n, .outer), .ring(.w, .outer)])
    }

    @Test func inputsAndResultsRoundTripThroughCodable() throws {
        var fixture = Fixture(positions: Fixture.radius)
        fixture.alerts = [AlertInfo(name: "Heat Advisory", severity: .moderate, positions: [.center])]
        let input = fixture.input
        let decodedInput = try JSONDecoder().decode(EvaluationInput.self, from: JSONEncoder().encode(input))
        #expect(decodedInput == input)

        let outlook = VerdictEngine.outlook(for: input)
        let decodedOutlook = try JSONDecoder().decode([DayEvaluation].self, from: JSONEncoder().encode(outlook))
        #expect(decodedOutlook == outlook)
    }

    @Test func fixtureBuildsHourlySamples() {
        let input = Fixture(positions: Fixture.radius).input
        #expect(input.samples.count == 9)
        #expect(input.samples[0].hours.first?.start == Fixture.at(day: -1, 0))
        #expect(input.samples[0].hours.count == 9 * 24)
    }
}
