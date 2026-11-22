import Foundation

/// Enforces unprompted narration pacing:
/// - At most 1 unprompted segment every 3 minutes (180s)
/// - Never interrupts while user is speaking
/// - Honours "quiet for N minutes" requests
public struct InterruptionBudget: Sendable, Equatable {
    public let minIntervalSeconds: TimeInterval
    public private(set) var lastUnpromptedAt: Date?
    public private(set) var quietUntil: Date?
    public private(set) var isUserSpeaking: Bool = false

    public init(minIntervalSeconds: TimeInterval = 180.0) {
        self.minIntervalSeconds = minIntervalSeconds
    }

    public mutating func setUserSpeaking(_ speaking: Bool) {
        isUserSpeaking = speaking
    }

    public mutating func requestQuiet(minutes: Int, now: Date = Date()) {
        let clamped = max(1, minutes)
        quietUntil = now.addingTimeInterval(TimeInterval(clamped * 60))
    }

    public mutating func cancelQuiet() {
        quietUntil = nil
    }

    public func isQuietActive(at now: Date = Date()) -> Bool {
        guard let quietUntil else { return false }
        return now < quietUntil
    }

    public func canDeliverUnpromptedSegment(at now: Date = Date()) -> Bool {
        if isUserSpeaking { return false }
        if isQuietActive(at: now) { return false }
        if let lastUnpromptedAt {
            return now.timeIntervalSince(lastUnpromptedAt) >= minIntervalSeconds
        }
        return true
    }

    public mutating func recordUnpromptedDelivery(at now: Date = Date()) {
        lastUnpromptedAt = now
    }
}
