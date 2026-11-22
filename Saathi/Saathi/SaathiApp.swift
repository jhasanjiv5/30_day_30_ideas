import SwiftUI
import SaathiCore

@main
struct SaathiApp: App {
    @State private var coordinator: SessionCoordinator

    init() {
        let args = ProcessInfo.processInfo.arguments
        let isMock = args.contains("-MockMode")
        let initialLanguage: SaathiLanguage = {
            if let idx = args.firstIndex(of: "-Language"), args.indices.contains(idx + 1),
               let parsed = SaathiLanguage(rawValue: args[idx + 1]) {
                return parsed
            }
            return SaathiLanguage.fromDeviceLocale()
        }()

        let coord = SessionCoordinator(
            mockMode: isMock,
            initialNarrationLanguage: initialLanguage,
            initialListeningLanguage: initialLanguage
        )
        _coordinator = State(initialValue: coord)
    }

    var body: some Scene {
        WindowGroup {
            RootContentView(coordinator: coordinator)
                .environment(\.layoutDirection, coordinator.narrationLanguage.isRightToLeft ? .rightToLeft : .leftToRight)
                .environment(\.locale, coordinator.narrationLanguage.locale)
        }
    }
}

struct RootContentView: View {
    @Bindable var coordinator: SessionCoordinator

    var body: some View {
        NavigationStack {
            switch coordinator.phase {
            case .idle, .requestingPermission:
                OnboardingPermissionsView(coordinator: coordinator)
            case .active, .pausedQuiet:
                LiveSessionView(coordinator: coordinator)
            case .ending, .wiped:
                PrivacyReceiptView(coordinator: coordinator)
            case .episodeDecision:
                EpisodePlayerView(coordinator: coordinator)
            }
        }
        .task {
            if ProcessInfo.processInfo.arguments.contains("-AutoStart"),
               coordinator.phase == .idle {
                await coordinator.startSession()
            }
            await startFromSiriIfRequested()
        }
        .onReceive(NotificationCenter.default.publisher(for: .saathiStartIntentTriggered)) { _ in
            Task { await startFromSiriIfRequested() }
        }
    }

    /// "Hey Siri, start Saathi here" — previously the notification was posted but never observed.
    private func startFromSiriIfRequested() async {
        guard PendingStartRequest.consume(), coordinator.phase == .idle else { return }
        await coordinator.startSession()
    }
}
