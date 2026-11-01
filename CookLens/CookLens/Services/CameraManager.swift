//
//  CameraManager.swift
//  CookLens
//

@preconcurrency import AVFoundation
import UIKit

@MainActor
@Observable
final class CameraManager: NSObject {
    var session = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer?
    var isAuthorized: Bool = false
    
    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.cooklens.cameraQueue")

    override init() {
        super.init()
        checkPermissions()
    }

    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor [weak self] in
                    self?.isAuthorized = granted
                    if granted { self?.setupSession() }
                }
            }
        default:
            isAuthorized = false
        }
    }

    private func setupSession() {
        let session = self.session
        let output = self.output
        sessionQueue.async {
            session.beginConfiguration()
            session.sessionPreset = .photo

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                session.commitConfiguration()
                return
            }

            session.addInput(input)

            if session.canAddOutput(output) {
                session.addOutput(output)
            }

            session.commitConfiguration()
            session.startRunning()
        }
    }

    func capturePhoto() async -> UIImage? {
        await withCheckedContinuation { continuation in
            let settings = AVCapturePhotoSettings()
            let delegate = PhotoCaptureDelegate { image in
                continuation.resume(returning: image)
            }
            objc_setAssociatedObject(self, UUID().uuidString, delegate, .OBJC_ASSOCIATION_RETAIN)
            self.output.capturePhoto(with: settings, delegate: delegate)
        }
    }
}

final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (UIImage?) -> Void

    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            completion(nil)
            return
        }
        completion(image)
    }
}
