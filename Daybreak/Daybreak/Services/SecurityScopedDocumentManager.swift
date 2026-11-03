import Foundation

public final class SecurityScopedDocumentManager {
    public static let shared = SecurityScopedDocumentManager()
    private let bookmarkKey = "com.daybreak.scopedFolderBookmark"

    private init() {}

    public func saveFolderBookmark(for url: URL) throws {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        #if os(macOS)
        let bookmarkOptions: URL.BookmarkCreationOptions = .withSecurityScope
        #else
        let bookmarkOptions: URL.BookmarkCreationOptions = []
        #endif
        let bookmarkData = try url.bookmarkData(
            options: bookmarkOptions,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
    }

    public func readDesignatedFolder() async throws -> [DocumentSnippet] {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else {
            return []
        }

        var isStale = false
        #if os(macOS)
        let resolutionOptions: URL.BookmarkResolutionOptions = .withSecurityScope
        #else
        let resolutionOptions: URL.BookmarkResolutionOptions = []
        #endif
        let resolvedURL = try URL(
            resolvingBookmarkData: data,
            options: resolutionOptions,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        if isStale {
            try? saveFolderBookmark(for: resolvedURL)
        }

        guard resolvedURL.startAccessingSecurityScopedResource() else { return [] }
        defer { resolvedURL.stopAccessingSecurityScopedResource() }

        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(
            at: resolvedURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        var snippets: [DocumentSnippet] = []
        for fileURL in contents {
            let ext = fileURL.pathExtension.lowercased()
            if ["md", "txt", "markdown"].contains(ext) {
                if let text = try? String(contentsOf: fileURL, encoding: .utf8) {
                    snippets.append(
                        DocumentSnippet(
                            name: fileURL.lastPathComponent,
                            excerpt: String(text.prefix(1500))
                        )
                    )
                }
            }
        }
        return snippets
    }
}
