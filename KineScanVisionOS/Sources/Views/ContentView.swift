//
//  ContentView.swift
//  KineScanVisionOS
//
//  Main visionOS Spatial Window with Glass Background, NavigationSplitView,
//  and Bottom Window Ornaments.
//

import SwiftUI
import RealityKit

struct ContentView: View {
    @Environment(MachineTwinModel.self) private var model
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow

    @State private var selectedTab: InspectorTab = .telemetry
    @State private var isImmersiveActive = false

    enum InspectorTab: String, CaseIterable, Identifiable {
        case telemetry = "I/O Telemetry"
        case reasoning = "Hybrid Reasoning"
        case maintenance = "Maintenance Schedule"
        case collaboration = "Spatial Peers"
        
        var id: String { rawValue }
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar: Machine Sub-Assemblies & LiDAR Confidence
            List {
                Section("Scanned Machine") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.machineName)
                            .font(.headline)
                        Text("\(model.modelNumber) · SN: \(model.serialNumber)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text("Health: \(Int(model.overallHealthScore))/100")
                                .font(.caption.bold())
                                .foregroundStyle(model.overallHealthScore > 80 ? .green : .orange)
                            Spacer()
                            Text("Mesh ±0.42mm")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("3D Sub-Assemblies") {
                    ForEach(model.subAssemblies) { part in
                        Button {
                            model.selectedPartId = part.id
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(part.index). \(part.name)")
                                        .font(.subheadline)
                                    Text(part.code)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(Int(part.confidence))%")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("Connected Spatial Devices") {
                    ForEach(model.connectedPeers) { peer in
                        HStack {
                            Image(systemName: peer.isVisionPro ? "visionpro" : "eyeglasses")
                            VStack(alignment: .leading) {
                                Text(peer.name)
                                    .font(.caption.bold())
                                Text(peer.role)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Circle()
                                .fill(peer.isActive ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
            .navigationTitle("KineScan Spatial")
        } detail: {
            VStack(spacing: 0) {
                // Top Action Toolbar
                HStack(spacing: 16) {
                    Picker("Visual Mode", selection: Bindable(model).visualMode) {
                        ForEach(VisualMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 420)

                    Spacer()

                    // Launch 3D Tabletop Volume
                    Button {
                        openWindow(id: "SubAssemblyVolume", value: model.selectedPartId)
                    } label: {
                        Label("Inspect Volume (1:1)", systemImage: "cube.transparent")
                    }

                    // Immersive Space Toggle
                    Button {
                        Task {
                            if isImmersiveActive {
                                await dismissImmersiveSpace()
                                isImmersiveActive = false
                            } else {
                                switch await openImmersiveSpace(id: "MachineTwinImmersiveSpace") {
                                case .opened:
                                    isImmersiveActive = true
                                case .userCancelled, .error:
                                    isImmersiveActive = false
                                @unknown default:
                                    break
                                }
                            }
                        }
                    } label: {
                        Label(
                            isImmersiveActive ? "Exit Immersive" : "Enter Factory Floor Space",
                            systemImage: isImmersiveActive ? "xmark.circle" : "visionpro"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(.ultraThinMaterial)

                // Main Stage: Interactive RealityView Preview & Inspector Tabs
                HStack(alignment: .top, spacing: 0) {
                    // Left 3D Embedded RealityView
                    RealityView { content in
                        let twin = RealityKitTwinBuilder.createMachineAssembly(
                            for: model.machineId,
                            explodeFactor: Float(model.explodeProgress)
                        )
                        content.add(twin)
                    } update: { content in
                        if let twin = content.entities.first {
                            RealityKitTwinBuilder.updateExplodedOffsets(
                                entity: twin,
                                explodeFactor: Float(model.explodeProgress)
                            )
                        }
                    }
                    .frame(minWidth: 480)
                    .overlay(alignment: .topLeading) {
                        Text("Interactive 3D RealityView")
                            .font(.caption2.bold())
                            .padding(6)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding()
                    }

                    // Right Telemetry & Reasoning Tabs
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Inspector View", selection: $selectedTab) {
                            ForEach(InspectorTab.allCases) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)

                        ScrollView {
                            switch selectedTab {
                            case .telemetry:
                                TelemetryTableView()
                            case .reasoning:
                                HybridReasoningView()
                            case .maintenance:
                                MaintenanceScheduleView()
                            case .collaboration:
                                CollaborationPinsView()
                            }
                        }
                    }
                    .frame(minWidth: 380, maxWidth: 520)
                }
            }
        }
        // visionOS Window Ornament Pinned to Bottom Edge
        .ornament(attachmentAnchor: .scene(.bottom)) {
            OrnamentsToolbarView()
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .glassBackgroundEffect()
        }
    }
}

// Subviews
struct TelemetryTableView: View {
    @Environment(MachineTwinModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(model.ioTags) { tag in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(tag.name)
                            .font(.subheadline.bold())
                        Spacer()
                        Text("\(String(format: "%.2f", tag.measured)) \(tag.unit)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(tag.isOutOfSpec ? .red : .primary)
                    }
                    HStack {
                        Text(tag.address)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Inferred: \(String(format: "%.2f", tag.inferred)) \(tag.unit)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
    }
}

struct HybridReasoningView: View {
    @Environment(MachineTwinModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Reasoning Engine")
                    .font(.headline)
                Spacer()
                Text(model.activeEngineTitle)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.2), in: Capsule())
            }

            Text(model.reasoningSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            Text("Predicted FMEA Failures")
                .font(.subheadline.bold())

            ForEach(model.failurePredictions) { pred in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(pred.title)
                            .font(.subheadline.bold())
                        Spacer()
                        Text("\(pred.probability)% · \(pred.rulHours)h RUL")
                            .font(.caption.bold())
                            .foregroundStyle(pred.severity == "critical" ? .red : .orange)
                    }
                    Text(pred.knownReference)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                    Text("Action: \(pred.preventativeAction)")
                        .font(.caption)
                }
                .padding(10)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
    }
}

struct MaintenanceScheduleView: View {
    @Environment(MachineTwinModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Automated Preventative Work Orders")
                .font(.headline)

            ForEach(model.maintenanceTasks) { task in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.title)
                            .font(.subheadline.bold())
                        Text(task.procedure)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(task.spec)
                            .font(.caption2.monospaced())
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(task.status.capitalized)
                            .font(.caption.bold())
                            .foregroundStyle(task.status == "overdue" ? .red : .green)
                        Text("Due: \(task.dueDate)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
    }
}

struct CollaborationPinsView: View {
    @Environment(MachineTwinModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spatial Troubleshooting Pins")
                .font(.headline)

            ForEach(model.spatialPins) { pin in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(pin.title)
                            .font(.subheadline.bold())
                        Spacer()
                        Text(pin.device)
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.12), in: Capsule())
                    }
                    Text(pin.author)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(pin.note)
                        .font(.caption)
                }
                .padding(10)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
    }
}
