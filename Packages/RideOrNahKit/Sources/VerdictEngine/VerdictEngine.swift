import Foundation

/// Turns forecasts, a profile and the current time into verdicts. Pure and synchronous: the same
/// input always produces the same output.
public enum VerdictEngine {
    /// Today and the next six days.
    public static func outlook(for input: EvaluationInput) -> [DayEvaluation] {
        Evaluator(input).outlook()
    }

    /// Any time range in the outlook, such as a ride added to the calendar, judged like a ride window.
    public static func evaluate(range: DateInterval, in input: EvaluationInput) -> RangeEvaluation {
        Evaluator(input).evaluate(range: range)
    }
}

/// Findings for a set of hours across every sample point.
struct HoursResult {
    var findings: [Finding] = []
    /// Hour and position pairs with no data (or no core values).
    var missing: Set<HourPosition> = []
    var notChecked: Set<Factor> = []
    var partiallyChecked: Set<Factor> = []

    func lacksData(at position: SamplePosition, in hours: [Date]) -> Bool {
        hours.contains { missing.contains(HourPosition(hour: $0, position: position)) }
    }

    /// Nah on any hard finding, then Unknown if any position lacks data, then Maybe or Ride.
    func verdict(for positions: [SamplePosition], hours: [Date]) -> Verdict {
        let relevant = findings.filter { positions.contains($0.position) }
        if relevant.contains(where: { $0.severity == .hard }) { return .nah }
        if positions.contains(where: { lacksData(at: $0, in: hours) }) { return .unknown }
        return relevant.isEmpty ? .ride : .maybe
    }
}

struct HourPosition: Hashable {
    var hour: Date
    var position: SamplePosition
}

struct Evaluator {
    let input: EvaluationInput
    let calendar: Calendar
    let rules: FactorRules
    let hoursByPosition: [SamplePosition: [Date: HourConditions]]
    /// Every sample point, sorted, including ones whose request failed.
    let positions: [SamplePosition]
    let startOfToday: Date

    init(_ input: EvaluationInput) {
        self.input = input
        calendar = input.calendar
        rules = FactorRules(limits: input.profile.limits)
        var index: [SamplePosition: [Date: HourConditions]] = [:]
        for sample in input.samples {
            var hours = index[sample.position] ?? [:]
            for hour in sample.hours { hours[hour.start] = hour }
            index[sample.position] = hours
        }
        hoursByPosition = index
        positions = index.keys.sorted()
        startOfToday = input.calendar.startOfDay(for: input.now)
    }

    // MARK: Outlook

