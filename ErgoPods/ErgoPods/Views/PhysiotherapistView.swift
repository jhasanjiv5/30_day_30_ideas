//
//  PhysiotherapistView.swift
//  ErgoPods
//
//  On-Device Foundation Reasoning Model Physiotherapist Interface
//

import SwiftUI

struct PhysiotherapistView: View {
    @EnvironmentObject var motion: HeadphoneMotionManager
    @EnvironmentObject var health: AppleHealthKitManager
    @State private var isElderlyMode = false
    @State private var isExercising = false
    @State private var countdown = 30
    
    var prescription: PhysiotherapistPrescription {
        OnDevicePhysioReasoningModel.shared.evaluate(
            heartRate: health.currentHeartRate,
            restingHeartRate: health.restingHeartRate,
            cervicalPitch: motion.pitchDegrees,
            continuousSittingMinutes: motion.continuousSittingSeconds / 60.0,
            isElderlyProfile: isElderlyMode
        )
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Profile Selector
                Picker("Clinical Mode", selection: $isElderlyMode) {
                    Text("Office Ergonomics").tag(false)
                    Text("Elderly Mobility Care").tag(true)
                }
                .pickerStyle(.segmented)
                
                // On-Device Neural Engine Privacy Badge
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(.green)
                    Text("Apple Neural Engine • 100% On-Device Foundation Model Inference")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(10)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(12)
                
                // Clinical Prescription Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: prescription.canWalkNow ? "figure.walk.circle.fill" : "heart.slash.fill")
                            .font(.title2)
                            .foregroundColor(prescription.canWalkNow ? .green : .red)
                        VStack(alignment: .leading) {
                            Text(prescription.canWalkNow ? "Safe for Walking Micro-Break" : "Walking Deferred: Rest First")
                                .font(.headline)
                            Text(prescription.canWalkNow ? "+\(prescription.stepPrescription) steps prescribed" : "Cardiovascular rest required")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text(prescription.clinicalAssessment)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    Divider()
                    
                    // Guided Micro-Stretch Exercise
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("PRESCRIBED EXERCISE")
                                    .font(.caption2.bold())
                                    .foregroundColor(.blue)
                                Text(prescription.exerciseName)
                                    .font(.headline)
                            }
                            Spacer()
                            Text("\(countdown)s")
                                .font(.system(.title2, design: .monospaced).bold())
                                .foregroundColor(.blue)
                        }
                        
                        ForEach(prescription.instructions, id: \.self) { step in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text(step)
                                    .font(.caption)
                            }
                        }
                        
                        Button {
                            isExercising.toggle()
                        } label: {
                            Label(isExercising ? "Pause Exercise" : "Start Guided Micro-Stretch", systemImage: isExercising ? "pause.fill" : "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .padding(.top, 4)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)
            }
            .padding()
        }
    }
}
