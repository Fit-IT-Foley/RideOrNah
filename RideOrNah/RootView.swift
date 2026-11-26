import SwiftUI

enum AppTab: Hashable {
    case today, week, alerts
}

/// The app's tabs. First-run setup covers everything until it's done.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(ForecastController.self) private var forecast
    @Environment(\.scenePhase) private var scenePhase
    #if DEBUG
        @State private var showsWeatherDebug = UserDefaults.standard.bool(forKey: "openWeatherDebug")
    #endif

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.selectedTab) {
            Tab("Today", systemImage: "gauge.open.with.lines.needle.33percent", value: AppTab.today) {
                TodayView(tab: $model.selectedTab)
            }
            Tab("Week", systemImage: "calendar", value: AppTab.week) {
                WeekView()
            }
            Tab("Alerts", systemImage: "bell", value: AppTab.alerts) {
                AlertsView()
            }
        }
        .tint(Theme.accent)
        .background(Theme.ground)
        .fullScreenCover(isPresented: .constant(model.needsFirstRun)) { FirstRunView() }
        .task(id: model.preferences?.activeProfileID) { await forecast.refresh(.foreground) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await forecast.refresh(.foreground) } }
        }
        .onChange(of: model.preferences?.activeProfile) { _, _ in forecast.evaluate() }
        #if DEBUG
            .sheet(isPresented: $showsWeatherDebug) { WeatherDebugView() }
        #endif
    }
}

#if DEBUG
    #Preview {
        let model = AppModel.preview()
        let forecast = ForecastController.live(app: model)
        RootView()
            .environment(model)
            .environment(forecast)
            .environment(NotificationCoordinator.live(app: model, forecast: forecast))
    }
#endif
