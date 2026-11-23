import UIKit

/// Fresh generated atlases stay intact in the bundle. Individual sprites are cropped
/// in memory at their exact grid boundaries and cached for the animated reel renderers.
@MainActor final class SolarImageArchive {
    static let shared = SolarImageArchive()
    private let sprites = NSCache<NSString, UIImage>()
    private let sheets = NSCache<NSString, UIImage>()
    private init() {
        sprites.totalCostLimit = 28 * 1024 * 1024
        sheets.totalCostLimit = 44 * 1024 * 1024
    }

    func solarImage(_ name: String) -> UIImage? {
        if let image = sprites.object(forKey: name as NSString) { return image }
        let image: UIImage?
        if let region = solarRegion(name), let atlas = solarSheet(region.sheet), let source = atlas.cgImage {
            let x = region.index % region.grid, y = region.index / region.grid
            let left = source.width * x / region.grid, top = source.height * y / region.grid
            let right = source.width * (x + 1) / region.grid, bottom = source.height * (y + 1) / region.grid
            let rect = CGRect(x: left, y: top, width: right - left, height: bottom - top)
            image = source.cropping(to: rect).map { UIImage(cgImage: $0, scale: 1, orientation: .up) }
        } else {
            image = solarSheet(solarCoverResource(name))
        }
        if let image {
            sprites.setObject(image, forKey: name as NSString,
                              cost: Int(image.size.width * image.size.height * 4))
        }
        return image
    }

    private func solarSheet(_ name: String) -> UIImage? {
        if let image = sheets.object(forKey: name as NSString) { return image }
        guard let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "CollectionArtwork")
                ?? Bundle.main.url(forResource: name, withExtension: "png"),
              let image = UIImage(contentsOfFile: url.path) else { return nil }
        sheets.setObject(image, forKey: name as NSString,
                         cost: Int(image.size.width * image.size.height * 4))
        return image
    }

    private func solarRegion(_ name: String) -> SolarSpriteRegion? {
        for theme in ["dynamo", "confection", "sanctum", "festival"] {
            let prefix = "aurum-\(theme)_"
            if name.hasPrefix(prefix), let index = Int(name.dropFirst(prefix.count)), (0..<9).contains(index) {
                return SolarSpriteRegion(sheet: "aurum-\(theme)-symbols", grid: 3, index: index)
            }
        }
        if name.hasPrefix("solar-property-"),
           let property = SolarProperty(rawValue: String(name.dropFirst("solar-property-".count))),
           let index = SolarProperty.allCases.firstIndex(of: property) {
            return SolarSpriteRegion(sheet: "solar-estate-properties", grid: 4, index: index)
        }
        let marks = ["cherry", "lemon", "grapes", "melon", "bell", "seven", "cyan", "pink",
                     "green", "amber", "violet", "scarlet", "wild", "scatter", "chip", "medal"]
        if name.hasPrefix("aurum-mark-"), let index = marks.firstIndex(of: String(name.dropFirst(11))) {
            return SolarSpriteRegion(sheet: "aurum-jewel-fruit-symbols", grid: 4, index: index)
        }
        let emblems = ["aurum-wallet-token", "aurum-celebration", "aurum-card-ornament", "aurum-trophy"]
        if let index = emblems.firstIndex(of: name) {
            return SolarSpriteRegion(sheet: "aurum-cabinet-emblems", grid: 2, index: index)
        }
        return nil
    }

    private func solarCoverResource(_ name: String) -> String {
        switch name {
        case "aurum-scene-redline": "aurum-crimson-cover"
        case "aurum-scene-prism": "aurum-prismatic-cover"
        case "aurum-scene-orbit": "aurum-astral-cover"
        case "aurum-scene-blackjack": "aurum-blackjack-cover"
        case "aurum-scene-roulette": "aurum-roulette-cover"
        default: name
        }
    }
}

private struct SolarSpriteRegion {
    let sheet: String
    let grid: Int
    let index: Int
}
