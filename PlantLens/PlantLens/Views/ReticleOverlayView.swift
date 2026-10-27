import SwiftUI

struct ReticleOverlayView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 24)
            .strokeBorder(
                style: StrokeStyle(lineWidth: 2, dash: [40, 180])
            )
            .foregroundColor(.white.opacity(0.6))
            .frame(width: 260, height: 260)
    }
}