    func outlook() -> [DayEvaluation] {
        (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startOfToday).map { evaluateDay($0, offset: offset) }
        }
    }

    func evaluateDay(_ day: Date, offset: Int) -> DayEvaluation {
        let isToday = offset == 0
        let freshness = freshness(isToday: isToday)
        var evaluation = DayEvaluation(
            day: day, status: .evaluated, verdict: nil, unknownReason: nil, hasNoScheduledWindow: false,
            windows: [], breaches: [], directions: nil, clearDirections: [], coverage: .full,
            freshness: freshness, confidence: offset >= 3 ? .lower : .normal, opportunities: [],
            notChecked: [], partiallyChecked: [])

        let weekday = calendar.component(.weekday, from: day)
        let windowIntervals = input.profile.windows
            .filter { $0.weekdays.contains(weekday) }
            .compactMap { interval(of: $0, on: day) }
            .sorted { $0.start < $1.start }
        let daylight = daylight(on: day)

        if windowIntervals.isEmpty {
            evaluation.hasNoScheduledWindow = true
            guard let daylight else {
                evaluation.verdict = .unknown
                evaluation.unknownReason = .missingSunTimes
                return evaluation
            }
            if isToday && daylight.end <= input.now {
                evaluation.status = .noDaylightRemaining
                return evaluation
            }
            let hours = hourStarts(in: daylight).filter { !isToday || $0.addingTimeInterval(3600) > input.now }
            evaluation.windows = [evaluateWindow(daylight, hours: hours, isEnded: false)]
        } else {
            evaluation.windows = windowIntervals.map { window in
                evaluateWindow(window, hours: hourStarts(in: window), isEnded: isToday && window.end <= input.now)
            }
            if evaluation.windows.allSatisfy(\.isEnded) {
                evaluation.status = .noRideWindowsRemaining
            }
        }

        let active = evaluation.windows.filter { !$0.isEnded }
        let hours = Array(Set(active.flatMap(\.evaluatedHours))).sorted()
        let result = evaluate(hours: hours)
        evaluation.breaches = merge(result.findings)
        evaluation.notChecked = result.notChecked.sorted()
        evaluation.partiallyChecked = result.partiallyChecked.sorted()
        if !hours.isEmpty { applyDirections(result, hours: hours, to: &evaluation) }

        if evaluation.status == .evaluated {
            evaluation.verdict = Verdict.combining(active.map(\.verdict))
            evaluation.unknownReason =
                evaluation.verdict == .unknown ? active.first { $0.verdict == .unknown }?.unknownReason : nil
        }
        if case .expired = freshness {
            evaluation.windows = evaluation.windows.map { window in
                var window = window
                window.verdict = .unknown
                window.unknownReason = .forecastTooOld
                return window
            }
            if evaluation.status == .evaluated {
                evaluation.verdict = .unknown
                evaluation.unknownReason = .forecastTooOld
            }
        }

        let anyPointFailed = positions.contains { hoursByPosition[$0]?.isEmpty ?? true }
        if evaluation.verdict != .unknown, evaluation.coverage == .full, !anyPointFailed, let daylight {
            evaluation.opportunities = opportunities(in: daylight, isToday: isToday)
        }
        return evaluation
    }

    func evaluateWindow(_ interval: DateInterval, hours: [Date], isEnded: Bool) -> WindowEvaluation {
        let result = evaluate(hours: hours)
        let verdict = windowVerdict(result, hours: hours)
        return WindowEvaluation(
            interval: interval, evaluatedHours: hours, verdict: verdict,
            unknownReason: verdict == .unknown ? .missingData : nil, isEnded: isEnded,
            breaches: merge(result.findings))
    }

    /// Nah on any hard finding at any point. Otherwise Unknown when the evaluation location lacks
    /// data for any hour; missing ring points only reduce coverage.
    func windowVerdict(_ result: HoursResult, hours: [Date]) -> Verdict {
        if result.findings.contains(where: { $0.severity == .hard }) { return .nah }
        if hours.isEmpty || result.lacksData(at: .center, in: hours) { return .unknown }
        return result.findings.isEmpty ? .ride : .maybe
    }

    // MARK: Ranges

    func evaluate(range: DateInterval) -> RangeEvaluation {
        let hours = hourStarts(in: range)
        let result = evaluate(hours: hours)
        var verdict = windowVerdict(result, hours: hours)
        var reason: UnknownReason? = verdict == .unknown ? .missingData : nil
        let isToday = calendar.isDate(range.start, inSameDayAs: input.now)
        if case .expired = freshness(isToday: isToday) {
            verdict = .unknown
            reason = .forecastTooOld
        }
        let missing = ringDirections.filter { direction in
            positions.filter { $0.direction == direction }.contains { result.lacksData(at: $0, in: hours) }
        }
        return RangeEvaluation(
            range: range, verdict: verdict, unknownReason: reason, breaches: merge(result.findings),
            coverage: missing.isEmpty ? .full : .partial(missing: missing),
            notChecked: result.notChecked.sorted(), partiallyChecked: result.partiallyChecked.sorted())
    }

    // MARK: Hours

    func evaluate(hours: [Date]) -> HoursResult {
        var result = HoursResult()
        for hour in hours {
            for position in positions {
                guard let conditions = hoursByPosition[position]?[hour], conditions.hasCoreValues else {
                    result.missing.insert(HourPosition(hour: hour, position: position))
                    continue
                }
                let hourResult = rules.evaluate(conditions, at: position) { hoursByPosition[position]?[$0] }
                result.findings += hourResult.findings
                result.notChecked.formUnion(hourResult.notChecked)
                result.partiallyChecked.formUnion(hourResult.partiallyChecked)
            }
            result.findings += alertFindings(at: hour)
        }
        if input.profile.limits.alertsEnabled && !input.alertsAvailable && !hours.isEmpty {
            result.notChecked.insert(.alert)
        }
        return result
    }

    func alertFindings(at hour: Date) -> [Finding] {
        guard input.profile.limits.alertsEnabled, input.alertsAvailable else { return [] }
        let hourEnd = hour.addingTimeInterval(3600)
        var findings: [Finding] = []
        for alert in input.alerts {
            let severity: Severity
            switch alert.severity {
            case .minor: continue
            case .moderate: severity = .soft
            case .severe, .extreme: severity = .hard
            }
            let applies =
                if let active = alert.active {
                    active.start < hourEnd && hour < active.end
                } else {
                    calendar.isDate(hour, inSameDayAs: input.now)
                }
            guard applies else { continue }
            for position in alert.positions.sorted() {
                findings.append(
                    Finding(factor: .alert, severity: severity, hour: hour, position: position, alertName: alert.name))
            }
        }
        return findings
    }

    /// Start of every hour that overlaps `interval`.
    func hourStarts(in interval: DateInterval) -> [Date] {
        guard interval.duration > 0, var hour = calendar.dateInterval(of: .hour, for: interval.start)?.start else {
            return []
        }
        var hours: [Date] = []
        while hour < interval.end {
            hours.append(hour)
            hour = hour.addingTimeInterval(3600)
        }
        return hours
    }

    func interval(of window: RideWindow, on day: Date) -> DateInterval? {
        guard window.end > window.start,
            let start = calendar.date(
                bySettingHour: window.start / 60, minute: window.start % 60, second: 0, of: day),
            let end = calendar.date(bySettingHour: window.end / 60, minute: window.end % 60, second: 0, of: day),
            end > start
        else { return nil }
        return DateInterval(start: start, end: end)
    }

    func daylight(on day: Date) -> DateInterval? {
        guard let sun = input.sun.first(where: { calendar.isDate($0.day, inSameDayAs: day) }),
            let sunrise = sun.sunrise, let sunset = sun.sunset, sunset > sunrise
        else { return nil }
        return DateInterval(start: sunrise, end: sunset)
    }

    func freshness(isToday: Bool) -> Freshness {
        let age = input.now.timeIntervalSince(input.fetchedAt)
        let policy = input.freshness
        if age > (isToday ? policy.todayExpiredAfter : policy.laterDaysExpiredAfter) { return .expired(age: age) }
        if isToday && age > policy.todayStaleAfter { return .stale(age: age) }
        return .fresh
    }

    // MARK: Directions

    var ringDirections: [CompassDirection] {
        Array(Set(positions.compactMap(\.direction))).sorted()
    }

    func applyDirections(_ result: HoursResult, hours: [Date], to evaluation: inout DayEvaluation) {
        let directions = ringDirections
        guard !directions.isEmpty else { return }
        let verdicts = directions.map { direction in
            DirectionVerdict(
                direction: direction,
                verdict: result.verdict(for: positions.filter { $0.direction == direction }, hours: hours))
        }
        evaluation.directions = verdicts
        evaluation.clearDirections = verdicts.filter { $0.verdict == .ride }.map(\.direction)
        let missing = directions.filter { direction in
            positions.filter { $0.direction == direction }.contains { result.lacksData(at: $0, in: hours) }
        }
        evaluation.coverage = missing.isEmpty ? .full : .partial(missing: missing)
    }

    // MARK: Opportunities

    /// Unbroken daylight stretches where every point has data and nothing is breached, at least
    /// the minimum ride duration long, longest first, at most three.
    func opportunities(in daylight: DateInterval, isToday: Bool) -> [DateInterval] {
        let hours = hourStarts(in: daylight).filter { !isToday || $0.addingTimeInterval(3600) > input.now }
        let result = evaluate(hours: hours)
        let breachedHours = Set(result.findings.map(\.hour))
        let missingHours = Set(result.missing.map(\.hour))
        let clear = hours.map { !breachedHours.contains($0) && !missingHours.contains($0) }

        var stretches: [DateInterval] = []
        var runStart: Date?
        for (index, hour) in hours.enumerated() {
            if clear[index] {
                if runStart == nil { runStart = hour }
            } else if let start = runStart {
                stretches.append(DateInterval(start: start, end: hour))
                runStart = nil
            }
        }
        if let start = runStart, let last = hours.last {
            stretches.append(DateInterval(start: start, end: last.addingTimeInterval(3600)))
        }

        let earliest = isToday ? max(daylight.start, input.now) : daylight.start
        return
            stretches
            .compactMap { stretch -> DateInterval? in
                let start = max(stretch.start, earliest)
                let end = min(stretch.end, daylight.end)
                return end > start ? DateInterval(start: start, end: end) : nil
            }
            .filter { $0.duration >= input.profile.minimumRideDuration }
            .sorted { $0.duration != $1.duration ? $0.duration > $1.duration : $0.start < $1.start }
            .prefix(3)
            .map { $0 }
    }

    // MARK: Breaches

    /// Merges findings with the same factor, severity and alert across consecutive hours, most
    /// severe first, then by start time.
    func merge(_ findings: [Finding]) -> [Breach] {
        struct Key: Hashable {
            var factor: Factor
            var severity: Severity
            var alertName: String?
        }
        let groups = Dictionary(grouping: findings) {
            Key(factor: $0.factor, severity: $0.severity, alertName: $0.alertName)
        }
        var breaches: [Breach] = []
        for (key, group) in groups {
            let hours = Array(Set(group.map(\.hour))).sorted()
            var runs: [[Date]] = []
            for hour in hours {
                if let previous = runs.last?.last, hour.timeIntervalSince(previous) == 3600 {
                    runs[runs.count - 1].append(hour)
                } else {
                    runs.append([hour])
                }
            }
            for run in runs {
                let inRun = group.filter { run.contains($0.hour) }
                let values = inRun.compactMap(\.value)
                breaches.append(
                    Breach(
                        factor: key.factor, severity: key.severity,
                        worstValue: key.factor.lowerIsWorse ? values.min() : values.max(),
                        limit: inRun.compactMap(\.limit).first,
                        range: DateInterval(start: run[0], end: run[run.count - 1].addingTimeInterval(3600)),
                        positions: Array(Set(inRun.map(\.position))).sorted(), alertName: key.alertName))
            }
        }
        return breaches.sorted {
            if $0.severity != $1.severity { return $0.severity > $1.severity }
            if $0.range.start != $1.range.start { return $0.range.start < $1.range.start }
            if $0.factor != $1.factor { return $0.factor < $1.factor }
            return ($0.alertName ?? "") < ($1.alertName ?? "")
        }
    }
}
