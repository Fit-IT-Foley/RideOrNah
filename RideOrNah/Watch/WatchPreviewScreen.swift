#if DEBUG
    import Presentation
    import SwiftUI

    /// The watch app's screen with the results this iPhone would send, for UI tests and trying
    /// the watch layout without a watch simulator.
    struct WatchPreviewScreen: View {
        @Environment(AppModel.self) private var model
        @Environment(ForecastController.self) private var forecast

        var body: some View {
            WatchMainView(
                content: content, markURL: forecast.attribution.darkMarkURL, legalURL: forecast.attribution.legalPageURL
            )
            .frame(width: 205)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.ground)
        }

        var content: WatchContent {
            let presenter = WatchPresenter(formatter: forecast.formatter)
            guard let preferences = model.preferences, let outlook = forecast.outlook,
                let fetchedAt = forecast.snapshot?.fetchedAt
            else { return presenter.content(nil, now: forecast.clock()) }
            let results = WatchResults.make(
                outlook: outlook, fetchedAt: fetchedAt, hasAccess: !forecast.isLocked,
                profile: preferences.activeProfile, placeName: forecast.place?.name ?? "",
                radius: preferences.radius(on: forecast.clock(), calendar: forecast.calendar),
                formatter: forecast.formatter)
            return presenter.content(results, now: forecast.clock())
        }
    }
#endif
