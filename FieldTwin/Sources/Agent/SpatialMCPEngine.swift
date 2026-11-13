import Foundation
import Observation

@Observable
@MainActor
final class SpatialMCPEngine {
    var activeRoom: RoomSpaceID = .serverRack
    var devices: [SpatialDevice] = RoomSeedCatalog.devices(for: .serverRack)
    var selectedDeviceId: String? = RoomSeedCatalog.devices(for: .serverRack).first?.id
    var viewLayer: ViewLayerMode = .pbr
    var signals: [MultimodalSignal] = []
    var proposals: [MCPProposal] = []
    var auditLog: [AuditEntry] = []
    var isScanningLiDAR: Bool = false
    var latestInferenceSummary = ""

    var selectedDevice: SpatialDevice? {
        devices.first(where: { $0.id == selectedDeviceId }) ?? devices.first
    }

    var pendingProposal: MCPProposal? {
        proposals.first(where: { $0.isPending })
    }

    func switchRoom(to room: RoomSpaceID) {
        activeRoom = room
        devices = RoomSeedCatalog.devices(for: room)
        selectedDeviceId = devices.first?.id
        signals.removeAll()
        proposals.removeAll(where: { $0.isPending })
    }

    func resetNominal() {
        devices = RoomSeedCatalog.devices(for: activeRoom)
        signals.removeAll()
        for idx in proposals.indices where proposals[idx].isPending {
            proposals[idx].isPending = false
        }
    }

