import Foundation
import SwiftUI

final class ChannelStore: ObservableObject {
    @Published var channels: [ChannelItem]
    @Published var showAddSheet: Bool = false

    init(channels: [ChannelItem] = ChannelItem.sampleChannels) {
        self.channels = (channels + Self.loadCustomChannels()).map { channel in
            var channel = channel
            channel.heroArtworkURL = Self.savedArtworkURL(for: channel.id)
            channel.keepsGeneratedHeroArtwork = UserDefaults.standard.bool(
                forKey: Self.keepArtworkKey(for: channel.id)
            )
            if let upNext = channel.upNextTitles.first {
                channel.upNextArtworkURL = Self.savedArtworkURL(for: Self.titleArtworkKey(
                    channelID: channel.id,
                    title: upNext
                ))
            }
            return channel
        }
    }

    @discardableResult
    func addCustomChannel(
        name: String,
        url: String,
        upNextTitle: String = ""
    ) throws -> ChannelItem {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw AddServiceError.missingName
        }
        let trimmedUpNextTitle = upNextTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlWithScheme = trimmedURL.contains("://") ? trimmedURL : "https://\(trimmedURL)"
        guard
            let components = URLComponents(string: urlWithScheme),
            let scheme = components.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            let host = components.host,
            !host.isEmpty,
            components.user == nil,
            components.password == nil,
            let serviceURL = components.url
        else {
            throw AddServiceError.invalidURL
        }

