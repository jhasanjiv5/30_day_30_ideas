import CoreGraphics
import Foundation

public enum ExportAspectRatio: String, Codable, CaseIterable, Equatable, Sendable {
    case landscape16x9
    case portrait9x16

    public var displayName: String {
        switch self {
        case .landscape16x9: return "16:9 Landscape"
        case .portrait9x16: return "9:16 Vertical"
        }
    }
}

public enum ExportResolutionTier: String, Codable, CaseIterable, Equatable, Sendable {
    case hd720p
    case fullHD1080p

    public var displayName: String {
        switch self {
        case .hd720p: return "720p HD"
        case .fullHD1080p: return "1080p Full HD"
        }
    }
}

public enum ExportFrameRate: Int, Codable, CaseIterable, Equatable, Sendable {
    case fps24 = 24
    case fps30 = 30
    case fps60 = 60

    public var displayName: String {
        "\(rawValue) fps"
    }
}

public struct ExportConfiguration: Codable, Equatable, Sendable {
    public var aspectRatio: ExportAspectRatio
    public var resolution: ExportResolutionTier
    public var frameRate: ExportFrameRate
    public var includeAudioMix: Bool

    public init(
        aspectRatio: ExportAspectRatio = .landscape16x9,
        resolution: ExportResolutionTier = .fullHD1080p,
        frameRate: ExportFrameRate = .fps30,
        includeAudioMix: Bool = true
    ) {
        self.aspectRatio = aspectRatio
        self.resolution = resolution
        self.frameRate = frameRate
        self.includeAudioMix = includeAudioMix
    }

    public static let default1080pLandscape = ExportConfiguration(
        aspectRatio: .landscape16x9,
        resolution: .fullHD1080p,
        frameRate: .fps30,
        includeAudioMix: true
    )

    public static let default1080pPortrait = ExportConfiguration(
        aspectRatio: .portrait9x16,
        resolution: .fullHD1080p,
        frameRate: .fps30,
        includeAudioMix: true
    )

    public var pixelSize: CGSize {
        switch (aspectRatio, resolution) {
        case (.landscape16x9, .hd720p):
            return CGSize(width: 1280, height: 720)
        case (.landscape16x9, .fullHD1080p):
            return CGSize(width: 1920, height: 1080)
        case (.portrait9x16, .hd720p):
            return CGSize(width: 720, height: 1280)
        case (.portrait9x16, .fullHD1080p):
            return CGSize(width: 1080, height: 1920)
        }
    }

    public var pixelWidth: Int { Int(pixelSize.width) }
    public var pixelHeight: Int { Int(pixelSize.height) }

    public func validate() throws {
        guard pixelWidth > 0 && pixelHeight > 0 else {
            throw VideoStudioError.invalidExportConfiguration(reason: "Output video dimensions must be positive.")
        }
        guard pixelWidth.isMultiple(of: 2) && pixelHeight.isMultiple(of: 2) else {
            throw VideoStudioError.invalidExportConfiguration(reason: "H.264 export dimensions must be even integers.")
        }
    }
}
