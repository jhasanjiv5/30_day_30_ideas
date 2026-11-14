import Foundation

public struct CSVPreviewRow: Identifiable, Sendable {
    public let id = UUID()
    public let rowNumber: Int
    public let timestampRaw: String
    public let assetIdRaw: String
    public let temperatureRaw: String
    public let unitRaw: String
    public let eventRaw: String
    public let isValid: Bool
    public let isDuplicate: Bool
    public let errors: [String]
    public let reading: TemperatureReading?
    public let event: RecordedEvent?
}

public struct CSVImporter {
    public init() {}

    public func parse(csvText: String, assets: [Asset], existingReadings: [TemperatureReading]) -> [CSVPreviewRow] {
        let rows = parseRecords(csvText).filter {
            $0.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }

        guard rows.count > 1 else { return [] }

        let headers = rows[0].map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\u{feff}", with: "")
                .lowercased()
        }
        guard let tIdx = headers.firstIndex(of: "timestamp"),
              let aIdx = headers.firstIndex(of: "asset_id"),
              let vIdx = headers.firstIndex(of: "temperature"),
              let uIdx = headers.firstIndex(of: "unit") else {
            return []
        }
        let eIdx = headers.firstIndex(of: "event")

        let assetIds = Set(assets.map(\.id))
        var seen = Set(existingReadings.map { "\($0.assetId)::\(Int($0.timestamp.timeIntervalSince1970))::\(String(format: "%.2f", $0.normalizedCelsius))" })
        let isoParser = ISO8601DateFormatter()

        var results: [CSVPreviewRow] = []
        for (offset, rawCells) in rows.dropFirst().enumerated() {
            let cells = rawCells.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            let tsRaw = cells.indices.contains(tIdx) ? cells[tIdx] : ""
            let idRaw = cells.indices.contains(aIdx) ? cells[aIdx] : ""
            let tempRaw = cells.indices.contains(vIdx) ? cells[vIdx] : ""
            let unitRaw = cells.indices.contains(uIdx) ? cells[uIdx] : ""
            let eventRaw = eIdx.flatMap { cells.indices.contains($0) ? cells[$0] : nil } ?? ""

            var errors: [String] = []
            let parsedDate = isoParser.date(from: tsRaw)
            if parsedDate == nil { errors.append("Invalid ISO-8601 timestamp") }
            if !assetIds.contains(idRaw) { errors.append("Unknown asset_id") }
            let numericVal = Double(tempRaw)
            if numericVal?.isFinite != true { errors.append("Invalid numeric temperature") }
            let parsedUnit: TemperatureUnit? = unitRaw.uppercased() == "C" ? .celsius : (unitRaw.uppercased() == "F" ? .fahrenheit : nil)
            if parsedUnit == nil { errors.append("Unsupported unit (expected C or F)") }

            if !errors.isEmpty {
                results.append(CSVPreviewRow(
                    rowNumber: offset + 2,
                    timestampRaw: tsRaw,
                    assetIdRaw: idRaw,
                    temperatureRaw: tempRaw,
                    unitRaw: unitRaw,
                    eventRaw: eventRaw,
                    isValid: false,
                    isDuplicate: false,
                    errors: errors,
                    reading: nil,
                    event: nil
                ))
                continue
            }

            let reading = TemperatureReading(
                assetId: idRaw,
                originalValue: numericVal!,
                originalUnit: parsedUnit!,
                originalTimestamp: tsRaw,
                timestamp: parsedDate!,
                sourceLabel: "CSV Import"
            )
            let dedupeKey = "\(idRaw)::\(Int(parsedDate!.timeIntervalSince1970))::\(String(format: "%.2f", reading.normalizedCelsius))"
            if seen.contains(dedupeKey) {
                results.append(CSVPreviewRow(
                    rowNumber: offset + 2,
                    timestampRaw: tsRaw,
                    assetIdRaw: idRaw,
                    temperatureRaw: tempRaw,
                    unitRaw: unitRaw,
                    eventRaw: eventRaw,
                    isValid: false,
                    isDuplicate: true,
                    errors: ["Duplicate reading"],
                    reading: nil,
                    event: nil
                ))
                continue
            }

            seen.insert(dedupeKey)
            let ev: RecordedEvent? = eventRaw.isEmpty ? nil : RecordedEvent(
                assetId: idRaw,
                originalTimestamp: tsRaw,
                timestamp: parsedDate!,
                category: eventRaw.lowercased().contains("door") ? .doorOpen : .other,
                note: eventRaw
            )

            results.append(CSVPreviewRow(
                rowNumber: offset + 2,
                timestampRaw: tsRaw,
                assetIdRaw: idRaw,
                temperatureRaw: tempRaw,
                unitRaw: unitRaw,
                eventRaw: eventRaw,
                isValid: true,
                isDuplicate: false,
                errors: [],
                reading: reading,
                event: ev
            ))
        }
        return results
    }

    private func parseRecords(_ text: String) -> [[String]] {
        let characters = Array(text)
        var records: [[String]] = []
        var record: [String] = []
        var field = ""
        var isQuoted = false
        var index = 0

        while index < characters.count {
            let character = characters[index]
            if character == "\"" {
                if isQuoted, index + 1 < characters.count, characters[index + 1] == "\"" {
                    field.append("\"")
                    index += 1
                } else {
                    isQuoted.toggle()
                }
            } else if character == "," && !isQuoted {
                record.append(field)
                field = ""
            } else if (character == "\n" || character == "\r") && !isQuoted {
                record.append(field)
                records.append(record)
                record = []
                field = ""
                if character == "\r", index + 1 < characters.count, characters[index + 1] == "\n" {
                    index += 1
                }
            } else {
                field.append(character)
            }
            index += 1
        }

        if !field.isEmpty || !record.isEmpty {
            record.append(field)
            records.append(record)
        }
        return records
    }
}
