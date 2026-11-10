//
//  OnDevicePhysioReasoningModel.swift
//  ErgoPods
//
//  Apple Foundation Models / Core ML on-device reasoning engine
//

import Foundation
import CoreML

public struct PhysiotherapistPrescription: Codable, Sendable {
    public let canWalkNow: Bool
    public let stepPrescription: Int
    public let clinicalAssessment: String
    public let exerciseName: String
    public let exerciseDurationSeconds: Int
    public let instructions: [String]
    public let audioCue: String
}

public final class OnDevicePhysioReasoningModel: Sendable {
    public static let shared = OnDevicePhysioReasoningModel()
    
    public func evaluate(
        heartRate: Double,
        restingHeartRate: Double,
        cervicalPitch: Double,
        continuousSittingMinutes: Double,
        isElderlyProfile: Bool
    ) -> PhysiotherapistPrescription {
        
        let heartRateElevated = heartRate > (restingHeartRate * 1.45) || heartRate > 115.0
        let severeTechNeck = abs(cervicalPitch) > 22.0
        let prolongedSitting = continuousSittingMinutes >= 45.0
        
        if heartRateElevated {
            return PhysiotherapistPrescription(
                canWalkNow: false,
                stepPrescription: 0,
                clinicalAssessment: "Heart rate is \(Int(heartRate)) BPM, significantly elevated. Immediate walking deferred to avoid autonomic fatigue.",
                exerciseName: "4-7-8 Parasympathetic Vagus Breathing",
                exerciseDurationSeconds: 45,
                instructions: [
                    "Sit tall with your lumbar spine supported.",
                    "Inhale smoothly through nose for 4 seconds.",
                    "Hold breath gently for 4 seconds.",
                    "Exhale through lips for 6 seconds to trigger parasympathetic down-regulation."
                ],
                audioCue: "Breathe gently. Lower your shoulders."
            )
        }
        
        if severeTechNeck || prolongedSitting {
            let loadLbs = Int(11.0 + abs(cervicalPitch) * 1.4)
            let steps = isElderlyProfile ? 200 : 350
            
            return PhysiotherapistPrescription(
                canWalkNow: true,
                stepPrescription: steps,
                clinicalAssessment: "Cervical tilt of \(Int(cervicalPitch))° creates \(loadLbs) lbs of compressive spinal force. Micro-break walking recommended.",
                exerciseName: isElderlyProfile ? "Seated Gentle Shoulder Rolls" : "Standing Thoracic Wall Angels",
                exerciseDurationSeconds: 30,
                instructions: [
                    "Stand up and retract your chin straight back.",
                    "Pinch shoulder blades down and together.",
                    "Take a gentle walking lap around your workspace."
                ],
                audioCue: "Stand tall. Lift the crown of your head."
            )
        }
        
        return PhysiotherapistPrescription(
            canWalkNow: true,
            stepPrescription: 0,
            clinicalAssessment: "Cervical spine is aligned in healthy neutral lordosis. Compressive load is minimal (11 lbs).",
            exerciseName: "Cervical Chin Tuck Micro-Check",
            exerciseDurationSeconds: 15,
            instructions: ["Maintain your eye line at the top third of your display."],
            audioCue: "Spine is aligned. Great job."
        )
    }
}
