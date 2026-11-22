import Foundation
import Photos
import EventKit
import PassKit
import SaathiCore

#if canImport(JournalingSuggestions)
import JournalingSuggestions
#endif

/// Handles strictly opt-in, on-device personal context sources.
/// Personal data never leaves the phone.
/// Wallet limitation: PassKit only exposes passes issued under this app's developer team ID;
/// third-party travel/museum passes cannot be read and are out of scope.
@MainActor
@Observable
final class PersonalContextService {
    var photosOptIn: Bool = false
    var calendarOptIn: Bool = false
    var journalingOptIn: Bool = false

    private(set) var selectedJournalingItems: [PersonalMemoryItem] = []

    func requestPhotosAuthorization() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        let granted = (status == .authorized || status == .limited)
        photosOptIn = granted
        return granted
    }

    func requestCalendarAuthorization() async -> Bool {
        let store = EKEventStore()
        let granted = (try? await store.requestFullAccessToEvents()) ?? false
        calendarOptIn = granted
        return granted
    }

    func addUserSelectedJournalingItem(title: String, detail: String, date: Date = Date()) {
        guard journalingOptIn else { return }
        selectedJournalingItems.append(
            PersonalMemoryItem(
                id: "journal_\(UUID().uuidString)",
                kind: .journalingSuggestion,
                title: title,
                detail: detail,
                date: date
            )
        )
    }

    /// Session-scoped, memory-only cache of photo matches per ~250 m tile, so the photo
    /// library is scanned once per area instead of on every narration.
    private var photoMatchesByTile: [String: [PersonalMemoryItem]] = [:]

    func resetSessionCache() {
        photoMatchesByTile.removeAll()
    }

    func fetchOnDeviceMemories(
        near coordinate: EphemeralCoordinate?,
        mockMode: Bool
    ) async -> [PersonalMemoryItem] {
        var results: [PersonalMemoryItem] = []

        if mockMode {
            let mocks = MockFixtures.samplePersonalMemories()
            if photosOptIn { results.append(contentsOf: mocks.filter { $0.kind == .photo }) }
            if calendarOptIn { results.append(contentsOf: mocks.filter { $0.kind == .calendarEvent }) }
            if journalingOptIn { results.append(contentsOf: selectedJournalingItems) }
            return results
        }

        if photosOptIn, let coordinate {
            let tileID = GeoTileSnapper.snap(coordinate).id
            if let cached = photoMatchesByTile[tileID] {
                results.append(contentsOf: cached)
            } else {
                // Scan off the main actor: large libraries take a while to enumerate.
                let matches = await Task.detached(priority: .utility) {
                    Self.scanPhotos(near: coordinate)
                }.value
                photoMatchesByTile[tileID] = matches
                results.append(contentsOf: matches)
            }
        }
        if calendarOptIn {
            results.append(contentsOf: fetchTodaysCalendarEvents())
        }
        if journalingOptIn {
            results.append(contentsOf: selectedJournalingItems)
        }
        return results
    }

    /// Reads only passes belonging to this developer team (if any). Documented PassKit limitation.
    func readTeamScopedWalletPassTitles() -> [String] {
        let library = PKPassLibrary()
        guard PKPassLibrary.isPassLibraryAvailable() else { return [] }
        return library.passes().map(\.localizedDescription)
    }

    /// PhotoKit has no location predicate, so enumerate assets and filter on-device.
    /// The old 50-photo limit meant "what did I photograph here in 2019?" almost never matched.
    private nonisolated static func scanPhotos(near coordinate: EphemeralCoordinate) -> [PersonalMemoryItem] {
        let options = PHFetchOptions()
        options.fetchLimit = 20_000
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let assets = PHAsset.fetchAssets(with: .image, options: options)

        var matched: [PersonalMemoryItem] = []
        assets.enumerateObjects { asset, _, stop in
            guard let loc = asset.location else { return }
            let assetCoord = EphemeralCoordinate(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
            if assetCoord.distanceMeters(to: coordinate) <= 300 {
                let dateText = asset.creationDate.map { DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .none) } ?? "a past visit"
                matched.append(
                    PersonalMemoryItem(
                        id: "ph_\(asset.localIdentifier)",
                        kind: .photo,
                        title: "Your Photo Memory",
                        detail: "You took a photo near here on \(dateText).",
                        date: asset.creationDate ?? Date(),
                        photoLocalIdentifier: asset.localIdentifier,
                        approximateCoordinate: assetCoord
                    )
                )
            }
            if matched.count >= 5 { stop.pointee = true }
        }
        return matched
    }

    private func fetchTodaysCalendarEvents() -> [PersonalMemoryItem] {
        let store = EKEventStore()
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? Date()
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).prefix(5).map { event in
            PersonalMemoryItem(
                id: "ek_\(event.eventIdentifier ?? UUID().uuidString)",
                kind: .calendarEvent,
                title: event.title ?? "Calendar Event",
                detail: event.location ?? "Scheduled today",
                date: event.startDate
            )
        }
    }
}
