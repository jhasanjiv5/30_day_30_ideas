//
//  HeadphoneMotionManager.swift
//  ErgoPods
//
//  CoreMotion CMHeadphoneMotionManager 6-DoF telemetry provider
//

import Foundation
@preconcurrency import CoreMotion
import Combine

@MainActor
public final class HeadphoneMotionManager: ObservableObject {
    @Published public var pitchDegrees: Double = 0.0
    @Published public var rollDegrees: Double = 0.0
    @Published public var yawDegrees: Double = 0.0
    @Published public var isCalibrated: Bool = false
    @Published public var isConnected: Bool = false
    @Published public var continuousSittingSeconds: TimeInterval = 0
    @Published public var isSeverePostureAlert: Bool = false
    
    private let motionManager = CMHeadphoneMotionManager()
    private var baselinePitch: Double = 0.0
    private var baselineRoll: Double = 0.0
    private var timerCancellable: AnyCancellable?
    
    public init() {
        startTracking()
        startSittingTimer()
    }
    
    public func startTracking() {
        guard motionManager.isDeviceMotionAvailable else {
            print("⚠️ Headphone motion sensors unavailable on this hardware.")
            return
        }
        
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion, error == nil else { return }
            
            self.isConnected = true
            
            let rawPitch = motion.attitude.pitch * (180.0 / .pi)
            let rawRoll = motion.attitude.roll * (180.0 / .pi)
            let rawYaw = motion.attitude.yaw * (180.0 / .pi)
            
            self.pitchDegrees = rawPitch - self.baselinePitch
            self.rollDegrees = rawRoll - self.baselineRoll
            self.yawDegrees = rawYaw
            
            self.isSeverePostureAlert = abs(self.pitchDegrees) > 22.0
        }
    }
    
    public func calibrateNeutralSpine() {
        if let current = motionManager.deviceMotion {
            baselinePitch = current.attitude.pitch * (180.0 / .pi)
            baselineRoll = current.attitude.roll * (180.0 / .pi)
            isCalibrated = true
        }
    }
    
    private func startSittingTimer() {
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.continuousSittingSeconds += 1.0
            }
    }
    
    public func resetSittingTimer() {
        continuousSittingSeconds = 0
    }
    
    deinit {
        motionManager.stopDeviceMotionUpdates()
    }
}
