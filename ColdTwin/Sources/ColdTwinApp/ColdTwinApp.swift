import SwiftUI
import Charts
import ColdTwinCore
import UniformTypeIdentifiers

@main
struct ColdTwinApp: App {
    @StateObject private var store = ColdTwinStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 1024, minHeight: 680)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Load Synthetic Demo Data") {
                    store.loadDemoData()
                }
            }
        }
    }
}

@MainActor
final class ColdTwinStore: ObservableObject {
    @Published var sites: [Site] = []
    @Published var assets: [Asset] = []
    @Published var readings: [TemperatureReading] = []
    @Published var events: [RecordedEvent] = []
    @Published var resourceContext = ResourceContext()
    @Published var analyses: [String: Analysis] = [:]
    @Published var selectedAssetId: String?
    @Published var inferenceMemory = InferenceMemory()
    @Published var isAnalyzing = false
    @Published var analysisError: String?
    @Published var memoryError: String?
    @Published var readingError: String?
    @Published var inventoryError: String?

    private let engine = OnDeviceDiagnosisEngine()
    private let externalEngine = OpenAICompatibleDiagnosisEngine()
    private let credentialStore = KeychainCredentialStore()
    private let memoryStore = LocalInferenceMemoryStore()
    private let inventoryStore = LocalColdTwinInventoryStore()
    private var analysisTask: Task<Void, Never>?

    init() {
        do {
            inferenceMemory = try memoryStore.load()
        } catch {
            memoryError = "Could not load local inference memory: \(error.localizedDescription)"
        }
        do {
            if let snapshot = try inventoryStore.load() {
                sites = snapshot.sites
                assets = snapshot.assets
                readings = snapshot.readings
                events = snapshot.events
                resourceContext = snapshot.resourceContext
                selectedAssetId = snapshot.selectedAssetID
                if let selectedAssetId, assets.contains(where: { $0.id == selectedAssetId }) {
                    runAnalysis(for: selectedAssetId)
                }
            } else {
                loadDemoData()
            }
        } catch {
            inventoryError = "Could not load local site and reading data: \(error.localizedDescription)"
            loadDemoData(persist: false)
        }
    }

    func loadDemoData(persist: Bool = true) {
        let now = Date()
        let formatter = ISO8601DateFormatter()
        let demoSite = Site(id: "site-harbor", name: "Harbor Street Market (Synthetic Demo)", location: "Ground Floor Kitchen", isDemo: true)
        let cooler = Asset(id: "cooler-07", siteId: demoSite.id, name: "Walk-in Cooler 7", assetType: .cooler, preferredUnit: .celsius, isDemo: true)
        sites.removeAll { $0.id == demoSite.id }
        sites.append(demoSite)
        assets.removeAll { $0.id == cooler.id }
        assets.append(cooler)
        readings.removeAll { $0.isDemo && $0.assetId == cooler.id }
        readings.append(contentsOf: [
            TemperatureReading(assetId: cooler.id, originalValue: 3.1, originalUnit: .celsius, originalTimestamp: formatter.string(from: now.addingTimeInterval(-14400)), timestamp: now.addingTimeInterval(-14400), sourceLabel: "Synthetic Demo", isDemo: true),
            TemperatureReading(assetId: cooler.id, originalValue: 6.9, originalUnit: .celsius, originalTimestamp: formatter.string(from: now.addingTimeInterval(-3600)), timestamp: now.addingTimeInterval(-3600), sourceLabel: "Synthetic Demo", isDemo: true),
            TemperatureReading(assetId: cooler.id, originalValue: 7.4, originalUnit: .celsius, originalTimestamp: formatter.string(from: now.addingTimeInterval(-900)), timestamp: now.addingTimeInterval(-900), sourceLabel: "Synthetic Demo", isDemo: true)
        ])
        events.removeAll { $0.isDemo && $0.assetId == cooler.id }
        events.append(contentsOf: [
            RecordedEvent(assetId: cooler.id, originalTimestamp: formatter.string(from: now.addingTimeInterval(-4200)), timestamp: now.addingTimeInterval(-4200), category: .doorOpen, note: "Door propped open during prep", isDemo: true)
        ])
        selectedAssetId = cooler.id
        if persist {
            persistInventory()
        }
        runAnalysis(for: cooler.id)
    }

    @discardableResult
    func addSite(name: String, location: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, trimmedName.count <= 100, trimmedLocation.count <= 160 else {
            inventoryError = "Enter a site name (up to 100 characters) and a location no longer than 160 characters."
            return false
        }
        let site = Site(
            id: "site-\(UUID().uuidString.lowercased())",
            name: trimmedName,
            location: trimmedLocation
        )
        sites.append(site)
        persistInventory()
        guard inventoryError == nil else {
            sites.removeAll { $0.id == site.id }
            return false
        }
        return true
    }

