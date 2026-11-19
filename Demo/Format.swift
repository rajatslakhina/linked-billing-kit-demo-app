import Foundation
import LinkedBilling
import SwiftUI

/// Display strings for the demo. Kept in one place so the views stay declarative.
enum Format {
    /// Built once: DateFormatter is expensive to create, and this runs in view updates.
    private static let utcFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "d MMM HH:mm 'UTC'"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static func dateTime(_ millis: EpochMillis) -> String {
        utcFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(millis) / 1_000))
    }

    static func phase(_ phase: LinkPhase) -> String {
        switch phase {
        case .notLinked: return "Not linked"
        case .linkPending: return "Linking…"
        case .unlinked: return "Unlinked"
        case let .linked(health):
            switch health {
            case .warmingUp: return "Linked · propagating"
            case .billable: return "Linked · customer pays"
            case .spendLimitReached: return "Linked · cap reached"
            case .billingUnavailable: return "Linked · billing unavailable"
            case .notBillable: return "Linked · not billable"
            }
        }
    }

    static func phaseColor(_ phase: LinkPhase) -> Color {
        switch phase {
        case .notLinked, .unlinked: return .gray
        case .linkPending: return .blue
        case let .linked(health):
            switch health {
            case .billable, .warmingUp: return .green
            case .spendLimitReached, .billingUnavailable, .notBillable: return .orange
            }
        }
    }

    static func payer(_ payer: Payer, budget: AppBudget?) -> String {
        switch payer {
        case .customer: return "Customer org"
        case .app:
            switch budget {
            case .included?: return "App · included"
            case .subsidy?: return "App · subsidy"
            case .operational?, nil: return "App · operational"
            }
        }
    }

    static func decision(_ decision: RouteDecision) -> String {
        switch decision {
        case let .billCustomer(_, model, isProbe):
            return "Bill customer\(isProbe ? " (probe)" : "") on \(model)"
        case let .billApp(model, budget, _, _):
            return "\(payer(.app, budget: budget)) on \(model)"
        case let .pause(reason):
            return "Pause: \(pause(reason))"
        }
    }

    static func payerTitle(_ decision: RouteDecision) -> String {
        switch decision {
        case .billCustomer: return "Customer org pays"
        case let .billApp(_, budget, _, _):
            switch budget {
            case .included: return "App pays (included)"
            case .subsidy: return "App pays (subsidy)"
            case .operational: return "App pays (own usage)"
            }
        case .pause: return "Paused"
        }
    }

    static func decisionDetail(_ decision: RouteDecision) -> String {
        switch decision {
        case let .billCustomer(_, model, isProbe):
            return "\(model)\(isProbe ? ", as the recovery probe" : "")"
        case let .billApp(model, _, reason, estimate):
            return "\(model), \(estimate) · \(appReason(reason))"
        case let .pause(reason):
            return pause(reason)
        }
    }

    static func decisionColor(_ decision: RouteDecision) -> Color {
        switch decision {
        case .billCustomer: return .green
        case let .billApp(_, budget, _, _):
            switch budget {
            case .included: return .blue
            case .subsidy: return .orange
            case .operational: return .gray
            }
        case .pause: return .red
        }
    }

    static func appReason(_ reason: AppPaidReason) -> String {
        switch reason {
        case .operational: return "app's own usage, never billed to the customer"
        case .includedInSubscription: return "covered by the App Store subscription"
        case .codeExecutionNotCustomerBillable: return "code execution can't be billed to a customer"
        case let .subsidy(denial): return "subsidy: \(self.denial(denial))"
        }
    }

    static func denial(_ denial: CustomerDenial) -> String {
        switch denial {
        case .notLinked: return "org not linked"
        case .linkInProgress: return "link in progress"
        case .unlinked: return "org unlinked"
        case let .spendLimitReached(resetsAt): return "cap reached until \(dateTime(resetsAt))"
        case .billingUnavailable: return "org billing unavailable"
        case .notBillable: return "org not billable"
        }
    }

    static func pause(_ reason: PauseReason) -> String {
        switch reason {
        case let .customerUnavailable(denial): return "\(self.denial(denial)); subsidy needs a subscription"
        case let .subsidyNotEligible(denial): return "\(self.denial(denial)); feature not subsidised"
        case let .subsidyBudgetExhausted(denial): return "\(self.denial(denial)); monthly subsidy used up"
        case .codeExecutionUnfunded: return "code execution needs app budget"
        case .reservationRefused: return "budget reserved by in-flight requests"
        }
    }

    static func refusal(_ refusal: BillingRefusal) -> String {
        switch refusal {
        case .notBillable: return "403 not_billable"
        case .billingUnavailable: return "402 billing_unavailable"
        case .spendLimitReached: return "402 spend_limit_reached"
        case let .overloaded(retryAfter): return "503 overloaded" + (retryAfter.map { ", retry-after \($0)s" } ?? "")
        case .userProfileRequired: return "400 user_profile_required"
        case .invalidRequest: return "400 invalid_request"
        case let .other(status, _, _): return "HTTP \(status)"
        }
    }

    static func attempt(_ result: AttemptResult) -> String {
        switch result {
        case let .served(cost): return "served, \(cost)"
        case let .refused(refusal, partial): return self.refusal(refusal) + (partial ? " (partial reply discarded)" : "")
        case .transportFailed: return "transport failed (billing unknown)"
        case .notSent: return "not sent"
        }
    }

    static func attemptSymbol(_ result: AttemptResult) -> String {
        switch result {
        case .served: return "checkmark.circle.fill"
        case .refused: return "xmark.circle.fill"
        case .transportFailed: return "questionmark.circle.fill"
        case .notSent: return "pause.circle.fill"
        }
    }

    static func attemptColor(_ result: AttemptResult) -> Color {
        switch result {
        case .served: return .green
        case .refused: return .orange
        case .transportFailed: return .red
        case .notSent: return .gray
        }
    }

    static func outcome(_ outcome: GatewayOutcome) -> String {
        switch outcome {
        case let .served(_, payer, _, cost):
            return "\(payer.isCustomer ? "Customer" : "App") paid \(cost)"
        case .paused: return "Paused"
        case .failed: return "Failed"
        }
    }

    static func outcomeColor(_ outcome: GatewayOutcome) -> Color {
        switch outcome {
        case let .served(_, payer, _, _): return payer.isCustomer ? .green : .orange
        case .paused: return .red
        case .failed: return .red
        }
    }

    static func ledgerOutcome(_ outcome: LedgerOutcome) -> String {
        switch outcome {
        case let .billed(amount): return amount.description
        case let .refused(refusal): return self.refusal(refusal)
        case .unknown: return "unknown"
        }
    }
}
