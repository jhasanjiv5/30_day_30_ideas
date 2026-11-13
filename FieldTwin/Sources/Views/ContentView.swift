import SwiftUI

struct ContentView: View {
    @Environment(SpatialMCPEngine.self) private var engine
    @Environment(NearbyCompanionSync.self) private var companionSync
    @State private var showCompanionSheet = false
    @State private var showTelemetrySheet = false
    @State private var showInferenceSummary = false

    var body: some View {
        @Bindable var bindableEngine = engine

        NavigationSplitView {
            List {
                Section("Physical Spaces") {
                    ForEach(RoomSpaceID.allCases) { room in
                        Button {
                            engine.switchRoom(to: room)
                        } label: {
                            HStack {
                                Text(room.title)
                                Spacer()
                                if engine.activeRoom == room {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.cyan)
                                }
                            }
                        }
                    }
                }

                Section("Demo Scenario Fixtures") {
                    Text("Synthetic readings for preview only.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(RoomSeedCatalog.scenarios(for: engine.activeRoom)) { scenario in
                        Button {
                            engine.triggerScenario(scenario)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(scenario.title)
                                    .font(.subheadline.weight(.medium))
                                Text(scenario.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Button("Reset Nominal", role: .cancel) {
                        engine.resetNominal()
                    }
                }

                Section("Audit Ledger (\(engine.auditLog.count))") {
                    if engine.auditLog.isEmpty {
                        Text("No executions yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(engine.auditLog.prefix(5)) { entry in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(entry.deviceName) · \(entry.toolName)")
                                    .font(.caption.weight(.medium))
                                Text("\(entry.actor) · \(entry.outcome) · \(entry.latencyMs) ms")
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("FieldTwin")
        } detail: {
            ZStack(alignment: .bottom) {
                RoomPlanLiDARView(
                    devices: engine.devices,
                    selectedDeviceId: engine.selectedDeviceId,
                    viewLayer: engine.viewLayer,
                    onSelectDevice: { devId in
                        engine.selectedDeviceId = devId
                    }
                )
                .ignoresSafeArea(edges: .bottom)

                VStack(spacing: 12) {
                    if let pending = engine.pendingProposal {
                        TrustCalibratedAROverlay(
                            proposal: pending,
                            onApprove: { actor in
                                engine.approveProposal(pending, actor: actor)
                            },
                            onDismiss: {
                                engine.dismissProposal(pending)
                            }
                        )
                        .frame(maxWidth: 460)
                    }

                    ScrollView(.horizontal) {
                        HStack(spacing: 12) {
                            Picker("Layer", selection: $bindableEngine.viewLayer) {
                                ForEach(ViewLayerMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 300)

                            Button {
                                engine.pulseLiDARScan()
                            } label: {
                                Label(engine.isScanningLiDAR ? "Scanning..." : "Scan Room", systemImage: "dot.radiowaves.left.and.right")
                            }
                            .buttonStyle(.borderedProminent)

                            Button {
                                showCompanionSheet = true
                            } label: {
                                Label("Companion", systemImage: "iphone")
                            }
                            .buttonStyle(.bordered)

                            Button {
                                showTelemetrySheet = true
                            } label: {
                                Label("Telemetry", systemImage: "slider.horizontal.3")
                            }
                            .buttonStyle(.bordered)

                            Button {
                                engine.analyzeTelemetry()
                                showInferenceSummary = true
                            } label: {
                                Label("Infer", systemImage: "sparkles")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .scrollIndicators(.hidden)
                    .padding(12)
                    .background(Color(red: 0.05, green: 0.08, blue: 0.13).opacity(0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .padding()
            }
            .navigationTitle(engine.activeRoom.title)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showCompanionSheet) {
                CompanionHandoffSheet()
            }
            .sheet(isPresented: $showTelemetrySheet) {
                if let device = engine.selectedDevice {
                    TelemetryEditorSheet(device: device) { temperatureC, airflowCfm, acousticDb in
                        engine.updateTelemetry(
                            for: device.id,
                            temperatureC: temperatureC,
                            airflowCfm: airflowCfm,
                            acousticDb: acousticDb
                        )
                    }
                }
            }
            .alert("Telemetry inference", isPresented: $showInferenceSummary) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(engine.latestInferenceSummary)
            }
        }
    }
}

private struct TelemetryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var temperatureText: String
    @State private var airflowText: String
    @State private var acousticText: String

    let device: SpatialDevice
    let onSave: (Double, Double, Double) -> Void

    init(device: SpatialDevice, onSave: @escaping (Double, Double, Double) -> Void) {
        self.device = device
        self.onSave = onSave
        _temperatureText = State(initialValue: String(device.temperatureC))
        _airflowText = State(initialValue: String(device.airflowCfm))
        _acousticText = State(initialValue: String(device.acousticDb))
    }

    private var readings: (temperature: Double, airflow: Double, acoustic: Double)? {
        guard let temperature = Double(temperatureText),
              let airflow = Double(airflowText),
              let acoustic = Double(acousticText),
              temperature.isFinite,
              airflow.isFinite,
              acoustic.isFinite,
              airflow >= 0,
              acoustic >= 0 else {
            return nil
        }
        return (temperature, airflow, acoustic)
    }

    private var isValidInput: Bool {
        readings.map { _ in true } ?? false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(device.name) {
                    TextField("Temperature (°C)", text: $temperatureText)
                        .keyboardType(.decimalPad)
                    TextField("Airflow (CFM; 0 if unavailable)", text: $airflowText)
                        .keyboardType(.decimalPad)
                    TextField("Acoustic level (dB)", text: $acousticText)
                        .keyboardType(.decimalPad)
                }
                Section {
                    Text("These readings are evaluated on-device. They are not collected from connected hardware.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Telemetry input")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let readings else { return }
                        onSave(readings.temperature, readings.airflow, readings.acoustic)
                        dismiss()
                    }
                    .disabled(!isValidInput)
                }
            }
        }
    }
}

private struct CompanionHandoffSheet: View {
    @Environment(SpatialMCPEngine.self) private var engine
    @Environment(NearbyCompanionSync.self) private var sync
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                if let dev = engine.selectedDevice {
                    VStack(spacing: 6) {
                        Text(dev.name)
                            .font(.title3.weight(.semibold))
                        Text("UWB Range: \(String(format: "%.2f", sync.uwbDistanceMeters)) m · Bearing \(sync.bearingDegrees)°")
                            .font(.caption.monospaced())
                            .foregroundStyle(.cyan)
                    }
                }

                if let pending = engine.pendingProposal {
                    TrustCalibratedAROverlay(
                        proposal: pending,
                        onApprove: { _ in
                            Task {
                                let ok = await sync.authenticateWithFaceID()
                                if ok {
                                    engine.approveProposal(pending, actor: "iPhone Companion")
                                    dismiss()
                                }
                            }
                        },
                        onDismiss: {
                            engine.dismissProposal(pending)
                        }
                    )
                } else {
                    Text("All physical gates are synced and nominal.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("iPhone Companion")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
