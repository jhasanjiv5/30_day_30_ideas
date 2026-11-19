import EnsembleCore
import SwiftUI

struct TVHomeView: View {
    @Bindable var model: TVAppModel
    @FocusState private var focusedItemID: String?

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 40) {
                    headerBar
                    roomPresenceStrip
                    installedAppsStrip
                    recommendationsShelf
                }
                .padding(.horizontal, 80)
                .padding(.vertical, 52)
            }
            .background(Color(red: 0.04, green: 0.06, blue: 0.09))
            .fullScreenCover(item: $model.activePlaybackItem) { item in
                TVPlayerView(model: model, item: item)
            }
            .sheet(isPresented: $model.showAboutSheet) {
                TVAboutView(catalogue: model.catalogue)
            }
        }
    }

    private var headerBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Ensemble")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                Text("Room-aware living room cinema · local Bonjour (_ensemble._tcp)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                model.showAboutSheet = true
            } label: {
                Label("About & Licenses", systemImage: "info.circle")
                    .font(.headline)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.bordered)
        }
    }

    private var roomPresenceStrip: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                Text("In the Room")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                if model.participants.isEmpty {
                    Text("Waiting for iPhones on Wi-Fi…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(model.participants.count) present · Child filter \(AgeRating.maxAllowed(for: model.participants).rawValue)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if !model.participants.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 24) {
                        ForEach(model.participants) { person in
                            HStack(spacing: 16) {
                                Image(systemName: person.avatarSymbol)
                                    .font(.system(size: 38))
                                    .foregroundStyle(Color(hex: person.accentHex))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(person.displayName)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Text(person.isChild ? "Child profile (G/PG)" : (person.isTeen ? "Teen profile" : "Adult profile"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                        }
                    }
                }
            }
        }
    }

    private var installedAppsStrip: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 20) {
                Text("Connected TV Apps")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                let installedCount = model.installedAppStatuses.filter(\.isInstalled).count
                Text("\(installedCount) detected via tvOS URL schemes")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    model.toggleInstalledAppsFilter()
                } label: {
                    Text(model.filterToInstalledAppsOnly ? "Showing Installed Apps Only" : "Show Installed Only")
                        .font(.callout)
                }
                .buttonStyle(.bordered)

                Button {
                    model.rescanInstalledApps()
                } label: {
                    Label("Rescan TV Apps", systemImage: "arrow.clockwise")
                        .font(.callout)
                }
                .buttonStyle(.bordered)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(model.installedAppStatuses) { status in
                        HStack(spacing: 10) {
                            Image(systemName: status.isInstalled ? "checkmark.circle.fill" : "circle.dashed")
                                .foregroundStyle(status.isInstalled ? Color(hex: status.appID.accentHex) : .secondary)
                            Text(status.displayName)
                                .font(.callout.weight(.medium))
                                .foregroundStyle(status.isInstalled ? .white : .secondary)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(.white.opacity(status.isInstalled ? 0.12 : 0.04), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }

            if let handoff = model.externalHandoffBanner {
                Text(handoff)
                    .font(.callout)
                    .foregroundStyle(.blue)
            }
        }
    }

    private var recommendationsShelf: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .firstTextBaseline) {
                Text(model.rowHeaderTitle)
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Spacer()

                if let banner = model.activeQueryBanner {
                    HStack(spacing: 16) {
                        Text(banner)
                            .font(.callout)
                            .foregroundStyle(.blue)
                        if model.maxRuntimeFilter != nil {
                            Button("Clear Filter") {
                                model.clearTimeBudget()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 40) {
                    ForEach(model.rankedItems) { ranked in
                        TVMediaPosterCard(
                            ranked: ranked,
                            installedAppIDs: model.installedAppIDSet,
                            isFocused: focusedItemID == ranked.id
                        ) {
                            model.launchItem(ranked.item)
                        }
                        .focused($focusedItemID, equals: ranked.id)
                    }
                }
                .padding(.vertical, 24)
            }
        }
    }
}

private struct TVMediaPosterCard: View {
    let ranked: RankedMediaItem
    let installedAppIDs: Set<StreamingAppID>
    let isFocused: Bool
    let action: () -> Void

    private var launchLabel: String {
        if ranked.item.isPlayableInApp {
            return "STREAM IN ENSEMBLE"
        }
        if let provider = ranked.item.preferredProvider(installedApps: installedAppIDs) {
            let installed = installedAppIDs.contains(provider.appID)
            return installed ? "OPEN IN \(provider.appID.displayName.uppercased())" : "TRY \(provider.appID.displayName.uppercased())"
        }
        return "CATALOGUE"
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.12, green: 0.17, blue: 0.27), Color(red: 0.07, green: 0.09, blue: 0.14)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 440, height: 248)
                        .overlay(
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(launchLabel)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.blue)
                                    Spacer()
                                    Text("\(ranked.item.ageRating.rawValue) · \(ranked.item.runtimeMinutes)m")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(ranked.item.title)
                                    .font(.title3.bold())
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                Text(ranked.item.genres.joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(24)
                        )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(ranked.whyCaption)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .frame(width: 440, alignment: .leading)
                }
            }
        }
        .buttonStyle(.card)
        .scaleEffect(isFocused ? 1.04 : 1.0)
        .animation(.easeOut(duration: 0.18), value: isFocused)
    }
}

private extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
