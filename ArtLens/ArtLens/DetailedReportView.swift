//
//  DetailedReportView.swift
//  ArtLens
//
//  Created for iOS 17.0+ / SwiftUI
//  Navigation-driven deep dive report covering Composition/Value critique, Reverse Search, Legal IP Risk & Valuation Comps
//

import SwiftUI

public struct DetailedReportView: View {
    public let analysis: ArtworkAnalysis
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: ReportSection = .composition
    
    public enum ReportSection: String, CaseIterable, Identifiable {
        case composition = "Composition"
        case valuation = "Valuation"
        case ipLegal = "IP & Legal"
        case checklist = "Stage Plan"
        
        public var id: String { rawValue }
    }
    
    public init(analysis: ArtworkAnalysis) {
        self.analysis = analysis
    }
    
    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                
                Picker("Report Section", selection: $selectedTab) {
                    ForEach(ReportSection.allCases) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.top, 4)
                
                switch selectedTab {
                case .composition:
                    CompositionSectionView(
                        critique: analysis.detailedBreakdown.compositionCritique,
                        stage: analysis.detectedStage
                    )
                case .valuation:
                    ValuationSectionView(valuation: analysis.valuation)
                case .ipLegal:
                    IPLegalSectionView(report: analysis.detailedBreakdown.ipComplianceReport, kpi: analysis.kpi)
                case .checklist:
                    StageChecklistSectionView(
                        checklist: analysis.detailedBreakdown.stageChecklist,
                        stage: analysis.detectedStage
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .navigationTitle("Art Intelligence Report")
        .navigationBarTitleDisplayMode(.inline)
    }
}
