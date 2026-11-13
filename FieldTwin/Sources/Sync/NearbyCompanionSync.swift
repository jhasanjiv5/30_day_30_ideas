import Foundation
import Observation
import LocalAuthentication
#if canImport(NearbyInteraction)
import NearbyInteraction
#endif

@Observable
@MainActor
final class NearbyCompanionSync {
    var isCompanionLinked: Bool = true
    var uwbDistanceMeters: Double = 1.42
    var bearingDegrees: Int = 24

    func authenticateWithFaceID() async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return true
        }
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Authorize Tier 3 physical actuation from Companion"
            )
        } catch {
            return false
        }
    }
}
