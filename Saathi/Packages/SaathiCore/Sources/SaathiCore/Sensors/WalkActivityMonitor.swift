#if os(iOS)
import Foundation
import HealthKit
import CoreMotion

/// Watches the walk itself so the session can end on its own:
/// - HealthKit: notices when an Outdoor Walk / Hike workout recorded by the Apple Watch
///   (or iPhone) is saved, i.e. the user ended it, and reads its totals.
/// - CoreMotion: live steps/distance from the iPhone pedometer, and walking vs stationary
///   vs in-a-vehicle activity for the `WalkEndDetector`.
///
/// Privacy: only totals are read (distance, steps, energy, elevation). Workout routes
/// (`HKWorkoutRoute`, the GPS trace) are never requested or read.
@MainActor
public final class WalkActivityMonitor {
    public struct LiveStats: Sendable, Equatable {
        public var steps: Int
        public var distanceMeters: Double
        public var floorsAscended: Int

        public static let zero = LiveStats(steps: 0, distanceMeters: 0, floorsAscended: 0)
    }

    /// Totals captured from the workout the moment it is seen, so nothing non-Sendable is kept.
    struct WorkoutTotals: Sendable {
        let startedAt: Date
        let endedAt: Date
        let fromWatch: Bool
        let distanceMeters: Double?
        let activeEnergyKilocalories: Double?
        let elevationGainMeters: Double?
        let steps: Int?
    }

    public private(set) var liveStats = LiveStats.zero
    public private(set) var healthAuthorizationRequested = false

    private let healthStore: HKHealthStore? = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
    private let pedometer = CMPedometer()
    private let activityManager = CMMotionActivityManager()
    private var observerQuery: HKObserverQuery?
    private var sessionStart: Date?
    private var endedWorkout: WorkoutTotals?
    private var onWorkoutEnded: (@MainActor () -> Void)?

    public init() {}

    public var isHealthAvailable: Bool { healthStore != nil }

