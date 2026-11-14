import Foundation

public enum DiagnosisRulesConfig {
    public static let minReadingsForTrend = 3
    public static let staleReadingHours: Double = 6.0
    public static let gapBreakMinutes: Double = 90.0
    public static let implausibleJumpC: Double = 12.0
    public static let implausibleJumpWindowMinutes: Double = 45.0
    public static let watchMarginC: Double = 1.0
    public static let investigateSevereDeltaC: Double = 1.5
}

public struct DiagnosisEngine {
    public init() {}

    public func evaluateStatus(asset: Asset, readings: [TemperatureReading], now: Date = Date()) -> (status: AssetStatus, reason: String, qualityNotes: [String]) {
        let sorted = readings.sorted { $0.timestamp < $1.timestamp }
        var notes: [String] = []

        guard sorted.count >= DiagnosisRulesConfig.minReadingsForTrend else {
            let reason = sorted.isEmpty
                ? "No readings recorded yet."
                : "Only \(sorted.count) reading(s) logged; 3+ needed for trend evaluation."
            notes.append(reason)
            return (.insufficientData, reason, notes)
        }

        for idx in 1..<sorted.count {
            let gapMin = sorted[idx].timestamp.timeIntervalSince(sorted[idx - 1].timestamp) / 60.0
            let deltaC = abs(sorted[idx].normalizedCelsius - sorted[idx - 1].normalizedCelsius)
            if gapMin > DiagnosisRulesConfig.gapBreakMinutes {
                notes.append("Telemetry gap of \(Int(gapMin)) minutes detected; unmeasured intervals are not interpolated.")
            }
            if gapMin <= DiagnosisRulesConfig.implausibleJumpWindowMinutes && deltaC >= DiagnosisRulesConfig.implausibleJumpC {
                notes.append("Abrupt discontinuity of \(String(format: "%.1f", deltaC))°C detected.")
            }
        }

        let latest = sorted.last!
        let staleHours = now.timeIntervalSince(latest.timestamp) / 3600.0
        if staleHours > DiagnosisRulesConfig.staleReadingHours {
            notes.append("Latest reading is \(String(format: "%.1f", staleHours)) hours old.")
        }

        let recent = Array(sorted.suffix(6))
        let outRecent = recent.filter { $0.normalizedCelsius > asset.rangeMaxC || $0.normalizedCelsius < asset.rangeMinC }
        let maxExcursion = recent.reduce(0.0) { acc, r in
            if r.normalizedCelsius > asset.rangeMaxC { return max(acc, r.normalizedCelsius - asset.rangeMaxC) }
            if r.normalizedCelsius < asset.rangeMinC { return max(acc, asset.rangeMinC - r.normalizedCelsius) }
            return acc
        }

        if notes.contains(where: { $0.contains("discontinuity") }) ||
            (outRecent.count >= 2 && maxExcursion >= DiagnosisRulesConfig.investigateSevereDeltaC) {
            return (.investigate, "Sustained out-of-range excursion or abrupt sensor discontinuity observed.", notes)
        }

        if !outRecent.isEmpty || staleHours > DiagnosisRulesConfig.staleReadingHours || !notes.isEmpty {
            return (.watch, "Minor excursion, proximity to configured limits, or data-quality warning.", notes)
        }

        return (.normal, "Recent readings remain inside configured limits.", notes)
    }

