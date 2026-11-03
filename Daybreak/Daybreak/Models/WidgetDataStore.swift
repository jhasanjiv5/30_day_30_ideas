import Foundation
import WidgetKit

public final class WidgetDataStore {
    public static let shared = WidgetDataStore()
    private let appGroupID = "group.com.daybreak.briefing"
    private let storageKey = "com.daybreak.latestBriefing"

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    private init() {}

    public func saveBriefing(_ briefing: MorningBriefing) throws {
        let data = try JSONEncoder().encode(briefing)
        sharedDefaults?.set(data, forKey: storageKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    public func loadBriefing() -> MorningBriefing? {
        guard let data = sharedDefaults?.data(forKey: storageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(MorningBriefing.self, from: data)
    }

    public func toggleTask(id: String) {
        guard var briefing = loadBriefing() else { return }
        if let idx = briefing.todos.firstIndex(where: { $0.id == id }) {
            briefing.todos[idx].completed.toggle()
            try? saveBriefing(briefing)
        }
    }
}
