import Foundation
import simd

enum RoomSpaceID: String, CaseIterable, Identifiable, Codable, Sendable {
    case serverRack = "server_rack"
    case makerWorkshop = "maker_workshop"
    case utilityCloset = "utility_closet"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .serverRack: return "Edge Cluster Rack 04"
        case .makerWorkshop: return "Fabrication Bay 02"
        case .utilityCloset: return "Apartment Utility Core"
        }
    }
}

enum ViewLayerMode: String, CaseIterable, Identifiable, Sendable {
    case pbr = "PBR Twin"
    case lidar = "LiDAR Mesh"
    case thermal = "Thermal"

    var id: String { rawValue }
}

enum RiskTier: Int, Codable, Sendable {
    case tier1AutoRead = 1
    case tier2TapConfirm = 2
    case tier3HoldPhysical = 3

    var label: String {
        switch self {
        case .tier1AutoRead: return "Tier 1 · Telemetry Read"
        case .tier2TapConfirm: return "Tier 2 · Tap Confirm"
        case .tier3HoldPhysical: return "Tier 3 · Physical Hazard Gate"
        }
    }
}

enum DeviceHealth: String, Codable, Sendable {
    case nominal = "Nominal"
    case elevated = "Elevated"
    case critical = "Critical"
    case isolated = "Isolated"
}

struct MCPToolSpec: Identifiable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let label: String
    let summary: String
    let riskTier: RiskTier
    let parameterSummary: String
}

struct SpatialDevice: Identifiable, Sendable {
    let id: String
    let room: RoomSpaceID
    let name: String
    let shortLabel: String
    let role: String
    let mcpEndpoint: String
    let position: SIMD3<Float>
    let bounds: SIMD3<Float>
    var status: DeviceHealth
    var temperatureC: Double
    var powerWatts: Double
    var airflowCfm: Double
    var acousticDb: Double
    var primaryMetric: String
    var valveOpen: Bool = true
    var damperPct: Double = 25
    let tools: [MCPToolSpec]
}

struct MultimodalSignal: Identifiable, Sendable {
    let id = UUID()
    let source: String
    let timestamp: Date
    let summary: String
    let deviceId: String
}

struct MCPProposal: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let deviceId: String
    let deviceName: String
    let toolName: String
    let rationale: String
    let riskTier: RiskTier
    let confidence: Double
    let blastRadius: [String]
    let rollbackPlan: String
    let createdAt: Date
    var isPending: Bool = true
}

struct AuditEntry: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let actor: String
    let deviceName: String
    let toolName: String
    let riskTier: RiskTier
    let outcome: String
    let latencyMs: Int
}

struct FaultScenario: Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String
    let room: RoomSpaceID
}

