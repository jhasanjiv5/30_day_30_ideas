//
//  MainCameraView.swift
//  ArtLens
//
//  Created for iOS 17.0+ / SwiftUI
//  Minimalist, distraction-free viewfinder with floating glass tier selector and white shutter
//

import SwiftUI
import AVFoundation

public struct MainCameraView: View {
    // MARK: - State Management
    @State private var cameraManager: CameraManager?
    @AppStorage("selectedAIModelTier") private var selectedTier: AIModelTier = .budgetFlash
    @State private var isAnalyzing = false
    @State private var analysisResult: ArtworkAnalysis?
    @State private var showSummarySheet = false
    @State private var analysisError: String?
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // The simulator has no camera device, so show sample artwork instead.
            #if targetEnvironment(simulator)
            SimulatorArtworkPreview()
                .ignoresSafeArea()
            #else
            if let cameraManager, cameraManager.permissionGranted {
                CameraPreviewView(session: cameraManager.captureSession)
                    .ignoresSafeArea()
            } else {
                CameraUnavailableView(
                    message: cameraManager?.errorMessage ?? "Point camera at canvas, sketchbook, or digital screen"
                )
            }
            #endif
            
            // Subtle framing grid lines for artist alignment
            CompositionOverlayGrid()
                .allowsHitTesting(false)
            
            // Minimalist Viewfinder Chrome (Only 2 elements: Top capsule, Bottom shutter)
            VStack {
                // TOP ELEMENT: Translucent Floating Glass Capsule
                TopModelSelectorCapsule(selectedTier: $selectedTier)
                .padding(.top, 16)
                
                Spacer()
                
                // BOTTOM ELEMENT: Clean Standard White Circular Shutter Button
                BottomShutterBar(
                    isAnalyzing: isAnalyzing,
                    onShutterTap: {
                        triggerCaptureAndAnalysis()
                    }
                )
                .padding(.bottom, 28)
            }
        }
        .sheet(isPresented: $showSummarySheet) {
            if let analysisResult {
                SummarySheetView(
                    analysis: analysisResult,
                    selectedTier: selectedTier,
                    onRetake: {
                        showSummarySheet = false
                    }
                )
                .presentationDetents([.fraction(0.48), .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
            }
        }
        .alert("Artwork Analysis Failed", isPresented: Binding(
            get: { analysisError != nil },
            set: { if !$0 { analysisError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(analysisError ?? "Please try again.")
        }
        .onAppear {
            #if !targetEnvironment(simulator)
            cameraManager = CameraManager()
            cameraManager?.startSession()
            #endif
        }
        .onDisappear {
            cameraManager?.stopSession()
        }
    }
    
    // MARK: - Scan Action
    private func triggerCaptureAndAnalysis() {
        guard !isAnalyzing else { return }
        isAnalyzing = true

        Task {
            do {
                let image: UIImage
                #if targetEnvironment(simulator)
                guard let sampleImage = SimulatorArtworkPreview.renderedImage() else {
                    throw SimulatorImageError.renderFailed
                }
                image = sampleImage
                #else
                guard let cameraManager else {
                    throw CameraManager.CameraError.sessionNotRunning
                }
                image = try await cameraManager.capturePhoto()
                #endif

                analysisResult = try await CritiqueService.shared.analyzeArtwork(
                    image: image,
                    tier: selectedTier
                )
                showSummarySheet = true
            } catch {
                analysisError = error.localizedDescription
            }
            isAnalyzing = false
        }
    }
}

private enum SimulatorImageError: LocalizedError {
    case renderFailed

    var errorDescription: String? {
        "The sample artwork could not be prepared for analysis."
    }
}

private struct SimulatorArtworkPreview: View {
    static func renderedImage() -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1024, height: 768))
        return renderer.image { context in
            let cg = context.cgContext
            cg.setFillColor(UIColor(red: 0.07, green: 0.09, blue: 0.11, alpha: 1).cgColor)
            cg.fill(CGRect(x: 0, y: 0, width: 1024, height: 768))

            let canvas = CGRect(x: 110, y: 90, width: 804, height: 590)
            let canvasPath = UIBezierPath(roundedRect: canvas, cornerRadius: 8)
            cg.saveGState()
            cg.addPath(canvasPath.cgPath)
            cg.clip()

            let colors = [
                UIColor(red: 0.22, green: 0.28, blue: 0.31, alpha: 1).cgColor,
                UIColor(red: 0.62, green: 0.37, blue: 0.24, alpha: 1).cgColor,
                UIColor(red: 0.12, green: 0.19, blue: 0.21, alpha: 1).cgColor
            ] as CFArray
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: [0, 0.5, 1]
            ) {
                cg.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: canvas.minX, y: canvas.minY),
                    end: CGPoint(x: canvas.maxX, y: canvas.maxY),
                    options: []
                )
            }

            cg.setFillColor(UIColor(red: 0.96, green: 0.72, blue: 0.39, alpha: 1).cgColor)
            cg.fillEllipse(in: CGRect(x: 560, y: 140, width: 190, height: 190))
            cg.setFillColor(UIColor(red: 0.28, green: 0.40, blue: 0.36, alpha: 1).cgColor)
            cg.fillEllipse(in: CGRect(x: 40, y: 335, width: 930, height: 285))
            cg.setFillColor(UIColor(red: 0.12, green: 0.24, blue: 0.24, alpha: 1).cgColor)
            cg.fillEllipse(in: CGRect(x: 330, y: 430, width: 740, height: 230))

            let horizon = UIBezierPath()
            horizon.move(to: CGPoint(x: 190, y: 545))
            horizon.addCurve(
                to: CGPoint(x: 845, y: 510),
                controlPoint1: CGPoint(x: 425, y: 440),
                controlPoint2: CGPoint(x: 580, y: 625)
            )
            UIColor.white.withAlphaComponent(0.32).setStroke()
            horizon.lineWidth = 2
            horizon.stroke()
            cg.restoreGState()
            UIColor.white.withAlphaComponent(0.22).setStroke()
            canvasPath.lineWidth = 1
            canvasPath.stroke()
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 0.07, green: 0.09, blue: 0.11)

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.22, green: 0.28, blue: 0.31),
                                Color(red: 0.62, green: 0.37, blue: 0.24),
                                Color(red: 0.12, green: 0.19, blue: 0.21)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        GeometryReader { canvas in
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.96, green: 0.72, blue: 0.39))
                                    .frame(width: canvas.size.width * 0.24)
                                    .blur(radius: 1)
                                    .position(
                                        x: canvas.size.width * 0.69,
                                        y: canvas.size.height * 0.30
                                    )

                                Ellipse()
                                    .fill(Color(red: 0.28, green: 0.40, blue: 0.36))
                                    .frame(width: canvas.size.width * 1.15, height: canvas.size.height * 0.48)
                                    .rotationEffect(.degrees(-8))
                                    .position(
                                        x: canvas.size.width * 0.39,
                                        y: canvas.size.height * 0.78
                                    )

                                Ellipse()
                                    .fill(Color(red: 0.12, green: 0.24, blue: 0.24))
                                    .frame(width: canvas.size.width * 0.92, height: canvas.size.height * 0.34)
                                    .rotationEffect(.degrees(9))
                                    .position(
                                        x: canvas.size.width * 0.74,
                                        y: canvas.size.height * 0.91
                                    )

                                Path { path in
                                    path.move(to: CGPoint(x: canvas.size.width * 0.10, y: canvas.size.height * 0.72))
                                    path.addCurve(
                                        to: CGPoint(x: canvas.size.width * 0.93, y: canvas.size.height * 0.63),
                                        control1: CGPoint(x: canvas.size.width * 0.39, y: canvas.size.height * 0.58),
                                        control2: CGPoint(x: canvas.size.width * 0.61, y: canvas.size.height * 0.81)
                                    )
                                }
                                .stroke(Color.white.opacity(0.32), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            }
                            .clipped()
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    }
                    .frame(width: geometry.size.width * 0.78, height: geometry.size.height * 0.62)
                    .shadow(color: .black.opacity(0.45), radius: 24, y: 14)

                VStack {
                    HStack(spacing: 7) {
                        Image(systemName: "viewfinder")
                        Text("SIMULATED CAMERA PREVIEW")
                            .tracking(1)
                    }
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.38), in: Capsule())
                    .padding(.top, 72)

                    Spacer()
                }
            }
        }
    }
}

