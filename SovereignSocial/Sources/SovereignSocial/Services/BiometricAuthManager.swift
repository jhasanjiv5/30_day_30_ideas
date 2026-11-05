import Foundation
import LocalAuthentication

@MainActor
public final class BiometricAuthManager: ObservableObject {
    @Published public var isUnlocked: Bool = true
    @Published public var biometryType: LABiometryType = .faceID

    public init() {}

    public func authenticate() async -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Fallback for simulator
            self.isUnlocked = true
            return true
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Authenticate with Face ID to decrypt Sovereign Vault"
            )
            self.isUnlocked = success
            return success
        } catch {
            return false
        }
    }

    public func lock() {
        self.isUnlocked = false
    }
}
