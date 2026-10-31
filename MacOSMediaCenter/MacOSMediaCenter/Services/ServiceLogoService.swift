import Foundation

enum ServiceLogoService {
    static func logoURL(for websiteURL: URL) async -> URL? {
        var request = URLRequest(url: websiteURL)
        request.timeoutInterval = 8
        request.setValue("text/html", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard
                let response = response as? HTTPURLResponse,
                (200..<300).contains(response.statusCode),
                let html = String(data: data, encoding: .utf8)
            else {
                return nil
            }
            return preferredIconURL(in: html, baseURL: response.url ?? websiteURL)
        } catch {
            print("Unable to load service logo from \(websiteURL.host ?? websiteURL.absoluteString): \(error)")
            return nil
        }
    }

    static func preferredIconURL(in html: String, baseURL: URL) -> URL? {
        let linkPattern = #"<link\b[^>]*>"#
        guard let linkRegex = try? NSRegularExpression(
            pattern: linkPattern,
            options: [.caseInsensitive]
        ) else {
            return nil
        }

        let document = html as NSString
        let matches = linkRegex.matches(
            in: html,
            range: NSRange(location: 0, length: document.length)
        )
        let candidates = matches.compactMap { match -> (URL, Int)? in
            let tag = document.substring(with: match.range)
            let attributes = parseAttributes(in: tag)
            let relations = Set((attributes["rel"] ?? "").lowercased().split(whereSeparator: \.isWhitespace))
            guard
                relations.contains("icon") ||
                    relations.contains("apple-touch-icon") ||
                    relations.contains("apple-touch-icon-precomposed"),
                let href = attributes["href"],
                let url = URL(string: href, relativeTo: baseURL)?.absoluteURL,
                ["https", "http"].contains(url.scheme?.lowercased() ?? "")
            else {
                return nil
            }

            let dimensionPattern = #"(\d+)\s*x\s*(\d+)"#
            let sizes = attributes["sizes"] ?? ""
            let sizeRegex = try? NSRegularExpression(pattern: dimensionPattern)
            let sizeRange = NSRange(sizes.startIndex..., in: sizes)
            let sizeMatches = sizeRegex?.matches(in: sizes, range: sizeRange) ?? []
            let sizeSource = sizes as NSString
            var largestDimension = 0
            for sizeMatch in sizeMatches {
                let width = Int(sizeSource.substring(with: sizeMatch.range(at: 1))) ?? 0
                let height = Int(sizeSource.substring(with: sizeMatch.range(at: 2))) ?? 0
                largestDimension = max(largestDimension, width, height)
            }
            let isTouchIcon = relations.contains("apple-touch-icon") ||
                relations.contains("apple-touch-icon-precomposed")
            return (url, largestDimension + (isTouchIcon ? 10_000 : 0))
        }

        return candidates.max(by: { $0.1 < $1.1 })?.0
    }

    private static func parseAttributes(in tag: String) -> [String: String] {
        let pattern = #"([a-zA-Z_:][a-zA-Z0-9_:.-]*)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [:]
        }
        let source = tag as NSString
        let matches = regex.matches(in: tag, range: NSRange(location: 0, length: source.length))
        return matches.reduce(into: [:]) { result, match in
            guard match.numberOfRanges == 5 else { return }
            let key = source.substring(with: match.range(at: 1)).lowercased()
            let valueRange = (2...4).first(where: { match.range(at: $0).location != NSNotFound })
            if let valueRange {
                result[key] = source.substring(with: match.range(at: valueRange))
            }
        }
    }
}
