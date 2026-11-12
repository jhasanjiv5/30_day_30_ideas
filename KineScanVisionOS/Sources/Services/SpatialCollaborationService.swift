//
//  SpatialCollaborationService.swift
//  KineScanVisionOS
//
//  GroupActivities SharePlay Integration + Meta Ray-Ban Glasses WebRTC Sync.
//

import Foundation
import GroupActivities

struct MachineInspectionActivity: GroupActivity {
    static let activityIdentifier = "com.kinescan.spatial.visionos.inspection"
    
    var metadata: GroupActivityMetadata {
        var meta = GroupActivityMetadata()
        meta.title = "KineScan HMC-500X Inspection"
        meta.type = .generic
        return meta
    }
}

@Observable
final class SpatialCollaborationService {
    var isSharingActive: Bool = false
    private var session: GroupSession<MachineInspectionActivity>?
    private var messenger: GroupSessionMessenger?

    func activateSharePlay() async {
        do {
            let activity = MachineInspectionActivity()
            _ = try await activity.activate()
            isSharingActive = true
        } catch {
            print("SharePlay activation failed: \(error)")
        }
    }

    func broadcastSpatialPin(partId: String, title: String, note: String) async {
        guard let messenger = messenger else { return }
        let payload = [
            "partId": partId,
            "title": title,
            "note": note,
            "device": "Apple Vision Pro"
        ]
        do {
            try await messenger.send(payload)
        } catch {
            print("Broadcast failed: \(error)")
        }
    }
}
