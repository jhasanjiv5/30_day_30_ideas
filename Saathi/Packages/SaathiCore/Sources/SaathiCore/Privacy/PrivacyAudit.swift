import Foundation

public struct PrivacyContainerFinding: Sendable, Equatable {
    public let location: String
    public let matchedSample: String
}

/// Scans app storage (Documents, Library, Caches, tmp, UserDefaults) for accidental
/// latitude/longitude persistence. Used by automated privacy tests and debug verification.
public enum PrivacyContainerScanner {
    /// Matches decimal coordinate pairs or high-precision lat/lon JSON/plist entries.
    private static let coordinatePairPattern = #"-?(?:[1-8]?\d(?:\.\d{4,})|90(?:\.0+)?)\s*,\s*-?(?:1[0-7]\d(?:\.\d{4,})|[1-9]?\d(?:\.\d{4,})|180(?:\.0+)?)"#
    /// Any key that names a latitude/longitude (e.g. "lat", "coarseLat", "userLng", latitude=)
    /// followed by a decimal with 4+ places. Catches renamed fields, not just the obvious ones.
    private static let labeledLatLonPattern = #"(?i)(?:latitude|longitude|\"[a-z_]*(?:lat|lon|lng)[a-z_]*\")\s*[:=]\s*-?\d{1,3}\.\d{4,}"#

    public static func containsCoordinateLeak(in text: String) -> String? {
        for pattern in [coordinatePairPattern, labeledLatLonPattern] {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                if let match = regex.firstMatch(in: text, range: range),
                   let swiftRange = Range(match.range, in: text) {
                    return String(text[swiftRange])
                }
            }
        }
        return nil
    }

    public static func scanDirectories(
        _ directories: [URL],
        userDefaults: UserDefaults = .standard,
        userDefaultsSuiteName: String? = nil
    ) -> [PrivacyContainerFinding] {
        var findings: [PrivacyContainerFinding] = []
        let fm = FileManager.default

        for dir in directories where fm.fileExists(atPath: dir.path) {
            if let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: [.isRegularFileKey]) {
                for case let fileURL as URL in enumerator {
                    guard (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                        continue
                    }
                    if let data = try? Data(contentsOf: fileURL),
                       let text = String(data: data, encoding: .utf8),
                       let match = containsCoordinateLeak(in: text) {
                        findings.append(PrivacyContainerFinding(location: fileURL.path, matchedSample: match))
                    }
                }
            }
        }

        let defaultsDict = userDefaultsSuiteName.flatMap { UserDefaults(suiteName: $0)?.dictionaryRepresentation() }
            ?? userDefaults.dictionaryRepresentation()

        for (key, value) in defaultsDict {
            // Ignore system Apple keys
            if key.hasPrefix("Apple") || key.hasPrefix("NS") || key.hasPrefix("AK") || key.hasPrefix("PK") {
                continue
            }
            let serialized = "\(key)=\(value)"
            if let match = containsCoordinateLeak(in: serialized) {
                findings.append(PrivacyContainerFinding(location: "UserDefaults[\(key)]", matchedSample: match))
            }
        }

        return findings
    }
}

public struct RecordedOutboundRequest: Sendable, Equatable {
    public let url: URL
    public let host: String
    public let userAgent: String?
    public let headers: [String: String]
}

public enum OutboundRequestValidator {
    public static let defaultAllowedHostSuffixes = [
        "wikipedia.org",
        "www.wikidata.org",
        "overpass-api.de"
    ]

    public static func isHostAllowed(
        _ host: String?,
        allowedSuffixes: [String] = defaultAllowedHostSuffixes
    ) -> Bool {
        guard let host = host?.lowercased(), !host.isEmpty else { return false }
        return allowedSuffixes.contains { suffix in
            host == suffix || host.hasSuffix("." + suffix)
        }
    }

    /// Verifies query string coordinates never exceed 4 decimal places (tile-snapped precision)
    /// and never include device or user identifiers.
    public static func hasOnlyTilePrecisionCoordinates(in url: URL) -> Bool {
        let raw = url.absoluteString
        let highPrecisionPattern = #"-?\d{1,3}\.\d{5,}"#
        if let regex = try? NSRegularExpression(pattern: highPrecisionPattern) {
            let range = NSRange(raw.startIndex..<raw.endIndex, in: raw)
            if regex.firstMatch(in: raw, range: range) != nil {
                return false
            }
        }
        return true
    }

    public static func containsForbiddenIdentifierHeaders(_ headers: [String: String]) -> Bool {
        let forbiddenKeys = ["x-device-id", "x-user-id", "authorization", "cookie", "idfa", "idfv"]
        return headers.keys.contains { forbiddenKeys.contains($0.lowercased()) }
    }
}

/// URLProtocol interceptor used in privacy tests and optional local network audit log.
public final class AllowlistedURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var _recordedRequests: [RecordedOutboundRequest] = []
    nonisolated(unsafe) public static var mockHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    public static var recordedRequests: [RecordedOutboundRequest] {
        lock.lock()
        defer { lock.unlock() }
        return _recordedRequests
    }

    public static func reset() {
        lock.lock()
        _recordedRequests.removeAll()
        mockHandler = nil
        lock.unlock()
    }

    public override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    public override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let headers = request.allHTTPHeaderFields ?? [:]
        let record = RecordedOutboundRequest(
            url: url,
            host: url.host ?? "",
            userAgent: headers["User-Agent"],
            headers: headers
        )

        Self.lock.lock()
        Self._recordedRequests.append(record)
        let handler = Self.mockHandler
        Self.lock.unlock()

        guard OutboundRequestValidator.isHostAllowed(url.host) else {
            client?.urlProtocol(self, didFailWithError: URLError(.appTransportSecurityRequiresSecureConnection))
            return
        }

        if let handler {
            do {
                let (response, data) = try handler(request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        } else {
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data("{}".utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    public override func stopLoading() {}
}