    @discardableResult
    func addAsset(
        siteID: String,
        name: String,
        assetType: AssetType,
        preferredUnit: TemperatureUnit,
        rangeMinimum: Double,
        rangeMaximum: Double
    ) -> Asset? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard sites.contains(where: { $0.id == siteID }) else {
            inventoryError = "Select an existing site for this unit."
            return nil
        }
        guard !trimmedName.isEmpty, trimmedName.count <= 100 else {
            inventoryError = "Enter a unit name up to 100 characters."
            return nil
        }
        guard rangeMinimum.isFinite, rangeMaximum.isFinite else {
            inventoryError = "Enter finite operating-range values."
            return nil
        }
        let minimumCelsius = preferredUnit.toCelsius(rangeMinimum)
        let maximumCelsius = preferredUnit.toCelsius(rangeMaximum)
        guard minimumCelsius < maximumCelsius else {
            inventoryError = "The minimum operating limit must be below the maximum."
            return nil
        }
        let asset = Asset(
            id: "asset-\(UUID().uuidString.lowercased())",
            siteId: siteID,
            name: trimmedName,
            assetType: assetType,
            preferredUnit: preferredUnit,
            rangeMinC: minimumCelsius,
            rangeMaxC: maximumCelsius,
            rangeSource: .userConfigured
        )
        let previousSelection = selectedAssetId
        assets.append(asset)
        selectedAssetId = asset.id
        persistInventory()
        guard inventoryError == nil else {
            assets.removeAll { $0.id == asset.id }
            selectedAssetId = previousSelection
            return nil
        }
        runAnalysis(for: asset.id)
        return asset
    }

    func preparedEvidence(for assetID: String) -> Analysis? {
        guard let asset = assets.first(where: { $0.id == assetID }) else { return nil }
        return DiagnosisEngine().prepare(
            asset: asset,
            readings: readings.filter { $0.assetId == assetID },
            events: events.filter { $0.assetId == assetID },
            context: resourceContext
        )
    }

    @discardableResult
    func importRows(_ rows: [CSVPreviewRow]) -> Bool {
        let validRows = rows.filter(\.isValid)
        guard !validRows.isEmpty else { return false }
        let previousReadings = readings
        let previousEvents = events
        readings.append(contentsOf: validRows.compactMap(\.reading))
        events.append(contentsOf: validRows.compactMap(\.event))
        persistInventory()
        guard inventoryError == nil else {
            readings = previousReadings
            events = previousEvents
            return false
        }
        if let selectedAssetId {
            runAnalysis(for: selectedAssetId)
        }
        return true
    }

    @discardableResult
    func addReading(assetID: String, value: Double, unit: TemperatureUnit, timestamp: Date) -> Bool {
        guard assets.contains(where: { $0.id == assetID }) else {
            readingError = "The selected refrigeration unit is unavailable."
            return false
        }
        guard value.isFinite else {
            readingError = "Enter a valid temperature."
            return false
        }
        let reading = TemperatureReading(
            assetId: assetID,
            originalValue: value,
            originalUnit: unit,
            originalTimestamp: ISO8601DateFormatter().string(from: timestamp),
            timestamp: timestamp,
            sourceLabel: "Manual"
        )
        readings.append(reading)
        readingError = nil
        persistInventory()
        guard inventoryError == nil else {
            readings.removeAll { $0.id == reading.id }
            readingError = inventoryError
            return false
        }
        runAnalysis(for: assetID)
        return true
    }

    func updateResourceContext(_ context: ResourceContext) {
        let previousContext = resourceContext
        resourceContext = context
        persistInventory()
        guard inventoryError == nil else {
            resourceContext = previousContext
            return
        }
        if let selectedAssetId {
            runAnalysis(for: selectedAssetId)
        }
    }

    private func persistInventory() {
        do {
            try inventoryStore.save(ColdTwinInventorySnapshot(
                sites: sites,
                assets: assets,
                readings: readings,
                events: events,
                resourceContext: resourceContext,
                selectedAssetID: selectedAssetId
            ))
            inventoryError = nil
        } catch {
            inventoryError = "Could not save local site and reading data: \(error.localizedDescription)"
        }
    }

    func reportData(for assetID: String) throws -> Data {
        guard let asset = assets.first(where: { $0.id == assetID }) else {
            throw ReportError.assetUnavailable
        }
        guard let site = sites.first(where: { $0.id == asset.siteId }) else {
            throw ReportError.siteUnavailable
        }

        let analysis: Analysis
        if let completedAnalysis = analyses[assetID] {
            analysis = completedAnalysis
        } else {
            guard let evidence = preparedEvidence(for: assetID) else {
                throw ReportError.evidenceUnavailable
            }
            analysis = Analysis(
                id: evidence.id,
                assetId: evidence.assetId,
                generatedAt: evidence.generatedAt,
                statusAtAnalysis: evidence.statusAtAnalysis,
                summary: "Evidence preparation only; model assessment unavailable. \(evidence.summary)",
                dataQualityNotes: evidence.dataQualityNotes + [
                    "Hypotheses were not assessed by an inference model."
                ],
                observations: evidence.observations,
                options: []
            )
        }
        return try ExportService().encodeJSON(
            asset: asset,
            siteName: site.name,
            analysis: analysis,
            context: resourceContext,
            events: events.filter { $0.assetId == assetID }
        )
    }

    func runAnalysis(for assetId: String) {
        guard inferenceMemory.selectedExternalModelID == nil else {
            analysisTask?.cancel()
            analyses[assetId] = nil
            analysisError = nil
            isAnalyzing = false
            return
        }
        guard let asset = assets.first(where: { $0.id == assetId }) else { return }
        let assetReadings = readings.filter { $0.assetId == assetId }
        let assetEvents = events.filter { $0.assetId == assetId }
        var memory = inferenceMemory
        memory.assessmentOverrides = [:]
        let context = resourceContext
        let engine = self.engine
        startAnalysis(for: assetId) {
            try await engine.analyze(
                asset: asset,
                readings: assetReadings,
                events: assetEvents,
                context: context,
                memory: memory
            )
        }
    }

    func runExternalAnalysis(for assetId: String) {
        guard let profileID = inferenceMemory.selectedExternalModelID,
              let profile = inferenceMemory.externalModels.first(where: { $0.id == profileID }) else {
            analysisError = "Select a configured external model first."
            return
        }
        guard let asset = assets.first(where: { $0.id == assetId }) else {
            analysisError = "The selected refrigeration unit is unavailable."
            return
        }
        let apiKey: String?
        do {
            apiKey = try credentialStore.load(for: profile.id)
        } catch {
            analysisError = "Could not read the API key from Keychain: \(error.localizedDescription)"
            return
        }
        let assetReadings = readings.filter { $0.assetId == assetId }
        let assetEvents = events.filter { $0.assetId == assetId }
        let context = resourceContext
        var memory = inferenceMemory
        memory.assessmentOverrides = [:]
        let engine = externalEngine
        startAnalysis(for: assetId) {
            try await engine.analyze(
                asset: asset,
                readings: assetReadings,
                events: assetEvents,
                context: context,
                profile: profile,
                apiKey: apiKey,
                memory: memory
            )
        }
    }

    func selectExternalModel(_ profileID: String?) {
        if let profileID,
           !inferenceMemory.externalModels.contains(where: { $0.id == profileID }) {
            memoryError = "That external model is no longer configured."
            return
        }
        var updatedMemory = inferenceMemory
        updatedMemory.selectedExternalModelID = profileID
        _ = saveMemory(updatedMemory)
    }

    @discardableResult
    func addExternalModel(name: String, baseURL: String, modelID: String, apiKey: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModelID = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, trimmedName.count <= 80,
              !trimmedModelID.isEmpty, trimmedModelID.count <= 200,
              apiKey.count <= 4096 else {
            memoryError = "Enter a name (up to 80 characters), model ID (up to 200 characters), and API key (up to 4096 characters)."
            return false
        }
        guard inferenceMemory.externalModels.count < 10 else {
            memoryError = "Remove an external model before adding another."
            return false
        }

        do {
            _ = try OpenAICompatibleDiagnosisEngine.validateBaseURL(baseURL)
            let profile = ExternalModelProfile(
                name: trimmedName,
                baseURL: baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
                modelID: trimmedModelID
            )
            if !apiKey.isEmpty {
                try credentialStore.save(apiKey, for: profile.id)
            }
            var updatedMemory = inferenceMemory
            updatedMemory.externalModels.append(profile)
            guard saveMemory(updatedMemory) else {
                if !apiKey.isEmpty {
                    do {
                        try credentialStore.delete(for: profile.id)
                    } catch {
                        memoryError = "Model was not saved and its Keychain entry could not be removed: \(error.localizedDescription)"
                    }
                }
                return false
            }
            return true
        } catch {
            memoryError = error.localizedDescription
            return false
        }
    }

    func removeExternalModel(_ profile: ExternalModelProfile) {
        var updatedMemory = inferenceMemory
        updatedMemory.externalModels.removeAll { $0.id == profile.id }
        if updatedMemory.selectedExternalModelID == profile.id {
            updatedMemory.selectedExternalModelID = nil
        }
        guard saveMemory(updatedMemory) else { return }
        do {
            try credentialStore.delete(for: profile.id)
        } catch {
            memoryError = "The model was removed, but its API key could not be deleted from Keychain: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func addRule(_ text: String) -> Bool {
        let rule = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rule.isEmpty, rule.count <= 500 else {
            memoryError = "Rules must contain 1–500 characters."
            return false
        }
        guard !inferenceMemory.customRules.contains(rule) else {
            memoryError = "That rule is already saved."
            return false
        }
        guard inferenceMemory.customRules.count < 20 else {
            memoryError = "Remove a saved rule before adding another."
            return false
        }

        var updatedMemory = inferenceMemory
        updatedMemory.customRules.append(rule)
        return saveMemory(updatedMemory)
    }

    func removeRule(_ rule: String) {
        var updatedMemory = inferenceMemory
        updatedMemory.customRules.removeAll { $0 == rule }
        _ = saveMemory(updatedMemory)
    }

    func setAssessmentOverride(
        _ assessment: UserAssessmentOverride,
        assetID: String,
        hypothesisID: String
    ) {
        var updatedMemory = inferenceMemory
        let key = "\(assetID)::\(hypothesisID)"
        if assessment == .automatic {
            updatedMemory.assessmentOverrides.removeValue(forKey: key)
        } else {
            updatedMemory.assessmentOverrides[key] = assessment
            updatedMemory.feedback.append(
                InferenceFeedback(assetID: assetID, hypothesisID: hypothesisID, assessment: assessment)
            )
            updatedMemory.feedback = Array(updatedMemory.feedback.suffix(20))
        }
        _ = saveMemory(updatedMemory, reanalyze: false)
    }

    @discardableResult
    private func saveMemory(_ updatedMemory: InferenceMemory, reanalyze: Bool = true) -> Bool {
        do {
            try memoryStore.save(updatedMemory)
            inferenceMemory = updatedMemory
            memoryError = nil
            if reanalyze, let selectedAssetId {
                runAnalysis(for: selectedAssetId)
            }
            return true
        } catch {
            memoryError = "Could not save local inference memory: \(error.localizedDescription)"
            return false
        }
    }

    private func startAnalysis(
        for assetId: String,
        operation: @escaping () async throws -> Analysis
    ) {
        analysisTask?.cancel()
        analyses[assetId] = nil
        analysisError = nil
        isAnalyzing = true
        analysisTask = Task {
            do {
                let analysis = try await operation()
                guard !Task.isCancelled else { return }
                analyses[assetId] = analysis
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                analysisError = error.localizedDescription
            }
            if !Task.isCancelled {
                isAnalyzing = false
            }
        }
    }
}

