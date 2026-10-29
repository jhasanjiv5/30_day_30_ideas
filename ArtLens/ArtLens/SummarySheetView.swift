//
//  SummarySheetView.swift
//  ArtLens
//
//  Created for iOS 17.0+ / SwiftUI
//  Apple-style glanceable modal sheet with native presentation detents (.fraction(0.48) & .large)
//

import SwiftUI

public struct SummarySheetView: View {
    public let analysis: ArtworkAnalysis
    public let selectedTier: AIModelTier
    public let onRetake: () -> Void
    
    @State private var showDetailedReport = false
    
    public init(
        analysis: ArtworkAnalysis,
        selectedTier: AIModelTier,
        onRetake: @escaping () -> Void
    ) {
        self.analysis = analysis
        self.selectedTier = selectedTier
        self.onRetake = onRetake
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Label {
                        Text("Apple Intelligence visual feedback. No web search, legal clearance, or market pricing.")
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "iphone")
                    }
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    
                    // 1. HEADER: Stage & Market Value
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CURRENT STAGE")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                                .tracking(0.8)
                            
                            HStack(spacing: 6) {
                                Text(analysis.detectedStage.rawValue)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Text("(\(Int(analysis.stageConfidence))%)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("MARKET VALUE")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                                .tracking(0.8)
                            
                            Text(analysis.valuation.formattedRange)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.top, 6)
                    
                    // 2. KPI ROW (3 Metric Capsules)
                    HStack(spacing: 10) {
                        KPICapsule(
                            title: "Novelty",
                            value: "\(analysis.kpi.noveltyScore)%",
                            subtitle: "Visual estimate",
                            accentColor: analysis.kpi.noveltyScore >= 80 ? .green : .orange
                        )
                        
                        KPICapsule(
                            title: "Similarity",
                            value: "\(analysis.kpi.ipRiskScore)%",
                            subtitle: "Visual only",
                            accentColor: analysis.kpi.ipRiskScore <= 15 ? .green : .red
                        )
                        
                        KPICapsule(
                            title: "Status",
                            value: analysis.kpi.stageStatus,
                            subtitle: "Stage \(analysis.detectedStage.stageIndex)/5",
                            accentColor: .blue
                        )
                    }
                    
                    // 3. ACTIONABLE NEXT STEP
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.yellow)
                            
                            Text("CRITICAL NEXT STEP")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                                .tracking(0.6)
                        }
                        
                        Text(analysis.actionableNextStep)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    
                    // 4. Reverse image search is not part of on-device analysis.
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Web Visual Matches")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("Not searched")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        if analysis.webVisualMatches.isEmpty {
                            Text("Reverse image search is not connected, so no web matches were checked.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(analysis.webVisualMatches) { match in
                                        VisualMatchCard(match: match)
                                    }
                                }
                            }
                        }
                    }
                    
                    // 5. BOTTOM NAVIGATION
                    Button {
                        showDetailedReport = true
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Detailed Breakdown")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text("Visual critique and stage checklist")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        .padding(14)
                        .background(Color(uiColor: .tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onRetake) {
                        Text("Scan Another Artwork")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .navigationDestination(isPresented: $showDetailedReport) {
                DetailedReportView(analysis: analysis)
            }
        }
    }
}
