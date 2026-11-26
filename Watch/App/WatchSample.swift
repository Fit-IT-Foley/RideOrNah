#if DEBUG
    import Foundation
    import Presentation
    import VerdictEngine

    /// Results like the iPhone sends on a morning with rain from 5 PM, for UI tests and trying the
    /// watch app without a paired iPhone. Launch with `-watchSample YES -fixedNow 2026-06-08T06:00`;
    /// release builds don't contain it.
    enum WatchSample {
        /// Hands the sample to the store as if the iPhone sent it at 05:50, and returns the clock
        /// `-fixedNow` stops at, if any.
        static func apply(to store: WatchStore, arguments: UserDefaults = .standard) -> Date? {
            let now = arguments.string(forKey: "fixedNow").flatMap(parseLocal)
            if arguments.bool(forKey: "watchSample") {
                store.receive(try? JSONEncoder().encode(rainFromFive(on: now ?? Date(), calendar: .current)))
            }
            return now
        }

        static func rainFromFive(on date: Date, calendar: Calendar) -> WatchResults {
            let today = calendar.startOfDay(for: date)
            func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: today)! }
            func at(_ hour: Int, _ minute: Int = 0) -> Date {
                calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today)!
            }
            let rain = "Rain likely 5–7 PM (80%)"
            // Days four to seven are lower confidence.
            let outlook: [(Verdict, String, Bool)] = [
                (.ride, "Clear all day", false), (.maybe, "Gusts to 31 mph", false), (.ride, "Clear all day", true),
                (.ride, "Clear all day", true), (.nah, "Rain likely all day (90%)", true),
                (.ride, "Clear all day", true),
            ]
            return WatchResults(
                fetchedAt: at(5, 50), hasAccess: true, profileName: "Commute", placeName: "Portland",
                days: [
                    WatchDay(
                        day: today, verdict: .nah, summary: rain,
                        windows: [
                            WatchWindow(start: at(7), end: at(9), verdict: .ride, reason: nil),
                            WatchWindow(start: at(16), end: at(19), verdict: .nah, reason: rain),
                        ],
                        directionText: nil, lowerConfidence: false)
                ]
                    + outlook.enumerated().map { index, entry in
                        WatchDay(
                            day: day(index + 1), verdict: entry.0, summary: entry.1, windows: [], directionText: nil,
                            lowerConfidence: entry.2)
                    })
        }

        static func parseLocal(_ text: String) -> Date? {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = .current
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
            return formatter.date(from: text)
        }
    }
#endif