private struct CameraUnavailableView: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 64, weight: .ultraLight))
                    .foregroundColor(.white.opacity(0.4))

                Text("Live Viewfinder")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                Text(message)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }
}

// MARK: - Top Floating Glass Capsule with Native Menu
struct TopModelSelectorCapsule: View {
    @Binding var selectedTier: AIModelTier
    
    var body: some View {
        Menu {
            Section("On-Device Reasoning") {
                ForEach(AIModelTier.allCases) { tier in
                    Button {
                        selectedTier = tier
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack {
                            Text(tier.displayName)
                            Spacer()
                            Text(tier.summary)
                            if selectedTier == tier {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            
            Section("Privacy") {
                Label("Apple Intelligence · no API key", systemImage: "iphone")
            }
        } label: {
            HStack(spacing: 6) {
                Text(selectedTier.capsuleTitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.22), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 4)
        }
    }
}

// MARK: - Native White Circular Shutter Button
struct BottomShutterBar: View {
    let isAnalyzing: Bool
    let onShutterTap: () -> Void
    
    var body: some View {
        Button(action: onShutterTap) {
            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 76, height: 76)
                
                if isAnalyzing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.4)
                } else {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 62, height: 62)
                        .scaleEffect(0.95)
                }
            }
        }
        .disabled(isAnalyzing)
        .buttonStyle(ShutterPressStyle())
    }
}

struct ShutterPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct CompositionOverlayGrid: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    path.move(to: CGPoint(x: width / 3, y: 0))
                    path.addLine(to: CGPoint(x: width / 3, y: height))
                    path.move(to: CGPoint(x: (width / 3) * 2, y: 0))
                    path.addLine(to: CGPoint(x: (width / 3) * 2, y: height))
                }
                .stroke(Color.white.opacity(0.08), lineWidth: 0.75)
                
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    path.move(to: CGPoint(x: 0, y: height / 3))
                    path.addLine(to: CGPoint(x: width, y: height / 3))
                    path.move(to: CGPoint(x: 0, y: (height / 3) * 2))
                    path.addLine(to: CGPoint(x: width, y: (height / 3) * 2))
                }
                .stroke(Color.white.opacity(0.08), lineWidth: 0.75)
            }
        }
    }
}
