import SwiftUI

public struct AudioLevelMeterView: View {
    public let level: Float
    public let isRecording: Bool
    public let elapsedSeconds: TimeInterval

    private let barCount = 24

    public init(level: Float, isRecording: Bool, elapsedSeconds: TimeInterval) {
        self.level = level
        self.isRecording = isRecording
        self.elapsedSeconds = elapsedSeconds
    }

    public var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isRecording ? Color.red : Color.secondary.opacity(0.35))
                    .frame(width: 9, height: 9)
                Text(isRecording ? "Recording" : "Standby")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isRecording ? .primary : .secondary)
            }
            .frame(width: 84, alignment: .leading)

            GeometryReader { proxy in
                HStack(spacing: 3) {
                    ForEach(0..<barCount, id: \.self) { idx in
                        let threshold = Float(idx) / Float(barCount)
                        let active = isRecording && level > threshold
                        RoundedRectangle(cornerRadius: 2)
                            .fill(barColor(index: idx, active: active))
                    }
                }
                .frame(width: proxy.size.width, height: 14)
            }
            .frame(height: 14)

            Text(String(format: "%.1fs", elapsedSeconds))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
    }

    private func barColor(index: Int, active: Bool) -> Color {
        guard active else {
            return Color.secondary.opacity(0.18)
        }
        if index >= Int(Double(barCount) * 0.85) {
            return StudioTheme.danger
        } else if index >= Int(Double(barCount) * 0.65) {
            return StudioTheme.warning
        } else {
            return StudioTheme.accent
        }
    }
}
