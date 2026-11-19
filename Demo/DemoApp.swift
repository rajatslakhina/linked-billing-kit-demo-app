import LinkedBilling
import LinkedBillingTesting
import SwiftUI

/// The app owns its business rules: which features exist, which model each uses,
/// what the App Store subscription includes and how much the app will subsidise.
/// They're compiled in here and handed to the scripted month the demo plays.
enum AppBillingConfiguration {
    static let opus: ModelID = "claude-opus-5-5"
    static let haiku: ModelID = "claude-haiku-4-5"

    static var demo: ScriptedMonth.Configuration? {
        // The back end creates one user profile per customer before linking.
        guard let profile = UserProfileID("uprof_acme_corp") else { return nil }
        return ScriptedMonth.Configuration(
            policy: RoutingPolicy(subsidyPerMonth: .dollars(3), subsidyRequiresSubscription: true),
            plan: .subscription(includedPerMonth: .dollars(1)),
            profile: profile,
            summarize: FeatureDescriptor(id: "summarize", displayName: "Summarize thread", model: opus,
                                         subsidyModel: SubsidyModel(haiku, costPercent: 20)),
            draft: FeatureDescriptor(id: "draft", displayName: "Draft reply", model: opus,
                                     subsidyModel: SubsidyModel(haiku, costPercent: 20)),
            analysis: FeatureDescriptor(id: "analysis", displayName: "Run analysis", model: opus,
                                        usesCodeExecution: true),
            safety: FeatureDescriptor(id: "safety", displayName: "Safety check", billing: .appOperational,
                                      model: haiku))
    }
}

@main
struct LinkedBillingDemoApp: App {
    /// Launch arguments (used for the Simulator screenshots):
    /// `-tab timeline|router|ledger` picks the first tab; `-steps N` runs the first N
    /// steps of the scripted month on launch; `-autoplay` runs all of it.
    private let initialTab: RootView.Tab
    private let autoplaySteps: Int

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        var tab = RootView.Tab.timeline
        if let index = arguments.firstIndex(of: "-tab"), arguments.indices.contains(index + 1),
           let parsed = RootView.Tab(rawValue: arguments[index + 1]) {
            tab = parsed
        }
        initialTab = tab
        var steps = arguments.contains("-autoplay") ? Int.max : 0
        if let index = arguments.firstIndex(of: "-steps"), arguments.indices.contains(index + 1),
           let parsed = Int(arguments[index + 1]) {
            steps = max(0, parsed)
        }
        autoplaySteps = steps
    }

    var body: some Scene {
        WindowGroup {
            if let configuration = AppBillingConfiguration.demo {
                RootView(configuration: configuration, initialTab: initialTab, autoplaySteps: autoplaySteps)
            } else {
                Text("Invalid demo configuration")
            }
        }
    }
}
