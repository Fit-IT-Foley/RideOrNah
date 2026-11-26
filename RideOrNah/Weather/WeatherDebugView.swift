#if DEBUG
    import SharedContainer
    import SwiftUI
    import VerdictEngine
    import WeatherData

    /// Debug-only: runs the weather pipeline end to end until the Today screen replaces it.
    /// Launch with `-openWeatherDebug YES -weatherSource fixture -weatherScenario stormToTheNorth`
    /// to open it on a fixture and evaluate straight away.
    struct WeatherDebugView: View {
        enum Source: Hashable {
            case live
            case fixture(FixtureProvider.Scenario)

            var title: String {
                switch self {
                case .live: "Live (WeatherKit)"
                case .fixture(let scenario): "Fixture: \(scenario.rawValue)"
                }
            }
        }

        struct Run {
            var snapshot: ForecastSnapshot
            var evaluation: RangeEvaluation?
            var now: Date
        }

        static let radiusOptions: [Double] = [0, 16, 40, 80, 160]
        /// Close to the defaults new profiles will get.
        static let profile = ProfileSnapshot(
            limits: Limits(
                precipitation: PrecipitationLimit(
                    chance: ThresholdLimit(soft: 0.3, hard: 0.6), intensity: ThresholdLimit(soft: 0.1, hard: 1)),
                cold: ThresholdLimit(soft: 10, hard: 4.4), heat: ThresholdLimit(soft: 32, hard: 37.8),
                wind: ThresholdLimit(soft: 8.9, hard: 13.4), gusts: ThresholdLimit(soft: 13.4, hard: 17.9),
                uv: ThresholdLimit(soft: 8), visibility: ThresholdLimit(soft: 1609, hard: 400),
                wetRoads: WetRoadsLimit(duration: 2 * 3600), ice: IceLimit(threshold: 3), alertsEnabled: true),
            windows: [])

        @State private var latitude = "40.7128"
        @State private var longitude = "-74.0060"
        @State private var radiusKilometres = 40.0
        @State private var source: Source
        @State private var run: Run?
        @State private var isRunning = false

        init() {
            let defaults = UserDefaults.standard
            let scenario = defaults.string(forKey: "weatherScenario").flatMap(FixtureProvider.Scenario.init(rawValue:))
            _source = State(
                initialValue: defaults.string(forKey: "weatherSource") == "live"
                    ? .live : .fixture(scenario ?? .clearDay))
        }

        var body: some View {
            NavigationStack {
                Form {
                    Section("Inputs") {
                        TextField("Latitude", text: $latitude).keyboardType(.numbersAndPunctuation)
                        TextField("Longitude", text: $longitude).keyboardType(.numbersAndPunctuation)
                        Picker("Radius", selection: $radiusKilometres) {
                            ForEach(Self.radiusOptions, id: \.self) { km in
                                Text(km == 0 ? "Local" : "\(Int(km)) km").tag(km)
                            }
                        }
                        Picker("Source", selection: $source) {
                            Text(Source.live.title).tag(Source.live)
                            ForEach(FixtureProvider.Scenario.allCases, id: \.self) { scenario in
                                Text(Source.fixture(scenario).title).tag(Source.fixture(scenario))
                            }
                        }
                        Button(isRunning ? "Evaluating…" : "Evaluate") { Task { await evaluate() } }
                            .disabled(isRunning)
                            .accessibilityIdentifier("weatherDebug.evaluate")
                    }
                    if let run { results(run) }
                    Section {
                        WeatherAttributionView(info: .fixture)
                    }
                }
                .navigationTitle("Weather pipeline")
            }
            .accessibilityIdentifier("weatherDebug.screen")
            .task {
                if UserDefaults.standard.bool(forKey: "openWeatherDebug") { await evaluate() }
            }
        }

        @ViewBuilder func results(_ run: Run) -> some View {
            Section("Result") {
                Text("Network requests: \(run.snapshot.networkRequests)")
                    .accessibilityIdentifier("weatherDebug.requests")
                Text("Outcome: \(String(describing: run.snapshot.outcome))")
                Text(freshness(run))
                Text("Next 12 hours: \(run.evaluation?.verdict.rawValue ?? "no forecast")")
                    .accessibilityIdentifier("weatherDebug.verdict")
            }
            Section("Breaches, next 12 hours") {
                ForEach(Array((run.evaluation?.breaches ?? []).enumerated()), id: \.offset) { _, breach in
                    Text(describe(breach)).accessibilityIdentifier("weatherDebug.breach")
                }
            }
        }

        func describe(_ breach: Breach) -> String {
            let places = breach.positions.map { position in
                position.direction.map { String(describing: $0).uppercased() } ?? "here"
            }
            var unique: [String] = []
            for place in places where !unique.contains(place) { unique.append(place) }
            return
                "\(breach.factor.rawValue), \(breach.severity == .hard ? "hard" : "soft"), \(unique.joined(separator: " "))"
        }

        func freshness(_ run: Run) -> String {
            guard let fetchedAt = run.snapshot.fetchedAt else { return "No forecast" }
            return "Fetched \(Int(run.now.timeIntervalSince(fetchedAt) / 60)) min ago"
        }

        func evaluate() async {
            isRunning = true
            defer { isRunning = false }
            let calendar = Calendar.current
            let center = GeoCoordinate(latitude: Double(latitude) ?? 40.7128, longitude: Double(longitude) ?? -74.006)
            let store: ForecastStore
            switch source {
            case .live:
                let group = Bundle.main.object(forInfoDictionaryKey: SharedContainer.infoPlistKey) as? String
                store = ForecastStore(
                    provider: WeatherKitProvider(), cache: ForecastCache(container: .current()),
                    budget: RequestBudget(suiteName: group), calendar: calendar)
            case .fixture(let scenario):
                // A fresh cache each run, so fixtures never mix with live data.
                let directory = FileManager.default.temporaryDirectory.appending(
                    path: "FixtureForecasts-\(UUID().uuidString)")
                store = ForecastStore(
                    provider: FixtureProvider(scenario: scenario, center: center, calendar: calendar),
                    cache: ForecastCache(directory: directory), budget: nil, calendar: calendar)
            }
            let snapshot = await store.snapshot(center: center, radius: radiusKilometres * 1000, purpose: .manual)
            let now = Date()
            let start = calendar.dateInterval(of: .hour, for: now)?.start ?? now
            let evaluation = snapshot.evaluationInput(profile: Self.profile, now: now, calendar: calendar).map {
                VerdictEngine.evaluate(range: DateInterval(start: start, duration: 12 * 3600), in: $0)
            }
            run = Run(snapshot: snapshot, evaluation: evaluation, now: now)
        }
    }

    #Preview {
        WeatherDebugView()
    }
#endif