private enum ReportError: LocalizedError {
    case assetUnavailable
    case siteUnavailable
    case evidenceUnavailable

    var errorDescription: String? {
        switch self {
        case .assetUnavailable:
            return "The selected refrigeration unit is unavailable."
        case .siteUnavailable:
            return "The selected unit’s site is unavailable."
        case .evidenceUnavailable:
            return "No evidence is available for the selected unit."
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var store: ColdTwinStore
    @State private var selectedPage: AppPage = .overview
    @State private var showingModelSettings = false
    @State private var showingAddSite = false
    @State private var showingAddAsset = false
    @State private var showingAddReading = false
    @State private var showingCSVImporter = false
    @State private var showingCSVPreview = false
    @State private var showingReportExporter = false
    @State private var csvText = ""
    @State private var reportDocument = JSONReportDocument(data: Data())
    @State private var reportFilename = "ColdTwin-Report.json"
    @State private var fileError: String?

    var body: some View {
        NavigationSplitView {
            List {
                Button {
                    selectedPage = .overview
                } label: {
                    Label("Site Overview", systemImage: "square.grid.2x2")
                }
                .listRowBackground(selectedPage == .overview ? Color.accentColor.opacity(0.15) : Color.clear)

                ForEach(store.sites) { site in
                    Section(site.name) {
                        ForEach(store.assets.filter { $0.siteId == site.id }) { asset in
                            Button {
                                showQuickCheck(for: asset)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(asset.name)
                                    Text("\(asset.assetType.rawValue.capitalized) · \(asset.id)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .listRowBackground(
                                selectedPage == .quickCheck && store.selectedAssetId == asset.id
                                    ? Color.accentColor.opacity(0.15)
                                    : Color.clear
                            )
                        }
                    }
                }
            }
            .navigationTitle("ColdTwin")
        } detail: {
            VStack(spacing: 0) {
                HStack(spacing: 18) {
                    Text("ColdTwin")
                        .font(.headline)
                    Spacer()
                    pageButton("Overview", page: .overview)
                    pageButton("Quick Check", page: .quickCheck)
                    Button("Import CSV", systemImage: "square.and.arrow.down") {
                        showingCSVImporter = true
                    }
                    Button("Export", systemImage: "square.and.arrow.up") {
                        exportReport()
                    }
                    .disabled(store.selectedAssetId == nil)
                    Button("Models", systemImage: "slider.horizontal.3") {
                        showingModelSettings = true
                    }
                    Button("Add Reading", systemImage: "plus") {
                        showingAddReading = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.selectedAssetId == nil)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                Divider()

                Group {
                    if selectedPage == .overview {
                        SiteOverviewView(
                            onQuickCheck: { asset in
                                showQuickCheck(for: asset)
                            },
                            onAddReading: { asset in
                                store.selectedAssetId = asset.id
                                showingAddReading = true
                            },
                            onImportCSV: { showingCSVImporter = true },
                            onAddSite: { showingAddSite = true },
                            onAddAsset: { showingAddAsset = true }
                        )
                    } else if let assetId = store.selectedAssetId,
                              let asset = store.assets.first(where: { $0.id == assetId }) {
                        AssetDetailView(asset: asset)
                    } else {
                        ContentUnavailableView(
                            "Select a Refrigeration Unit",
                            systemImage: "thermometer.snowflake",
                            description: Text("Choose a unit in the sidebar to run a quick check.")
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $showingModelSettings) {
            ExternalModelSettingsView()
        }
        .sheet(isPresented: $showingAddReading) {
            if let assetID = store.selectedAssetId {
                AddReadingView(assetID: assetID)
                    .environmentObject(store)
            }
        }
        .sheet(isPresented: $showingAddSite) {
            AddSiteView()
                .environmentObject(store)
        }
        .sheet(isPresented: $showingAddAsset) {
            AddAssetView()
                .environmentObject(store)
        }
        .sheet(isPresented: $showingCSVPreview) {
            CSVImportReviewView(csvText: csvText)
                .environmentObject(store)
        }
        .fileImporter(
            isPresented: $showingCSVImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText]
        ) { result in
            do {
                let url = try result.get()
                let hasAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if hasAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                let data = try Data(contentsOf: url)
                guard let text = String(data: data, encoding: .utf8) else {
                    throw FileImportError.invalidEncoding
                }
                csvText = text
                showingCSVPreview = true
            } catch {
                fileError = error.localizedDescription
            }
        }
        .fileExporter(
            isPresented: $showingReportExporter,
            document: reportDocument,
            contentType: .json,
            defaultFilename: reportFilename
        ) { result in
            if case .failure(let error) = result {
                fileError = error.localizedDescription
            }
        }
        .alert("File operation failed", isPresented: Binding(
            get: { fileError != nil },
            set: { if !$0 { fileError = nil } }
        )) {
            Button("OK") { fileError = nil }
        } message: {
            Text(fileError ?? "An unknown error occurred.")
        }
    }

    private func pageButton(_ title: String, page: AppPage) -> some View {
        Button(title) {
            if page == .quickCheck {
                if let assetID = store.selectedAssetId,
                   let asset = store.assets.first(where: { $0.id == assetID }) {
                    showQuickCheck(for: asset)
                } else if let asset = store.assets.first {
                    showQuickCheck(for: asset)
                }
            }
            selectedPage = page
        }
        .buttonStyle(.plain)
        .foregroundStyle(selectedPage == page ? Color.accentColor : Color.primary)
    }

    private func showQuickCheck(for asset: Asset) {
        store.selectedAssetId = asset.id
        selectedPage = .quickCheck
        if store.analyses[asset.id] == nil {
            store.runAnalysis(for: asset.id)
        }
    }

    private func exportReport() {
        guard let assetID = store.selectedAssetId,
              let asset = store.assets.first(where: { $0.id == assetID }) else { return }
        do {
            reportDocument = JSONReportDocument(data: try store.reportData(for: assetID))
            reportFilename = "\(asset.id)-ColdTwin-Report"
            showingReportExporter = true
            fileError = nil
        } catch {
            fileError = error.localizedDescription
        }
    }
}

private enum AppPage {
    case overview
    case quickCheck
}

private struct SiteOverviewView: View {
    @EnvironmentObject private var store: ColdTwinStore
    @State private var searchText = ""
    let onQuickCheck: (Asset) -> Void
    let onAddReading: (Asset) -> Void
    let onImportCSV: () -> Void
    let onAddSite: () -> Void
    let onAddAsset: () -> Void

    private var visibleAssets: [Asset] {
        guard !searchText.isEmpty else { return store.assets }
        return store.assets.filter { asset in
            asset.name.localizedCaseInsensitiveContains(searchText) ||
            asset.id.localizedCaseInsensitiveContains(searchText) ||
            store.sites.first(where: { $0.id == asset.siteId })?.name.localizedCaseInsensitiveContains(searchText) == true
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Site Refrigeration Overview")
                        .font(.largeTitle.bold())
                    Text("Advisory status summary across \(store.sites.count) sites and \(store.assets.count) refrigeration units. Synthetic demo readings are labeled.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let inventoryError = store.inventoryError {
                    Label(inventoryError, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
                HStack {
                    Button("Load Demo Data", systemImage: "arrow.clockwise") {
                        store.loadDemoData()
                    }
                    Button("Add Site", systemImage: "building.2", action: onAddSite)
                    Button("Add Asset", systemImage: "thermometer.snowflake", action: onAddAsset)
                        .disabled(store.sites.isEmpty)
                    Button("Import CSV", systemImage: "square.and.arrow.down", action: onImportCSV)
                    Spacer()
                    Button("Add Reading", systemImage: "plus") {
                        if let asset = store.assets.first(where: { $0.id == store.selectedAssetId }) {
                            onAddReading(asset)
                        } else if let asset = store.assets.first {
                            onAddReading(asset)
                        }
                    }
                    .disabled(store.assets.isEmpty)
                    .buttonStyle(.borderedProminent)
                }

                let statuses = store.assets.compactMap { asset -> AssetStatus? in
                    store.preparedEvidence(for: asset.id)?.statusAtAnalysis
                }
                HStack(spacing: 12) {
                    statusCard("Investigate", count: statuses.filter { $0 == .investigate }.count, color: .red)
                    statusCard("Watch", count: statuses.filter { $0 == .watch }.count, color: .orange)
                    statusCard("Normal", count: statuses.filter { $0 == .normal }.count, color: .green)
                    statusCard("Insufficient data", count: statuses.filter { $0 == .insufficientData }.count, color: .secondary)
                }

                HStack {
                    TextField("Filter assets or sites…", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                    Text("All Sites (\(store.sites.count))")
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 0) {
                    HStack {
                        Text("Asset & Site")
                        Spacer()
                        Text("Latest Reading").frame(width: 120, alignment: .trailing)
                        Text("Configured Range").frame(width: 150, alignment: .trailing)
                        Text("Actions").frame(width: 180, alignment: .trailing)
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(12)
                    ForEach(visibleAssets) { asset in
                        assetRow(asset)
                        Divider()
                    }
                }
                .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(24)
        }
    }

    private func statusCard(_ title: String, count: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text("\(count)").font(.title2.bold()).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
    }

    private func assetRow(_ asset: Asset) -> some View {
        let latest = store.readings.filter { $0.assetId == asset.id }.max { $0.timestamp < $1.timestamp }
        let status = store.preparedEvidence(for: asset.id)?.statusAtAnalysis ?? .insufficientData
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(asset.name).font(.headline)
                if let site = store.sites.first(where: { $0.id == asset.siteId }) {
                    Text(site.name).font(.caption).foregroundStyle(.secondary)
                    if !site.location.isEmpty {
                        Text(site.location).font(.caption2).foregroundStyle(.secondary)
                    }
                } else {
                    Text("Unknown site").font(.caption).foregroundStyle(.secondary)
                }
                Text("\(asset.assetType.rawValue.capitalized) · \(asset.id)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                if asset.isDemo {
                    Text("Synthetic demo").font(.caption2).foregroundStyle(.orange)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let latest {
                    Text(String(format: "%.1f°%@", asset.preferredUnit.fromCelsius(latest.normalizedCelsius), asset.preferredUnit.rawValue))
                        .font(.system(.body, design: .monospaced))
                    Text(latest.timestamp, style: .date).font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("No readings").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(width: 120, alignment: .trailing)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(asset.preferredUnit.fromCelsius(asset.rangeMinC), specifier: "%.1f") to \(asset.preferredUnit.fromCelsius(asset.rangeMaxC), specifier: "%.1f") °\(asset.preferredUnit.rawValue)")
                    .font(.system(.caption, design: .monospaced))
                Text(asset.rangeSource.rawValue.replacingOccurrences(of: "_", with: " "))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .frame(width: 150, alignment: .trailing)
            Label(status.rawValue, systemImage: status == .normal ? "checkmark.circle" : "exclamationmark.magnifyingglass")
                .font(.caption)
                .frame(width: 120, alignment: .trailing)
            Button("Reading") { onAddReading(asset) }
                .buttonStyle(.bordered)
            Button("Quick Check") { onQuickCheck(asset) }
                .buttonStyle(.borderedProminent)
        }
        .padding(12)
    }
}

private struct AddReadingView: View {
    @EnvironmentObject private var store: ColdTwinStore
    @Environment(\.dismiss) private var dismiss
    @State private var value = ""
    @State private var unit: TemperatureUnit = .celsius
    @State private var timestamp = Date()
    let assetID: String

    var body: some View {
        NavigationStack {
            Form {
                if let asset = store.assets.first(where: { $0.id == assetID }) {
                    LabeledContent("Refrigeration unit", value: asset.name)
                }
                TextField("Temperature", text: $value)
                    .textFieldStyle(.roundedBorder)
                Picker("Unit", selection: $unit) {
                    Text("Celsius (°C)").tag(TemperatureUnit.celsius)
                    Text("Fahrenheit (°F)").tag(TemperatureUnit.fahrenheit)
                }
                DatePicker("Reading time", selection: $timestamp)
                if let error = store.readingError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
            .padding()
            .navigationTitle("Add Temperature Reading")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Reading") {
                        guard let numericValue = Double(value),
                              store.addReading(assetID: assetID, value: numericValue, unit: unit, timestamp: timestamp) else {
                            if Double(value) == nil {
                                store.readingError = "Enter a valid temperature."
                            }
                            return
                        }
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 420, minHeight: 300)
    }
}

private struct AddSiteView: View {
    @EnvironmentObject private var store: ColdTwinStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var location = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Site name", text: $name)
                TextField("Location (optional)", text: $location)
                if let inventoryError = store.inventoryError {
                    Label(inventoryError, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
            .padding()
            .navigationTitle("Add Site")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add Site") {
                        if store.addSite(name: name, location: location) {
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(minWidth: 440, minHeight: 240)
    }
}

private struct AddAssetView: View {
    @EnvironmentObject private var store: ColdTwinStore
    @Environment(\.dismiss) private var dismiss
    @State private var siteID = ""
    @State private var name = ""
    @State private var assetType: AssetType = .cooler
    @State private var unit: TemperatureUnit = .celsius
    @State private var minimum = "1.0"
    @State private var maximum = "5.0"

    var body: some View {
        NavigationStack {
            Form {
                Picker("Site", selection: $siteID) {
                    ForEach(store.sites) { site in
                        Text(site.name).tag(site.id)
                    }
                }
                TextField("Unit name", text: $name)
                Picker("Unit type", selection: $assetType) {
                    Text("Cooler").tag(AssetType.cooler)
                    Text("Freezer").tag(AssetType.freezer)
                }
                Picker("Temperature unit", selection: $unit) {
                    Text("Celsius (°C)").tag(TemperatureUnit.celsius)
                    Text("Fahrenheit (°F)").tag(TemperatureUnit.fahrenheit)
                }
                TextField("Minimum operating limit (°\(unit.rawValue))", text: $minimum)
                TextField("Maximum operating limit (°\(unit.rawValue))", text: $maximum)
                Text("Limits are saved in Celsius and marked as user-configured.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let inventoryError = store.inventoryError {
                    Label(inventoryError, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
            .padding()
            .onAppear {
                if siteID.isEmpty {
                    siteID = store.sites.first?.id ?? ""
                }
            }
            .onChange(of: assetType) { _, type in
                let limits = type == .cooler ? (1.0, 5.0) : (-22.0, -15.0)
                minimum = String(format: "%.1f", unit.fromCelsius(limits.0))
                maximum = String(format: "%.1f", unit.fromCelsius(limits.1))
            }
            .onChange(of: unit) { oldUnit, newUnit in
                if let value = Double(minimum) {
                    minimum = String(format: "%.1f", newUnit.fromCelsius(oldUnit.toCelsius(value)))
                }
                if let value = Double(maximum) {
                    maximum = String(format: "%.1f", newUnit.fromCelsius(oldUnit.toCelsius(value)))
                }
            }
            .navigationTitle("Add Refrigeration Unit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add Unit") {
                        guard let minimumValue = Double(minimum),
                              let maximumValue = Double(maximum) else {
                            store.inventoryError = "Enter numeric operating limits."
                            return
                        }
                        if store.addAsset(
                            siteID: siteID,
                            name: name,
                            assetType: assetType,
                            preferredUnit: unit,
                            rangeMinimum: minimumValue,
                            rangeMaximum: maximumValue
                        ) != nil {
                            dismiss()
                        }
                    }
                    .disabled(store.sites.isEmpty || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(minWidth: 520, minHeight: 420)
    }
}

private enum FileImportError: LocalizedError {
    case invalidEncoding

    var errorDescription: String? {
        "The selected file is not valid UTF-8 text."
    }
}

private struct JSONReportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct AssetDetailView: View {
    @EnvironmentObject var store: ColdTwinStore
    @State private var showingExternalConsent = false
    @State private var displayUnit: TemperatureUnit = .celsius
    @State private var chartWindow: ChartWindow = .all
    @State private var showingReadingTable = false
    let asset: Asset

    private var selectedExternalModel: ExternalModelProfile? {
        guard let id = store.inferenceMemory.selectedExternalModelID else { return nil }
        return store.inferenceMemory.externalModels.first { $0.id == id }
    }

    var assetReadings: [TemperatureReading] {
        store.readings.filter { $0.assetId == asset.id }.sorted { $0.timestamp < $1.timestamp }
    }

    private var visibleReadings: [TemperatureReading] {
        guard let latest = assetReadings.last, chartWindow.hours != nil else { return assetReadings }
        let cutoff = latest.timestamp.addingTimeInterval(-chartWindow.hours! * 3600)
        return assetReadings.filter { $0.timestamp >= cutoff }
    }

    private var readingSegments: [[TemperatureReading]] {
        var segments: [[TemperatureReading]] = []
        var currentSegment: [TemperatureReading] = []
        for reading in visibleReadings {
            if let previous = currentSegment.last,
               reading.timestamp.timeIntervalSince(previous.timestamp) > DiagnosisRulesConfig.gapBreakMinutes * 60 {
                segments.append(currentSegment)
                currentSegment = []
            }
            currentSegment.append(reading)
        }
        if !currentSegment.isEmpty {
            segments.append(currentSegment)
        }
        return segments
    }

    private var chartDateDomain: ClosedRange<Date> {
        guard let first = visibleReadings.first?.timestamp,
              let last = visibleReadings.last?.timestamp else {
            let now = Date()
            return now.addingTimeInterval(-3600)...now
        }
        if first == last {
            return first.addingTimeInterval(-1800)...last.addingTimeInterval(1800)
        }
        return first...last
    }

    private var visibleEvents: [RecordedEvent] {
        guard let first = visibleReadings.first?.timestamp,
              let last = visibleReadings.last?.timestamp else { return [] }
        return store.events.filter {
            $0.assetId == asset.id && $0.timestamp >= first && $0.timestamp <= last
        }.sorted { $0.timestamp < $1.timestamp }
    }

    private var preparedEvidence: Analysis? {
        store.preparedEvidence(for: asset.id)
    }

    private var latestReading: TemperatureReading? {
        assetReadings.last
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let memoryError = store.memoryError {
                    Label(memoryError, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
                if let inventoryError = store.inventoryError {
                    Label(inventoryError, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }

                assetSummary

                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        temperatureTimeline
                        recordedEventsPanel
                    }
                    .frame(maxWidth: .infinity)
                    ResourceContextPanel()
                        .frame(width: 270)
                }

                InferenceRulesPanel()

                if let preparedEvidence {
                    GroupBox("Observed Facts & Data Quality") {
                        VStack(alignment: .leading, spacing: 8) {
                            LabeledContent("Status", value: preparedEvidence.statusAtAnalysis.rawValue)
                            Text(preparedEvidence.summary)
                            if !preparedEvidence.dataQualityNotes.isEmpty {
                                ForEach(preparedEvidence.dataQualityNotes, id: \.self) { note in
                                    Label(note, systemImage: "exclamationmark.triangle")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                            ForEach(preparedEvidence.observations) { observation in
                                LabeledContent(observation.kind.replacingOccurrences(of: "_", with: " ")) {
                                    Text(observation.description)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .font(.caption)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if store.isAnalyzing {
                    ProgressView(selectedExternalModel == nil
                        ? "Reasoning with the on-device model…"
                        : "Reasoning with the selected external model…")
                }
                if let error = store.analysisError {
                    ContentUnavailableView(
                        selectedExternalModel == nil ? "On-device analysis unavailable" : "External analysis failed",
                        systemImage: selectedExternalModel == nil ? "brain" : "network",
                        description: Text(error)
                    )
                }
                if let analysis = store.analyses[asset.id] {
                    Text("Advisory Diagnosis & Resource-Aware Next Checks")
                        .font(.title3.bold())
                    Text("Provisional advisory assessment — not a confirmed diagnosis.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text(analysis.summary).font(.subheadline)
                    ForEach(analysis.options) { option in
                        diagnosisCard(option, analysis: analysis)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            displayUnit = asset.preferredUnit
        }
        .alert(
            "Send data to \(selectedExternalModel?.name ?? "the external model")?",
            isPresented: $showingExternalConsent
        ) {
            Button("Send and analyze") {
                store.runExternalAnalysis(for: asset.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("""
            This sends \(asset.name)'s temperature values, timestamps and source labels, event notes, configured range, local reasoning rules, and recent feedback for this unit to \(selectedExternalModel?.baseURL ?? "the configured endpoint") for \(selectedExternalModel?.modelID ?? "the selected model"). Your API key is sent for authorization and stored in macOS Keychain. No request is made unless you choose Send and analyze. A hosted provider may process data under its own privacy and retention terms.
            """)
        }
    }

    private var assetSummary: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text(asset.name).font(.title2.bold())
                    if let preparedEvidence {
                        Label(preparedEvidence.statusAtAnalysis.rawValue, systemImage: "exclamationmark.magnifyingglass")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Spacer()
                    Picker("Display unit", selection: $displayUnit) {
                        Text("°C").tag(TemperatureUnit.celsius)
                        Text("°F").tag(TemperatureUnit.fahrenheit)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 110)
                }
                Text("\(store.sites.first(where: { $0.id == asset.siteId })?.name ?? "Unknown site") · \(asset.assetType.rawValue.capitalized) · \(asset.id)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    if let selectedExternalModel {
                        Button("Analyze with \(selectedExternalModel.name)", systemImage: "sparkles") {
                            showingExternalConsent = true
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(store.isAnalyzing)
                    } else {
                        Button("Analyze", systemImage: "sparkles") {
                            store.runAnalysis(for: asset.id)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(store.isAnalyzing)
                    }
                    Picker(
                        "Inference model",
                        selection: Binding(
                            get: { store.inferenceMemory.selectedExternalModelID ?? "" },
                            set: { store.selectExternalModel($0.isEmpty ? nil : $0) }
                        )
                    ) {
                        Text("On-device Foundation Model").tag("")
                        ForEach(store.inferenceMemory.externalModels) { model in
                            Text(model.name).tag(model.id)
                        }
                    }
                    .frame(maxWidth: 250)
                    Text("External analysis requires confirmation.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Divider()
                HStack(alignment: .top, spacing: 24) {
                    summaryValue(
                        "Latest Reading",
                        value: latestReading.map {
                            String(format: "%.1f °%@", displayUnit.fromCelsius($0.normalizedCelsius), displayUnit.rawValue)
                        } ?? "No readings",
                        detail: latestReading.map {
                            "\(ISO8601DateFormatter().string(from: $0.timestamp)) · \($0.sourceLabel)"
                        } ?? "Add or import a reading to begin."
                    )
                    summaryValue(
                        "Configured Operating Range",
                        value: String(
                            format: "%.1f to %.1f °%@",
                            displayUnit.fromCelsius(asset.rangeMinC),
                            displayUnit.fromCelsius(asset.rangeMaxC),
                            displayUnit.rawValue
                        ),
                        detail: "\(asset.rangeSource.rawValue.replacingOccurrences(of: "_", with: " ")) · illustrative, not a regulatory limit"
                    )
                    summaryValue(
                        "Assessment & Data Quality",
                        value: preparedEvidence?.summary ?? "No assessment available.",
                        detail: preparedEvidence?.dataQualityNotes.joined(separator: " ") ?? "No data-quality notes."
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func summaryValue(_ title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline)
            Text(detail).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var temperatureTimeline: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Temperature Timeline (°\(displayUnit.rawValue))").font(.headline)
                        Text("Operating band: \(displayUnit.fromCelsius(asset.rangeMinC), specifier: "%.1f") to \(displayUnit.fromCelsius(asset.rangeMaxC), specifier: "%.1f") °\(displayUnit.rawValue) · data gaps are not interpolated")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("Time window", selection: $chartWindow) {
                        ForEach(ChartWindow.allCases) { window in
                            Text(window.rawValue).tag(window)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 280)
                    Picker("Timeline view", selection: $showingReadingTable) {
                        Text("Chart").tag(false)
                        Text("Table Summary").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 170)
                }
                if showingReadingTable {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Timestamp")
                            Spacer()
                            Text("Temperature")
                            Text("Source").frame(width: 150, alignment: .trailing)
                        }
                        .font(.caption.bold())
                        ForEach(visibleReadings.reversed()) { reading in
                            Divider()
                            HStack {
                                Text(reading.originalTimestamp)
                                Spacer()
                                Text(String(format: "%.1f °%@", displayUnit.fromCelsius(reading.normalizedCelsius), displayUnit.rawValue))
                                Text(reading.sourceLabel).frame(width: 150, alignment: .trailing)
                            }
                            .font(.caption)
                        }
                    }
                    .padding(.vertical, 6)
                } else {
                    Chart {
                        RectangleMark(
                            yStart: .value("Min", displayUnit.fromCelsius(asset.rangeMinC)),
                            yEnd: .value("Max", displayUnit.fromCelsius(asset.rangeMaxC))
                        )
                        .foregroundStyle(.green.opacity(0.12))

                        ForEach(Array(zip(visibleReadings, visibleReadings.dropFirst())), id: \.1.id) { previous, next in
                            if next.timestamp.timeIntervalSince(previous.timestamp) > DiagnosisRulesConfig.gapBreakMinutes * 60 {
                                RectangleMark(
                                    xStart: .value("Gap start", previous.timestamp),
                                    xEnd: .value("Gap end", next.timestamp),
                                    yStart: .value("Gap min", displayUnit.fromCelsius(asset.rangeMinC)),
                                    yEnd: .value("Gap max", displayUnit.fromCelsius(asset.rangeMaxC))
                                )
                                .foregroundStyle(.gray.opacity(0.18))
                                .annotation(position: .top) {
                                    Text("No data (\(Int(next.timestamp.timeIntervalSince(previous.timestamp) / 60))m gap)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        ForEach(visibleEvents) { event in
                            RuleMark(x: .value("Event", event.timestamp))
                                .foregroundStyle(.orange.opacity(0.8))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        }

                        ForEach(Array(readingSegments.enumerated()), id: \.offset) { segmentIndex, segment in
                            ForEach(segment) { reading in
                                LineMark(
                                    x: .value("Time", reading.timestamp),
                                    y: .value("Temp", displayUnit.fromCelsius(reading.normalizedCelsius)),
                                    series: .value("Reading segment", segmentIndex)
                                )
                                .foregroundStyle(.blue)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                            }
                        }

                        ForEach(visibleReadings) { reading in
                            PointMark(
                                x: .value("Time", reading.timestamp),
                                y: .value("Temp", displayUnit.fromCelsius(reading.normalizedCelsius))
                            )
                            .foregroundStyle(
                                reading.normalizedCelsius < asset.rangeMinC || reading.normalizedCelsius > asset.rangeMaxC
                                    ? Color.red
                                    : Color.blue
                            )
                        }
                    }
                    .chartXScale(domain: chartDateDomain)
                    .chartYAxisLabel("Temperature (°\(displayUnit.rawValue))")
                    .frame(height: 250)
                    HStack(spacing: 14) {
                        Label("In-range reading", systemImage: "circle.fill").foregroundStyle(.blue)
                        Label("Out-of-range reading", systemImage: "circle.fill").foregroundStyle(.red)
                        Label("Configured range", systemImage: "square.fill").foregroundStyle(.green)
                        Label("Trend between nearby readings", systemImage: "line.diagonal").foregroundStyle(.blue)
                        Label("Recorded event", systemImage: "line.diagonal").foregroundStyle(.orange)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var recordedEventsPanel: some View {
        if !visibleEvents.isEmpty {
            GroupBox("Recorded Events in Window") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(visibleEvents) { event in
                        HStack(alignment: .top) {
                            Text(event.originalTimestamp)
                                .font(.caption2.monospaced())
                            Text(event.category.rawValue.replacingOccurrences(of: "_", with: " "))
                                .font(.caption.bold())
                                .foregroundStyle(.orange)
                            Text(event.note).font(.caption)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func diagnosisCard(_ option: DiagnosisOption, analysis: Analysis) -> some View {
        let observations = Dictionary(uniqueKeysWithValues: analysis.observations.map { ($0.id, $0.description) })
        let override = store.inferenceMemory.assessmentOverrides["\(asset.id)::\(option.id)"] ?? .automatic
        let displayedAssessment: String
        switch override {
        case .automatic:
            displayedAssessment = option.status.replacingOccurrences(of: "_", with: " ")
        case .possible:
            displayedAssessment = "possible · your override"
        case .needsMoreEvidence:
            displayedAssessment = "needs more evidence · your override"
        }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(option.hypothesis).font(.headline)
                Spacer()
                Text(displayedAssessment)
                    .font(.caption.bold())
                Text("\(override == .automatic ? "" : "Model priority · ")\(option.priorityLabel.replacingOccurrences(of: "_", with: " "))")
                    .font(.caption)
                    .foregroundStyle(option.priorityLabel == "requires_technician" ? .red : .orange)
            }
            Text(option.plainLanguageExplanation).font(.subheadline)
            if override != .automatic {
                Text("Model assessment: \(option.status.replacingOccurrences(of: "_", with: " ")). Your override changes this hypothesis's status only; it does not change the evidence.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Label("~\(option.requirements.estimatedMinutes) min", systemImage: "clock")
                Text("Skills: \(option.requirements.skills.map(\.rawValue).joined(separator: ", "))")
                Text("Tools: \(option.requirements.tools.map(\.rawValue).joined(separator: ", "))")
                Spacer()
                Text("Risk: \(option.requirements.risk)")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            Text(option.availabilityStatus == "ready" ? "Ready with current resources" : "Resource fit: \(option.availabilityStatus.replacingOccurrences(of: "_", with: " "))")
                .font(.caption)
                .foregroundStyle(option.availabilityStatus == "ready" ? .green : .orange)
            DisclosureGroup("Details") {
                VStack(alignment: .leading, spacing: 8) {
                    detailList("Supporting Observations", ids: option.supportingObservationIds, observations: observations)
                    detailList("Conflicting Observations", ids: option.conflictingObservationIds, observations: observations)
                    detailList("Assumptions", values: option.assumptions)
                    detailList("Missing Information", values: option.missingInformation)
                    LabeledContent("Counterfactual", value: option.counterfactualPrediction)
                    LabeledContent("Safe next check", value: option.nextCheck)
                    LabeledContent("Supports", value: option.expectedResults.supportsHypothesis)
                    LabeledContent("Weakens", value: option.expectedResults.weakensHypothesis)
                    detailList("Why it is ranked here", values: option.priorityFactors)
                }
                .font(.caption)
                .padding(.top, 8)
            }
            Picker(
                "Assessment",
                selection: Binding(
                    get: {
                        store.inferenceMemory.assessmentOverrides["\(asset.id)::\(option.id)"] ?? .automatic
                    },
                    set: {
                        store.setAssessmentOverride($0, assetID: asset.id, hypothesisID: option.id)
                    }
                )
            ) {
                Text("Use model assessment").tag(UserAssessmentOverride.automatic)
                Text("Override: possible").tag(UserAssessmentOverride.possible)
                Text("Override: needs more evidence").tag(UserAssessmentOverride.needsMoreEvidence)
            }
            .pickerStyle(.menu)
            Text("Overrides change this status label only—not the evidence, model output, or priority ranking. Choose “Use model assessment” to clear it.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func detailList(_ title: String, ids: [String], observations: [String: String]) -> some View {
        if !ids.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).fontWeight(.semibold)
                ForEach(ids, id: \.self) { id in
                    Text("• \(observations[id] ?? "Unresolved observation")")
                }
            }
        } else {
            LabeledContent(title, value: "None recorded.")
        }
    }

    @ViewBuilder
    private func detailList(_ title: String, values: [String]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).fontWeight(.semibold)
            if values.isEmpty {
                Text("None recorded.")
            } else {
                ForEach(values, id: \.self) { value in Text("• \(value)") }
            }
        }
    }
}

private enum ChartWindow: String, CaseIterable, Identifiable {
    case sixHours = "6H"
    case oneDay = "24H"
    case sevenDays = "7D"
    case all = "All"

    var id: String { rawValue }
    var hours: Double? {
        switch self {
        case .sixHours: 6
        case .oneDay: 24
        case .sevenDays: 168
        case .all: nil
        }
    }
}

private struct ResourceContextPanel: View {
    @EnvironmentObject private var store: ColdTwinStore

    var body: some View {
        GroupBox("Resources Available") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Available time", selection: Binding(
                    get: { store.resourceContext.availableMinutes ?? 15 },
                    set: { minutes in update { $0.availableMinutes = minutes } }
                )) {
                    Text("5 min").tag(5)
                    Text("15 min").tag(15)
                    Text("30 min").tag(30)
                    Text("60 min").tag(60)
                }
                Text("Skills Available").font(.headline)
                ForEach(SkillLevel.allCases, id: \.self) { skill in
                    Toggle(skill.rawValue.capitalized, isOn: toggle(for: skill))
                        .font(.caption)
                }
                Text("Tools Available").font(.headline)
                ForEach(ToolItem.allCases, id: \.self) { tool in
                    Toggle(tool.rawValue.capitalized, isOn: toggle(for: tool))
                        .font(.caption)
                }
                Divider()
                Label("Labels reflect evidence fit and check feasibility, not fault confirmation.", systemImage: "info.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let assetID = store.selectedAssetId,
                   let evidence = store.preparedEvidence(for: assetID),
                   !evidence.dataQualityNotes.isEmpty {
                    Text("Data-Quality Caveats").font(.headline)
                    ForEach(evidence.dataQualityNotes, id: \.self) { note in
                        Label(note, systemImage: "exclamationmark.triangle")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func toggle(for skill: SkillLevel) -> Binding<Bool> {
        Binding(
            get: { store.resourceContext.availableSkills.contains(skill) },
            set: { enabled in
                update { context in
                    if enabled {
                        if !context.availableSkills.contains(skill) { context.availableSkills.append(skill) }
                    } else {
                        context.availableSkills.removeAll { $0 == skill }
                    }
                }
            }
        )
    }

    private func toggle(for tool: ToolItem) -> Binding<Bool> {
        Binding(
            get: { store.resourceContext.availableTools.contains(tool) },
            set: { enabled in
                update { context in
                    if enabled {
                        if !context.availableTools.contains(tool) { context.availableTools.append(tool) }
                    } else {
                        context.availableTools.removeAll { $0 == tool }
                    }
                }
            }
        )
    }

    private func update(_ change: (inout ResourceContext) -> Void) {
        var context = store.resourceContext
        change(&context)
        store.updateResourceContext(context)
    }
}

private struct InferenceRulesPanel: View {
    @EnvironmentObject private var store: ColdTwinStore
    @State private var draftRule = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Local reasoning rules").font(.headline)
            Text("These preferences are saved on this Mac and included in future on-device assessments.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .top) {
                TextField("Add a reasoning preference", text: $draftRule, axis: .vertical)
                    .lineLimit(2...4)
                Button("Add") {
                    if store.addRule(draftRule) {
                        draftRule = ""
                    }
                }
                .disabled(draftRule.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            ForEach(store.inferenceMemory.customRules, id: \.self) { rule in
                HStack(alignment: .top) {
                    Text(rule).frame(maxWidth: .infinity, alignment: .leading)
                    Button("Remove", systemImage: "trash") {
                        store.removeRule(rule)
                    }
                    .labelStyle(.iconOnly)
                }
            }
        }
        .padding()
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ExternalModelSettingsView: View {
    @EnvironmentObject private var store: ColdTwinStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var baseURL = "https://api.openai.com/v1"
    @State private var modelID = ""
    @State private var apiKey = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Add an OpenAI-compatible model") {
                    TextField("Display name", text: $name)
                    TextField("Base URL", text: $baseURL)
                    TextField("Model ID", text: $modelID)
                    SecureField("API key (optional for local servers)", text: $apiKey)
                    Text("HTTPS is required for remote endpoints. HTTP is allowed only for localhost. API keys are stored in macOS Keychain, not in app preferences.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Add model") {
                        if store.addExternalModel(
                            name: name,
                            baseURL: baseURL,
                            modelID: modelID,
                            apiKey: apiKey
                        ) {
                            name = ""
                            modelID = ""
                            apiKey = ""
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let memoryError = store.memoryError {
                    Section {
                        Label(memoryError, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }

                Section("Configured models") {
                    if store.inferenceMemory.externalModels.isEmpty {
                        Text("No external models configured.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(store.inferenceMemory.externalModels) { model in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(model.name)
                                Text("\(model.modelID) · \(model.baseURL)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if store.inferenceMemory.selectedExternalModelID == model.id {
                                Text("Selected").font(.caption)
                            }
                            Button("Remove", systemImage: "trash") {
                                store.removeExternalModel(model)
                            }
                            .labelStyle(.iconOnly)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Inference models")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 620, minHeight: 520)
    }
}