    public func prepare(
        asset: Asset,
        readings: [TemperatureReading],
        events: [RecordedEvent],
        context: ResourceContext,
        now: Date = Date()
    ) -> Analysis {
        let sortedReadings = readings.sorted { $0.timestamp < $1.timestamp }
        let sortedEvents = events.sorted { $0.timestamp < $1.timestamp }
        let eval = evaluateStatus(asset: asset, readings: sortedReadings, now: now)

        var observations: [Observation] = []
        var obsIndex = 1
        func nextId() -> String {
            defer { obsIndex += 1 }
            return "obs-\(obsIndex)"
        }

        let highReadings = sortedReadings.filter { $0.normalizedCelsius > asset.rangeMaxC }
        var highObsId: String?
        if !highReadings.isEmpty {
            let id = nextId()
            highObsId = id
            observations.append(Observation(
                id: id,
                kind: "measured_fact",
                description: "\(highReadings.count) reading(s) exceeded configured maximum.",
                readingIds: highReadings.map(\.id),
                eventIds: [],
                timestamp: highReadings.last!.originalTimestamp
            ))
        }

        let doorEvents = sortedEvents.filter { $0.category == .doorOpen }
        var doorObsIds: [String] = []
        for ev in doorEvents {
            let id = nextId()
            doorObsIds.append(id)
            observations.append(Observation(
                id: id,
                kind: "user_event",
                description: "User recorded door event: \(ev.note)",
                readingIds: [],
                eventIds: [ev.id],
                timestamp: ev.originalTimestamp
            ))
        }

        let loadingEvents = sortedEvents.filter { $0.category == .stockDelivery || $0.category == .cleaning }
        var loadingObsIds: [String] = []
        for ev in loadingEvents {
            let id = nextId()
            loadingObsIds.append(id)
            observations.append(Observation(
                id: id,
                kind: "user_event",
                description: "User recorded loading/cleaning event: \(ev.note)",
                readingIds: [],
                eventIds: [ev.id],
                timestamp: ev.originalTimestamp
            ))
        }

        let defrostEvents = sortedEvents.filter { $0.category == .defrost }
        var defrostObsIds: [String] = []
        for ev in defrostEvents {
            let id = nextId()
            defrostObsIds.append(id)
            observations.append(Observation(
                id: id,
                kind: "user_event",
                description: "User recorded defrost note: \(ev.note)",
                readingIds: [],
                eventIds: [ev.id],
                timestamp: ev.originalTimestamp
            ))
        }

        var dqObsIds: [String] = []
        for note in eval.qualityNotes {
            let id = nextId()
            dqObsIds.append(id)
            observations.append(Observation(
                id: id,
                kind: "data_quality",
                description: note,
                readingIds: [],
                eventIds: [],
                timestamp: ISO8601DateFormatter().string(from: now)
            ))
        }

        let rawOptions: [DiagnosisOption] = [
            DiagnosisOption(
                id: "option-door-seal",
                hypothesis: "Door open or seal issue",
                status: (!doorEvents.isEmpty || !highReadings.isEmpty) ? "possible" : "not_enough_evidence",
                priorityLabel: "needs_more_evidence",
                availabilityStatus: "ready",
                plainLanguageExplanation: doorEvents.isEmpty
                    ? "Warm readings occurred, though no door event log confirms door activity."
                    : "A door event was logged alongside elevated readings.",
                supportingObservationIds: doorObsIds + (doorEvents.isEmpty ? [] : (highObsId.map { [$0] } ?? [])),
                conflictingObservationIds: [],
                assumptions: ["Assumes gasket integrity or latch closure affects cabinet air temperature."],
                missingInformation: doorEvents.isEmpty ? ["No door-open event or door-switch log recorded."] : [],
                counterfactualPrediction: "If a door or seal issue were responsible, temperature would rise during exposure and recover once sealed.",
                nextCheck: "Inspect door hinges, latch, and gasket perimeter; perform a paper grip check.",
                expectedResults: ExpectedResults(
                    supportsHypothesis: "Visible gasket gap, obstruction, or failed paper grip test.",
                    weakensHypothesis: "Door seals flush around full perimeter."
                ),
                requirements: CheckRequirements(estimatedMinutes: 5, skills: [.basicInspection], tools: [.flashlight, .gasketCard], risk: "low"),
                priorityFactors: [],
                rankScore: 0
            ),
            DiagnosisOption(
                id: "option-loading-ambient",
                hypothesis: "Recent loading or ambient heat",
                status: (!loadingEvents.isEmpty && !highReadings.isEmpty) ? "possible" : "not_enough_evidence",
                priorityLabel: "needs_more_evidence",
                availabilityStatus: "ready",
                plainLanguageExplanation: loadingEvents.isEmpty
                    ? "No stock delivery or ambient heat event was recorded by the user."
                    : "A loading or cleaning event was recorded alongside warm temperatures.",
                supportingObservationIds: loadingObsIds + (loadingEvents.isEmpty ? [] : (highObsId.map { [$0] } ?? [])),
                conflictingObservationIds: [],
                assumptions: ["Assumes incoming stock or ambient room temperature added thermal load."],
                missingInformation: loadingEvents.isEmpty ? ["No stock delivery or room-temperature note entered."] : [],
                counterfactualPrediction: "If loading caused the excursion, temperature should trend downward once doors stay closed.",
                nextCheck: "Confirm recent warm restocking and inspect condenser airflow clearance.",
                expectedResults: ExpectedResults(
                    supportsHypothesis: "Recent restocking confirmed and cabinet pulls down steadily.",
                    weakensHypothesis: "No loading occurred or temperature keeps rising."
                ),
                requirements: CheckRequirements(estimatedMinutes: 5, skills: [.basicInspection], tools: [], risk: "low"),
                priorityFactors: [],
                rankScore: 0
            ),
            DiagnosisOption(
                id: "option-defrost-cycle",
                hypothesis: "Defrost or operating-cycle variation",
                status: !defrostEvents.isEmpty ? "possible" : "not_enough_evidence",
                priorityLabel: "needs_more_evidence",
                availabilityStatus: "ready",
                plainLanguageExplanation: "Evaluates whether periodic warm peaks align with scheduled defrost or compressor cycles.",
                supportingObservationIds: defrostObsIds,
                conflictingObservationIds: [],
                assumptions: ["Assumes probe sits in airstream influenced by defrost cycles."],
                missingInformation: ["Defrost controller schedule is not directly connected."],
                counterfactualPrediction: "If driven by defrost, warm peaks occur periodically and recover cleanly inside range.",
                nextCheck: "Compare warm peak timestamps with posted defrost schedule.",
                expectedResults: ExpectedResults(
                    supportsHypothesis: "Peaks match defrost intervals and recover smoothly.",
                    weakensHypothesis: "Warm readings persist without recovery."
                ),
                requirements: CheckRequirements(estimatedMinutes: 10, skills: [.basicInspection], tools: [.flashlight], risk: "low"),
                priorityFactors: [],
                rankScore: 0
            ),
            DiagnosisOption(
                id: "option-sensor-quality",
                hypothesis: "Sensor or data-quality issue",
                status: !dqObsIds.isEmpty ? "possible" : "not_enough_evidence",
                priorityLabel: "needs_more_evidence",
                availabilityStatus: "ready",
                plainLanguageExplanation: "Checks for stale timestamps, gaps, sparse samples, or abrupt discontinuities without discarding data.",
                supportingObservationIds: dqObsIds,
                conflictingObservationIds: [],
                assumptions: ["Assumes logged values could diverge from air temperature if probe is dislodged or drifting."],
                missingInformation: ["No independent calibrated thermometer verification reading logged."],
                counterfactualPrediction: "If a sensor fault occurred, an independent calibrated thermometer would disagree with the logged probe.",
                nextCheck: "Take an independent calibrated thermometer reading and inspect probe placement.",
                expectedResults: ExpectedResults(
                    supportsHypothesis: "Independent thermometer differs noticeably or probe is dislodged.",
                    weakensHypothesis: "Independent thermometer matches logged temperature."
                ),
                requirements: CheckRequirements(estimatedMinutes: 10, skills: [.basicInspection], tools: [.calibratedThermometer, .flashlight], risk: "low"),
                priorityFactors: [],
                rankScore: 0
            ),
            DiagnosisOption(
                id: "option-system-escalation",
                hypothesis: "Refrigeration-system issue requiring technician assessment",
                status: eval.status == .investigate ? "possible" : "not_enough_evidence",
                priorityLabel: "requires_technician",
                availabilityStatus: "ready",
                plainLanguageExplanation: "Broad escalation when out-of-range conditions persist without a simpler operational explanation.",
                supportingObservationIds: highObsId.map { [$0] } ?? [],
                conflictingObservationIds: [],
                assumptions: ["Assumes simpler door, loading, and sensor causes do not account for excursion."],
                missingInformation: ["Compressor, fan, and refrigerant diagnostics require a qualified technician."],
                counterfactualPrediction: "If a mechanical issue exists, temperature stays out of range with doors sealed and sensor verified.",
                nextCheck: "Share exported PDF/JSON report with a qualified refrigeration technician.",
                expectedResults: ExpectedResults(
                    supportsHypothesis: "Doors sealed and thermometer verified, yet cabinet stays out of range.",
                    weakensHypothesis: "Unit recovers after simple operational fix."
                ),
                requirements: CheckRequirements(estimatedMinutes: 30, skills: [.refrigerationTechnician], tools: [.calibratedThermometer, .multimeter], risk: "elevated"),
                priorityFactors: [],
                rankScore: 0
            )
        ]

        let ranked = rankOptions(rawOptions, context: context)
        return Analysis(
            id: "analysis-\(Int(now.timeIntervalSince1970))",
            assetId: asset.id,
            generatedAt: now,
            statusAtAnalysis: eval.status,
            summary: eval.reason,
            dataQualityNotes: eval.qualityNotes,
            observations: observations,
            options: ranked
        )
    }

