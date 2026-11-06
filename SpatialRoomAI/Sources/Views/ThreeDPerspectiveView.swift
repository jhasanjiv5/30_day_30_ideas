import SwiftUI
import SceneKit

public enum CameraAnglePreset: String, CaseIterable {
    case frontal = "Frontal (0°)"
    case elevated = "Elevated 30°"
    case corner = "Corner 45°"
    case lidar = "LiDAR Mesh"
}

public struct ThreeDPerspectiveView: View {
    @Binding public var room: Room
    @State private var activeAngle: CameraAnglePreset = .frontal
    @State private var splitPosition: Double = 0.5 // 0.0 to 1.0 Before/After
    @State private var showDeclutterBoxes: Bool = false
    @State private var isEnhanced: Bool = true
    @State private var selectedItem: StagedItem? = nil

    public init(room: Binding<Room>) {
        self._room = room
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // 3D Perspective Plane & Split Image Layer
            GeometryReader { geo in
                ZStack {
                    // Before 2D image (Left portion)
                    AsyncImage(url: URL(string: room.beforeImage)) { phase in
                        if let img = phase.image {
                            img.resizable().scaledToFill()
                        } else {
                            Color.black.opacity(0.8)
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                    // Staged After 2D image (Right portion revealed by split)
                    AsyncImage(url: URL(string: room.afterImage)) { phase in
                        if let img = phase.image {
                            img.resizable()
                                .scaledToFill()
                                .brightness(isEnhanced ? 0.06 : 0)
                                .saturation(isEnhanced ? 1.1 : 1.0)
                        } else {
                            Color.black.opacity(0.9)
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .mask(
                        HStack(spacing: 0) {
                            Spacer()
                                .frame(width: geo.size.width * splitPosition)
                            Rectangle()
                                .frame(width: geo.size.width * (1.0 - splitPosition))
                        }
                    )

                    // Split Line Handle
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2)
                        .position(x: geo.size.width * splitPosition, y: geo.size.height / 2)
                        .overlay(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: "arrow.left.and.right")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                )
                                .position(x: geo.size.width * splitPosition, y: geo.size.height / 2)
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newPos = value.location.x / geo.size.width
                                    splitPosition = min(max(newPos, 0.05), 0.95)
                                }
                        )

                    // 3D Staged Furniture Pins
                    if splitPosition < 0.8 {
                        ForEach(room.stagedItems) { item in
                            Button(action: { selectedItem = item }) {
                                HStack(spacing: 4) {
                                    Circle().fill(Color.green).frame(width: 6, height: 6)
                                    Text(item.name)
                                        .font(.system(size: 10, weight: .semibold))
                                    Text("$\(Int(item.price))")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(.green)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                                .shadow(radius: 6)
                            }
                            .position(
                                x: geo.size.width * (item.spatialPosition.x / 100.0),
                                y: geo.size.height * (item.spatialPosition.y / 100.0)
                            )
                        }
                    }

                    // Declutter Bounding Boxes
                    if showDeclutterBoxes {
                        ForEach(room.declutterItems) { item in
                            Rectangle()
                                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                .foregroundColor(.red)
                                .background(Color.red.opacity(0.12))
                                .frame(
                                    width: geo.size.width * (item.boundingBox.w / 100.0),
                                    height: geo.size.height * (item.boundingBox.h / 100.0)
                                )
                                .position(
                                    x: geo.size.width * ((item.boundingBox.x + item.boundingBox.w / 2.0) / 100.0),
                                    y: geo.size.height * ((item.boundingBox.y + item.boundingBox.h / 2.0) / 100.0)
                                )
                        }
                    }
                }
            }

            // Floating Controls Bar
            VStack {
                Spacer()

                HStack {
                    // Angle Presets
                    Picker("Angle", selection: $activeAngle) {
                        ForEach(CameraAnglePreset.allCases, id: \.self) { angle in
                            Text(angle.rawValue).tag(angle)
                        }
                    }
                    .pickerStyle(.segmented)
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .frame(maxWidth: 240)

                    Spacer()

                    // Declutter Toggle
                    Button(action: { showDeclutterBoxes.toggle() }) {
                        Image(systemName: showDeclutterBoxes ? "cube.box.fill" : "cube.box")
                            .font(.system(size: 14))
                            .padding(8)
                            .background(showDeclutterBoxes ? Color.red : Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }

                    // Apple Intelligence Tone
                    Button(action: { isEnhanced.toggle() }) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                            .foregroundColor(isEnhanced ? .yellow : .white)
                            .padding(8)
                            .background(isEnhanced ? Color.purple : Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
    }
}
