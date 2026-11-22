import Foundation

/// Aggregate facts about the walk, taken at the end of the session from an Apple Watch or
/// iPhone workout (HealthKit) or, without one, from the iPhone pedometer.
/// Totals only: the workout route (GPS trace) is never read, so this holds no coordinates.
public struct WalkSummary: Sendable, Codable, Equatable {
    public enum Source: String, Sendable, Codable {
        case appleWatchWorkout
        case iPhoneWorkout
        case iPhonePedometer
        case sessionClockOnly
    }

    public let startedAt: Date
    public let endedAt: Date
    public let source: Source
    public let distanceMeters: Double?
    public let steps: Int?
    public let activeEnergyKilocalories: Double?
    public let elevationGainMeters: Double?
    public let endReason: WalkEndReason

    public init(
        startedAt: Date,
        endedAt: Date,
        source: Source,
        distanceMeters: Double? = nil,
        steps: Int? = nil,
        activeEnergyKilocalories: Double? = nil,
        elevationGainMeters: Double? = nil,
        endReason: WalkEndReason
    ) {
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.source = source
        self.distanceMeters = distanceMeters
        self.steps = steps
        self.activeEnergyKilocalories = activeEnergyKilocalories
        self.elevationGainMeters = elevationGainMeters
        self.endReason = endReason
    }

    public var durationSeconds: TimeInterval { max(0, endedAt.timeIntervalSince(startedAt)) }

    /// English sentence for the episode intro (translated downstream like other English text).
    public func spokenSummary() -> String {
        var parts: [String] = []
        if let distanceMeters, distanceMeters >= 50 {
            let km = distanceMeters / 1000
            parts.append(String(format: "You walked %.1f kilometres in %@", km, Self.spokenDuration(durationSeconds)))
        } else {
            parts.append("You spent \(Self.spokenDuration(durationSeconds)) exploring")
        }
        if let steps, steps > 0 {
            let formatted = NumberFormatter.localizedString(from: NSNumber(value: steps), number: .decimal)
            parts.append("about \(formatted) steps")
        }
        if let elevationGainMeters, elevationGainMeters >= 5 {
            parts.append("climbing \(Int(elevationGainMeters.rounded())) metres")
        }
        var sentence = parts.joined(separator: ", ") + "."
        switch source {
        case .appleWatchWorkout: sentence += " Your Apple Watch recorded the walk."
        case .iPhoneWorkout: sentence += " Your iPhone recorded the walk."
        case .iPhonePedometer, .sessionClockOnly: break
        }
        return sentence
    }

    static func spokenDuration(_ seconds: TimeInterval) -> String {
        let totalMinutes = max(1, Int((seconds / 60).rounded()))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        switch (hours, minutes) {
        case (0, let m): return "\(m) minute\(m == 1 ? "" : "s")"
        case (let h, 0): return "\(h) hour\(h == 1 ? "" : "s")"
        case (let h, let m): return "\(h) hour\(h == 1 ? "" : "s") \(m) minute\(m == 1 ? "" : "s")"
        }
    }
}

public enum WalkMotionState: String, Sendable, Codable {
    case walking
    case running
    case cycling
    case stationary
    case automotive
    case unknown
}

public enum WalkEndReason: String, Sendable, Codable {
    case workoutEnded
    case stoppedMoving
    case leftByVehicle
    case safetyCap
    case userEnded
}

public enum WalkEndDecision: Sendable, Equatable {
    case keepGoing
    case askToWrapUp(WalkEndReason)
    case end(WalkEndReason)
}

/// Decides when a walk is over, so the user never has to pick a duration up front.
///
/// Signals, strongest first:
/// 1. The Apple Watch / iPhone Outdoor Walk workout ends → end immediately.
/// 2. iPhone motion: in a vehicle for a while, or stationary for a long time → ask
///    "Shall I wrap up your walk?", then end if there is no answer and still no walking.
///    While a workout is active, long stationary stretches are ignored (the workout decides).
/// 3. A safety cap so location never runs indefinitely if everything else fails.
/// Pure value type: unit-tested without sensors.
public struct WalkEndDetector: Sendable, Equatable {
    public struct Settings: Sendable, Codable, Equatable {
        public var stationaryAskAfterSeconds: TimeInterval
        public var vehicleAskAfterSeconds: TimeInterval
        public var autoEndAfterAskSeconds: TimeInterval
        public var maxSessionSeconds: TimeInterval

