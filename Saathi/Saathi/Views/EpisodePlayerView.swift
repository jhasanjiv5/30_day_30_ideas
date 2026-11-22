import SwiftUI
import SaathiCore

struct EpisodePlayerView: View {
    @Bindable var coordinator: SessionCoordinator
    @State private var isPlaying = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let episode = coordinator.generatedEpisode {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(episode.title)
                            .font(.title2.bold())
                        Text("Duration: ~\(episode.estimatedDurationSeconds / 60) min · 0 coordinates stored")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Button {
                            if isPlaying {
                                coordinator.audioService.stopSpeaking()
                                isPlaying = false
                            } else {
                                coordinator.audioService.speak(episode.script, language: coordinator.narrationLanguage)
                                isPlaying = true
                            }
                        } label: {
                            Label(isPlaying ? "Pause Episode" : "Play Memory Episode", systemImage: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("playEpisodeButton")
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

                    if let walk = episode.walkSummary {
                        walkCard(walk)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Stops in Order")
                            .font(.headline)
                        ForEach(episode.stops) { stop in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(stop.placeName)
                                        .font(.subheadline.bold())
                                    Spacer()
                                    Text(stop.visitedAt, style: .time)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(stop.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

                    if !episode.linkedPhotoLocalIdentifiers.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Linked PhotoKit References (No Copies)")
                                .font(.headline)
                            ForEach(episode.linkedPhotoLocalIdentifiers, id: \.self) { id in
                                Label(id, systemImage: "photo")
                                    .font(.caption.monospaced())
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transcript")
                            .font(.headline)
                        Text(episode.script)
                            .font(.body)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

                    VStack(spacing: 10) {
                        Button {
                            Task { await coordinator.finalizeEpisode(decision: .keepOnDevice) }
                        } label: {
                            Label("Keep on Device", systemImage: "iphone")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("keepEpisodeButton")

                        Button {
                            Task { await coordinator.finalizeEpisode(decision: .saveToICloud) }
                        } label: {
                            Label("Save to iCloud", systemImage: "icloud")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("saveICloudEpisodeButton")

                        Button(role: .destructive) {
                            Task { await coordinator.finalizeEpisode(decision: .discard) }
                        } label: {
                            Label("Discard Episode", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("discardEpisodeButton")
                    }
                } else {
                    ContentUnavailableView("No Episode Available", systemImage: "waveform")
                }
            }
            .padding()
        }
        .navigationTitle("Memory Episode")
    }

    /// Walk totals from the Apple Watch / iPhone workout or pedometer (never a route).
    private func walkCard(_ walk: WalkSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(sourceLabel(walk.source), systemImage: walk.source == .appleWatchWorkout ? "applewatch" : "figure.walk")
                .font(.headline)
            HStack(spacing: 24) {
                stat(String(format: "%.1f km", (walk.distanceMeters ?? 0) / 1000), "Distance")
                stat(durationText(walk.durationSeconds), "Time")
                stat(walk.steps.map { NumberFormatter.localizedString(from: NSNumber(value: $0), number: .decimal) } ?? "—", "Steps")
                if let gain = walk.elevationGainMeters {
                    stat("\(Int(gain.rounded())) m", "Climb")
                }
            }
            Text(endReasonText(walk.endReason))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("walkSummaryCard")
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title3.monospacedDigit().bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func sourceLabel(_ source: WalkSummary.Source) -> String {
        switch source {
        case .appleWatchWorkout: return "Your walk · Apple Watch"
        case .iPhoneWorkout: return "Your walk · iPhone workout"
        case .iPhonePedometer: return "Your walk · iPhone steps"
        case .sessionClockOnly: return "Your walk"
        }
    }

    private func endReasonText(_ reason: WalkEndReason) -> String {
        switch reason {
        case .workoutEnded: return "Wrapped up automatically when your Outdoor Walk workout ended."
        case .stoppedMoving: return "Wrapped up after you stopped walking for a while."
        case .leftByVehicle: return "Wrapped up when you left by vehicle."
        case .safetyCap: return "Wrapped up at the session safety limit."
        case .userEnded: return "Ended by you."
        }
    }

    private func durationText(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(max(minutes, 1)) min"
    }
}
