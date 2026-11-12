//
//  MachineTwinModel.swift
//  KineScanVisionOS
//
//  Observable data store coordinating LiDAR meshes, OPC-UA telemetry,
//  CoreML on-device physics reasoning, and Cloud API escalation.
//

import SwiftUI
import CoreML

enum VisualMode: String, CaseIterable, Identifiable {
    case pbr = "PBR Twin"
    case lidar = "LiDAR Cloud"
    case thermal = "Thermal Stress"
    case wireframe = "I/O Wireframe"
    
    var id: String { rawValue }
}

struct SubAssemblyItem: Identifiable, Hashable {
    let id: String
    let index: Int
    let name: String
    let code: String
    let material: String
    let confidence: Double
}

struct IOTagItem: Identifiable, Hashable {
    let id: String
    let partId: String
    let name: String
    let address: String
    let unit: String
    var measured: Double
    var inferred: Double
    let nominalMin: Double
    let nominalMax: Double
    
    var isOutOfSpec: Bool {
        measured < nominalMin || measured > nominalMax
    }
}

struct FailurePredictionItem: Identifiable, Hashable {
    let id = UUID()
    let code: String
    let title: String
    let partId: String
    let probability: Int
    let rulHours: Int
    let severity: String
    let knownReference: String
    let preventativeAction: String
}

struct MaintenanceTaskItem: Identifiable, Hashable {
    let id: String
    let title: String
    let procedure: String
    let spec: String
    var status: String
    let dueDate: String
}

struct SpatialPinItem: Identifiable, Hashable {
    let id: String
    let partId: String
    let title: String
    let note: String
    let author: String
    let device: String
}

struct PeerDeviceItem: Identifiable, Hashable {
    let id: String
    let name: String
    let role: String
    let isVisionPro: Bool
    let isActive: Bool
}

@Observable
final class MachineTwinModel {
    var machineId: String
    var machineName: String
    var modelNumber: String
    var serialNumber: String
    var protocolEndpoint: String

    var selectedPartId: String = "spindle-head"
    var visualMode: VisualMode = .pbr
    var explodeProgress: Double = 0.0
    var overallHealthScore: Double = 92.0
    var activeEngineTitle: String = "On-Device CoreML"
    var reasoningSummary: String = "Nominal mechanical equilibrium; all 8 sub-assemblies within calibrated ISO 20816 baseline."
    var activeFaultScenario: String = "nominal" {
        didSet { simulateFault(scenario: activeFaultScenario) }
    }

    var isScanning: Bool = false
    var scanProgress: Double = 0.0
    var isDroppingPin: Bool = false

    var subAssemblies: [SubAssemblyItem] = []
    var ioTags: [IOTagItem] = []
    var failurePredictions: [FailurePredictionItem] = []
    var maintenanceTasks: [MaintenanceTaskItem] = []
    var spatialPins: [SpatialPinItem] = []
    var connectedPeers: [PeerDeviceItem] = []

    init(machineId: String, machineName: String, modelNumber: String, serialNumber: String, protocolEndpoint: String) {
        self.machineId = machineId
        self.machineName = machineName
        self.modelNumber = modelNumber
        self.serialNumber = serialNumber
        self.protocolEndpoint = protocolEndpoint

        loadDefaultSeedData()
    }

