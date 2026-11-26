import Presentation
import SwiftUI

enum AppTab: Hashable {
    case today, week, alerts
}

/// What covers the tabs: setup until it's done, then the paywall when it's asked for.
enum Cover: String, Identifiable {
    case firstRun, paywall
    var id: String { rawValue }
}

/// The app's tabs. First-run setup covers everything until it's done.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(ForecastController.self) private var forecast
    @Environment(AccessController.self) private var access
    @Environment(RideCalendar.self) private var calendar
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
        .fullScreenCover(item: cover) { cover in
            switch cover {
            case .firstRun: FirstRunView()
            case .paywall: PaywallView { access.showsPaywall = false }
            }
        }
        .onOpenURL { model.open($0) }
        .sheet(item: calendarDraft) { draft in
            CalendarEditor(draft: draft) { saved in calendar.finish(saved: saved) }
                .ignoresSafeArea()
        }
        .onChange(of: model.needsFirstRun) { wasRunning, isRunning in
            if wasRunning, !isRunning, !access.access.isActive { access.showsPaywall = true }
        }
        .task(id: model.preferences?.activeProfileID) { await forecast.refresh(.foreground) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await access.refresh()
                    await forecast.refresh(.foreground)
                }
            }
        }
        .onChange(of: model.preferences?.activeProfile) { _, _ in forecast.evaluate() }
        #if DEBUG
            .sheet(isPresented: $showsWeatherDebug) { WeatherDebugView() }
        #endif
    }

    var calendarDraft: Binding<CalendarDraft?> {
        Binding(get: { calendar.draft }, set: { if $0 == nil, calendar.draft != nil { calendar.finish(saved: false) } })
    }

    var cover: Binding<Cover?> {
        Binding(
            get: { model.needsFirstRun ? .firstRun : access.showsPaywall ? .paywall : nil },
            set: { if $0 == nil { access.showsPaywall = false } })
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
            .environment(
                AccessController(store: StubStore(active: true), container: .current())
            )
            .environment(RideCalendar(app: model, forecast: forecast))
    }
#endif
