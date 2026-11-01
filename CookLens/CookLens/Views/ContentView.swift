//
//  ContentView.swift
//  CookLens
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var viewModel = RecipeViewModel()
    @State private var selectedRecipeForCooking: Recipe?
    @State private var selectedRecipeForStores: Recipe?

    var body: some View {
        ZStack {
            // Background Live Camera Feed
            if viewModel.cameraManager.isAuthorized {
                CameraPreviewView(session: viewModel.cameraManager.session)
                    .ignoresSafeArea()
            } else {
                ContentUnavailableView(
                    "Camera Access Required",
                    systemImage: "camera.fill",
                    description: Text("Please grant camera access in iOS Settings to scan ingredients.")
                )
            }

            // Viewfinder Target Overlay
            VStack {
                // Top Navigation Pill
                HStack {
                    Label("CookLens On-Device Vision", systemImage: "sparkles")
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                    Spacer()
                    ModelIndicatorPill(engineName: "Apple Vision")
                }
                .padding(.horizontal)
                .padding(.top, 50)

                Spacer()

                // Framing Reticle
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.8), .white.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 2.5, dash: [12, 6])
                    )
                    .frame(height: 340)
                    .padding(.horizontal, 28)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "viewfinder")
                                .font(.system(size: 32, weight: .light))
                                .foregroundStyle(.white.opacity(0.9))
                            Text("Frame visible ingredients inside")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                    }

                Spacer()

                // Bottom Shutter & Controls
                captureBar
            }

            // On-device image classification progress
            if case .analyzing = viewModel.state {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    VStack(spacing: 18) {
                        ProgressView()
                            .scaleEffect(1.6)
                            .tint(.white)
                        Text("Classifying image with Apple Vision...")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("On-device image classification")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .padding(28)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                }
            }
        }
        // Result Sheet with Detents
        .sheet(isPresented: Binding(
            get: {
                if case .success = viewModel.state { return true }
                return false
            },
            set: { if !$0 { viewModel.reset() } }
        )) {
            if case let .success(recipes) = viewModel.state {
                NavigationStack {
                    ScrollView {
                        VStack(spacing: 20) {
                            ForEach(recipes) { recipe in
                                RecipeCardView(
                                    recipe: recipe,
                                    onStartCooking: {
                                        selectedRecipeForCooking = recipe
                                    },
                                    onLocateStores: {
                                        selectedRecipeForStores = recipe
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                    .navigationTitle("Suggested Recipes")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { viewModel.reset() }
                                .bold()
                        }
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        // Hands-Free Cooking Mode Sheet
        .fullScreenCover(item: $selectedRecipeForCooking) { recipe in
            CookingModeView(recipe: recipe)
        }
        // Store Locator & Traffic View
        .sheet(item: $selectedRecipeForStores) { recipe in
            StoreLocatorView(recipe: recipe)
        }
    }

    private var captureBar: some View {
        HStack {
            Spacer()
            Button {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                viewModel.scanAndSuggest()
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(.white, lineWidth: 4)
                        .frame(width: 78, height: 78)
                    Circle()
                        .fill(.white)
                        .frame(width: 64, height: 64)
                    Image(systemName: "sparkles")
                        .foregroundStyle(.black)
                        .font(.headline)
                }
            }
            .disabled(viewModel.state == .analyzing)
            Spacer()
        }
        .padding(.bottom, 36)
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

struct ModelIndicatorPill: View {
    let engineName: String
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.green)
                .frame(width: 7, height: 7)
            Text(engineName)
                .font(.caption2.bold())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
    }
}
