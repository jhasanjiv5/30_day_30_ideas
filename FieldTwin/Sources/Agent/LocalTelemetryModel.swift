import Foundation

struct TelemetryInference: Sendable {
    enum Signal: String, Sendable {
        case temperature = "Elevated temperature"
        case airflow = "Reduced airflow"
        case acoustic = "Abnormal acoustic level"
    }

    let signal: Signal
    let score: Double
    let rationale: String
}

enum LocalTelemetryModel {
    private static let minimumRiskScore = 0.4

    static func infer(from device: SpatialDevice) -> TelemetryInference? {
        let candidates: [(TelemetryInference.Signal, Double, String)] = [
            (
                .temperature,
                normalized((device.temperatureC - 55) / 30),
                String(format: "%.1f °C", device.temperatureC)
            ),
            (
                .airflow,
                device.airflowCfm > 0 ? normalized((80 - device.airflowCfm) / 50) : 0,
                String(format: "%.0f CFM", device.airflowCfm)
            ),
            (
                .acoustic,
                normalized((device.acousticDb - 50) / 20),
                String(format: "%.0f dB", device.acousticDb)
            )
        ]

        guard let strongest = candidates.max(by: { $0.1 < $1.1 }),
              strongest.1 >= minimumRiskScore else {
            return nil
        }

        return TelemetryInference(
            signal: strongest.0,
            score: strongest.1,
            rationale: "\(strongest.0.rawValue): \(strongest.2) on \(device.name)."
        )
    }

    private static func normalized(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