enum RoomSeedCatalog {
    static func devices(for room: RoomSpaceID) -> [SpatialDevice] {
        switch room {
        case .serverRack:
            return [
                SpatialDevice(
                    id: "rack_compute_4u",
                    room: .serverRack,
                    name: "Compute Node 4U",
                    shortLabel: "Node 4U",
                    role: "Primary ML Inference Blade",
                    mcpEndpoint: "mcp://rack04/ipmi-compute",
                    position: SIMD3<Float>(0, 1.02, 0.04),
                    bounds: SIMD3<Float>(0.62, 0.24, 0.72),
                    status: .nominal,
                    temperatureC: 46.2,
                    powerWatts: 680,
                    airflowCfm: 92,
                    acousticDb: 48,
                    primaryMetric: "46.2 °C",
                    tools: [
                        MCPToolSpec(name: "poll_bmc_telemetry", label: "Poll BMC Sensors", summary: "Reads VRM, NVMe SMART, and tachometers.", riskTier: .tier1AutoRead, parameterSummary: "{ target: all }"),
                        MCPToolSpec(name: "set_fan_curve", label: "Boost Fan Curve", summary: "Sets chassis fan PWM to 85%.", riskTier: .tier2TapConfirm, parameterSummary: "{ pwmPct: 85 }")
                    ]
                ),
                SpatialDevice(
                    id: "rack_coolant_manifold",
                    room: .serverRack,
                    name: "Coolant Manifold & Pump",
                    shortLabel: "Coolant Loop",
                    role: "Direct-to-Chip Closed Loop",
                    mcpEndpoint: "mcp://rack04/coolant-plc",
                    position: SIMD3<Float>(0, 0.56, 0.02),
                    bounds: SIMD3<Float>(0.62, 0.28, 0.68),
                    status: .nominal,
                    temperatureC: 31.8,
                    powerWatts: 95,
                    airflowCfm: 0,
                    acousticDb: 44,
                    primaryMetric: "4.8 L/min",
                    tools: [
                        MCPToolSpec(name: "sample_pressure_transducer", label: "Sample Loop Pressure", summary: "Captures 200 Hz pressure trace.", riskTier: .tier1AutoRead, parameterSummary: "{ hz: 200 }"),
                        MCPToolSpec(name: "actuate_solenoid_valve", label: "Close Isolation Valve", summary: "Rotates motorized brass valve 90° closed.", riskTier: .tier3HoldPhysical, parameterSummary: "{ valveOpen: false }")
                    ]
                ),
                SpatialDevice(
                    id: "rack_intake_plenum",
                    room: .serverRack,
                    name: "Intake Plenum & Mic Array",
                    shortLabel: "Intake Plenum",
                    role: "Filtered Cold-Aisle Intake",
                    mcpEndpoint: "mcp://rack04/env-plenum",
                    position: SIMD3<Float>(0, 0.20, 0.16),
                    bounds: SIMD3<Float>(0.64, 0.24, 0.50),
                    status: .nominal,
                    temperatureC: 22.4,
                    powerWatts: 28,
                    airflowCfm: 145,
                    acousticDb: 41,
                    primaryMetric: "145 CFM",
                    tools: [
                        MCPToolSpec(name: "open_bypass_damper", label: "Open Bypass Damper", summary: "Opens auxiliary intake louver to 85%.", riskTier: .tier2TapConfirm, parameterSummary: "{ bypassPct: 85 }")
                    ]
                )
            ]
        case .makerWorkshop:
            return [
                SpatialDevice(
                    id: "shop_corexy_printer",
                    room: .makerWorkshop,
                    name: "CoreXY 3D Printer",
                    shortLabel: "CoreXY Rig",
                    role: "High-Speed Enclosure Fab",
                    mcpEndpoint: "mcp://fab02/klipper-corexy",
                    position: SIMD3<Float>(-0.58, 1.05, 0),
                    bounds: SIMD3<Float>(0.52, 0.58, 0.52),
                    status: .nominal,
                    temperatureC: 38.5,
                    powerWatts: 240,
                    airflowCfm: 32,
                    acousticDb: 51,
                    primaryMetric: "215 °C",
                    tools: [
                        MCPToolSpec(name: "halt_cnc_spindle", label: "Emergency Cut Heaters", summary: "Parks gantry and disables hotend MOSFETs.", riskTier: .tier3HoldPhysical, parameterSummary: "{ gantryActive: false }")
                    ]
                ),
                SpatialDevice(
                    id: "shop_fume_extractor",
                    room: .makerWorkshop,
                    name: "Fume Extractor & Damper",
                    shortLabel: "Fume Hood",
                    role: "HEPA + Carbon Scrubbing Blower",
                    mcpEndpoint: "mcp://fab02/exhaust-hvac",
                    position: SIMD3<Float>(0.15, 1.18, -0.18),
                    bounds: SIMD3<Float>(0.44, 0.42, 0.38),
                    status: .nominal,
                    temperatureC: 26.2,
                    powerWatts: 78,
                    airflowCfm: 110,
                    acousticDb: 47,
                    primaryMetric: "40% Open",
                    tools: [
                        MCPToolSpec(name: "adjust_hepa_damper", label: "Open Blast Gate 100%", summary: "Opens damper and ramps blower to 3,200 RPM.", riskTier: .tier2TapConfirm, parameterSummary: "{ damperPct: 100 }")
                    ]
                )
            ]
        case .utilityCloset:
            return [
                SpatialDevice(
                    id: "home_water_solenoid",
                    room: .utilityCloset,
                    name: "Main Water Solenoid",
                    shortLabel: "Water Valve",
                    role: "3/4-in Motorized Shutoff",
                    mcpEndpoint: "mcp://home/plumbing-valve",
                    position: SIMD3<Float>(0.32, 0.68, -0.38),
                    bounds: SIMD3<Float>(0.28, 0.36, 0.24),
                    status: .nominal,
                    temperatureC: 18.2,
                    powerWatts: 3,
                    airflowCfm: 0,
                    acousticDb: 31,
                    primaryMetric: "Open · 54 PSI",
                    tools: [
                        MCPToolSpec(name: "poll_flow_ultrasonic", label: "Ultrasonic Flow Check", summary: "Checks micro-drip ultrasonic flow counter.", riskTier: .tier1AutoRead, parameterSummary: "{ windowSec: 5 }"),
                        MCPToolSpec(name: "actuate_solenoid_valve", label: "Shut Off Main Water", summary: "Closes domestic water supply valve 90°.", riskTier: .tier3HoldPhysical, parameterSummary: "{ valveOpen: false }")
                    ]
                ),
                SpatialDevice(
                    id: "home_air_handler",
                    room: .utilityCloset,
                    name: "Heat-Pump Air Handler",
                    shortLabel: "Air Handler",
                    role: "Variable-Speed HVAC Unit",
                    mcpEndpoint: "mcp://home/hvac-matter",
                    position: SIMD3<Float>(-0.42, 0.88, -0.18),
                    bounds: SIMD3<Float>(0.64, 1.24, 0.52),
                    status: .nominal,
                    temperatureC: 19.6,
                    powerWatts: 420,
                    airflowCfm: 380,
                    acousticDb: 43,
                    primaryMetric: "380 CFM",
                    tools: [
                        MCPToolSpec(name: "set_defrost_purge", label: "Run Defrost Purge", summary: "Pauses cooling and purges evaporator coil.", riskTier: .tier2TapConfirm, parameterSummary: "{ blowerPct: 80 }")
                    ]
                )
            ]
        }
    }

