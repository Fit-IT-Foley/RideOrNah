import Entitlements
import Presentation
import StoreKit
import SwiftUI

/// Where the legal pages live. Both open in Safari, outside the app.
enum LegalLinks {
    /// Apple's standard licensed application end user license agreement.
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    /// `docs/privacy-policy.md`, served by GitHub Pages.
    static let privacy = URL(string: "https://fit-it-foley.github.io/RideOrNah/privacy-policy.html")!
}

/// The free trial and the two plans, in the design-system style (the canvas doesn't draw it).
struct PaywallView: View {
    @Environment(AccessController.self) private var store
    let close: () -> Void
    @State private var selected = Plan.annual
    @State private var redeeming = false

    static let included = [
        "Today's call for your ride hours, across your radius",
        "The next 7 days, hour by hour",
        "A morning notification with the reason",
        "Ride suggestions for your calendar",
        "Widgets and Apple Watch",
    ]

    var body: some View {
        let plans = PaywallPresenter().plans(store.offers)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Wordmark()
                    Spacer()
                    Button(action: close) {
                        Image(systemName: "xmark").font(.headline).foregroundStyle(Theme.ink)
                            .frame(width: 44, height: 44)
                            .adaptiveSurface(in: .circle)
                    }
                    .accessibilityLabel("Close")
                    .accessibilityIdentifier("paywall.close")
                }
                Text("KNOW BEFORE YOU GEAR UP\(Text(".").foregroundStyle(Theme.accent))")
                    .font(Theme.display(.largeTitle))
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("Your limits, your hours, your radius. Called every morning, worked out on your phone.")
                    .font(.title3.weight(.semibold)).foregroundStyle(Theme.ink)
                Card {
                    SectionLabel(text: "What's included")
                    ForEach(Self.included, id: \.self) { item in
                        Label {
                            Text(item).foregroundStyle(Theme.ink)
                        } icon: {
                            Image(systemName: "checkmark").foregroundStyle(Theme.accent)
                        }
                    }
                }
                if plans.isEmpty {
                    Card {
                        Text("Plans couldn't load from the App Store. Check your connection.")
                            .foregroundStyle(Theme.inkSecondary)
                        Button("Try again") { Task { await store.retry() } }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                } else {
                    ForEach(plans, id: \.plan) { plan in planCard(plan) }
                    if let plan = plans.first(where: { $0.plan == selected }) ?? plans.first {
                        Button(plan.button) { Task { await store.purchase(plan.plan) } }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(store.isPurchasing)
                            .accessibilityIdentifier("paywall.subscribe")
                        Text(plan.disclosure).font(.footnote).foregroundStyle(Theme.inkTertiary)
                            .accessibilityIdentifier("paywall.disclosure")
                    }
                }
                if let message = store.message {
                    Text(message).font(.subheadline).foregroundStyle(Theme.reasonWarm)
                        .accessibilityIdentifier("paywall.message")
                }
                HStack(spacing: 20) {
                    Button("Restore Purchases") { Task { await store.restore() } }
                        .accessibilityIdentifier("paywall.restore")
                    Button("Redeem code") { redeeming = true }
                        .accessibilityIdentifier("paywall.redeem")
                }
                .font(.subheadline.weight(.semibold))
                .tint(Theme.ink)
                HStack(spacing: 20) {
                    Link("Terms of Use", destination: LegalLinks.terms).accessibilityIdentifier("paywall.terms")
                    Link("Privacy Policy", destination: LegalLinks.privacy).accessibilityIdentifier("paywall.privacy")
                }
                .font(.subheadline)
                .tint(Theme.inkSecondary)
            }
            .padding(20)
        }
        .background(Theme.ground)
        .offerCodeRedemption(isPresented: $redeeming) { _ in Task { await store.refresh() } }
        .accessibilityIdentifier("paywall.screen")
    }

    func planCard(_ plan: PaywallPlan) -> some View {
        let isSelected = plan.plan == selected
        return Button {
            selected = plan.plan
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Theme.accent : Theme.inkQuiet)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(plan.title).font(Theme.display(.title3, weight: .bold)).foregroundStyle(Theme.ink)
                        if let trial = plan.trial {
                            Text(trial.uppercased()).font(.caption.weight(.bold)).tracking(1)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .foregroundStyle(Theme.ground).background(Theme.accent, in: .capsule)
                        }
                    }
                    Text(plan.price).foregroundStyle(Theme.ink)
                    if let equivalent = plan.equivalent {
                        Text(equivalent).font(.subheadline).foregroundStyle(Theme.inkTertiary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: .rect(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20).strokeBorder(
                    isSelected ? Theme.accent : Theme.cardEdge, lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("paywall.plan.\(plan.plan.rawValue)")
    }
}

/// What Today and Week show without access: everything is saved, and plans are one tap away.
struct LockedCard: View {
    @Environment(AccessController.self) private var store
    let title: String

    var body: some View {
        let hasTrial = store.offers.contains { $0.trial != nil }
        Card {
            SectionLabel(text: title)
            Text("Subscribe to see the call.").font(Theme.display(.title2)).foregroundStyle(Theme.ink)
                .accessibilityIdentifier("locked.title")
            Text(
                "Your profiles, limits and places are saved. \(hasTrial ? "Start your free trial" : "Subscribe") to see today's call, the next 7 days and the morning notification."
            )
            .font(.subheadline).foregroundStyle(Theme.inkSecondary)
            Button("See plans") { store.showsPaywall = true }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("locked.seePlans")
        }
    }
}
