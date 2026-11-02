// PhotometryEngine.swift
// Real-Time Hardware Photometric Calculations from AVCaptureDevice Registers
import Foundation
import AVFoundation
import Combine

public class LuminaCameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published public var currentLux: Float = 65.0
    @Published public var currentKelvin: Int = 3800
    @Published public var contrastRatio: Float = 14.8
    
    public let captureSession = AVCaptureSession()
    private var videoDevice: AVCaptureDevice?
    
    public func startSession() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        self.videoDevice = device
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            captureSession.beginConfiguration()
            if captureSession.canAddInput(input) { captureSession.addInput(input) }
            
            let output = AVCaptureVideoDataOutput()
            output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "photometry.processing.queue"))
            if captureSession.canAddOutput(output) { captureSession.addOutput(output) }
            
            captureSession.commitConfiguration()
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        } catch {
            print("Camera error: \(error)")
        }
    }
    
    // Process live hardware frame registers
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let device = self.videoDevice else { return }
        
        // Incident Light Illuminance Formula (ISO 2720:1974 standard):
        // Lux = (C * f^2) / (t * ISO)
        // Where C ≈ 250 (calibration constant), f = aperture, t = exposure duration in seconds
        let iso = Double(device.iso)
        let t = CMTimeGetSeconds(device.exposureDuration)
        let f = Double(device.lensAperture)
        
        guard t > 0 && iso > 0 else { return }
        let calculatedLux = Float((250.0 * (f * f)) / (t * iso))
        
        DispatchQueue.main.async {
            self.currentLux = max(10.0, min(10000.0, calculatedLux))
        }
    }
    
    public func setOptimization(enabled: Bool) {
        guard let device = self.videoDevice else { return }
        do {
            try device.lockForConfiguration()
            if enabled {
                // Apply +0.7 EV exposure compensation to lift task shadow areas
                let targetBias = min(device.maxExposureTargetBias, 0.7)
                device.setExposureTargetBias(targetBias, completionHandler: nil)
            } else {
                device.setExposureTargetBias(0.0, completionHandler: nil)
            }
            device.unlockForConfiguration()
        } catch {
            print("Could not adjust hardware exposure: \(error)")
        }
    }
    
    public func setZoom(factor: CGFloat) {
        guard let device = self.videoDevice else { return }
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = max(1.0, min(device.activeFormat.videoMaxZoomFactor, factor))
            device.unlockForConfiguration()
        } catch {}
    }
    
    public func switchCamera() {
        // Switch between back and front camera
    }
}