    func pulseLiDARScan() {
        isScanningLiDAR = true
        viewLayer = .lidar
        signals.insert(
            MultimodalSignal(
                source: "LiDAR",
                timestamp: .now,
                summary: "RoomPlan mesh refreshed (\(devices.count) semantic anchors locked).",
                deviceId: selectedDevice?.id ?? ""
            ),
            at: 0
        )
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            isScanningLiDAR = false
        }
    }

    func updateTelemetry(
        for deviceId: String,
        temperatureC: Double,
        airflowCfm: Double,
        acousticDb: Double
    ) {
        guard let idx = devices.firstIndex(where: { $0.id == deviceId }) else { return }
        clearPendingProposals(for: deviceId)
        devices[idx].temperatureC = temperatureC
        devices[idx].airflowCfm = airflowCfm
        devices[idx].acousticDb = acousticDb
        signals.insert(
            MultimodalSignal(
                source: "User telemetry",
                timestamp: .now,
                summary: "Updated temperature, airflow, and acoustic readings.",
                deviceId: deviceId
            ),
            at: 0
        )
    }

    func analyzeTelemetry() {
        clearPendingProposals()
        guard let (device, inference) = devices
            .compactMap({ device -> (SpatialDevice, TelemetryInference)? in
                guard let inference = LocalTelemetryModel.infer(from: device) else { return nil }
                return (device, inference)
            })
            .max(by: { $0.1.score < $1.1.score }) else {
            latestInferenceSummary = "No anomaly exceeded the local model threshold in the current readings."
            signals.insert(
                MultimodalSignal(
                    source: "Local model",
                    timestamp: .now,
                    summary: latestInferenceSummary,
                    deviceId: selectedDevice?.id ?? ""
                ),
                at: 0
            )
            return
        }

        guard let tool = device.tools
            .filter({ $0.riskTier != .tier1AutoRead })
            .max(by: { $0.riskTier.rawValue < $1.riskTier.rawValue }) else {
            latestInferenceSummary = "\(inference.rationale) No non-read action is configured for this device."
            return
        }

        let scorePercent = Int(inference.score * 100)
        latestInferenceSummary = "\(inference.rationale) Model risk score: \(scorePercent)%. Review the proposed action before approval."
        enqueueProposal(
            title: tool.label,
            deviceId: device.id,
            deviceName: device.name,
            toolName: tool.name,
            rationale: inference.rationale,
            riskTier: tool.riskTier,
            confidence: inference.score,
            blastRadius: [
                tool.summary,
                "Local model risk score: \(scorePercent)% (not a calibrated probability)."
            ],
            rollbackPlan: "Review and restore baseline parameters on \(device.name)."
        )
    }

    func triggerScenario(_ scenario: FaultScenario) {
        devices = RoomSeedCatalog.devices(for: activeRoom)
        for idx in proposals.indices where proposals[idx].isPending {
            proposals[idx].isPending = false
        }

        switch scenario.id {
        case "rack_intake_clog":
            updateDevice("rack_intake_plenum") { dev in
                dev.status = .elevated
                dev.airflowCfm = 52
                dev.primaryMetric = "52 CFM (Occluded)"
            }
            updateDevice("rack_compute_4u") { dev in
                dev.status = .critical
                dev.temperatureC = 84.6
                dev.primaryMetric = "84.6 °C"
            }
            recordAutoTier1(deviceName: "Compute Node 4U", toolName: "poll_bmc_telemetry")
            enqueueProposal(
                title: "Open Auxiliary Intake Damper",
                deviceId: "rack_intake_plenum",
                deviceName: "Intake Plenum & Mic Array",
                toolName: "open_bypass_damper",
                rationale: "Camera segmentation shows 78% dust matting starving Compute Node 4U.",
                riskTier: .tier2TapConfirm,
                confidence: 0.94,
                blastRadius: [
                    "Moves intake louver servo from 20% to 85%",
                    "Compute Node 4U cools below 55 °C within 45 s"
                ],
                rollbackPlan: "Close bypass louver back to 20%."
            )

        case "coolant_cavitation":
            updateDevice("rack_coolant_manifold") { dev in
                dev.status = .critical
                dev.temperatureC = 54.2
                dev.acousticDb = 66
                dev.primaryMetric = "1.2 L/min (Cavitation)"
            }
            recordAutoTier1(deviceName: "Coolant Manifold & Pump", toolName: "sample_pressure_transducer")
            enqueueProposal(
                title: "Isolate Coolant Loop Brass Valve",
                deviceId: "rack_coolant_manifold",
                deviceName: "Coolant Manifold & Pump",
                toolName: "actuate_solenoid_valve",
                rationale: "Acoustic array localized 2.4 kHz cavitation whine with line pressure drop.",
                riskTier: .tier3HoldPhysical,
                confidence: 0.91,
                blastRadius: [
                    "Cuts direct-to-chip coolant flow to Compute Node 4U",
                    "Rotates motorized brass isolation valve 90° closed"
                ],
                rollbackPlan: "Re-open valve after coolant reservoir bleed."
            )

        case "water_leak_detected":
            updateDevice("home_water_solenoid") { dev in
                dev.status = .critical
                dev.primaryMetric = "Open · 2.8 GPM Flow"
            }
            recordAutoTier1(deviceName: "Main Water Solenoid", toolName: "poll_flow_ultrasonic")
            enqueueProposal(
                title: "Shut Off Main Apartment Water Solenoid",
                deviceId: "home_water_solenoid",
                deviceName: "Main Water Solenoid",
                toolName: "actuate_solenoid_valve",
                rationale: "Floor moisture sensor + continuous 2.8 GPM flow indicates active plumbing leak.",
                riskTier: .tier3HoldPhysical,
                confidence: 0.97,
                blastRadius: [
                    "Cuts cold and hot domestic water to entire apartment",
                    "Rotates 3/4-in brass ball valve 90° closed"
                ],
                rollbackPlan: "Re-open solenoid once leak is repaired."
            )

        default:
            guard let target = devices.first else { return }
            updateDevice(target.id) { dev in
                dev.status = .critical
                dev.temperatureC += 28
                dev.primaryMetric = String(format: "%.1f °C (Alert)", dev.temperatureC)
            }
            if let tool = target.tools.last {
                enqueueProposal(
                    title: tool.label,
                    deviceId: target.id,
                    deviceName: target.name,
                    toolName: tool.name,
                    rationale: scenario.detail,
                    riskTier: tool.riskTier,
                    confidence: 0.93,
                    blastRadius: [tool.summary],
                    rollbackPlan: "Revert device setpoint via MCP."
                )
            }
        }
    }

    func invokeTool(_ tool: MCPToolSpec, on device: SpatialDevice) {
        if tool.riskTier == .tier1AutoRead {
            recordAutoTier1(deviceName: device.name, toolName: tool.name)
            return
        }
        enqueueProposal(
            title: "\(tool.label) (\(device.shortLabel))",
            deviceId: device.id,
            deviceName: device.name,
            toolName: tool.name,
            rationale: tool.summary,
            riskTier: tool.riskTier,
            confidence: 0.99,
            blastRadius: [tool.summary],
            rollbackPlan: "Restore baseline parameters on \(device.name)."
        )
    }

    func approveProposal(_ proposal: MCPProposal, actor: String) {
        guard let idx = proposals.firstIndex(where: { $0.id == proposal.id }) else { return }
        proposals[idx].isPending = false

        updateDevice(proposal.deviceId) { dev in
            if proposal.toolName == "actuate_solenoid_valve" {
                dev.valveOpen = false
                dev.status = .isolated
                dev.primaryMetric = "Isolated · 0 Flow"
            } else if proposal.toolName == "open_bypass_damper" || proposal.toolName == "adjust_hepa_damper" {
                dev.damperPct = 90
                dev.airflowCfm = 152
                dev.status = .nominal
                dev.primaryMetric = "152 CFM (Bypass)"
            } else {
                dev.status = .nominal
                dev.temperatureC = max(24, dev.temperatureC - 22)
                dev.primaryMetric = String(format: "%.1f °C", dev.temperatureC)
            }
        }

        auditLog.insert(
            AuditEntry(
                timestamp: .now,
                actor: actor,
                deviceName: proposal.deviceName,
                toolName: proposal.toolName,
                riskTier: proposal.riskTier,
                outcome: "Executed",
                latencyMs: actor == "iPhone Companion" ? 34 : 18
            ),
            at: 0
        )
    }

    func dismissProposal(_ proposal: MCPProposal) {
        guard let idx = proposals.firstIndex(where: { $0.id == proposal.id }) else { return }
        proposals[idx].isPending = false
        auditLog.insert(
            AuditEntry(
                timestamp: .now,
                actor: "iPad AR Gate",
                deviceName: proposal.deviceName,
                toolName: proposal.toolName,
                riskTier: proposal.riskTier,
                outcome: "Dismissed",
                latencyMs: 9
            ),
            at: 0
        )
    }

    private func updateDevice(_ id: String, mutate: (inout SpatialDevice) -> Void) {
        guard let idx = devices.firstIndex(where: { $0.id == id }) else { return }
        mutate(&devices[idx])
        selectedDeviceId = id
    }

    private func clearPendingProposals(for deviceId: String? = nil) {
        for idx in proposals.indices where proposals[idx].isPending {
            if deviceId == nil || proposals[idx].deviceId == deviceId {
                proposals[idx].isPending = false
            }
        }
    }

    private func recordAutoTier1(deviceName: String, toolName: String) {
        auditLog.insert(
            AuditEntry(
                timestamp: .now,
                actor: "Agent Auto · Tier 1",
                deviceName: deviceName,
                toolName: toolName,
                riskTier: .tier1AutoRead,
                outcome: "Executed",
                latencyMs: 12
            ),
            at: 0
        )
    }

    private func enqueueProposal(
        title: String,
        deviceId: String,
        deviceName: String,
        toolName: String,
        rationale: String,
        riskTier: RiskTier,
        confidence: Double,
        blastRadius: [String],
        rollbackPlan: String
    ) {
        proposals.insert(
            MCPProposal(
                title: title,
                deviceId: deviceId,
                deviceName: deviceName,
                toolName: toolName,
                rationale: rationale,
                riskTier: riskTier,
                confidence: confidence,
                blastRadius: blastRadius,
                rollbackPlan: rollbackPlan,
                createdAt: .now
            ),
            at: 0
        )
        signals.insert(
            MultimodalSignal(
                source: "Triage",
                timestamp: .now,
                summary: rationale,
                deviceId: deviceId
            ),
            at: 0
        )
        selectedDeviceId = deviceId
    }
}
