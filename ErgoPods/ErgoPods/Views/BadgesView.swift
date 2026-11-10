//
//  BadgesView.swift
//  ErgoPods
//
//  Virtual Achievement Badges & Workday Step Milestones
//

import SwiftUI

struct BadgesView: View {
    @EnvironmentObject var health: AppleHealthKitManager
    
    let badges = [
        ("Stand & Stretch", "Responded to sedentary alert and took a 2m posture walk.", "figure.stand", Color.brown, true),
        ("Desk Nomad 5,000", "Walked 5,000 steps while taking posture micro-breaks.", "shoeprints.fill", Color.gray, false),
        ("Spine Sentinel Gold", "Maintained optimal cervical angle (< 12°) for 45 minutes.", "shield.fill", Color.yellow, false),
        ("Century Strides 10K", "Reached 10,000 steps synchronized with Apple Health.", "trophy.fill", Color.yellow, false),
        ("Cervical Zen Master", "Completed 3 on-device guided micro-stretches.", "sparkles", Color.orange, true)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(badges, id: \.0) { title, desc, icon, color, unlocked in
                    VStack(spacing: 12) {
                        Image(systemName: icon)
                            .font(.system(size: 36))
                            .foregroundColor(unlocked ? color : .secondary)
                            .padding()
                            .background(Circle().fill(unlocked ? color.opacity(0.2) : Color(.tertiarySystemBackground)))
                        
                        Text(title)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        Text(desc)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Text(unlocked ? "UNLOCKED" : "LOCKED")
                            .font(.caption2.bold())
                            .foregroundColor(unlocked ? .green : .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().stroke(unlocked ? Color.green : Color.secondary, lineWidth: 1))
                    }
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 210)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(20)
                }
            }
            .padding()
        }
    }
}
