import Foundation

public struct BM25Hit: Sendable, Equatable {
    public let window: SubtitleWindow
    public let score: Double

    public init(window: SubtitleWindow, score: Double) {
        self.window = window
        self.score = score
    }
}

/// Pure Swift Okapi BM25 index over ~30-second subtitle windows.
public struct BM25Index: Sendable {
    public let windows: [SubtitleWindow]
    private let termFrequencies: [[String: Int]]
    private let documentLengths: [Int]
    private let averageDocLength: Double
    private let idf: [String: Double]
    private let k1: Double
    private let b: Double

    private static let stopWords: Set<String> = [
        "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for",
        "of", "with", "by", "is", "are", "was", "were", "be", "been", "this",
        "that", "it", "i", "you", "he", "she", "we", "they", "what", "where",
        "when", "part", "scene", "moment", "show", "find", "jump"
    ]

    public init(windows: [SubtitleWindow], k1: Double = 1.5, b: Double = 0.75) {
        self.windows = windows
        self.k1 = k1
        self.b = b

        var tfs: [[String: Int]] = []
        var lengths: [Int] = []
        var docFreq: [String: Int] = [:]

        for window in windows {
            let tokens = Self.tokenize(window.text)
            var counts: [String: Int] = [:]
            for token in tokens {
                counts[token, default: 0] += 1
            }
            for uniqueTerm in counts.keys {
                docFreq[uniqueTerm, default: 0] += 1
            }
            tfs.append(counts)
            lengths.append(tokens.count)
        }

        self.termFrequencies = tfs
        self.documentLengths = lengths
        let totalLength = lengths.reduce(0, +)
        self.averageDocLength = windows.isEmpty ? 1.0 : max(1.0, Double(totalLength) / Double(windows.count))

        let n = Double(windows.count)
        var computedIDF: [String: Double] = [:]
        for (term, df) in docFreq {
            let dfDouble = Double(df)
            computedIDF[term] = log(((n - dfDouble + 0.5) / (dfDouble + 0.5)) + 1.0)
        }
        self.idf = computedIDF
    }

    public func search(query: String, filmIDFilter: String? = nil, limit: Int = 20) -> [BM25Hit] {
        let queryTokens = Self.tokenize(query)
        guard !queryTokens.isEmpty else { return [] }

        var hits: [BM25Hit] = []
        for idx in windows.indices {
            let window = windows[idx]
            if let filter = filmIDFilter, window.filmID != filter {
                continue
            }

            let tfMap = termFrequencies[idx]
            let docLen = Double(documentLengths[idx])
            var score = 0.0

            for term in queryTokens {
                guard let tf = tfMap[term], let termIDF = idf[term] else { continue }
                let tfDouble = Double(tf)
                let numerator = tfDouble * (k1 + 1.0)
                let denominator = tfDouble + k1 * (1.0 - b + b * (docLen / averageDocLength))
                score += termIDF * (numerator / denominator)
            }

            if score > 0 {
                hits.append(BM25Hit(window: window, score: score))
            }
        }

        return Array(hits.sorted { $0.score > $1.score }.prefix(limit))
    }

    public static func tokenize(_ text: String) -> [String] {
        text
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { $0.count > 1 && !stopWords.contains($0) }
    }
}