    public func rankOptions(_ options: [DiagnosisOption], context: ResourceContext) -> [DiagnosisOption] {
        return options.map { opt in
            var copy = opt
            var score = opt.status == "possible" ? 40 : 10
            score += min(25, opt.supportingObservationIds.count * 10)
            score -= min(20, opt.conflictingObservationIds.count * 8)

            var factors: [String] = []
            factors.append("Status: \(opt.status) (\(opt.supportingObservationIds.count) supporting)")

            let skillOk = opt.requirements.skills.allSatisfy { context.availableSkills.contains($0) }
            let missingTools = opt.requirements.tools.filter { !context.availableTools.contains($0) }
            let timeOk = context.availableMinutes == nil || opt.requirements.estimatedMinutes <= context.availableMinutes!

            if !skillOk {
                copy.availabilityStatus = "missing_skill"
                score -= 35
                factors.append("Requires technician skill not in resource context")
            } else if !timeOk {
                copy.availabilityStatus = "exceeds_time"
                score -= 22
                factors.append("Estimated \(opt.requirements.estimatedMinutes)m exceeds available time")
            } else if !missingTools.isEmpty {
                copy.availabilityStatus = "missing_tool"
                score -= 15
                factors.append("Missing tool(s): \(missingTools.map(\.rawValue).joined(separator: ", "))")
            } else {
                copy.availabilityStatus = "ready"
                score += 20
                factors.append("Feasible with available time, skills, and tools")
            }

            if opt.requirements.skills.contains(.refrigerationTechnician) {
                copy.priorityLabel = "requires_technician"
            } else if opt.status == "possible" && copy.availabilityStatus == "ready" && !opt.supportingObservationIds.isEmpty {
                copy.priorityLabel = "higher_priority_to_check"
            } else {
                copy.priorityLabel = "needs_more_evidence"
            }

            copy.priorityFactors = factors
            copy.rankScore = score
            return copy
        }.sorted { $0.rankScore > $1.rankScore }
    }
}
