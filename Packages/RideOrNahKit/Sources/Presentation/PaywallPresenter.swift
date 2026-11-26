import Entitlements
import Foundation

/// What the App Store reports for one plan. Prices and currency always come from here.
public struct PlanOffer: Sendable, Equatable {
    public struct Trial: Sendable, Equatable {
        public enum Unit: Sendable, Equatable { case day, week, month, year }
        public var value: Int
        public var unit: Unit
        public init(value: Int, unit: Unit) {
            self.value = value
            self.unit = unit
        }
    }

    public var plan: Plan
    /// The App Store's own formatted price, such as "$4.99" or "4,99 €".
    public var displayPrice: String
    public var price: Decimal
    public var priceFormat: Decimal.FormatStyle.Currency
    /// The free trial, only when the rider is eligible for one.
    public var trial: Trial?

    public init(
        plan: Plan, displayPrice: String, price: Decimal, priceFormat: Decimal.FormatStyle.Currency, trial: Trial?
    ) {
        self.plan = plan
        self.displayPrice = displayPrice
        self.price = price
        self.priceFormat = priceFormat
        self.trial = trial
    }
}

/// One plan as the paywall shows it.
public struct PaywallPlan: Sendable, Equatable {
    public var plan: Plan
    public var title: String
    /// "$29.99 a year"
    public var price: String
    /// The annual plan's monthly equivalent, such as "$2.50 a month".
    public var equivalent: String?
    /// "1 week free"
    public var trial: String?
    /// "Start free trial" or "Subscribe"
    public var button: String
    /// The price, trial and renewal terms, shown under the button.
    public var disclosure: String
}

public struct PaywallPresenter {
    public init() {}

    /// The plans, annual first.
    public func plans(_ offers: [PlanOffer]) -> [PaywallPlan] {
        offers.sorted { $0.plan == .annual && $1.plan != .annual }.map(plan)
    }

    public func plan(_ offer: PlanOffer) -> PaywallPlan {
        let period = offer.plan == .annual ? "a year" : "a month"
        let price = "\(offer.displayPrice) \(period)"
        let renewal = "Renews automatically until you cancel."
        let trial = offer.trial.map(Self.length)
        let disclosure =
            if let trial {
                "Free for \(trial), then \(price). \(renewal) Cancel at least a day before the trial ends and you won't be charged."
            } else {
                "\(price). \(renewal) Cancel any time in Settings."
            }
        return PaywallPlan(
            plan: offer.plan, title: offer.plan == .annual ? "Annual" : "Monthly", price: price,
            equivalent: offer.plan == .annual ? "\((offer.price / 12).formatted(offer.priceFormat)) a month" : nil,
            trial: trial.map { "\($0) free" }, button: trial == nil ? "Subscribe" : "Start free trial",
            disclosure: disclosure)
    }

    /// "1 week", "7 days", "1 month"
    static func length(_ trial: PlanOffer.Trial) -> String {
        let unit =
            switch trial.unit {
            case .day: "day"
            case .week: "week"
            case .month: "month"
            case .year: "year"
            }
        return "\(trial.value) \(unit)\(trial.value == 1 ? "" : "s")"
    }
}
