import AppKit
import SceneKit

@MainActor
public final class TextureGenerator {
    public static let shared = TextureGenerator()
    private var cache: [String: NSImage] = [:]

    private init() {}

    public func material(for block: BlockType, face: BlockFace) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = image(for: block, face: face)
        mat.diffuse.magnificationFilter = .nearest
        mat.diffuse.minificationFilter = .nearest
        mat.diffuse.mipFilter = .none
        mat.roughness.contents = 0.8
        mat.metalness.contents = 0.0

        if block == .ice {
            mat.transparency = 0.65
            mat.isDoubleSided = true
        } else if block == .holidayTorch || block == .goldenStar {
            mat.emission.contents = (block == .goldenStar) ? NSColor.systemYellow : NSColor.systemOrange
        }
        return mat
    }

    public func image(for block: BlockType, face: BlockFace) -> NSImage {
        let key = "\(block.rawValue)_\(face.rawValue)"
        if let cached = cache[key] {
            return cached
        }
        let img = generateImage(for: block, face: face)
        cache[key] = img
        return img
    }

    private func generateImage(for block: BlockType, face: BlockFace) -> NSImage {
        let size = 16
        var pixels = [UInt32](repeating: 0xFFFFFFFF, count: size * size)

        func setPixel(_ x: Int, _ y: Int, r: UInt8, g: UInt8, b: UInt8, a: UInt8 = 255) {
            guard x >= 0, x < size, y >= 0, y < size else { return }
            let color = (UInt32(a) << 24) | (UInt32(r) << 16) | (UInt32(g) << 8) | UInt32(b)
            pixels[y * size + x] = color
        }

        func hexColor(_ hex: UInt32, a: UInt8 = 255) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
            let r = UInt8((hex >> 16) & 0xFF)
            let g = UInt8((hex >> 8) & 0xFF)
            let b = UInt8(hex & 0xFF)
            return (r, g, b, a)
        }

        switch block {
        case .snowGrass:
            if face == .top {
                // Pure snow with soft blue shading
                for y in 0..<size {
                    for x in 0..<size {
                        let shade = (x * 7 + y * 13) % 15
                        let val = UInt8(240 + shade)
                        setPixel(x, y, r: val, g: val, b: min(255, val + 5))
                    }
                }
            } else if face == .bottom {
                // Dirt
                fillDirt(pixels: &pixels, size: size)
            } else {
                // Snow top, dirt bottom with dripping snow icicles
                fillDirt(pixels: &pixels, size: size)
                let snowDepth = [4, 4, 5, 6, 5, 4, 3, 5, 6, 4, 3, 4, 5, 4, 3, 4]
                for x in 0..<size {
                    let depth = snowDepth[x % snowDepth.count]
                    for y in 0..<depth {
                        let shade = (x * 3 + y * 5) % 12
                        let val = UInt8(240 + shade)
                        setPixel(x, y, r: val, g: val, b: min(255, val + 4))
                    }
                }
            }

        case .dirt:
            fillDirt(pixels: &pixels, size: size)

        case .stone:
            for y in 0..<size {
                for x in 0..<size {
                    let noise = (x * 11 + y * 17 + (x ^ y)) % 40
                    let val = UInt8(100 + noise)
                    setPixel(x, y, r: val, g: val, b: val)
                }
            }

        case .cobblestone:
            for y in 0..<size {
                for x in 0..<size {
                    let isBorder = (x % 4 == 0) || (y % 4 == 0)
                    let base = isBorder ? 60 : 120
                    let noise = (x * 13 + y * 7) % 30
                    let val = UInt8(base + noise)
                    setPixel(x, y, r: val, g: val, b: val)
                }
            }

        case .pineLog:
            if face == .top || face == .bottom {
                // Tree rings
                for y in 0..<size {
                    for x in 0..<size {
                        let dx = x - 8
                        let dy = y - 8
                        let dist = Int(Double(dx * dx + dy * dy).squareRoot())
                        if dist >= 7 {
                            setPixel(x, y, r: 60, g: 40, b: 20) // Bark
                        } else if dist == 4 || dist == 2 {
                            setPixel(x, y, r: 160, g: 120, b: 70) // Ring
                        } else {
                            setPixel(x, y, r: 185, g: 145, b: 90) // Core
                        }
                    }
                }
            } else {
                // Vertical bark
                for y in 0..<size {
                    for x in 0..<size {
                        let groove = (x % 3 == 0) ? 20 : 0
                        let noise = (y * 7 + x * 5) % 25
                        let r = UInt8(max(0, 75 - groove + noise))
                        let g = UInt8(max(0, 50 - groove + noise))
                        let b = UInt8(max(0, 25 - groove + noise))
                        setPixel(x, y, r: r, g: g, b: b)
                    }
                }
            }

        case .pineLeaves:
            for y in 0..<size {
                for x in 0..<size {
                    let isSnow = ((x + y * 2) % 7 == 0) || (y <= 2 && (x % 3 == 0))
                    if isSnow {
                        setPixel(x, y, r: 240, g: 245, b: 255)
                    } else {
                        let noise = (x * 13 + y * 23) % 40
                        let g = UInt8(70 + noise)
                        let r = UInt8(20 + noise / 2)
                        let b = UInt8(20 + noise / 3)
                        setPixel(x, y, r: r, g: g, b: b)
                    }
                }
            }

        case .pinePlanks:
            for y in 0..<size {
                for x in 0..<size {
                    let seam = (y % 4 == 0)
                    if seam {
                        setPixel(x, y, r: 90, g: 60, b: 35)
                    } else {
                        let isNail = (y % 4 == 2) && (x == 2 || x == 13)
                        if isNail {
                            setPixel(x, y, r: 50, g: 50, b: 50)
                        } else {
                            let noise = (x * 7 + y * 3) % 20
                            setPixel(x, y, r: UInt8(150 + noise), g: UInt8(110 + noise), b: UInt8(65 + noise))
                        }
                    }
                }
            }

        case .candyCane:
            for y in 0..<size {
                for x in 0..<size {
                    let stripe = (x + y) % 6
                    if stripe < 3 {
                        // Holiday red
                        setPixel(x, y, r: 220, g: 30, b: 40)
                    } else {
                        // White mint
                        let noise = (x * 5 + y * 7) % 15
                        let val = UInt8(240 + noise)
                        setPixel(x, y, r: val, g: val, b: val)
                    }
                }
            }

        case .ice:
            for y in 0..<size {
                for x in 0..<size {
                    let crack = ((x * 3 + y * 5) % 17 == 0)
                    let base: UInt8 = crack ? 230 : 160
                    let noise = UInt8((x * 7 + y * 11) % 30)
                    setPixel(x, y, r: base / 2, g: base + noise / 2, b: min(255, base + 40 + noise), a: 190)
                }
            }

        case .presentRed:
            for y in 0..<size {
                for x in 0..<size {
                    let isRibbon = (x == 7 || x == 8) || (y == 7 || y == 8)
                    if isRibbon {
                        // Golden ribbon
                        setPixel(x, y, r: 255, g: 215, b: 0)
                    } else {
                        // Festive velvet red
                        let noise = (x * 3 + y * 7) % 25
                        setPixel(x, y, r: UInt8(190 + noise), g: 20, b: 30)
                    }
                }
            }

        case .presentGreen:
            for y in 0..<size {
                for x in 0..<size {
                    let isRibbon = (x == 7 || x == 8) || (y == 7 || y == 8)
                    if isRibbon {
                        // Silver/red ribbon
                        setPixel(x, y, r: 240, g: 240, b: 240)
                    } else {
                        // Pine green
                        let noise = (x * 5 + y * 11) % 25
                        setPixel(x, y, r: 20, g: UInt8(130 + noise), b: 50)
                    }
                }
            }

        case .holidayTorch:
            for y in 0..<size {
                for x in 0..<size {
                    let inStick = (x >= 6 && x <= 9) && (y >= 6)
                    let inFlame = (x >= 5 && x <= 10) && (y >= 1 && y <= 5)
                    if inFlame {
                        let isInner = (x >= 7 && x <= 8) && (y >= 2 && y <= 4)
                        if isInner {
                            setPixel(x, y, r: 255, g: 255, b: 180)
                        } else {
                            setPixel(x, y, r: 255, g: 140, b: 20)
                        }
                    } else if inStick {
                        setPixel(x, y, r: 120, g: 80, b: 40)
                    } else {
                        setPixel(x, y, r: 0, g: 0, b: 0, a: 0)
                    }
                }
            }

        case .goldenStar:
            for y in 0..<size {
                for x in 0..<size {
                    let dx = abs(x - 7)
                    let dy = abs(y - 7)
                    if (dx + dy <= 6) || (dx <= 1 && dy <= 7) || (dy <= 1 && dx <= 7) {
                        let isCore = (dx <= 2 && dy <= 2)
                        if isCore {
                            setPixel(x, y, r: 255, g: 255, b: 200)
                        } else {
                            setPixel(x, y, r: 255, g: 215, b: 0)
                        }
                    } else {
                        setPixel(x, y, r: 30, g: 30, b: 60) // Star frame
                    }
                }
            }

        case .frostNetherrack:
            for y in 0..<size {
                for x in 0..<size {
                    let noise = (x * 17 + y * 23 + (x ^ y * 3)) % 50
                    let r = UInt8(30 + noise / 2)
                    let g = UInt8(20 + noise / 3)
                    let b = UInt8(80 + noise)
                    setPixel(x, y, r: r, g: g, b: b)
                }
            }

        case .gingerbread:
            for y in 0..<size {
                for x in 0..<size {
                    let isIcing = ((x == 3 && y == 3) || (x == 12 && y == 3) || (x == 7 && y == 11) || (x == 7 && y == 7))
                    if isIcing {
                        setPixel(x, y, r: 255, g: 255, b: 255) // White sugar icing
                    } else {
                        let noise = (x * 7 + y * 13) % 20
                        setPixel(x, y, r: UInt8(180 + noise), g: UInt8(115 + noise), b: UInt8(50 + noise))
                    }
                }
            }

        case .portalBlock:
            for y in 0..<size {
                for x in 0..<size {
                    let swirl = (x * x + y * y + (x * y)) % 60
                    setPixel(x, y, r: UInt8(180 + swirl), g: 60, b: UInt8(200 + swirl / 2), a: 220)
                }
            }
        }

        // Build CGImage safely via self-allocating CGContext
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)

        guard let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return NSImage(size: NSSize(width: size, height: size))
        }

        if let dest = context.data?.assumingMemoryBound(to: UInt32.self) {
            for i in 0..<(size * size) {
                dest[i] = pixels[i]
            }
        }

        guard let cgImage = context.makeImage() else {
            return NSImage(size: NSSize(width: size, height: size))
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
    }

    private func fillDirt(pixels: inout [UInt32], size: Int) {
        for y in 0..<size {
            for x in 0..<size {
                let noise = (x * 19 + y * 29) % 35
                let r = UInt8(110 + noise)
                let g = UInt8(70 + noise)
                let b = UInt8(40 + noise)
                let color = (UInt32(255) << 24) | (UInt32(r) << 16) | (UInt32(g) << 8) | UInt32(b)
                pixels[y * size + x] = color
            }
        }
    }
}
