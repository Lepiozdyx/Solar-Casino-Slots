import Foundation

enum SolarCabinet: String, CaseIterable, Codable, Identifiable {
    case forge, nougat, temple, carnival
    var id: String { rawValue }
    var solarArtPrefix: String {
        switch self { case .forge: "aurum-dynamo"; case .nougat: "aurum-confection"; case .temple: "aurum-sanctum"; case .carnival: "aurum-festival" }
    }
    var solarCoverName: String { solarArtPrefix + "-cover" }
    var title: String {
        switch self {
        case .forge: "Storm Vault"
        case .nougat: "Sugar Comet"
        case .temple: "Solar Relic"
        case .carnival: "Comet Carnival"
        }
    }
    var width: Int { self == .forge ? 3 : self == .nougat ? 6 : 5 }
    var height: Int { self == .nougat ? 5 : 3 }
    var bonusPrice: Int { switch self { case .forge: return 70; case .nougat: return 65; case .temple: return 75; case .carnival: return 95 } }
    var bonusTitle: String {
        switch self {
        case .forge: "Storm Lock"
        case .nougat: "Sugar Trail"
        case .temple: "Serpent Rise"
        case .carnival: "Comet Parade"
        }
    }
    var symbols: [String] {
        switch self {
        case .forge: return ["Storm coin", "Copper bell", "Cherry pair", "Citrus slice", "Ruby prism", "Blue diamond", "Storm hammer", "Lightning scatter", "Power charge"]
        case .nougat: return ["Strawberry heart", "Teal gummy star", "Violet jelly", "Orange sweet", "Pink bonbon", "Sugar plum", "Golden candy", "Sugar portal", "Multiplier charge"]
        case .temple: return ["Jade mask", "Sun disk", "Golden feather", "Amber chalice", "Ruby tablet", "Turquoise gem", "Golden serpent", "Temple gate", "Sun charge"]
        case .carnival: return ["Carnival mask", "Golden drum", "Maracas", "Ruby balloon", "Teal candy", "Orange pinwheel", "Rocket piñata", "Festival ticket", "Firework charge"]
        }
    }
}

struct SolarReelToken: Identifiable, Codable, Equatable {
    let id: UUID
    var face: Int
    var factor: Int
    init(_ face: Int, factor: Int = 0, id: UUID = UUID()) { self.face = face; self.factor = factor; self.id = id }
}

struct SolarReelField: Codable, Equatable {
    let columns: Int
    let rows: Int
    var tokens: [SolarReelToken]
    init(cabinet: SolarCabinet, tokens: [SolarReelToken]) {
        precondition(tokens.count == cabinet.width * cabinet.height)
        columns = cabinet.width; rows = cabinet.height; self.tokens = tokens
    }
    subscript(_ column: Int, _ row: Int) -> SolarReelToken {
        get { tokens[row * columns + column] }
        set { tokens[row * columns + column] = newValue }
    }
    func solarColumn(_ index: Int) -> [SolarReelToken] { (0..<rows).map { self[index, $0] } }
}

struct SolarPayEvent {
    var positions: Set<Int>
    var coins: Int
}
struct SolarCascadePage {
    let field: SolarReelField
    let pays: [SolarPayEvent]
    var cleared: Set<Int> { pays.reduce(into: Set<Int>()) { $0.formUnion($1.positions) } }
    var coins: Int { pays.reduce(0) { $0 + $1.coins } }
}
struct SolarRocketWild: Identifiable, Codable, Equatable {
    var id = UUID()
    var column: Int
    var row: Int
    var boost: Int
}
struct SolarBonusContract: Codable, Equatable {
    var cabinet: SolarCabinet
    var stake: Int
    var awarded: Int
    var left: Int
    var winnings = 0
    var rockets: [SolarRocketWild] = []
    var reveals: [Int] = []
    var started = false
}
struct SolarLockedMedal: Codable, Equatable {
    var index: Int
    var value: Int
    var tier: Int? = nil
}
enum SolarLockJackpot: String, CaseIterable {
    case mini = "MINI"
    case minor = "MINOR"
    case major = "MAJOR"
    case grand = "GRAND"

