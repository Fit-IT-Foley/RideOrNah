import SwiftUI

@main
struct RideOrNahApp: App {
    @State private var model: AppModel
    @State private var forecast: ForecastController

    init() {
        let model = AppModel.live()
        _model = State(initialValue: model)
        _forecast = State(initialValue: ForecastController.live(app: model))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(forecast)
                .preferredColorScheme(.dark)
        }
    }
}
