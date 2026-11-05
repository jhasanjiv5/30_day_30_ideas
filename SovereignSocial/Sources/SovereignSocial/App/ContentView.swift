import SwiftUI

public struct MainContentView: View {
    @EnvironmentObject var authManager: BiometricAuthManager
    @State private var selectedTab: TabDestination = .assistant
    @State private var isShowingOnboarding = false

    public init() {}

    public enum TabDestination: String, CaseIterable, Identifiable {
        case assistant = "Brain"
        case scheduler = "Schedule"
        case vault = "Vault"
        case permissions = "Privacy"

        public var id: String { rawValue }

        public var iconName: String {
            switch self {
            case .assistant: return "sparkles"
            case .scheduler: return "calendar"
            case .vault: return "lock.shield"
            case .permissions: return "slider.horizontal.3"
            }
        }
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            AssistantView()
                .tabItem {
                    Label(TabDestination.assistant.rawValue, systemImage: TabDestination.assistant.iconName)
                }
                .tag(TabDestination.assistant)

            SchedulerView()
                .tabItem {
                    Label(TabDestination.scheduler.rawValue, systemImage: TabDestination.scheduler.iconName)
                }
                .tag(TabDestination.scheduler)

            VaultView()
                .tabItem {
                    Label(TabDestination.vault.rawValue, systemImage: TabDestination.vault.iconName)
                }
                .tag(TabDestination.vault)

            PermissionsView()
                .tabItem {
                    Label(TabDestination.permissions.rawValue, systemImage: TabDestination.permissions.iconName)
                }
                .tag(TabDestination.permissions)
        }
        .tint(Color.indigo)
    }
}
