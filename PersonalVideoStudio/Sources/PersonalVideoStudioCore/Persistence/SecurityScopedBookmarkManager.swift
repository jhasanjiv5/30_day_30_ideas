import Foundation

public enum SecurityScopedBookmarkManager {
    public static func withSecurityScopedAccess<T>(
        to url: URL,
        operation: (URL) throws -> T
    ) throws -> T {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try operation(url)
    }

    public static func withAsyncSecurityScopedAccess<T>(
        to url: URL,
        operation: (URL) async throws -> T
    ) async throws -> T {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try await operation(url)
    }
}
