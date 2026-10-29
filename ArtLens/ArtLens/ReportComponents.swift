import SwiftUI

struct KPICapsule: View {
    let title: String
    let value: String
    let subtitle: String
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct VisualMatchCard: View {
    let match: WebVisualMatch

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: match.thumbnailURL.flatMap { URL(string: $0) }) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Image(systemName: "photo.artframe")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
                    .padding(30)
            }
            .frame(width: 160, height: 110)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(match.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text(match.artistOrSource)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text("\(match.similarityPercent)% match · \(match.matchCategory)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 160, alignment: .leading)
    }
}

struct CompositionSectionView: View {
    let critique: CompositionCritique
    let stage: PaintingStage

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(stage.stageScopeNote)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ReportTextCard(title: "Focal Point", text: critique.focalPointAnalysis)
            ReportTextCard(title: "Value Structure", text: critique.valueStructure)
            ReportTextCard(title: "Balance & Rhythm", text: critique.balanceAndRhythm)
            ReportTextCard(title: "Geometric Guidance", text: critique.geometricGuidance)
        }
    }
}

struct ValuationSectionView: View {
    let valuation: CommercialValuation

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ReportTextCard(title: "Estimated Value", text: valuation.formattedRange)
            ReportTextCard(title: "Rationale", text: valuation.rationale)
            ReportTextCard(title: "Projected Completed Value", text: valuation.completedProjectedValuation)
            ForEach(valuation.marketComps) { comp in
                ReportTextCard(
                    title: comp.referenceArt,
                    text: "\(comp.price) · \(comp.marketplace)"
                )
            }
        }
    }
}

struct IPLegalSectionView: View {
    let report: IPComplianceReport
    let kpi: KPIScores

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ReportTextCard(title: "Visual Similarity Caution · \(kpi.ipRiskScore)%", text: report.verdict)
            ReportTextCard(
                title: "Elements to Review",
                text: report.flaggedElements.isEmpty ? "No flagged elements reported." : report.flaggedElements.joined(separator: "\n")
            )
            ReportTextCard(title: "Commercial Safety", text: report.commercialSafetyAssessment)
            ReportTextCard(title: "Fair Use Considerations", text: report.fairUseConsiderations)
        }
    }
}

struct StageChecklistSectionView: View {
    let checklist: [ChecklistItem]
    let stage: PaintingStage

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Stage \(stage.stageIndex): \(stage.rawValue)")
                .font(.headline)
            ForEach(checklist) { item in
                ReportTextCard(
                    title: "\(item.status.label) · \(item.item)",
                    text: item.note
                )
            }
        }
    }
}

private struct ReportTextCard: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private extension ChecklistStatus {
    var label: String {
        switch self {
        case .passed:
            "Done"
        case .attention:
            "Review"
        case .pending:
            "Next"
        }
    }
}
