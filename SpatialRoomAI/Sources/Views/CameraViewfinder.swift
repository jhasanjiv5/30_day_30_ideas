import SwiftUI
import AVFoundation

public struct CameraViewfinder: View {
    @Binding public var room: Room
    public var onCapture: (UIImage) -> Void
    
    @State private var selectedLens = "1x"
    @State private var isFlashing = false
    @State private var showGrid = true
    
    public init(room: Binding<Room>, onCapture: @escaping (UIImage) -> Void) {
        self._room = room
        self.onCapture = onCapture
    }
    
    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Viewfinder Surface (Simulated live feed / room background)
            AsyncImage(url: URL(string: room.beforeImage)) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Color.black
                }
            }
            .scaleEffect(selectedLens == "0.5x" ? 0.9 : selectedLens == "2x" ? 1.25 : 1.0)
            .clipped()
            
            // Rule of thirds grid
            if showGrid {
                GeometryReader { geo in
                    Path { path in
                        // Vertical lines
                        path.move(to: CGPoint(x: geo.size.width / 3, y: 0))
                        path.addLine(to: CGPoint(x: geo.size.width / 3, y: geo.size.height))
                        path.move(to: CGPoint(x: geo.size.width * 2 / 3, y: 0))
                        path.addLine(to: CGPoint(x: geo.size.width * 2 / 3, y: geo.size.height))
                        // Horizontal lines
                        path.move(to: CGPoint(x: 0, y: geo.size.height / 3))
                        path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 3))
                        path.move(to: CGPoint(x: 0, y: geo.size.height * 2 / 3))
                        path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height * 2 / 3))
                    }
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                }
            }
            
            // Center LiDAR Horizon crosshair
            Circle()
                .stroke(Color.yellow.opacity(0.8), lineWidth: 1.5)
                .frame(width: 36, height: 36)
                .overlay(Circle().fill(Color.yellow).frame(width: 4, height: 4))
            
            // Shutter Flash
            if isFlashing {
                Color.white
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
            
            // Camera Controls Overlay
            VStack {
                // Top Telemetry
                HStack {
                    HStack(spacing: 6) {
                        Circle().fill(Color.red).frame(width: 6, height: 6)
                        Text("LiDAR SPATIAL ACTIVE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    
                    Spacer()
                }
                .padding(.top, 16)
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Lens switcher
                HStack(spacing: 8) {
                    ForEach(["0.5x", "1x", "2x"], id: \.self) { lens in
                        Button(action: { selectedLens = lens }) {
                            Text(lens)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(selectedLens == lens ? .black : .white)
                                .frame(width: 32, height: 32)
                                .background(selectedLens == lens ? Color.yellow : Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.bottom, 20)
                
                // Bottom Tray (Shutter + Library)
                HStack {
                    Button(action: {}) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    // Shutter button
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.15)) { isFlashing = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation { isFlashing = false }
                            onCapture(UIImage())
                        }
                    }) {
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 4)
                            .frame(width: 72, height: 72)
                            .overlay(
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 58, height: 58)
                            )
                    }
                    
                    Spacer()
                    
                    Button(action: {}) {
                        Image(systemName: "camera.rotate")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 30)
            }
        }
    }
}
