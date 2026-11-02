// CameraLightScannerView.swift
// Native iOS Camera Viewfinder with Real-Time Light Scanning & Auto-Optimization
import SwiftUI
import AVFoundation

struct CameraLightScannerView: View {
    @StateObject private var cameraManager = LuminaCameraManager()
    @State private var isOptimized = false
    @State private var showSettings = false
    @State private var activeZoom: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Camera Hardware Video Preview
            CameraPreviewHolder(session: cameraManager.captureSession)
                .ignoresSafeArea()
                .overlay(
                    // Auto-optimization optical bias wash
                    Color.yellow.opacity(isOptimized ? 0.08 : 0.0)
                        .blendMode(.softLight)
                        .animation(.easeInOut(duration: 0.4), value: isOptimized)
                )
            
            // Native Apple Yellow Tracking Reticle
            VStack {
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(isOptimized ? Color.green : Color.yellow, lineWidth: 2)
                        .frame(width: 220, height: 220)
                        .shadow(color: (isOptimized ? Color.green : Color.yellow).opacity(0.6), radius: 8)
                    
                    Circle()
                        .fill(isOptimized ? Color.green : Color.yellow)
                        .frame(width: 6, height: 6)
                }
                Spacer()
            }
            
            // Top HUD Bar: Dynamic Island Telemetry
            VStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(isOptimized ? Color.green : Color.yellow)
                        .frame(width: 8, height: 8)
                    
                    Text("\(Int(cameraManager.currentLux)) lx")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                    
                    Text("•")
                        .foregroundColor(.gray)
                    
                    Text("\(cameraManager.currentKelvin)K")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                    
                    if isOptimized {
                        Text("OPT")
                            .font(.system(size: 10, weight: .black))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.green)
                            .foregroundColor(.black)
                            .cornerRadius(4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.85))
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.15), lineWidth: 1))
                .padding(.top, 48)
                
                Spacer()
                
                // FLOATING QR-STYLE PILL BANNER
                Button(action: {
                    withAnimation(.spring()) {
                        isOptimized.toggle()
                        cameraManager.setOptimization(enabled: isOptimized)
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: isOptimized ? "checkmark.circle.fill" : "sun.max.fill")
                            .font(.system(size: 20))
                            .foregroundColor(isOptimized ? .green : .yellow)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isOptimized ? "Camera Light Auto-Optimized" : "Sub-Optimal Room Light (\(Int(cameraManager.currentLux)) lx)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(isOptimized ? "450 lx • 4000K Focus • Glare 2.8:1 (Tap to Revert)" : "⚡ Tap to auto-optimize camera settings")
                                .font(.system(size: 11))
                                .foregroundColor(isOptimized ? .green : .yellow)
                        }
                        
                        Spacer()
                        
                        Image(systemName: isOptimized ? "arrow.counterclockwise" : "sparkles")
                            .foregroundColor(.white)
                            .font(.system(size: 16))
                    }
                    .padding(14)
                    .background(Color.black.opacity(0.88))
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(isOptimized ? Color.green.opacity(0.4) : Color.yellow.opacity(0.4), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                
                // Camera Shutter & Controls
                HStack(spacing: 40) {
                    Button(action: { activeZoom = activeZoom == 1.0 ? 2.0 : 1.0; cameraManager.setZoom(factor: activeZoom) }) {
                        Text(String(format: "%.1fx", activeZoom))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    
                    // Shutter
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }) {
                        ZStack {
                            Circle().stroke(Color.white, lineWidth: 4).frame(width: 72, height: 72)
                            Circle().fill(Color.white).frame(width: 60, height: 60)
                        }
                    }
                    
                    Button(action: { cameraManager.switchCamera() }) {
                        Image(systemName: "camera.rotate.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 36)
            }
        }
        .onAppear {
            cameraManager.startSession()
        }
    }
}

// UIKit Camera Preview Wrapper
struct CameraPreviewHolder: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}