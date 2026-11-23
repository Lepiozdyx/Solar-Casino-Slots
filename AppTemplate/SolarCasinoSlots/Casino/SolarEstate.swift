import Foundation

enum SolarProperty: String, Codable, CaseIterable {
    case casino, bar, cashier, coatCheck, lounge, restaurant, bingo, baccarat
    case craps, slots, blackjack, roulette, poker, concert, hotel, vip

    var income: Int {
        switch self {
        case .casino, .slots: 5_000
        case .bar: 3_000
        case .cashier: 3_250
        case .coatCheck: 3_500
        case .lounge: 3_750
        case .restaurant: 4_000
        case .bingo: 4_250
        case .baccarat: 4_500
        case .craps: 4_750
        case .blackjack: 5_250
        case .roulette: 5_500
        case .poker: 5_750
        case .concert: 6_000
        case .hotel: 6_250
        case .vip: 6_500
        }
    }

    var symbol: String {
        switch self {
        case .casino: "building.columns.fill"
        case .bar: "wineglass.fill"
        case .cashier: "coins.fill"
        case .coatCheck: "hanger"
        case .lounge: "chair.lounge.fill"
        case .restaurant: "fork.knife"
        case .bingo: "circle.grid.cross.fill"
        case .baccarat: "suit.diamond.fill"
        case .craps: "dice.fill"
        case .slots: "rectangle.split.3x1.fill"
        case .blackjack: "suit.club.fill"
        case .roulette: "circle.dotted.circle.fill"
        case .poker: "suit.spade.fill"
        case .concert: "music.mic"
        case .hotel: "building.2.fill"
        case .vip: "crown.fill"
        }
    }
}

struct SolarEstate: Codable, Equatable {
    static let casinoIndex = 5
    private static let interval: TimeInterval = 86_400

    struct Lot: Codable, Equatable {
        let property: SolarProperty
        var nextPayout: Date?

        var isOpen: Bool { nextPayout != nil }

        func isReady(at now: Date) -> Bool {
            nextPayout.map { $0 <= now } ?? false
        }
    }

    private(set) var lots: [Lot]
    init(now: Date = .now, starterIncomeReady: Bool = false) {
        lots = SolarProperty.allCases.filter { $0 != .casino }.shuffled().map {
            Lot(property: $0)
        }
        let firstPayout = starterIncomeReady ? now : now.addingTimeInterval(Self.interval)
        lots.insert(Lot(property: .casino, nextPayout: firstPayout), at: Self.casinoIndex)
    }

    var isValid: Bool {
        lots.count == SolarProperty.allCases.count
            && Set(lots.map(\.property)) == Set(SolarProperty.allCases)
            && lots[Self.casinoIndex].property == .casino
            && lots[Self.casinoIndex].isOpen
            && lots.allSatisfy { $0.nextPayout?.timeIntervalSinceReferenceDate.isFinite ?? true }
    }

    var ownedCount: Int { lots.count(where: \.isOpen) }

    var dailyIncome: Int {
        lots.lazy.filter(\.isOpen).reduce(0) { $0 + $1.property.income }
    }

    var nextPayout: Date? { lots.lazy.compactMap(\.nextPayout).min() }

    var nextPrice: Int? {
        guard ownedCount < lots.count else { return nil }
        return 30_000 + (ownedCount - 1) * 10_000
    }

    mutating func open(_ index: Int, at now: Date) {
        lots[index].nextPayout = now.addingTimeInterval(Self.interval)
    }

    func readyIncome(at now: Date) -> Int {
        lots.reduce(0) { $0 + ($1.isReady(at: now) ? $1.property.income : 0) }
    }

    mutating func collect(_ index: Int?, at now: Date) -> Int {
        let candidates = index.map { [$0] } ?? Array(lots.indices)
        var income = 0
        for index in candidates where lots.indices.contains(index) && lots[index].isReady(at: now) {
            income += lots[index].property.income
            open(index, at: now)
        }
        return income
    }
}
