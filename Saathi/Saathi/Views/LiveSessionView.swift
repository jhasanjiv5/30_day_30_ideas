import SwiftUI
import MapKit
import SaathiCore

struct LiveSessionView: View {
    @Bindable var coordinator: SessionCoordinator
    @State private var showMap = false
    @State private var questionInput = ""

    var body: some View {
        VStack(spacing: 0) {
            sessionHeaderBar
            if coordinator.phase == .pausedQuiet {
                quietBanner
            }
            if let banner = coordinator.statusBanner, coordinator.phase != .pausedQuiet {
                // Spoken answers ("where is it?", lookup offline, translation fallback) also
                // need to be visible in touch mode.
                Text(banner)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.yellow.opacity(0.15))
                    .accessibilityIdentifier("statusBanner")
            }
            if let prompt = coordinator.pendingHeadGesturePrompt {
                headGestureBanner(prompt: prompt)
            }
            if showMap {
                nearbyPlacesMap
                    .frame(height: 240)
            }

            narrationCardStream
            commandDock
        }
        .navigationTitle(Text("app_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Toggle(isOn: $coordinator.touchModeEnabled) {
                    Label("Touch Mode", systemImage: coordinator.touchModeEnabled ? "hand.tap.fill" : "ear")
                }
                .accessibilityIdentifier("liveTouchModeToggle")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showMap.toggle()
                } label: {
                    Label("Map", systemImage: showMap ? "map.fill" : "map")
                }
                .accessibilityIdentifier("toggleMapButton")
            }
        }
        // Runs whenever the coordinator queues English segments for the narration language.
        // TranslationSession is only vended through SwiftUI, so the view hosts it.
        .translationTask(coordinator.pendingTranslationConfig) { session in
            await coordinator.processTranslationQueue(using: session)
        }
    }

    private var sessionHeaderBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Walking")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formatDuration(coordinator.elapsedSeconds))
                    .font(.title3.monospacedDigit().bold())
                    .accessibilityIdentifier("elapsedLabel")
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%.1f km", coordinator.liveWalkStats.distanceMeters / 1000))
                    .font(.subheadline.monospacedDigit().bold())
                Text("\(coordinator.liveWalkStats.steps) steps")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 8)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("liveWalkStats")
            Spacer()

            Button(role: .destructive) {
                Task { await coordinator.endSession() }
            } label: {
                Text("end_session")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("endSessionButton")
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private var quietBanner: some View {
        HStack {
            Label("Quiet Mode (\(formatDuration(coordinator.quietRemainingSeconds)))", systemImage: "speaker.slash.fill")
                .font(.subheadline.bold())
            Spacer()
            Button("Resume") {
                Task { await coordinator.handleVoiceCommand(.resumeNarration) }
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("resumeNarrationButton")
        }
        .padding()
        .background(Color.orange.opacity(0.15))
        .accessibilityIdentifier("quietBanner")
    }

    private func headGestureBanner(prompt: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(prompt)
                    .font(.subheadline.bold())
                Text("Nod AirPods for Yes · Shake for No")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Yes") {
                Task { await coordinator.handleHeadGesture(.nodYes) }
            }
            .buttonStyle(.borderedProminent)
            Button("No") {
                Task { await coordinator.handleHeadGesture(.shakeNo) }
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.accentColor.opacity(0.12))
    }

    /// Map of nearby monuments ONLY — intentionally NEVER draws or stores a user path trail.
    private var nearbyPlacesMap: some View {
        Map {
            ForEach(coordinator.nearbyRankedPlaces, id: \.place.id) { ranked in
                Marker(
                    ranked.place.title,
                    coordinate: CLLocationCoordinate2D(
                        latitude: ranked.place.coordinate.latitude,
                        longitude: ranked.place.coordinate.longitude
                    )
                )
            }
        }
        .accessibilityLabel("Nearby historic places map. No path trail is drawn or stored.")
        .accessibilityIdentifier("nearbyPlacesMap")
    }

    private var narrationCardStream: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if coordinator.segments.isEmpty {
                    ContentUnavailableView(
                        "Listening to your surroundings",
                        systemImage: "sparkles",
                        description: Text("Walk near a historic landmark or ask a question below.")
                    )
                }

                ForEach(coordinator.segments) { segment in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(segment.placeTitle)
                                .font(.headline)
                            Spacer()
                            Text(segment.timestamp, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(segment.captionText)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)

                        if !segment.citations.isEmpty {
                            Divider()
                            ForEach(segment.citations) { citation in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(citation.provider.rawValue): \(citation.title) (\(citation.languageCode))")
                                        .font(.caption.bold())
                                    Text(citation.licence)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("narrationCard_\(segment.placeID)")
                }
            }
            .padding()
        }
    }

    private var commandDock: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        Task { await coordinator.handleVoiceCommand(.tellMeMore) }
                    } label: {
                        Text("tell_me_more")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("tellMeMoreButton")

                    Button {
                        Task { await coordinator.handleVoiceCommand(.skip) }
                    } label: {
                        Text("skip_place")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("skipButton")

                    Button {
                        Task { await coordinator.handleVoiceCommand(.quiet(minutes: 20)) }
                    } label: {
                        Text("quiet_20_min")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("quietButton")

                    Button("My Photos Here") {
                        Task { await coordinator.handleVoiceCommand(.whatDidIPhotographHere) }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("photosHereButton")

                    Button("Where Is It?") {
                        Task { await coordinator.handleVoiceCommand(.whereIsIt) }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("whereIsItButton")
                }
                .padding(.horizontal)
            }

            HStack {
                TextField("Ask about this place...", text: $questionInput)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("questionTextField")
                Button("Ask") {
                    let query = questionInput
                    questionInput = ""
                    Task {
                        let cmd = VoiceCommandGrammar.parse(query, language: coordinator.listeningLanguage)
                        await coordinator.handleVoiceCommand(cmd)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(questionInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .padding(.top, 8)
        .background(.ultraThinMaterial)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}
