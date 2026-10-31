import Foundation
import FoundationModels

enum ServiceRecommendationGenerator {
    static func generate(
        name: String,
        url: URL,
        vibe: String,
        knownRecommendations: [ServiceTitle]
    ) async -> [ServiceTitle] {
        guard knownRecommendations.isEmpty else {
            return knownRecommendations
        }
        guard #available(macOS 26.0, *), SystemLanguageModel.default.isAvailable else {
            return fallback(for: name)
        }

        do {
            let session = LanguageModelSession(
                instructions: """
                Suggest up to three real, well-known TV series relevant to this media
                service. Use the service name, website domain, and vibe. Do not claim a
                title is available in its catalog. Return only one title per line,
                without bullets or explanations. If you cannot identify a relevant
                title, return no lines.
                """
            )
            let response = try await session.respond(to: """
            Service: \(name)
            Website: \(url.host ?? "unknown")
            Vibe: \(vibe)
            """)
            let suggestions = parse(response.content, serviceName: name)
            return suggestions.isEmpty ? fallback(for: name) : suggestions
        } catch {
            print("Unable to generate title suggestions for \(name): \(error)")
            return fallback(for: name)
        }
    }

    static func parse(_ response: String, serviceName: String) -> [ServiceTitle] {
        var seenTitles = Set<String>()
        return response
            .components(separatedBy: .newlines)
            .compactMap { line -> ServiceTitle? in
                let title = line.replacingOccurrences(
                    of: #"^\s*(?:[-*•]|\d+[.)])\s*"#,
                    with: "",
                    options: .regularExpression
                )
                .trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: "\"'")))
                guard
                    !title.isEmpty,
                    title.count <= 100,
                    seenTitles.insert(title.lowercased()).inserted
                else {
                    return nil
                }
                return ServiceTitle(
                    title: title,
                    detail: "Suggested to search on \(serviceName)",
                    placement: .recommended
                )
            }
            .prefix(3)
            .map { $0 }
    }

    static func fallback(for name: String) -> [ServiceTitle] {
        [
            ServiceTitle(
                title: "Browse \(name)",
                detail: "Explore the catalog for a title to watch",
                placement: .recommended
            )
        ]
    }
}
