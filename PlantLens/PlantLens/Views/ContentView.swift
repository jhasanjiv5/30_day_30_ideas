//
//  ContentView.swift
//  PlantLens
//
//  Created by Sanjiv Jha on 27.10.2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var camera = CameraManager()
    @State private var isAnalyzing = false
    @State private var analysis: PlantAnalysis?
    @State private var showDetail = false
    @State private var alertMessage: String?
    
    // Impact feedback generator for physical shutter feel
    private let impact = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        ZStack {
            // Viewfinder
            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()
            
            // Reticle overlay in center
            if analysis == nil && !isAnalyzing {
                ReticleOverlayView()
            }
            
            // Top branding badge
            VStack {
                HStack(spacing: 8) {
                    Image(systemName: "sparkle.magnifyingglass")
                    Text("Plant Lens")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(.top, 48)
                
                Spacer()
            }
            
            // Bottom Action Area
            VStack {
                Spacer()
                
                if let result = analysis {
                    // Result Summary Popup Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.plantName)
                                    .font(.headline)
                                
                                if result.isPlant {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(result.healthPercentage >= 70 ? Color.green : Color.orange)
                                            .frame(width: 8, height: 8)
                                        Text("\(result.healthPercentage)% Healthy")
                                            .font(.caption.bold())
                                            .foregroundColor(result.healthPercentage >= 70 ? .green : .orange)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                withAnimation(.spring()) { self.analysis = nil }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.title2)
                            }
                        }
                        
                        Text(result.briefStatus)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                        
                        if result.isPlant {
                            Button(action: { showDetail = true }) {
                                HStack {
                                    Text("View More")
                                    Image(systemName: "arrow.right")
                                }
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.green)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(18)
                    .background(.regularMaterial)
                    .cornerRadius(22)
                    .shadow(radius: 12)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 34)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    
                } else {
                    // Google Lens Shutter Button
                    Button(action: captureAndAnalyze) {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 80, height: 80)
                            Circle()
                                .fill(Color.white)
                                .frame(width: 68, height: 68)
                        }
                    }
                    .disabled(isAnalyzing)
                    .padding(.bottom, 36)
                }
            }
            
            // Scanning State Indicator
            if isAnalyzing {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 14) {
                        ProgressView()
                            .scaleEffect(1.3)
                            .tint(.white)
                        Text("Diagnosing plant health...")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .cornerRadius(18)
                }
            }
        }
        .sheet(isPresented: $showDetail) {
            if let result = analysis {
                PlantDetailView(result: result)
            }
        }
        .alert("Notice", isPresented: .constant(alertMessage != nil)) {
            Button("OK") { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
    }
    
    private func captureAndAnalyze() {
        impact.impactOccurred()
        isAnalyzing = true
        
        Task {
            do {
                let photo = try await camera.capturePhoto()
                let result = try await GeminiService.shared.analyze(image: photo)
                await MainActor.run {
                    withAnimation(.spring()) {
                        self.analysis = result
                        self.isAnalyzing = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.isAnalyzing = false
                    self.alertMessage = error.localizedDescription
                }
            }
        }
    }
}