    func loadDefaultSeedData() {
        subAssemblies = [
            SubAssemblyItem(id: "cast-bed", index: 1, name: "Meehanite Cast Bed", code: "ASM-101", material: "FC300 Cast Iron", confidence: 99.4),
            SubAssemblyItem(id: "column-gantry", index: 2, name: "Thermo Column", code: "ASM-102", material: "Ribbed Ductile Iron", confidence: 98.9),
            SubAssemblyItem(id: "spindle-head", index: 3, name: "HSK-A63 18k RPM Spindle", code: "ASM-201", material: "Ceramic / 6061-T6", confidence: 99.1),
            SubAssemblyItem(id: "rotary-table", index: 4, name: "B/C Trunnion Table", code: "ASM-301", material: "Hardened 4140", confidence: 98.7),
            SubAssemblyItem(id: "ballscrew-drive", index: 5, name: "Z-Axis Ballscrew", code: "ASM-304", material: "SCM440 Ground Alloy", confidence: 97.8),
            SubAssemblyItem(id: "atc-magazine", index: 6, name: "60-Tool Matrix", code: "ASM-401", material: "Anodized Al", confidence: 98.3),
            SubAssemblyItem(id: "coolant-manifold", index: 7, name: "70-Bar Pump", code: "ASM-501", material: "Forged Brass", confidence: 98.5),
            SubAssemblyItem(id: "plc-cabinet", index: 8, name: "OPC-UA Cabinet", code: "ASM-601", material: "Sheet Steel", confidence: 99.6)
        ]

        ioTags = [
            IOTagItem(id: "ai-01", partId: "spindle-head", name: "Spindle Nose Vibration", address: "IW64 (OPC-UA)", unit: "mm/s RMS", measured: 2.14, inferred: 2.21, nominalMin: 0.4, nominalMax: 2.8),
            IOTagItem(id: "ai-02", partId: "spindle-head", name: "Front Bearing Temp", address: "IW66 (OPC-UA)", unit: "°C", measured: 43.6, inferred: 44.1, nominalMin: 24.0, nominalMax: 52.0),
            IOTagItem(id: "ao-01", partId: "spindle-head", name: "Stator Current Draw", address: "QW80 (OPC-UA)", unit: "A", measured: 31.8, inferred: 32.4, nominalMin: 8.0, nominalMax: 46.0),
            IOTagItem(id: "ai-03", partId: "coolant-manifold", name: "Coolant Supply Pressure", address: "IW72 (OPC-UA)", unit: "bar", measured: 67.4, inferred: 66.8, nominalMin: 58.0, nominalMax: 74.0),
            IOTagItem(id: "ai-04", partId: "ballscrew-drive", name: "Z-Axis Following Error", address: "IW78 (OPC-UA)", unit: "µm", measured: 4.30, inferred: 4.60, nominalMin: 0.5, nominalMax: 9.0)
        ]

        failurePredictions = [
            FailurePredictionItem(code: "FMEA-CLN-02", title: "Duplex Filter Differential Saturation", partId: "coolant-manifold", probability: 64, rulHours: 92, severity: "warning", knownReference: "OEM Table 4.2 · 500h Cycle", preventativeAction: "Swap twin 10 µm sintered filter cartridges.")
        ]

        maintenanceTasks = [
            MaintenanceTaskItem(id: "pm-1", title: "Replace 10 µm high-pressure coolant element", procedure: "Bleed 70-bar manifold accumulator, swap twin cartridges.", spec: "Filter cap: 42 N·m · Max ΔP 1.5 bar", status: "overdue", dueDate: "2026-11-10"),
            MaintenanceTaskItem(id: "pm-2", title: "Verify HSK-A63 drawbar retention force", procedure: "Insert digital force gauge into spindle taper.", spec: "18.0 - 20.5 kN retention force", status: "due-soon", dueDate: "2026-11-15")
        ]

        spatialPins = [
            SpatialPinItem(id: "pin-1", partId: "spindle-head", title: "Bearing harmonic resonance check", note: "BPFI harmonic peak flagged during high-speed pass.", author: "M. Lindqvist", device: "Apple Vision Pro"),
            SpatialPinItem(id: "pin-2", partId: "coolant-manifold", title: "Strainer ΔP rising", note: "Verified 1.4 bar differential across filter basket.", author: "R. Okafor", device: "Meta Ray-Ban Glasses")
        ]

        connectedPeers = [
            PeerDeviceItem(id: "peer-1", name: "M. Lindqvist", role: "Reliability Lead", isVisionPro: true, isActive: true),
            PeerDeviceItem(id: "peer-2", name: "R. Okafor", role: "Floor Millwright", isVisionPro: false, isActive: true)
        ]
    }

    func startLidarScan() {
        guard !isScanning else { return }
        isScanning = true
        scanProgress = 0.0

        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            self.scanProgress += 5.0
            if self.scanProgress >= 100.0 {
                timer.invalidate()
                self.isScanning = false
                self.scanProgress = 100.0
            }
        }
    }

    func simulateFault(scenario: String) {
        if scenario == "spindle_spall" {
            overallHealthScore = 58.0
            activeEngineTitle = "Gemini 3.8 Flash Cloud (Auto Handover)"
            reasoningSummary = "Vibration harmonic spike (4.82 mm/s RMS) on front ceramic bearing indicates inner-race spall. CoreML confidence dropped below 82%, escalating to Cloud Reasoning."
            failurePredictions.insert(
                FailurePredictionItem(code: "FMEA-SPN-04", title: "Front Ceramic Bearing Inner-Race Spall", partId: "spindle-head", probability: 88, rulHours: 48, severity: "critical", knownReference: "ISO 20816-3 Zone C", preventativeAction: "Schedule spindle cartridge replacement; inspect oil-air lube."),
                at: 0
            )
        } else {
            overallHealthScore = 92.0
            activeEngineTitle = "On-Device CoreML"
            reasoningSummary = "Nominal mechanical equilibrium; all 8 sub-assemblies within calibrated ISO 20816 baseline."
        }
    }

    func handleEntityTapped(name: String) {
        if let match = subAssemblies.first(where: { $0.id == name }) {
            selectedPartId = match.id
        }
        if isDroppingPin {
            spatialPins.append(
                SpatialPinItem(id: UUID().uuidString, partId: selectedPartId, title: "Annotation on \(selectedPartId)", note: "Pinned via VisionOS gesture.", author: "You (Vision Pro)", device: "Apple Vision Pro")
            )
            isDroppingPin = false
        }
    }

    func getPartName(for partId: String) -> String {
        subAssemblies.first(where: { $0.id == partId })?.name ?? partId
    }
}
