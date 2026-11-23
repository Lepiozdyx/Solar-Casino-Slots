import Foundation

enum AurumRoom: String,Codable,CaseIterable,Identifiable {
    case redline,prism,orbit,blackjack,roulette
    var id: String { rawValue }
    var isSlot: Bool { self != .blackjack && self != .roulette }
    var title: String {
        switch self {
        case .redline: "Crimson Sevens"
        case .prism: "Prism Cascade"
        case .orbit: "Celestial Orbit"
        case .blackjack: "Eclipse Blackjack"
        case .roulette: "Meridian Roulette"
        }
    }
    var columns: Int { self == .redline ? 3:5 }
    var rows: Int { self == .prism ? 4:3 }
    var scene: String { "aurum-scene-"+rawValue }
    var featurePrice: Int { self == .prism ? 13:self == .orbit ? 10:48 }
    var freeTurns: Int { self == .orbit ? 7:8 }
    var featureName: String {
        switch self {
        case .redline: "Crimson Boost"
        case .prism: "Gem Surge"
        default: "Star Orbit"
        }
    }
    var ordinary: [AurumMark] { self == .prism ? [.cyan,.pink,.green,.amber,.violet,.scarlet]:[.cherry,.lemon,.grapes,.melon,.bell,.seven] }
}
enum AurumMark: Int,Codable,CaseIterable {
    case cherry,lemon,grapes,melon,bell,seven,cyan,pink,green,amber,violet,scarlet,wild,scatter,chip,medal
    var art: String { "aurum-mark-"+String(describing:self) }
}
struct AurumTile: Codable,Identifiable,Equatable {
    let id: UUID
    let mark: AurumMark
    init(_ mark: AurumMark) { id = UUID();self.mark = mark }
}
struct AurumDice {
    private var state: UInt64
    init(_ seed: UInt64) { state = seed == 0 ? 0xAC247B19:seed }
    mutating func solarNext(_ count: Int) -> Int {
        precondition(count>0)
        state ^= state>>12;state ^= state<<25;state ^= state>>27
        return Int((state &* 2685821657736338717)%UInt64(count))
    }
    mutating func solarShuffle<T>(_ values: inout [T]) { guard values.count>1 else { return };for i in stride(from:values.count-1,through:1,by:-1) { values.swapAt(i,solarNext(i+1)) } }
}
struct AurumLineAward: Codable { let indices: [Int];let amount: Int }
struct AurumFall: Codable {
    let before: [AurumTile]
    let after: [AurumTile]
    let removed: [Int]
    let amount: Int
    let boost: Int
}
struct AurumReelResult: Codable,Identifiable {
    let id: UUID
    let room: AurumRoom
    let stake: Int
    let free: Bool
    let seed: UInt64
    let entrance: [AurumTile]
    let final: [AurumTile]
    let falls: [AurumFall]
    let lines: [AurumLineAward]
    let payout: Int
    let awarded: Int
    let orbit: Int?
}
struct AurumFeature: Codable {
    let room: AurumRoom
    let stake: Int
    var left: Int
    var played = 0
    var total = 0
    var entered = false
    var orbit = 0
}
