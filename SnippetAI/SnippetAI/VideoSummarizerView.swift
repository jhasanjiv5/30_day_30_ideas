import AVFoundation
import AVKit
import CoreImage
import Combine
import SwiftUI
import UniformTypeIdentifiers

struct VideoSummarizerView: View {
    @State private var player: AVPlayer?
    @State private var videoURL: URL?
    @State private var isAnalyzing = false
    @State private var isExporting = false
    @State private var segments: [VideoSegment] = []
    @State private var selectedFilter: ColorFilter = .clean
    @State private var targetPlatform: SocialPlatform = .tiktok
    @State private var targetDuration = 30
    @State private var showComplianceSheet = false
    @State private var showVideoImporter = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var statusMessage = "Choose a video to get started."
    @State private var duration = 0.0
    @State private var playhead = 0.0
    @State private var projectID = UUID().uuidString
    @State private var exportedVideoURL: URL?

    private let summarizer = VideoSummarizationEngine()

    private var currentCaption: String? {
        segments.first {
            $0.startTime <= playhead && playhead < $0.endTime
        }?.caption
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if videoURL == nil {
                    dashboard
                        .padding()
                } else {
                    VStack(spacing: 20) {
                        videoCanvas
                        settings
                        TimelineScrubberTrack(
                            segments: $segments,
                            playhead: $playhead,
                            duration: duration,
                            onSeek: seekPlayer,
                            onSplit: splitAtPlayhead,
                            onMute: toggleSegmentSound
                        )

                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        actionBar
                    }
                    .padding()
                }
            }
            .navigationTitle("SnippetAI")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showVideoImporter = true
                    } label: {
                        Label("Import Video", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Compliance") { showComplianceSheet = true }
                }
            }
            .fileImporter(
                isPresented: $showVideoImporter,
                allowedContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie]
            ) { result in
                importVideo(result)
            }
            .sheet(isPresented: $showComplianceSheet) {
                ComplianceSheet()
                    .presentationDetents([.medium])
            }
            .alert("Unable to complete action", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onReceive(
                Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
            ) { _ in
                guard let player, player.currentItem != nil else { return }
                let time = player.currentTime().seconds
                if time.isFinite {
                    playhead = time
                    player.isMuted = segments.first {
                        $0.startTime <= time && time < $0.endTime
                    }?.isMuted ?? false
                }
            }
        }
    }

    private var dashboard: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 16))
                    Spacer()
                    Text("ON-DEVICE AI")
                        .font(.caption.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.14), in: Capsule())
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Make a highlight reel.")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Turn your video into a share-worthy story in just a few taps.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(.white)

                Button {
                    showVideoImporter = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                        Text("Choose a video")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.22, green: 0.16, blue: 0.52))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
                }
                .accessibilityHint("Select a video to analyze on this device")
            }
            .padding(22)
            .background {
                LinearGradient(
                    colors: [
                        Color(red: 0.32, green: 0.28, blue: 0.83),
                        Color(red: 0.48, green: 0.25, blue: 0.78),
                        Color(red: 0.72, green: 0.31, blue: 0.65)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            VStack(alignment: .leading, spacing: 16) {
                Text("A better reel, made simple")
                    .font(.title3.weight(.bold))

                HStack(alignment: .top, spacing: 14) {
                    workflowStep(
                        number: "01",
                        symbol: "video.badge.plus",
                        title: "Add a video",
                        detail: "Pick a clip from Photos or Files."
                    )
                    workflowStep(
                        number: "02",
                        symbol: "sparkles",
                        title: "Find highlights",
                        detail: "On-device AI selects the key moments."
                    )
                    workflowStep(
                        number: "03",
                        symbol: "square.and.arrow.up",
                        title: "Share your reel",
                        detail: "Trim, style, export, and share."
                    )
                }
            }

            HStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.title3)
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Your video stays on your device")
                        .font(.subheadline.weight(.semibold))
                    Text("Frame analysis and highlight reasoning happen locally.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private func workflowStep(
        number: String,
        symbol: String,
        title: String,
        detail: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
                Spacer(minLength: 0)
                Text(number)
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            Text(title)
                .font(.caption.weight(.semibold))
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 15))
    }

    private var videoCanvas: some View {
        VideoPlayer(player: player)
            .aspectRatio(targetPlatform.aspectRatio, contentMode: .fit)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(alignment: .bottom) {
                DynamicCaptionsOverlay(activeCaption: currentCaption)
            }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Summary length")
                Spacer()
                Stepper(
                    "\(targetDuration) sec",
                    value: $targetDuration,
                    in: 5...90,
                    step: 5
                )
                .fixedSize()
            }

            Picker("Platform", selection: $targetPlatform) {
                ForEach(SocialPlatform.allCases) { platform in
                    Text(platform.title).tag(platform)
                }
            }
            .pickerStyle(.segmented)

            Picker("Filter", selection: $selectedFilter) {
                ForEach(ColorFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private var actionBar: some View {
        VStack(spacing: 12) {
            Button(action: runOnDeviceFoundationModel) {
                Label(
                    isAnalyzing ? "Analyzing…" : "AI Summarize",
                    systemImage: isAnalyzing ? "hourglass" : "sparkles"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.cyan)
                .foregroundStyle(.black)
                .clipShape(Capsule())
            }
            .disabled(videoURL == nil || isAnalyzing || isExporting)

            HStack(spacing: 12) {
                Button(action: syncProject) {
                    Label("Sync Project", systemImage: "icloud.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(segments.isEmpty || isAnalyzing || isExporting)

                if let exportedVideoURL {
                    ShareLink(item: exportedVideoURL) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button(action: exportSummary) {
                        Label(
                            isExporting ? "Exporting…" : "Export",
                            systemImage: "square.and.arrow.up"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(segments.isEmpty || isAnalyzing || isExporting)
                }
            }
        }
    }

    private func importVideo(_ result: Result<URL, Error>) {
        do {
            let sourceURL = try result.get()
            let hasAccess = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }

            let fileExtension = sourceURL.pathExtension.isEmpty
                ? "mov"
                : sourceURL.pathExtension
            let destinationURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(fileExtension)
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

            player?.pause()
            player = AVPlayer(url: destinationURL)
            videoURL = destinationURL
            segments = []
            exportedVideoURL = nil
            projectID = UUID().uuidString
            playhead = 0
            Task {
                do {
                    let asset = AVURLAsset(url: destinationURL)
                    duration = try await asset.load(.duration).seconds
                    statusMessage = "Ready to summarize \(sourceURL.deletingPathExtension().lastPathComponent)."
                } catch {
                    present(error)
                }
            }
        } catch {
            present(error)
        }
    }

    private func runOnDeviceFoundationModel() {
        guard let videoURL else { return }
        isAnalyzing = true
        statusMessage = "Analyzing video frames on this device…"

        Task {
            do {
                let asset = AVURLAsset(url: videoURL)
                let decisions = try await summarizer.summarizeVideoFootage(
                    videoAsset: asset,
                    targetDurationSeconds: targetDuration
                )
                segments = decisions.filter(\.keep).map { decision in
                    VideoSegment(
                        startTime: decision.timeRange.start.seconds,
                        endTime: decision.timeRange.end.seconds,
                        caption: decision.caption,
                        reason: decision.reason
                    )
                }
                exportedVideoURL = nil
                statusMessage = segments.isEmpty
                    ? "No highlight segments were found."
                    : "Found \(segments.count) highlight segment(s)."
            } catch {
                present(error)
            }
            isAnalyzing = false
        }
    }

    private func splitAtPlayhead() {
        guard let index = segments.firstIndex(where: {
            $0.startTime < playhead && playhead < $0.endTime
        }) else { return }

        var secondHalf = segments[index]
        secondHalf.id = UUID()
        secondHalf.startTime = playhead
        segments[index].endTime = playhead
        segments.insert(secondHalf, at: index + 1)
        exportedVideoURL = nil
    }

    private func toggleSegmentSound() {
        guard let index = segments.firstIndex(where: {
            $0.startTime <= playhead && playhead < $0.endTime
        }) else { return }
        segments[index].isMuted.toggle()
        player?.isMuted = segments[index].isMuted
        exportedVideoURL = nil
    }

    private func seekPlayer(to time: Double) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
    }

    private func syncProject() {
        guard !segments.isEmpty else { return }
        let project = VideoProject(
            id: projectID,
            title: videoURL?.deletingPathExtension().lastPathComponent ?? "Video Summary",
            segments: segments,
            filter: selectedFilter
        )
        statusMessage = "Syncing project…"
        Task {
            do {
                try await FirebaseCloudSyncService.shared.autoSaveProject(project: project)
                statusMessage = "Project synced to Firebase."
            } catch {
                present(error)
            }
        }
    }

    private func exportSummary() {
        guard let videoURL, !segments.isEmpty else { return }
        isExporting = true
        statusMessage = "Preparing your edited video…"

        Task {
            do {
                let asset = AVURLAsset(url: videoURL)
                let sourceVideoTracks = try await asset.loadTracks(withMediaType: .video)
                guard let sourceVideoTrack = sourceVideoTracks.first else {
                    throw VideoSummarizationEngine.AnalysisError.noVideoTrack
                }

                let composition = AVMutableComposition()
                guard let outputVideoTrack = composition.addMutableTrack(
                    withMediaType: .video,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                ) else {
                    throw ExportError.cannotCreateVideoTrack
                }
                outputVideoTrack.preferredTransform =
                    try await sourceVideoTrack.load(.preferredTransform)

                let sourceAudioTracks = try await asset.loadTracks(withMediaType: .audio)
                let sourceAudioTrack = sourceAudioTracks.first
                let outputAudioTrack = sourceAudioTrack.flatMap { _ in
                    composition.addMutableTrack(
                        withMediaType: .audio,
                        preferredTrackID: kCMPersistentTrackID_Invalid
                    )
                }

                var outputTime = CMTime.zero
                for segment in segments.sorted(by: { $0.startTime < $1.startTime }) {
                    let start = CMTime(seconds: segment.startTime, preferredTimescale: 600)
                    let end = CMTime(seconds: segment.endTime, preferredTimescale: 600)
                    let range = CMTimeRange(start: start, end: end)
                    try outputVideoTrack.insertTimeRange(
                        range,
                        of: sourceVideoTrack,
                        at: outputTime
                    )

                    if let sourceAudioTrack, let outputAudioTrack {
                        if segment.isMuted {
                            outputAudioTrack.insertEmptyTimeRange(
                                CMTimeRange(start: outputTime, duration: range.duration)
                            )
                        } else {
                            try outputAudioTrack.insertTimeRange(
                                range,
                                of: sourceAudioTrack,
                                at: outputTime
                            )
                        }
                    }
                    outputTime = CMTimeAdd(outputTime, range.duration)
                }

                let outputURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("mp4")
                guard let exporter = AVAssetExportSession(
                    asset: composition,
                    presetName: AVAssetExportPresetHighestQuality
                ) else {
                    throw ExportError.cannotCreateExporter
                }
                exporter.shouldOptimizeForNetworkUse = true
                let filter = selectedFilter
                exporter.videoComposition = try await AVVideoComposition(
                    applyingFiltersTo: composition,
                    applier: { request in
                        let image: CIImage
                        switch filter {
                        case .clean:
                            image = request.sourceImage
                        case .warm:
                            image = request.sourceImage.applyingFilter(
                                "CIColorControls",
                                parameters: [
                                    kCIInputSaturationKey: 1.15,
                                    kCIInputBrightnessKey: 0.03
                                ]
                            )
                        case .monochrome:
                            image = request.sourceImage.applyingFilter("CIPhotoEffectMono")
                        }
                        return AVCIImageFilteringResult(resultImage: image)
                    }
                )
                try await exporter.export(to: outputURL, as: .mp4)
                exportedVideoURL = outputURL
                statusMessage = "Export complete. Your edited video is ready to share."
            } catch {
                present(error)
            }
            isExporting = false
        }
    }

    private func present(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
        statusMessage = "The last action could not be completed."
    }

    enum ExportError: LocalizedError {
        case cannotCreateVideoTrack
        case cannotCreateExporter

        var errorDescription: String? {
            switch self {
            case .cannotCreateVideoTrack:
                "Could not prepare the video for export."
            case .cannotCreateExporter:
                "Video export is not available for this file."
            }
        }
    }
}

private struct TimelineScrubberTrack: View {
    @Binding var segments: [VideoSegment]
    @Binding var playhead: Double
    let duration: Double
    let onSeek: (Double) -> Void
    let onSplit: () -> Void
    let onMute: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Timeline")
                    .font(.headline)
                Spacer()
                Button(action: onSplit) {
                    Label("Split", systemImage: "scissors")
                }
                .disabled(!canEditCurrentSegment)

                Button(action: onMute) {
                    Label("Mute", systemImage: "speaker.slash")
                }
                .disabled(!canEditCurrentSegment)
            }

            Slider(
                value: $playhead,
                in: 0...max(duration, 0.1),
                onEditingChanged: { editing in
                    if !editing {
                        onSeek(playhead)
                    }
                }
            )

            if segments.isEmpty {
                Text("Your selected highlights will appear here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(segments.indices, id: \.self) { index in
                    HStack(alignment: .top, spacing: 10) {
                        Text(
                            "\(segments[index].startTime, format: .number.precision(.fractionLength(1)))s"
                        )
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(segments[index].caption)
                                .font(.subheadline.weight(.medium))
                            Text(segments[index].reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: segments[index].isMuted ? "speaker.slash.fill" : "speaker.wave.2")
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private var canEditCurrentSegment: Bool {
        segments.contains {
            $0.startTime <= playhead && playhead < $0.endTime
        }
    }
}

private struct DynamicCaptionsOverlay: View {
    let activeCaption: String?

    var body: some View {
        if let activeCaption {
            Text(activeCaption)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.black.opacity(0.7), in: Capsule())
                .foregroundStyle(.white)
                .padding(.bottom, 18)
        }
    }
}

private struct ComplianceSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Label("Vision frame analysis and Apple Intelligence highlight reasoning run on this device.", systemImage: "iphone")
                Label("The source video is not uploaded; optional Firebase sync stores project metadata.", systemImage: "icloud")
                Label("Review exported clips and captions before sharing.", systemImage: "checkmark.shield")
            }
            .navigationTitle("Privacy & Compliance")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