    static func scenarios(for room: RoomSpaceID) -> [FaultScenario] {
        switch room {
        case .serverRack:
            return [
                FaultScenario(id: "rack_intake_clog", title: "Intake Dust Occlusion", detail: "Lower HEPA mesh 78% occluded; Node 4U climbing to 84.6 °C.", room: .serverRack),
                FaultScenario(id: "coolant_cavitation", title: "Coolant Pump Cavitation", detail: "2.4 kHz impeller whine paired with 1.2 L/min flow drop.", room: .serverRack)
            ]
        case .makerWorkshop:
            return [
                FaultScenario(id: "voc_fume_spike", title: "VOC Spike & Damper Closed", detail: "Styrene climbed to 4.25 ppm while blast gate stays at 15%.", room: .makerWorkshop),
                FaultScenario(id: "printer_thermal_runaway", title: "CoreXY Hotend Overshoot", detail: "Nozzle reached 268 °C with thermistor PID saturation.", room: .makerWorkshop)
            ]
        case .utilityCloset:
            return [
                FaultScenario(id: "water_leak_detected", title: "Floor Leak & Flow Alert", detail: "Conductive floor moisture + continuous 2.8 GPM flow.", room: .utilityCloset),
                FaultScenario(id: "hvac_coil_freeze", title: "Air Handler Coil Frost", detail: "Supply airflow dropped 59% with coil temp at 3.2 °C.", room: .utilityCloset)
            ]
        }
    }
}
