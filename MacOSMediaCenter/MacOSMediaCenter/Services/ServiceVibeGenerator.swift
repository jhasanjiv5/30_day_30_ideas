import Foundation
import FoundationModels

enum ServiceVibeGenerator {
    static func generate(name: String, url: URL) async -> String {
        guard #available(macOS 26.0, *), SystemLanguageModel.default.isAvailable else {
            return ChannelVibe.infer(name: name, url: url)
        }

        do {
            let session = LanguageModelSession(
                instructions: """
                Describe a streaming or media service with one concise vibe phrase.
                Use only the service name and website domain provided. Do not invent
                specific shows, catalog availability, or personal viewing history.
                Return only a short phrase, no quotes or explanation.
                """
            )
            let response = try await session.respond(to: """
            Service name: \(name)
            Website domain: \(url.host ?? "unknown")
            Website path: \(url.path.isEmpty ? "/" : url.path)
            """)
            let vibe = response.content
                .components(separatedBy: .newlines)
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: "\"'")))
            guard !vibe.isEmpty else {
                throw GenerationError.emptyResponse
            }
            return String(vibe.prefix(80))
        } catch {
            print("Unable to generate an on-device vibe for \(name): \(error)")
            return ChannelVibe.infer(name: name, url: url)
        }
    }

    private enum GenerationError: LocalizedError {
        case emptyResponse

        var errorDescription: String? {
            "The on-device model returned an empty service vibe."
        }
    }
}
