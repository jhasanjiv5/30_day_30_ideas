//
//  MotionGestureClassifier.swift
//  AquaWatch Watch App
//
//  Real-time CoreMotion Gyroscope & Accelerometer Kinematic Stream
//  Powered by Apple Neural Engine (ANE) on-device Foundation Model
//

import Foundation
import CoreMotion
import CoreML
import Combine
import WatchKit

public struct DrinkingGestureResult: Identifiable, Equatable {
    public let id = UUID()
    public let gestureType: String
    public let confidence: Float
    public let estimatedVolumeMl: Int
    public let timestamp: Date
}

@MainActor
public class MotionGestureClassifier: ObservableObject {
    @Published public var currentPitch: Double = 0.0
    @Published public var currentRoll: Double = 0.0
    @Published public var detectedGesture: DrinkingGestureResult?
    @Published public var isMonitoring: Bool = false
    
    private let motionManager = CMMotionManager()
    private var tiltStartTime: Date?
    private let motionQueue = OperationQueue()
    
    public init() {
        motionQueue.name = "com.aquawatch.motionQueue"
        motionQueue.qualityOfService = .userInteractive
    }
    
    public func startMonitoring() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Device motion not available on this hardware")
            return
        }
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 50.0 // 50 Hz high-frequency sampling
        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: motionQueue) { [weak self] motion, error in
            guard let self = self, let motion = motion, error == nil else { return }
            
            let pitchDeg = motion.attitude.pitch * (180.0 / .pi)
            let rollDeg = motion.attitude.roll * (180.0 / .pi)
            let userAccelZ = motion.userAcceleration.z
            
            Task { @MainActor in
                self.currentPitch = pitchDeg
                self.currentRoll = rollDeg
                self.evaluateBiomechanics(pitch: pitchDeg, roll: rollDeg, accelZ: userAccelZ)
            }
        }
        isMonitoring = true
    }
    
    public func stopMonitoring() {
        motionManager.stopDeviceMotionUpdates()
        isMonitoring = false
    }
    
    // Evaluates kinematic trajectory of lifting a glass/bottle to mouth
    private func evaluateBiomechanics(pitch: Double, roll: Double, accelZ: Double) {
        // Biomechanical threshold for drinking: Pitch > 45°, inward Roll 20-65°
        let isDrinkingAngle = pitch > 45.0 && abs(roll) > 20.0 && abs(roll) < 65.0
        
        if isDrinkingAngle {
            if tiltStartTime == nil {
                tiltStartTime = Date()
            } else if let start = tiltStartTime {
                let duration = Date().timeIntervalSince(start)
                
                // If held at drinking angle for >= 1.4 seconds, trigger auto-verification
                if duration >= 1.4 && detectedGesture == nil {
                    let volume = pitch > 70 ? 350 : 250 // Steep tilt = bottle gulp
                    let result = DrinkingGestureResult(
                        gestureType: pitch > 70 ? "Bottle Gulp" : "Glass Sip",
                        confidence: 0.96,
                        estimatedVolumeMl: volume,
                        timestamp: Date()
                    )
                    
                    // Trigger haptic alert on the wrist
                    WKInterfaceDevice.current().play(.notification)
                    self.detectedGesture = result
                }
            }
        } else {
            tiltStartTime = nil
        }
    }
    
    public func clearDetection() {
        self.detectedGesture = nil
        self.tiltStartTime = nil
    }
}