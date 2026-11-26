import EventKit
import EventKitUI
import Presentation
import SwiftUI

/// The system event editor, pre-filled from a draft. It runs outside the app, so it needs no
/// calendar permission, and the app only learns whether the rider saved or cancelled.
struct CalendarEditor: UIViewControllerRepresentable {
    let draft: CalendarDraft
    let done: (Bool) -> Void

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = draft.title
        event.startDate = draft.range.start
        event.endDate = draft.range.end
        event.location = draft.location
        event.notes = draft.notes
        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.event = event
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(done: done) }

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let done: (Bool) -> Void
        init(done: @escaping (Bool) -> Void) { self.done = done }

        func eventEditViewController(
            _ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction
        ) {
            done(action == .saved)
        }
    }
}
