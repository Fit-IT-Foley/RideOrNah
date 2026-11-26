import Entitlements
import Foundation
import Presentation
import Testing

struct PaywallTests {
    static func offer(
        _ plan: Plan, _ price: Decimal, display: String, currency: String = "USD", locale: String = "en_US",
        trial: PlanOffer.Trial? = PlanOffer.Trial(value: 1, unit: .week)
    ) -> PlanOffer {
        PlanOffer(
            plan: plan, displayPrice: display, price: price,
            priceFormat: .currency(code: currency).locale(Locale(identifier: locale)), trial: trial)
    }

    // Scenario: subscription: Localized pricing
    @Test("Localized pricing")
    func localizedPricing() {
        let plans = PaywallPresenter().plans([
            Self.offer(.monthly, 4.99, display: "4,99 €", currency: "EUR", locale: "de_DE"),
            Self.offer(.annual, 29.99, display: "29,99 €", currency: "EUR", locale: "de_DE"),
        ])
        #expect(plans.map(\.plan) == [.annual, .monthly])
        #expect(plans[0].price == "29,99 € a year")
        // German formatting puts a non-breaking space before the euro sign.
        #expect(plans[0].equivalent?.replacingOccurrences(of: "\u{A0}", with: " ") == "2,50 € a month")
        #expect(plans[1].price == "4,99 € a month")
        #expect(plans.allSatisfy { !$0.disclosure.contains("$") })
    }

    // Scenario: subscription: Not eligible for a trial
    @Test("Not eligible for a trial")
    func notEligibleForATrial() {
        let plan = PaywallPresenter().plan(Self.offer(.monthly, 4.99, display: "$4.99", trial: nil))
        #expect(plan.trial == nil)
        #expect(plan.button == "Subscribe")
        #expect(plan.disclosure == "$4.99 a month. Renews automatically until you cancel. Cancel any time in Settings.")
        #expect(!plan.disclosure.lowercased().contains("trial"))
        #expect(!plan.disclosure.lowercased().contains("free"))
    }

    // Restore, Terms and Privacy are on the paywall itself; AlertsTests-style UI tests check them.
    // Scenario: subscription: Required disclosures
    @Test("Required disclosures")
    func requiredDisclosures() {
        let plan = PaywallPresenter().plan(Self.offer(.annual, 29.99, display: "$29.99"))
        #expect(plan.trial == "1 week free")
        #expect(plan.button == "Start free trial")
        #expect(plan.equivalent == "$2.50 a month")
        #expect(
            plan.disclosure
                == "Free for 1 week, then $29.99 a year. Renews automatically until you cancel. Cancel at least a day before the trial ends and you won't be charged."
        )
    }

    @Test("Trial lengths")
    func trialLengths() {
        let presenter = PaywallPresenter()
        let days = presenter.plan(Self.offer(.monthly, 4.99, display: "$4.99", trial: .init(value: 7, unit: .day)))
        #expect(days.trial == "7 days free")
        let month = presenter.plan(Self.offer(.monthly, 4.99, display: "$4.99", trial: .init(value: 1, unit: .month)))
        #expect(month.disclosure.hasPrefix("Free for 1 month, then $4.99 a month."))
    }
}
