import Foundation

public struct RoomParticipant: Codable, Sendable, Identifiable, Equatable, Hashable {
    public let id: UUID
    public var displayName: String
    public var avatarSymbol: String
    public var accentHex: String
    public var isChild: Bool
    public var isTeen: Bool
    public var tasteVector: TasteVector
    public var lastHeartbeat: Date

    public init(
        id: UUID,
        displayName: String,
        avatarSymbol: String,
        accentHex: String,
        isChild: Bool,
        isTeen: Bool = false,
        tasteVector: TasteVector,
        lastHeartbeat: Date = .now
    ) {
        self.id = id
        self.displayName = displayName
        self.avatarSymbol = avatarSymbol
        self.accentHex = accentHex
        self.isChild = isChild
        self.isTeen = isTeen
        self.tasteVector = tasteVector
        self.lastHeartbeat = lastHeartbeat
    }

    public init(from join: JoinPayload, now: Date = .now) {
        self.id = join.participantID
        self.displayName = join.displayName
        self.avatarSymbol = join.avatarSymbol
        self.accentHex = join.accentHex
        self.isChild = join.isChild
        self.isTeen = join.isTeen
        self.tasteVector = join.tasteVector
        self.lastHeartbeat = now
    }
}

/// Pure-Swift presence state manager enforcing the 6-second heartbeat timeout rule.
public struct PresenceTracker: Sendable {
    public private(set) var participants: [RoomParticipant] = []
    public let timeoutSeconds: TimeInterval

    public init(timeoutSeconds: TimeInterval = WireMessage.presenceTimeoutSeconds) {
        self.timeoutSeconds = timeoutSeconds
    }

    @discardableResult
    public mutating func apply(_ message: WireMessage, at now: Date = .now) -> Bool {
        switch message {
        case .join(let payload):
            if let idx = participants.firstIndex(where: { $0.id == payload.participantID }) {
                participants[idx] = RoomParticipant(from: payload, now: now)
            } else {
                participants.append(RoomParticipant(from: payload, now: now))
            }
            return true

        case .leave(let payload):
            let before = participants.count
            participants.removeAll { $0.id == payload.participantID }
            return participants.count != before

        case .heartbeat(let payload):
            if let idx = participants.firstIndex(where: { $0.id == payload.participantID }) {
                participants[idx].lastHeartbeat = now
            }
            return false

        case .tasteVector(let participantID, let vector):
            if let idx = participants.firstIndex(where: { $0.id == participantID }) {
                participants[idx].tasteVector = vector
                participants[idx].lastHeartbeat = now
                return true
            }
            return false

        default:
            return false
        }
    }

    /// Drops any phone silent for longer than `timeoutSeconds` (default 6s).
    @discardableResult
    public mutating func pruneExpired(at now: Date = .now) -> [RoomParticipant] {
        let expired = participants.filter { now.timeIntervalSince($0.lastHeartbeat) > timeoutSeconds }
        if !expired.isEmpty {
            participants.removeAll { now.timeIntervalSince($0.lastHeartbeat) > timeoutSeconds }
        }
        return expired
    }
}
