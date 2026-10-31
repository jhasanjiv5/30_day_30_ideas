import Foundation

enum TitleArtworkService {
    static func artworkData(for title: String) async throws -> Data? {
        guard let artworkURL = try await matchingShow(for: title)?.image?.original else {
            return nil
        }

        var artworkRequest = URLRequest(url: artworkURL)
        artworkRequest.timeoutInterval = 15
        let (artworkData, artworkResponse) = try await URLSession.shared.data(for: artworkRequest)
        try validate(artworkResponse)
        return artworkData
    }

    private static func matchingShow(for title: String) async throws -> Show? {
        var components = URLComponents(string: "https://api.tvmaze.com/search/shows")
        components?.queryItems = [URLQueryItem(name: "q", value: title)]
        guard let searchURL = components?.url else {
            throw ArtworkLookupError.invalidSearchURL
        }

        var request = URLRequest(url: searchURL)
        request.timeoutInterval = 10
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        let matches = try JSONDecoder().decode([ShowSearchResult].self, from: data)

        return matches.first {
            isExactTitleMatch(requested: title, result: $0.show.name)
        }?.show
    }

    static func isExactTitleMatch(requested: String, result: String) -> Bool {
        normalize(requested) == normalize(result)
    }

    private static func normalize(_ title: String) -> String {
        title.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func validate(_ response: URLResponse) throws {
        guard
            let response = response as? HTTPURLResponse,
            (200..<300).contains(response.statusCode)
        else {
            throw ArtworkLookupError.invalidResponse
        }
    }

    private struct ShowSearchResult: Decodable {
        let show: Show
    }

    private struct Show: Decodable {
        let name: String
        let image: Artwork?
    }

    private struct Artwork: Decodable {
        let original: URL?
    }

    private enum ArtworkLookupError: LocalizedError {
        case invalidSearchURL
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .invalidSearchURL:
                return "Could not create a title artwork search request."
            case .invalidResponse:
                return "The title artwork service returned an unsuccessful response."
            }
        }
    }
}
