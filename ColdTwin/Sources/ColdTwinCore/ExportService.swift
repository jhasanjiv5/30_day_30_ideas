import Foundation

public struct ColdTwinJSONExport: Codable, Sendable {
    public let schema_version: String
    public let generated_at: String
    public let asset: AssetPayload
    public let assessment: AssessmentPayload
    public let observations: [Observation]
    public let options: [DiagnosisOption]
    public let selection_context: SelectionContextPayload
    public let user_notes: [String]

    public struct AssetPayload: Codable, Sendable {
        public let id: String
        public let name: String
        public let site: String
        public let asset_type: String
        public let temperature_unit: String
    }

    public struct AssessmentPayload: Codable, Sendable {
        public let status: String
        public let summary: String
        public let configured_range: RangePayload
        public let data_quality_notes: [String]
    }

    public struct RangePayload: Codable, Sendable {
        public let minimum: Double
        public let maximum: Double
        public let unit: String
        public let source: String
    }

    public struct SelectionContextPayload: Codable, Sendable {
        public let available_time_minutes: Int?
        public let available_skills: [String]
        public let available_tools: [String]
    }
}

public struct ExportService {
    public init() {}

    public func encodeJSON(
        asset: Asset,
        siteName: String,
        analysis: Analysis,
        context: ResourceContext,
        events: [RecordedEvent]
    ) throws -> Data {
        let payload = ColdTwinJSONExport(
            schema_version: "1.0",
            generated_at: ISO8601DateFormatter().string(from: Date()),
            asset: .init(
                id: asset.id,
                name: asset.name,
                site: siteName,
                asset_type: asset.assetType.rawValue,
                temperature_unit: asset.preferredUnit.rawValue
            ),
            assessment: .init(
                status: "provisional",
                summary: analysis.summary,
                configured_range: .init(
                    minimum: asset.preferredUnit.fromCelsius(asset.rangeMinC),
                    maximum: asset.preferredUnit.fromCelsius(asset.rangeMaxC),
                    unit: asset.preferredUnit.rawValue,
                    source: asset.rangeSource.rawValue
                ),
                data_quality_notes: analysis.dataQualityNotes
            ),
            observations: analysis.observations,
            options: analysis.options,
            selection_context: .init(
                available_time_minutes: context.availableMinutes,
                available_skills: context.availableSkills.map(\.rawValue),
                available_tools: context.availableTools.map(\.rawValue)
            ),
            user_notes: events.map { "[\($0.originalTimestamp)] \($0.note)" }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }
}
