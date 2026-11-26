import Foundation
import Presentation
import RiderSettings
import SharedContainer
import SwiftUI
import WeatherData
import WidgetKit

@main
struct RideOrNahWidgets: WidgetBundle {
    var body: some Widget { RideWidget() }
}

struct RideWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RideOrNah", provider: RideProvider()) { entry in
            RideWidgetView(content: entry.content)
        }
        .configurationDisplayName("Ride or Nah")
        .description("Today's call at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct RideEntry: TimelineEntry {
    let date: Date
    let content: WidgetContent
}

/// Builds timelines from the app's cached forecasts, settings and access, fetching only when the
/// cache is more than 2 hours old and the daily budget allows.
struct RideProvider: TimelineProvider {
    func placeholder(in context: Context) -> RideEntry {
        RideEntry(date: Date(), content: .placeholder(calendar: .current))
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (RideEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        let fallback = placeholder(in: context)
        Task {
            let first = await Self.loader().timeline().entries.first
            completion(first.map { RideEntry(date: $0.date, content: $0.content) } ?? fallback)
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<RideEntry>) -> Void) {
        Task {
            let (entries, _) = await Self.loader().timeline()
            let reload = Date().addingTimeInterval(RefreshPurpose.widget.reuseInterval)
            completion(
                Timeline(entries: entries.map { RideEntry(date: $0.date, content: $0.content) }, policy: .after(reload))
            )
        }
    }

    static func loader() -> WidgetLoader {
        let container = SharedContainer.current()
        let group = Bundle.main.object(forInfoDictionaryKey: SharedContainer.infoPlistKey) as? String
        let defaults = group.flatMap(UserDefaults.init(suiteName:)) ?? .standard
        return WidgetLoader(
            store: PreferencesStore(defaults: defaults, cloud: nil), container: container,
            cache: ForecastCache(container: container), budget: RequestBudget(suiteName: group),
            provider: { _ in WeatherKitProvider() }, calendar: .current, clock: { Date() })
    }
}
