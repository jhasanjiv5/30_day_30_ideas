import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum HeroArtworkProcessor {
    static let width = 3840
    static let height = 1440
    static let maximumFileSize = 10 * 1024 * 1024

    private static let imageContext = CIContext()

    static func jpegData(from sourceData: Data) throws -> Data {
        guard
            let source = CGImageSourceCreateWithData(sourceData as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(
                source,
                0,
                [kCGImageSourceCreateThumbnailFromImageAlways: true,
                 kCGImageSourceThumbnailMaxPixelSize: 6000] as CFDictionary
            )
        else {
            throw ProcessingError.invalidImage
        }

        guard
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            throw ProcessingError.couldNotCreateCanvas
        }

        let canvas = CGRect(x: 0, y: 0, width: width, height: height)
        context.setFillColor(CGColor(gray: 0.04, alpha: 1))
        context.fill(canvas)

        if CGFloat(image.width) / CGFloat(image.height) < 1.25 {
            drawPortraitArtwork(image, in: context, canvas: canvas)
        } else {
            drawAspectFill(image, in: context, canvas: canvas)
        }
        drawLeftGradient(in: context, canvas: canvas)

        guard let banner = context.makeImage() else {
            throw ProcessingError.couldNotCreateCanvas
        }
        return try encodeJPEG(banner)
    }

    private static func drawPortraitArtwork(_ image: CGImage, in context: CGContext, canvas: CGRect) {
        let source = CIImage(cgImage: image).clampedToExtent()
        let blurred = source
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 70])
            .cropped(to: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        if let background = imageContext.createCGImage(blurred, from: blurred.extent) {
            drawAspectFill(background, in: context, canvas: canvas)
        } else {
            drawAspectFill(image, in: context, canvas: canvas)
        }

        let maximumWidth = CGFloat(width) * 0.36
        let scale = min(maximumWidth / CGFloat(image.width), CGFloat(height) * 0.9 / CGFloat(image.height))
        let displayedWidth = CGFloat(image.width) * scale
        let displayedHeight = CGFloat(image.height) * scale
        let posterRect = CGRect(
            x: CGFloat(width) - displayedWidth - CGFloat(width) * 0.08,
            y: (CGFloat(height) - displayedHeight) / 2,
            width: displayedWidth,
            height: displayedHeight
        )
        context.draw(image, in: posterRect)
    }

    private static func drawAspectFill(_ image: CGImage, in context: CGContext, canvas: CGRect) {
        let scale = max(canvas.width / CGFloat(image.width), canvas.height / CGFloat(image.height))
        let displayedWidth = CGFloat(image.width) * scale
        let displayedHeight = CGFloat(image.height) * scale
        let imageRect = CGRect(
            x: (canvas.width - displayedWidth) / 2,
            y: (canvas.height - displayedHeight) / 2,
            width: displayedWidth,
            height: displayedHeight
        )
        context.draw(image, in: imageRect)
    }

    private static func drawLeftGradient(in context: CGContext, canvas: CGRect) {
        let colors = [
            CGColor(red: 0.015, green: 0.02, blue: 0.035, alpha: 0.94),
            CGColor(red: 0.015, green: 0.02, blue: 0.035, alpha: 0.62),
            CGColor(red: 0.015, green: 0.02, blue: 0.035, alpha: 0)
        ] as CFArray
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: [0, 0.56, 1]
        ) else {
            return
        }

        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: canvas.midY),
            end: CGPoint(x: canvas.width * 0.78, y: canvas.midY),
            options: []
        )
    }

    private static func encodeJPEG(_ image: CGImage) throws -> Data {
        for quality in [0.92, 0.84, 0.76, 0.68, 0.60, 0.52, 0.44, 0.36] {
            let output = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(
                output,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            ) else {
                throw ProcessingError.couldNotEncodeImage
            }

            CGImageDestinationAddImage(
                destination,
                image,
                [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
            )
            guard CGImageDestinationFinalize(destination) else {
                throw ProcessingError.couldNotEncodeImage
            }

            let data = output as Data
            if data.count <= maximumFileSize {
                return data
            }
        }
        throw ProcessingError.fileTooLarge
    }

    enum ProcessingError: LocalizedError {
        case invalidImage
        case couldNotCreateCanvas
        case couldNotEncodeImage
        case fileTooLarge

        var errorDescription: String? {
            switch self {
            case .invalidImage:
                return "The selected artwork file could not be decoded."
            case .couldNotCreateCanvas:
                return "Could not create the 3840 × 1440 banner canvas."
            case .couldNotEncodeImage:
                return "Could not encode the banner as a JPEG image."
            case .fileTooLarge:
                return "The banner could not be compressed below 10 MB."
            }
        }
    }
}
