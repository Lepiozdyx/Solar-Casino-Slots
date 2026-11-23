import Foundation

/// The cue names and saved game IDs are stable; only newly composed resources ship.
enum SolarAudioResources {
    static func solarMechanical(_ name: String) -> URL? {
        let tracks = ["forge": "dynamo", "nougat": "confection", "temple": "sanctum", "carnival": "festival", "bonus": "surge"]
        let resource = tracks[name].map { "aurum-track-" + $0 } ?? "aurum-metal-" + name
        return solarResource(resource)
    }
    static func solarLuminous(_ name: String, music: Bool) -> URL? {
        let tracks = ["redline": "crimson", "prism": "prismatic", "orbit": "astral", "blackjack": "blackjack", "roulette": "roulette"]
        let resource = music ? "aurum-track-" + (tracks[name] ?? name) : "aurum-lumen-" + name
        return solarResource(resource)
    }
    private static func solarResource(_ name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "CollectionAudio")
            ?? Bundle.main.url(forResource: name, withExtension: "wav")
    }
}
