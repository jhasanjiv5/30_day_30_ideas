import Foundation

public struct JoinPayload: Codable, Sendable, Equatable {
    public let participantID: UUID
    public let displayName: String
    public let avatarSymbol: String
    public let accentHex: String
    public let isChild: Bool
    public let isTeen: Bool
    public let tasteVector: TasteVector

    public init(
        participantID: UUID,
        displayName: String,
        avatarSymbol: String,
        accentHex: String,
        isChild: Bool,
        isTeen: Bool = false,
        tasteVector: TasteVector
    ) {
        self.participantID = participantID
        self.displayName = displayName
        self.avatarSymbol = avatarSymbol
        self.accentHex = accentHex
        self.isChild = isChild
        self.isTeen = isTeen
        self.tasteVector = tasteVector
    }
}

public struct HeartbeatPayload: Codable, Sendable, Equatable {
    public let participantID: UUID
    public let sentAt: Date

    public init(participantID: UUID, sentAt: Date = .now) {
        self.participantID = participantID
        self.sentAt = sentAt
    }
}

public struct LeavePayload: Codable, Sendable, Equatable {
    public let participantID: UUID

    public init(participantID: UUID) {
        self.participantID = participantID
    }
}

public struct QueryPayload: Codable, Sendable, Equatable {
    public let participantID: UUID
    public let text: String

    public init(participantID: UUID, text: String) {
        self.participantID = participantID
        self.text = text
    }
}

public struct SubtitleWindowPayload: Codable, Sendable, Equatable {
    public let filmID: String
    public let filmTitle: String
    public let currentTimeSeconds: Double
    public let transcriptUpToNow: String

    public init(
        filmID: String,
        filmTitle: String,
        currentTimeSeconds: Double,
        transcriptUpToNow: String
    ) {
        self.filmID = filmID
        self.filmTitle = filmTitle
        self.currentTimeSeconds = currentTimeSeconds
        self.transcriptUpToNow = transcriptUpToNow
    }
}

public struct RecapPayload: Codable, Sendable, Equatable {
    public let participantID: UUID
    public let requesterName: String
    public let filmID: String
    public let summary: String
    public let keyCharacters: [String]
    public let generatedOnDeviceWithAppleIntelligence: Bool

    public init(
        participantID: UUID,
        requesterName: String,
        filmID: String,
        summary: String,
        keyCharacters: [String],
        generatedOnDeviceWithAppleIntelligence: Bool
    ) {
        self.participantID = participantID
        self.requesterName = requesterName
        self.filmID = filmID
        self.summary = summary
        self.keyCharacters = keyCharacters
        self.generatedOnDeviceWithAppleIntelligence = generatedOnDeviceWithAppleIntelligence
    }
}

public enum TVCommandKind: String, Codable, Sendable {
    case playItem
    case jumpToScene
    case requestRecapContext
    case clearTimeBudget
}

public struct CommandPayload: Codable, Sendable, Equatable {
    public let kind: TVCommandKind
    public let participantID: UUID
    public let itemID: String?
    public let timestampSeconds: Double?
    public let targetAppID: StreamingAppID?

    public init(
        kind: TVCommandKind,
        participantID: UUID,
        itemID: String? = nil,
        timestampSeconds: Double? = nil,
        targetAppID: StreamingAppID? = nil
    ) {
        self.kind = kind
        self.participantID = participantID
        self.itemID = itemID
        self.timestampSeconds = timestampSeconds
        self.targetAppID = targetAppID
    }
}

public enum WireMessage: Codable, Sendable, Equatable {
    case join(JoinPayload)
    case leave(LeavePayload)
    case heartbeat(HeartbeatPayload)
    case tasteVector(participantID: UUID, vector: TasteVector)
    case query(QueryPayload)
    case subtitleWindow(SubtitleWindowPayload)
    case recap(RecapPayload)
    case command(CommandPayload)
    case installedApps([InstalledAppStatus])

    public static let bonjourServiceType = "_ensemble._tcp"
    public static let heartbeatIntervalSeconds: TimeInterval = 2.0
    public static let presenceTimeoutSeconds: TimeInterval = 6.0
}

/// 4-byte big-endian length-prefixed framing for streaming JSON messages over NWConnection.
public enum LengthPrefixedFraming {
    public static func encode(_ message: WireMessage) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let payload = try encoder.encode(message)
        var length = UInt32(payload.count).bigEndian
        var frame = Data(bytes: &length, count: 4)
        frame.append(payload)
        return frame
    }

    public static func decodeMessages(from buffer: inout Data) throws -> [WireMessage] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var messages: [WireMessage] = []

        while buffer.count >= 4 {
            let lengthBytes = buffer.prefix(4)
            let bodyLength = lengthBytes.withUnsafeBytes { ptr in
                Int(UInt32(bigEndian: ptr.load(as: UInt32.self)))
            }
            guard bodyLength > 0 && bodyLength < 4_194_304 else {
                buffer.removeAll()
                throw NSError(domain: "EnsembleCore.Framing", code: 400, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid frame length \(bodyLength)"
                ])
            }
            guard buffer.count >= 4 + bodyLength else { break }
            let jsonSlice = buffer.subdata(in: 4..<(4 + bodyLength))
            buffer.removeFirst(4 + bodyLength)
            let msg = try decoder.decode(WireMessage.self, from: jsonSlice)
            messages.append(msg)
        }

        return messages
    }
}