        public init(
            stationaryAskAfterSeconds: TimeInterval = 600,
            vehicleAskAfterSeconds: TimeInterval = 120,
            autoEndAfterAskSeconds: TimeInterval = 300,
            maxSessionSeconds: TimeInterval = 6 * 3600
        ) {
            self.stationaryAskAfterSeconds = stationaryAskAfterSeconds
            self.vehicleAskAfterSeconds = vehicleAskAfterSeconds
            self.autoEndAfterAskSeconds = autoEndAfterAskSeconds
            self.maxSessionSeconds = maxSessionSeconds
        }

        public static let `default` = Settings()
    }

    public let settings: Settings
    public let sessionStart: Date
    public private(set) var workoutActive = false
    public private(set) var currentState: WalkMotionState = .unknown
    private var nonWalkingSince: Date?
    private var askedAt: Date?
    private var askedReason: WalkEndReason?
    private var snoozedUntil: Date?

    public init(sessionStart: Date, settings: Settings = .default) {
        self.sessionStart = sessionStart
        self.settings = settings
    }

    public var isAwaitingWrapUpAnswer: Bool { askedAt != nil }

    public mutating func setWorkoutActive(_ active: Bool) {
        workoutActive = active
    }

    public mutating func recordMotion(_ state: WalkMotionState, at time: Date) {
        switch state {
        case .walking, .running:
            // Moving on foot again: cancel any pending wrap-up question.
            nonWalkingSince = nil
            askedAt = nil
            askedReason = nil
        case .unknown:
            break // no information; keep the previous state's clock running
        case .stationary, .automotive, .cycling:
            if currentState != state { nonWalkingSince = time }
        }
        if state != .unknown { currentState = state }
    }

    /// The watch/iPhone workout finished: the walk is over.
    public mutating func recordWorkoutEnded() -> WalkEndDecision {
        workoutActive = false
        return .end(.workoutEnded)
    }

    /// User said "no, keep going" to the wrap-up question.
    public mutating func userDeclinedWrapUp(at time: Date) {
        askedAt = nil
        askedReason = nil
        nonWalkingSince = time
        snoozedUntil = time.addingTimeInterval(settings.stationaryAskAfterSeconds)
    }

    public mutating func evaluate(at now: Date) -> WalkEndDecision {
        if now.timeIntervalSince(sessionStart) >= settings.maxSessionSeconds {
            return .end(.safetyCap)
        }
        if let askedAt, let askedReason {
            return now.timeIntervalSince(askedAt) >= settings.autoEndAfterAskSeconds ? .end(askedReason) : .keepGoing
        }
        if let snoozedUntil, now < snoozedUntil { return .keepGoing }
        guard let since = nonWalkingSince else { return .keepGoing }
        let elapsed = now.timeIntervalSince(since)

        switch currentState {
        case .automotive, .cycling:
            if elapsed >= settings.vehicleAskAfterSeconds { return ask(.leftByVehicle, at: now) }
        case .stationary where !workoutActive:
            if elapsed >= settings.stationaryAskAfterSeconds { return ask(.stoppedMoving, at: now) }
        default:
            break
        }
        return .keepGoing
    }

    private mutating func ask(_ reason: WalkEndReason, at now: Date) -> WalkEndDecision {
        askedAt = now
        askedReason = reason
        return .askToWrapUp(reason)
    }
}

/// Plain-language compass direction used when talking about places farther away.
public enum CompassDirection {
    public static func spoken(bearingDegrees: Double) -> String {
        let names = ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
        let normalized = (bearingDegrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        let index = Int((normalized + 22.5) / 45) % 8
        return names[index]
    }

    public static func spokenDistance(meters: Double) -> String {
        if meters < 950 {
            return "about \(Int((meters / 50).rounded()) * 50) metres"
        }
        return String(format: "about %.1f kilometres", meters / 1000)
    }
}