    /// Read-only HealthKit access: workouts and the quantities used for the walk summary.
    @discardableResult
    public func requestHealthAuthorization() async -> Bool {
        guard let healthStore else { return false }
        healthAuthorizationRequested = true
        let readTypes: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.stepCount),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.activeEnergyBurned)
            // Deliberately NOT HKSeriesType.workoutRoute(): Saathi never reads GPS traces.
        ]
        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            return true
        } catch {
            return false
        }
    }

    public func start(
        sessionStart: Date,
        onLiveStats: @escaping @MainActor (LiveStats) -> Void,
        onMotion: @escaping @MainActor (WalkMotionState) -> Void,
        onWorkoutEnded: @escaping @MainActor () -> Void
    ) {
        stop()
        self.sessionStart = sessionStart
        self.onWorkoutEnded = onWorkoutEnded
        liveStats = .zero
        endedWorkout = nil

        if CMPedometer.isStepCountingAvailable() {
            Self.startPedometer(pedometer, from: sessionStart) { [weak self] stats in
                Task { @MainActor in
                    self?.liveStats = stats
                    onLiveStats(stats)
                }
            }
        }

        if CMMotionActivityManager.isActivityAvailable() {
            activityManager.startActivityUpdates(to: .main) { activity in
                guard let activity else { return }
                let state = Self.motionState(from: activity)
                MainActor.assumeIsolated { onMotion(state) }
            }
        }

        if let healthStore {
            let query = Self.makeWorkoutObserver { [weak self] in
                Task { @MainActor in await self?.checkForEndedWalkWorkout() }
            }
            observerQuery = query
            healthStore.execute(query)
        }
    }

    // CMPedometer and HKObserverQuery call their handlers on their own background queues.
    // Closures written inside this @MainActor class would be inferred main-actor isolated
    // and Swift 6 traps (`_dispatch_assert_queue_fail`) when they run off the main thread.
    // These nonisolated helpers build the closures outside the actor and only hand
    // Sendable values to a `@Sendable` callback, which hops to the main actor itself.

    private nonisolated static func startPedometer(
        _ pedometer: CMPedometer,
        from start: Date,
        onStats: @escaping @Sendable (LiveStats) -> Void
    ) {
        pedometer.startUpdates(from: start) { data, _ in
            guard let data else { return }
            onStats(LiveStats(
                steps: data.numberOfSteps.intValue,
                distanceMeters: data.distance?.doubleValue ?? 0,
                floorsAscended: data.floorsAscended?.intValue ?? 0
            ))
        }
    }

    private nonisolated static func makeWorkoutObserver(
        onChange: @escaping @Sendable () -> Void
    ) -> HKObserverQuery {
        HKObserverQuery(sampleType: HKObjectType.workoutType(), predicate: nil) { _, completion, _ in
            completion()
            onChange()
        }
    }

    public func stop() {
        pedometer.stopUpdates()
        activityManager.stopActivityUpdates()
        if let observerQuery, let healthStore {
            healthStore.stop(observerQuery)
        }
        observerQuery = nil
        onWorkoutEnded = nil
    }

    /// Builds the end-of-walk summary: the watch/iPhone workout if one was recorded during the
    /// session, otherwise pedometer totals, otherwise just the session clock.
    public func buildSummary(endedAt: Date, reason: WalkEndReason) async -> WalkSummary {
        let start = sessionStart ?? endedAt
        if endedWorkout == nil, healthStore != nil {
            // The user may end Saathi first and the watch workout moments later, or the
            // workout may have been saved without an observer callback (e.g. app suspended).
            await checkForEndedWalkWorkout(notify: false)
        }
        if let workout = endedWorkout {
            return WalkSummary(
                startedAt: min(start, workout.startedAt),
                endedAt: max(endedAt, workout.endedAt),
                source: workout.fromWatch ? .appleWatchWorkout : .iPhoneWorkout,
                distanceMeters: workout.distanceMeters,
                steps: workout.steps ?? (liveStats.steps > 0 ? liveStats.steps : nil),
                activeEnergyKilocalories: workout.activeEnergyKilocalories,
                elevationGainMeters: workout.elevationGainMeters,
                endReason: reason
            )
        }
        if liveStats.steps > 0 {
            return WalkSummary(
                startedAt: start,
                endedAt: endedAt,
                source: .iPhonePedometer,
                distanceMeters: liveStats.distanceMeters > 0 ? liveStats.distanceMeters : nil,
                steps: liveStats.steps,
                elevationGainMeters: liveStats.floorsAscended > 0 ? Double(liveStats.floorsAscended) * 3.0 : nil,
                endReason: reason
            )
        }
        return WalkSummary(startedAt: start, endedAt: endedAt, source: .sessionClockOnly, endReason: reason)
    }

    // MARK: - HealthKit

    private func checkForEndedWalkWorkout(notify: Bool = true) async {
        guard let healthStore, let sessionStart, endedWorkout == nil else { return }
        // Accept a workout started up to 30 min before Saathi (user started the watch first).
        let earliest = sessionStart.addingTimeInterval(-30 * 60)
        let timePredicate = HKQuery.predicateForSamples(withStart: earliest, end: nil, options: [])
        let walkPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            HKQuery.predicateForWorkouts(with: .walking),
            HKQuery.predicateForWorkouts(with: .hiking)
        ])
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(NSCompoundPredicate(andPredicateWithSubpredicates: [timePredicate, walkPredicate]))],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 5
        )
        guard let workouts = try? await descriptor.result(for: healthStore) else { return }
        // Outdoor only, and it must have ended after the Saathi session began.
        guard let workout = workouts.first(where: { workout in
            let indoor = (workout.metadata?[HKMetadataKeyIndoorWorkout] as? Bool) ?? false
            return !indoor && workout.endDate > sessionStart
        }) else { return }

        let steps = await stepCount(from: workout.startDate, to: workout.endDate)
        let elevation = (workout.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity)?.doubleValue(for: .meter())
        let productType = workout.sourceRevision.productType ?? ""
        let fromWatch = productType.hasPrefix("Watch") || workout.device?.model == "Watch"

        endedWorkout = WorkoutTotals(
            startedAt: workout.startDate,
            endedAt: workout.endDate,
            fromWatch: fromWatch,
            distanceMeters: workout.statistics(for: HKQuantityType(.distanceWalkingRunning))?
                .sumQuantity()?.doubleValue(for: .meter()),
            activeEnergyKilocalories: workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
                .sumQuantity()?.doubleValue(for: .kilocalorie()),
            elevationGainMeters: elevation,
            steps: steps
        )
        if notify { onWorkoutEnded?() }
    }

    private func stepCount(from start: Date, to end: Date) async -> Int? {
        guard let healthStore else { return nil }
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(
                type: HKQuantityType(.stepCount),
                predicate: HKQuery.predicateForSamples(withStart: start, end: end)
            ),
            options: .cumulativeSum
        )
        guard let value = try? await descriptor.result(for: healthStore)?
            .sumQuantity()?.doubleValue(for: .count()) else { return nil }
        return Int(value)
    }

    // MARK: - CoreMotion

    nonisolated static func motionState(from activity: CMMotionActivity) -> WalkMotionState {
        guard activity.confidence != .low else { return .unknown }
        if activity.automotive { return .automotive }
        if activity.cycling { return .cycling }
        if activity.running { return .running }
        if activity.walking { return .walking }
        if activity.stationary { return .stationary }
        return .unknown
    }
}
#endif
