import LinkedBilling
import LinkedBillingTesting
import Observation

/// The view model: drives `ScriptedMonth` (the library's scripted customer month) one
/// step at a time and publishes what the screens need. The steps run the real
/// `LinkedBillingGateway`, `ConnectionReconciler` and `LinkSession` against a
/// simulated Claude API, so every card shows what the gateway actually decided.
@MainActor
@Observable
final class BillingDemoModel {
    let configuration: ScriptedMonth.Configuration
    private(set) var steps: [ScriptedMonth.StepRecord] = []
    private(set) var phase: LinkPhase = .notLinked
    private(set) var now: EpochMillis = ScriptedMonth.start
    private(set) var thisMonth = SpendTotals()
    private(set) var months: [(month: BillingMonth, totals: SpendTotals)] = []
    private(set) var entries: [LedgerEntry] = []
    private(set) var isRunning = false
    private(set) var isFinished = false
    let matrix: [ScriptedMonth.MatrixRow]

    private var month: ScriptedMonth

    init(configuration: ScriptedMonth.Configuration) {
        self.configuration = configuration
        month = ScriptedMonth(configuration: configuration)
        matrix = ScriptedMonth.matrix(for: configuration)
    }

    var totalSteps: Int { ScriptedMonth.stepCount }

    func reset() {
        guard !isRunning else { return }
        month = ScriptedMonth(configuration: configuration)
        steps = []
        phase = .notLinked
        now = ScriptedMonth.start
        thisMonth = SpendTotals()
        months = []
        entries = []
        isFinished = false
    }

    func runNextStep() async {
        guard !isRunning, !isFinished else { return }
        isRunning = true
        defer { isRunning = false }
        let current = month
        let step = await current.runNextStep()
        let snapshot = await current.snapshot()
        // `reset()` refuses while a step runs, but if `month` was ever replaced
        // mid-step, a stale result must not land on the new run.
        guard current === month else { return }
        if let step { steps.append(step) }
        phase = snapshot.phase
        now = snapshot.now
        thisMonth = snapshot.thisMonth
        months = snapshot.months
        entries = snapshot.entries
        isFinished = await current.isFinished
    }

    /// Run up to `count` steps (the `-steps N` launch argument).
    func run(steps count: Int) async {
        var remaining = max(0, count)
        while remaining > 0, !isFinished, !isRunning {
            await runNextStep()
            remaining -= 1
        }
    }

    func displayName(forFeatureID id: String) -> String {
        configuration.features.first(where: { $0.id == id })?.displayName ?? id
    }
}