        let normalizedHost = host.lowercased()
        let normalizedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let isDuplicate = channels.contains { existing in
            existing.url.host?.lowercased() == normalizedHost &&
                existing.url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) == normalizedPath
        }
        guard !isDuplicate else {
            throw AddServiceError.duplicateService
        }
        let serviceVibe = ChannelVibe.infer(name: trimmedName, url: serviceURL)
        let knownRecommendations = ChannelVibe.recommendations(
            for: trimmedName,
            url: serviceURL,
            vibe: serviceVibe
        )
        let recommendations = knownRecommendations.isEmpty
            ? ServiceRecommendationGenerator.fallback(for: trimmedName)
            : knownRecommendations
        let titleSections = ChannelVibe.titleSections(
            name: trimmedName,
            recommendations: recommendations,
            explicitUpNextTitle: trimmedUpNextTitle
        )

        let channel = ChannelItem(
            id: "custom-\(UUID().uuidString)",
            name: trimmedName,
            category: ChannelVibe.category(name: trimmedName, url: serviceURL, vibe: serviceVibe),
            url: serviceURL,
            primaryColor: ChannelVibe.color(name: trimmedName, url: serviceURL),
            iconSystemName: ChannelVibe.icon(name: trimmedName, url: serviceURL),
            tagline: "Explore \(serviceVibe.lowercased()) on \(trimmedName)",
            aiContextHint: serviceVibe,
            backdropImageName: "tv",
            upNextTitles: titleSections.upNext,
            recommendedTitles: titleSections.recommended,
            explicitUpNextTitle: trimmedUpNextTitle.isEmpty ? nil : trimmedUpNextTitle
        )
        channels.append(channel)
        saveCustomChannels()
        return channel
    }

    func populateCustomService(for channelID: String) async throws {
        guard let channel = channels.first(where: { $0.id == channelID }) else { return }
        let generatedVibe = await ServiceVibeGenerator.generate(name: channel.name, url: channel.url)
        let vibe = ChannelVibe.resolvedVibe(name: channel.name, url: channel.url, savedVibe: generatedVibe)
        guard let index = channels.firstIndex(where: { $0.id == channelID }) else { return }

        let explicitUpNextTitle = channels[index].explicitUpNextTitle
        let knownRecommendations = ChannelVibe.recommendations(
            for: channel.name,
            url: channel.url,
            vibe: vibe
        )
        let recommendations = await ServiceRecommendationGenerator.generate(
            name: channel.name,
            url: channel.url,
            vibe: vibe,
            knownRecommendations: knownRecommendations
        )
        let sections = ChannelVibe.titleSections(
            name: channel.name,
            recommendations: recommendations,
            explicitUpNextTitle: explicitUpNextTitle
        )

        channels[index].category = ChannelVibe.category(name: channel.name, url: channel.url, vibe: vibe)
        channels[index].tagline = "Explore \(vibe.lowercased()) on \(channel.name)"
        channels[index].aiContextHint = vibe
        channels[index].upNextTitles = sections.upNext
        channels[index].recommendedTitles = sections.recommended
        channels[index].upNextArtworkURL = nil
        channels[index].bannerArtworkStatus = nil
        saveCustomChannels()

        guard let upNext = sections.upNext.first else {
            channels[index].bannerArtworkStatus = "No matching recommendations are available for this service yet."
            return
        }
        if let cachedURL = cachedTitleArtwork(for: channel, title: upNext) {
            channels[index].upNextArtworkURL = cachedURL
            return
        }

        do {
            guard let imageData = try await TitleArtworkService.artworkData(for: upNext.title) else {
                channels[index].bannerArtworkStatus = "No matching title artwork is available yet."
                return
            }

            let artworkURL = try saveTitleArtwork(for: channel, title: upNext, data: imageData)
            guard
                let currentIndex = channels.firstIndex(where: { $0.id == channelID }),
                channels[currentIndex].upNextTitles.first?.id == upNext.id
            else {
                return
            }
            channels[currentIndex].upNextArtworkURL = artworkURL
            channels[currentIndex].bannerArtworkStatus = nil
        } catch {
            if let currentIndex = channels.firstIndex(where: { $0.id == channelID }) {
                channels[currentIndex].bannerArtworkStatus = "Title artwork could not be loaded."
            }
            throw error
        }
    }

    func removeCustomChannel(id channelID: String) throws {
        guard channelID.hasPrefix("custom-") else {
            throw RemoveServiceError.cannotRemoveBuiltInService
        }
        guard channels.contains(where: { $0.id == channelID }) else { return }

        let filenamePrefix = Self.safeFilename(for: channelID)
        let directory = try Self.artworkDirectory()
        let artworkFiles = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        for file in artworkFiles {
            let filename = file.deletingPathExtension().lastPathComponent
            if filename == filenamePrefix || filename.hasPrefix("\(filenamePrefix)-") {
                try FileManager.default.removeItem(at: file)
            }
        }

        channels.removeAll { $0.id == channelID }
        UserDefaults.standard.removeObject(forKey: Self.keepArtworkKey(for: channelID))
        saveCustomChannels()
    }

    @discardableResult
    func saveHeroArtwork(for channel: ChannelItem, from sourceURL: URL) throws -> URL {
        guard sourceURL.isFileURL, FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw ArtworkError.missingGeneratedImage
        }
        let data = try Data(contentsOf: sourceURL)
        let bannerData = try HeroArtworkProcessor.jpegData(from: data)
        let destinationURL = try storeArtwork(bannerData, named: Self.safeFilename(for: channel.id))

        if let index = channels.firstIndex(where: { $0.id == channel.id }) {
            channels[index].heroArtworkURL = destinationURL
        }
        return destinationURL
    }

    @discardableResult
    func saveTitleArtwork(for channel: ChannelItem, title: ServiceTitle, data: Data) throws -> URL {
        let bannerData = try HeroArtworkProcessor.jpegData(from: data)
        let artworkURL = try storeArtwork(
            bannerData,
            named: Self.titleArtworkKey(channelID: channel.id, title: title)
        )
        if
            let index = channels.firstIndex(where: { $0.id == channel.id }),
            channels[index].upNextTitles.first?.id == title.id
        {
            channels[index].upNextArtworkURL = artworkURL
            channels[index].bannerArtworkStatus = nil
        }
        return artworkURL
    }

    func cachedTitleArtwork(for channel: ChannelItem, title: ServiceTitle) -> URL? {
        Self.savedArtworkURL(for: Self.titleArtworkKey(channelID: channel.id, title: title))
    }

    private static func titleArtworkKey(channelID: String, title: ServiceTitle) -> String {
        safeFilename(for: "\(channelID)-\(title.id)")
    }

    private func storeArtwork(_ data: Data, named name: String) throws -> URL {
        let directory = try Self.artworkDirectory()
        let destinationURL = directory.appendingPathComponent(name).appendingPathExtension("jpg")
        let existingFiles = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for existingURL in existingFiles where existingURL.deletingPathExtension().lastPathComponent == name {
            try FileManager.default.removeItem(at: existingURL)
        }
        try data.write(to: destinationURL, options: .atomic)
        return destinationURL
    }

    func setKeepGeneratedHeroArtwork(_ shouldKeep: Bool, for channel: ChannelItem) {
        guard let index = channels.firstIndex(where: { $0.id == channel.id }) else { return }
        channels[index].keepsGeneratedHeroArtwork = shouldKeep
        UserDefaults.standard.set(shouldKeep, forKey: Self.keepArtworkKey(for: channel.id))
    }

    private static func keepArtworkKey(for channelID: String) -> String {
        "tvOSDashboard.keepGeneratedHeroArtwork.\(safeFilename(for: channelID))"
    }

    private static func artworkDirectory() throws -> URL {
        let applicationSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = applicationSupport
            .appendingPathComponent("tvOSDashboard", isDirectory: true)
            .appendingPathComponent("HeroArtwork", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func safeFilename(for channelID: String) -> String {
        let filename = channelID.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_" }
            .map(String.init)
            .joined()
        return filename.isEmpty ? UUID().uuidString : filename
    }

    private static func savedArtworkURL(for channelID: String) -> URL? {
        guard
            let directory = try? artworkDirectory(),
            let files = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )
        else {
            return nil
        }
        let filename = safeFilename(for: channelID)
        return files.first { $0.deletingPathExtension().lastPathComponent == filename }
    }

    private struct SavedChannel: Codable {
        let id: String
        let name: String
        let url: String
        let vibe: String?
        let upNextTitle: String?
        let manualUpNextTitle: String?
        let recommendations: [ServiceTitle]?
    }

    private static let savedChannelsKey = "tvOSDashboard.customChannels"

    private static func loadCustomChannels() -> [ChannelItem] {
        guard let data = UserDefaults.standard.data(forKey: savedChannelsKey) else {
            return []
        }

        do {
            let saved = try JSONDecoder().decode([SavedChannel].self, from: data)
            return saved.compactMap { item in
                guard let url = URL(string: item.url), ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
                    print("Skipping saved service with invalid URL: \(item.url)")
                    return nil
                }
                let vibe = ChannelVibe.resolvedVibe(name: item.name, url: url, savedVibe: item.vibe)
                let recommendations = item.recommendations ?? ChannelVibe.recommendations(
                    for: item.name,
                    url: url,
                    vibe: vibe
                )
                let savedUpNextTitle = ChannelVibe.resolvedSavedUpNextTitle(
                    name: item.name,
                    url: url,
                    vibe: vibe,
                    legacyTitle: item.upNextTitle,
                    explicitTitle: item.manualUpNextTitle
                )
                let titleSections = ChannelVibe.titleSections(
                    name: item.name,
                    recommendations: recommendations,
                    explicitUpNextTitle: savedUpNextTitle
                )
                return ChannelItem(
                    id: item.id,
                    name: item.name,
                    category: ChannelVibe.category(name: item.name, url: url, vibe: vibe),
                    url: url,
                    primaryColor: ChannelVibe.color(name: item.name, url: url),
                    iconSystemName: ChannelVibe.icon(name: item.name, url: url),
                    tagline: "Explore \(vibe.lowercased()) on \(item.name)",
                    aiContextHint: vibe,
                    backdropImageName: "tv",
                    upNextTitles: titleSections.upNext,
                    recommendedTitles: titleSections.recommended,
                    explicitUpNextTitle: item.manualUpNextTitle
                )
            }
        } catch {
            print("Unable to load saved services: \(error)")
            return []
        }
    }

    private func saveCustomChannels() {
        let saved = channels
            .filter { $0.id.hasPrefix("custom-") }
            .map {
                SavedChannel(
                    id: $0.id,
                    name: $0.name,
                    url: $0.url.absoluteString,
                    vibe: $0.aiContextHint,
                    upNextTitle: $0.upNextTitles.first?.title,
                    manualUpNextTitle: $0.explicitUpNextTitle,
                    recommendations: ($0.upNextTitles + $0.recommendedTitles).map {
                        ServiceTitle(title: $0.title, detail: $0.detail, placement: .recommended)
                    }
                )
            }
        do {
            let data = try JSONEncoder().encode(saved)
            UserDefaults.standard.set(data, forKey: Self.savedChannelsKey)
        } catch {
            print("Unable to save custom services: \(error)")
        }
    }

    enum AddServiceError: LocalizedError {
        case missingName
        case invalidURL
        case duplicateService

        var errorDescription: String? {
            switch self {
            case .missingName:
                return "Enter a name for this service."
            case .invalidURL:
                return "Enter a valid website address beginning with http:// or https://."
            case .duplicateService:
                return "This website has already been added."
            }
        }

    }

    enum ArtworkError: LocalizedError {
        case missingGeneratedImage

        var errorDescription: String? {
            "Image Playground did not return a readable generated image."
        }
    }

    enum RemoveServiceError: LocalizedError {
        case cannotRemoveBuiltInService

        var errorDescription: String? {
            "Built-in services cannot be removed."
        }
    }
}
