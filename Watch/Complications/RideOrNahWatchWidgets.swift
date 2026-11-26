import Foundation
import Presentation
import SwiftUI
import WidgetKit

@main
struct RideOrNahWatchWidgets: WidgetBundle {
    var body: some Widget { RideComplication() }
}

struct RideComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RideOrNahComplication", provider: ComplicationProvider()) { entry in
            WatchComplicationView(content: entry.content)
                .containerBackground(Theme.ground, for: .widget)
        }
        .configurationDisplayName("Ride or Nah")
        .description("Today's call on your watch face.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

struct ComplicationEntry: TimelineEntry {
    let date: Date
    let content: WatchContent
}

/// Builds timelines from the last results the iPhone sent, with entries for window ends,
/// midnight, and when the results turn stale and expire.
struct ComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> ComplicationEntry {
        ComplicationEntry(date: Date(), content: Self.presenter.content(nil, now: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (ComplicationEntry) -> Void) {
        let now = Date()
        completion(ComplicationEntry(date: now, content: Self.presenter.content(Self.results(), now: now)))
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<ComplicationEntry>) -> Void) {
        let now = Date()
        let results = Self.results()
        let dates = [now] + WatchTimeline.entryDates(results, now: now, calendar: .current)
        let entries = dates.map { ComplicationEntry(date: $0, content: Self.presenter.content(results, now: $0)) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    static var presenter: WatchPresenter {
        WatchPresenter(formatter: DisplayFormatter(units: .imperial, calendar: .current))
    }

    static func results() -> WatchResults? {
        let group = Bundle.main.object(forInfoDictionaryKey: "RideOrNahAppGroup") as? String
        return WatchStore.load(from: group.flatMap(UserDefaults.init(suiteName:)) ?? .standard)
    }
}
