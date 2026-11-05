import SwiftUI
import LocalAuthentication
import CryptoKit
import SovereignSocial

@main
public struct SovereignApp: App {
    @StateObject private var authManager = BiometricAuthManager()
    @StateObject private var localReasoning = OnDeviceReasoningModel()
    @StateObject private var vaultStore = SecureVaultStore()
    @StateObject private var schedulerStore = PostSchedulerStore()

    public init() {}

    public var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isUnlocked {
                    MainContentView()
                        .environmentObject(authManager)
                        .environmentObject(localReasoning)
                        .environmentObject(vaultStore)
                        .environmentObject(schedulerStore)
                } else {
                    BiometricLockView()
                        .environmentObject(authManager)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}
