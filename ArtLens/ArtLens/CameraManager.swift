//
//  CameraManager.swift
//  ArtLens
//
//  Created for iOS 17.0+ / Swift Observation
//  Native AVFoundation camera session handler with AVCapturePhotoOutput
//

import AVFoundation
import SwiftUI
import Observation

@Observable
public final class CameraManager: NSObject {
    // MARK: - State Properties
    public var isSessionRunning = false
    public var capturedImage: UIImage? = nil
    public var isCapturing = false
    public var permissionGranted = false
    public var flashMode: AVCaptureDevice.FlashMode = .auto
    public var errorMessage: String? = nil
    
    // MARK: - AVFoundation Internals
    public let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var activeDeviceInput: AVCaptureDeviceInput?
    private let sessionQueue = DispatchQueue(label: "com.artlens.camera.sessionQueue")
    
    private var photoCaptureContinuation: CheckedContinuation<UIImage, Error>?
    
    public override init() {
        super.init()
        checkPermissions()
    }
    
    // MARK: - Permissions Check
    public func checkPermissions() {
        #if targetEnvironment(simulator)
        permissionGranted = false
        errorMessage = "Camera preview is unavailable in the iPhone Simulator."
        #else
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.permissionGranted = true
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                    if granted {
                        self?.setupSession()
                    }
                }
            }
        case .denied, .restricted:
            self.permissionGranted = false
            self.errorMessage = "Camera access denied. Please enable camera in iOS Settings."
        @unknown default:
            self.permissionGranted = false
        }
        #endif
    }
    
    // MARK: - Capture Session Setup
    private func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .photo
            
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: camera) else {
                DispatchQueue.main.async {
                    self.errorMessage = "Unable to access primary rear camera device."
                }
                self.captureSession.commitConfiguration()
                return
            }
            
            if self.captureSession.canAddInput(input) {
                self.captureSession.addInput(input)
                self.activeDeviceInput = input
            }
            
            if self.captureSession.canAddOutput(self.photoOutput) {
                self.captureSession.addOutput(self.photoOutput)
                self.photoOutput.maxPhotoQualityPrioritization = .quality
            }
            
            self.captureSession.commitConfiguration()
            self.startSession()
        }
    }
    
    // MARK: - Session Lifecycle
    public func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = self.captureSession.isRunning
            }
        }
    }
    
    public func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }
    
    // MARK: - Shutter Action (Async/Await)
    public func capturePhoto() async throws -> UIImage {
        guard isSessionRunning else {
            throw CameraError.sessionNotRunning
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: CameraError.unknown)
                    return
                }
                
                DispatchQueue.main.async {
                    self.isCapturing = true
                }
                
                self.photoCaptureContinuation = continuation
                
                var photoSettings = AVCapturePhotoSettings()
                if self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                    photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
                }
                
                if let device = self.activeDeviceInput?.device, device.hasFlash {
                    photoSettings.flashMode = self.flashMode
                }
                
                photoSettings.photoQualityPrioritization = .quality
                self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
            }
        }
    }
    
    public enum CameraError: LocalizedError {
        case sessionNotRunning
        case captureFailed
        case unknown
        
        public var errorDescription: String? {
            switch self {
            case .sessionNotRunning: return "Camera session is not active."
            case .captureFailed: return "Failed to process photo capture."
            case .unknown: return "An unexpected camera error occurred."
            }
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraManager: AVCapturePhotoCaptureDelegate {
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        DispatchQueue.main.async {
            self.isCapturing = false
        }
        
        if let error = error {
            photoCaptureContinuation?.resume(throwing: error)
            photoCaptureContinuation = nil
            return
        }
        
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            photoCaptureContinuation?.resume(throwing: CameraError.captureFailed)
            photoCaptureContinuation = nil
            return
        }
        
        DispatchQueue.main.async {
            self.capturedImage = image
        }
        
        photoCaptureContinuation?.resume(returning: image)
        photoCaptureContinuation = nil
    }
}

// MARK: - Native SwiftUI Camera Preview Container
public struct CameraPreviewView: UIViewRepresentable {
    public let session: AVCaptureSession
    
    public init(session: AVCaptureSession) {
        self.session = session
    }
    
    public func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer
        return view
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.previewLayer?.frame = uiView.bounds
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    public class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}