    var factor: Int {
        switch self {
        case .mini: 8
        case .minor: 25
        case .major: 100
        case .grand: 1_200
        }
    }
}

struct SolarLockContract: Codable, Equatable {
    var stake: Int
    var medals: [SolarLockedMedal]
    var attempts = 3
    var complete: Bool { attempts == 0 || medals.count == 9 }
    var collected: Int { medals.reduce(0) { $0 + $1.value } + (medals.count == 9 ? stake * SolarLockJackpot.grand.factor : 0) }
}
struct SolarResolvedSpin {
    var pages: [SolarCascadePage]
    var multiplier = 1
    var nextRockets: [SolarRocketWild] = []
    var addedSpins = 0
    var expandedColumn: Int? = nil
    var startsBonus = false
    var lock: SolarLockContract? = nil
    var coins: Int { pages.reduce(0) { $0 + $1.coins } * multiplier }
    var lastField: SolarReelField { pages.last!.field }
}

/// One immutable journey per spin. A token may occur at both ends of a strip;
/// occurrences, rather than logical token UUIDs, identify positions on that strip.
struct SolarReelOccurrence: Identifiable {
    let id: Int
    let token: SolarReelToken
}
struct SolarReelRibbon {
    let cells: [SolarReelOccurrence]
    let visibleRows: Int
    var landingOffset: Int { cells.count-visibleRows }
    var landing: [SolarReelToken] { cells.suffix(visibleRows).map(\.token) }
}
struct SolarReelJourney: Identifiable {
    let id = UUID()
    let source: SolarReelField
    let destination: SolarReelField
    let ribbons: [SolarReelRibbon]
    let fast: Bool
    func solarDuration(column: Int) -> TimeInterval { (fast ? 0.43 : 1.05)+Double(column)*(fast ? 0.045 : 0.09) }
    init<R: RandomNumberGenerator>(game: SolarCabinet,source: SolarReelField,destination: SolarReelField,fast: Bool,random: inout R) {
        precondition(source.columns == destination.columns && source.rows == destination.rows)
        self.source = source; self.destination = destination; self.fast = fast
        var engine = SolarProbabilityEngine(random:random)
        ribbons = (0..<game.width).map { column in
            let transit = (0..<(game.height*5+column*2)).map { _ in engine.solarDraw(game) }
            let tokens = source.solarColumn(column)+transit+destination.solarColumn(column)
            return SolarReelRibbon(cells:tokens.enumerated().map { SolarReelOccurrence(id:$0.offset,token:$0.element) },visibleRows:game.height)
        }
        random = engine.random
    }
}

/// Each unlocked position has its own physical strip and a fixed final cell.
struct SolarLockJourney: Identifiable {
    let id = UUID()
    let source: SolarLockContract
    let destination: SolarLockContract
    let ribbons: [Int:[SolarLockedMedal?]]
    let fast: Bool
    func solarDuration(index: Int) -> TimeInterval { (fast ? 0.48 : 1.05)+Double(index)*(fast ? 0.025 : 0.055) }
    init<R: RandomNumberGenerator>(source: SolarLockContract,destination: SolarLockContract,fast: Bool,random: inout R) {
        self.source = source; self.destination = destination; self.fast = fast
        let occupied = Set(source.medals.map(\.index))
        var engine = SolarProbabilityEngine(random:random)
        var strips: [Int:[SolarLockedMedal?]] = [:]
        for index in 0..<9 where !occupied.contains(index) {
            var strip: [SolarLockedMedal?] = [nil]
            for step in 0..<(12+index%3*2) {
                strip.append(step%3 == 1 ? nil : engine.solarMedal(stake:source.stake,index:index))
            }
            strip.append(destination.medals.first { $0.index == index })
            strips[index] = strip
        }
        ribbons = strips; random = engine.random
    }
}
