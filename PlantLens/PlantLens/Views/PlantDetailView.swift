import SwiftUI

struct PlantDetailView: View {
    let result: PlantAnalysis
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    // Header Health Meter
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                            Circle()
                                .trim(from: 0, to: CGFloat(result.healthPercentage) / 100)
                                .stroke(colorForScore(result.healthPercentage), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            
                            Text("\(result.healthPercentage)%")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                        }
                        .frame(width: 70, height: 70)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.plantName)
                                .font(.title3.bold())
                            Text(healthLabel(result.healthPercentage))
                                .font(.subheadline)
                                .foregroundColor(colorForScore(result.healthPercentage))
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(18)
                    
                    // Detailed Diagnosis
                    SectionBlock(icon: "stethoscope", title: "Pathologist Diagnosis") {
                        Text(result.diagnosis)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Quick Care Needs
                    SectionBlock(icon: "heart.text.square", title: "Essentials") {
                        VStack(spacing: 14) {
                            DetailCard(icon: "drop.fill", title: "Water Schedule", value: result.wateringNeeds, color: .blue)
                            DetailCard(icon: "sun.max.fill", title: "Sunlight Requirements", value: result.sunlightNeeds, color: .orange)
                        }
                    }
                    
                    // Action Items
                    SectionBlock(icon: "checklist", title: "Action Steps") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(result.immediateCareSteps, id: \.self) { step in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .padding(.top, 2)
                                    Text(step)
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                    
                    // Long Term Advice
                    SectionBlock(icon: "sparkles", title: "Long-term Care") {
                        Text(result.longTermAdvice)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Plant Assessment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func colorForScore(_ score: Int) -> Color {
        if score >= 75 { return .green }
        if score >= 45 { return .orange }
        return .red
    }
    
    private func healthLabel(_ score: Int) -> String {
        if score >= 75 { return "Healthy & Thriving" }
        if score >= 45 { return "Needs Attention" }
        return "Critical Health Risk"
    }
}

struct SectionBlock<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
            content
        }
    }
}

struct DetailCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(value).font(.footnote).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
}