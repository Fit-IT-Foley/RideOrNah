import WidgetKit

/// Asks widgets to rebuild their timelines after new forecasts, settings or access. They read
/// the shared cache, so this costs no weather request.
enum WidgetReloader {
    static func reload() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
