import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import UIKit

@MainActor
final class FirebaseCloudSyncService {
    static let shared = FirebaseCloudSyncService()

    private init() {}

    func autoSaveProject(
        project: VideoProject,
        deviceId: String? = nil
    ) async throws {
        guard FirebaseApp.app() != nil else {
            throw SyncError.firebaseNotConfigured
        }

        let user: User
        if let currentUser = Auth.auth().currentUser {
            user = currentUser
        } else {
            user = try await Auth.auth().signInAnonymously().user
        }

        let document = Firestore.firestore()
            .collection("users").document(user.uid)
            .collection("projects").document(project.id)

        try await document.setData([
            "title": project.title,
            "segments": project.segments.map(\.dictionaryRepresentation),
            "filter": project.filter.rawValue,
            "updatedAt": FieldValue.serverTimestamp(),
            "lastEditedDevice": deviceId ?? UIDevice.current.name,
            "cloudVersion": FieldValue.increment(Int64(1))
        ], merge: true)
    }

    enum SyncError: LocalizedError {
        case firebaseNotConfigured

        var errorDescription: String? {
            switch self {
            case .firebaseNotConfigured:
                "Firebase is not configured. Add GoogleService-Info.plist to the app target."
            }
        }
    }
}
