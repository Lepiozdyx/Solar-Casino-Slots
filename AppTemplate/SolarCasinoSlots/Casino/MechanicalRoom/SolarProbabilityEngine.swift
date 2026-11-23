import Foundation

/// Independent weighted draws. Outcomes never depend on wallet, purchases or player history.
struct SolarProbabilityEngine<R: RandomNumberGenerator> {
    var random: R
    static var stakes: [Int] { [10, 25, 50, 100, 250] }
    static var paths: [[Int]] {
        [[0,0,0,0,0],[1,1,1,1,1],[2,2,2,2,2],[0,1,2,1,0],[2,1,0,1,2],
         [0,0,1,2,2],[2,2,1,0,0],[1,0,0,0,1],[1,2,2,2,1],[0,1,1,1,0],
         [2,1,1,1,2],[0,1,0,1,0],[2,1,2,1,2],[1,0,1,0,1],[1,2,1,2,1]]
    }
    mutating func solarChoose(_ chances: [Int]) -> Int {
        precondition(chances.contains { $0 > 0 } && chances.allSatisfy { $0 >= 0 })
        var ticket = Int.random(in: 0..<chances.reduce(0,+), using: &random)
        for (i, chance) in chances.enumerated() { ticket -= chance; if ticket < 0 { return i } }
        return chances.count - 1
    }
    mutating func solarDraw(_ game: SolarCabinet, bonus: Bool = false) -> SolarReelToken {
        let chances: [Int]
        switch game {
        case .forge: chances = [8,11,17,20,22,23,0,0,0]
        case .nougat: chances = bonus ? [14,15,17,18,20,22,25,3,5] : [14,15,17,18,20,22,25,3,0]
        case .temple: chances = [12,15,18,20,23,26,4,4,0]
        case .carnival: chances = bonus ? [14,16,19,22,25,28,3,4,0] : [14,16,19,22,25,28,3,4,0]
        }
        let value = solarChoose(chances)
        return SolarReelToken(value, factor: value == 8 ? [2,3,5,8,12,25,50][solarChoose([42,25,18,8,4,2,1])] : 0)
    }
    mutating func solarFresh(_ game: SolarCabinet, bonus: Bool = false) -> SolarReelField {
        SolarReelField(cabinet: game, tokens: (0..<(game.width * game.height)).map { _ in solarDraw(game, bonus: bonus) })
    }
    func solarLineAwards(_ board: SolarReelField, game: SolarCabinet, stake: Int, rockets: [SolarRocketWild] = []) -> [SolarPayEvent] {
        let count = game == .forge ? 5 : 15
        let value = game == .forge ? [90,45,26,18,14,10] : [60,42,30,22,16,12]
        var substituted: [Int:Int] = [:]
        for rocket in rockets { substituted[rocket.row * board.columns + rocket.column] = rocket.boost }
        return Self.paths.prefix(count).compactMap { path in
            var best: SolarPayEvent?
            for candidate in 0..<6 {
                var cells = Set<Int>(); var boost = 0
                for c in 0..<board.columns {
                    let p = path[c] * board.columns + c
                    let glyph = board.tokens[p].face
                    if let multiplier = substituted[p] { boost += multiplier; cells.insert(p) }
                    else if glyph == candidate || (glyph == 6 && game != .forge) { cells.insert(p) }
                    else { break }
                }
                guard cells.count >= 3 else { continue }
                let length = cells.count == 5 ? 7 : cells.count == 4 ? 3 : 1
                let win = SolarPayEvent(positions: cells, coins: max(1, stake * value[candidate] * length / count) * max(1,boost))
                if win.coins > (best?.coins ?? 0) { best = win }
            }
            return best
        }
    }
    func solarAnywhereAwards(_ field: SolarReelField, stake: Int) -> [SolarPayEvent] {
        (0..<7).compactMap { face in
            let cells = Set(field.tokens.indices.filter { field.tokens[$0].face == face })
            guard cells.count >= 8 else { return nil }
            let band = cells.count >= 12 ? 4 : cells.count >= 10 ? 2 : 1
            return SolarPayEvent(positions: cells, coins: max(1,stake * [480,360,260,190,140,100,65][face] * band / 100))
        }
    }
    mutating func solarCollapse(_ page: SolarCascadePage, game: SolarCabinet, bonus: Bool) -> SolarReelField {
        var next = page.field
        for column in 0..<next.columns {
            let survivors = (0..<next.rows).filter { !page.cleared.contains($0 * next.columns + column) }.map { page.field[column,$0] }
            let replacements = (0..<(next.rows-survivors.count)).map { _ in solarDraw(game,bonus:bonus) }
            for (row,token) in (replacements + survivors).enumerated() { next[column,row] = token }
        }
        return next
    }
    mutating func solarResolve(_ game: SolarCabinet, stake: Int, contract: SolarBonusContract? = nil, supplied: SolarReelField? = nil) -> SolarResolvedSpin {
        precondition(stake > 0)
        var field = supplied ?? solarFresh(game,bonus:contract != nil)
        precondition(field.columns == game.width && field.rows == game.height)
        var result = SolarResolvedSpin(pages: [])
        var scatters = field.tokens.filter { $0.face == 7 }.count
        if game == .nougat {
            for depth in 0..<12 {
                scatters = max(scatters,field.tokens.filter { $0.face == 7 }.count)
                let page = SolarCascadePage(field:field,pays:solarAnywhereAwards(field,stake:stake))
                result.pages.append(page)
                if page.pays.isEmpty || depth == 11 { break }
                field = solarCollapse(page,game:game,bonus:contract != nil)
            }
            if contract != nil {
                result.multiplier = max(1,field.tokens.filter { $0.face == 8 }.reduce(0) { $0 + $1.factor })
                if scatters >= 3 { result.addedSpins = 3 }
            }
        } else {
            if game == .temple, contract != nil {
                let reel = Int.random(in:0..<5,using:&random)
                result.expandedColumn = reel
                // The displayed landing board expands only after stopping; both stages are retained.
                result.pages.append(SolarCascadePage(field:field,pays:[]))
                for row in 0..<3 { field[reel,row] = SolarReelToken(6) }
            }
            if game == .carnival {
                var rockets = contract?.rockets ?? []
                for i in rockets.indices { rockets[i].column = (rockets[i].column + 4) % 5 }
                for position in field.tokens.indices where field.tokens[position].face == 6 {
                    let c = position % 5, r = position / 5
                    if !rockets.contains(where: { $0.column == c && $0.row == r }) {
                        if rockets.count < 5 {
                            let multiplier = [2,3,5][solarChoose([65,28,7])]
                            rockets.append(SolarRocketWild(column:c,row:r,boost:multiplier))
                            if contract != nil { result.addedSpins += Int.random(in:1...3,using:&random) }
                        }
                    }
                }
                result.nextRockets = rockets
                // Resolve scatter visibility without counting symbols covered by moving rockets.
                let occupied = Set(rockets.map { $0.row * 5 + $0.column })
                scatters = field.tokens.indices.filter { field.tokens[$0].face == 7 && !occupied.contains($0) }.count
            }
            result.pages.append(SolarCascadePage(field:field,pays:solarLineAwards(field,game:game,stake:stake,rockets:result.nextRockets)))
            if game == .temple, contract != nil, scatters >= 3 { result.addedSpins = 4 }
        }
        if contract == nil {
            result.startsBonus = scatters >= (game == .nougat ? 4 : 3) && game != .forge
            if game == .forge {
                let positions = field.tokens.indices.filter { field.tokens[$0].face == 0 }
                if positions.count >= 3 { result.lock = solarOpenLock(stake:stake,positions:positions) }
            }
        } else if let contract = contract { result.addedSpins = min(result.addedSpins,max(0,40-contract.awarded)) }
        return result
    }
    mutating func solarOpenBonus(_ game: SolarCabinet, stake: Int) -> SolarBonusContract {
        let awards = game == .carnival ? (0..<3).map { _ in [2,3,4,5][solarChoose([25,45,25,5])] } : []
        let spins = game == .nougat ? 10 : game == .temple ? 8 : awards.reduce(0,+)
        return SolarBonusContract(cabinet:game,stake:stake,awarded:spins,left:spins,reveals:awards)
    }
    mutating func solarMedal(stake: Int, index: Int) -> SolarLockedMedal {
        let kind = solarChoose([650,200,100,37,10,3])
        let factors = [1, 2, 5, SolarLockJackpot.mini.factor, SolarLockJackpot.minor.factor, SolarLockJackpot.major.factor]
        return SolarLockedMedal(index:index,value:stake * factors[kind],tier:kind >= 3 ? kind-3 : nil)
    }
    mutating func solarOpenLock(stake: Int, positions: [Int] = [0,4,8]) -> SolarLockContract {
        SolarLockContract(stake:stake,medals:positions.map { solarMedal(stake:stake,index:$0) })
    }
    mutating func solarRespin(_ contract: SolarLockContract) -> SolarLockContract {
        guard !contract.complete else { return contract }
        var next = contract; let taken = Set(contract.medals.map(\.index))
        for index in 0..<9 where !taken.contains(index) {
            if Int.random(in:0..<100,using:&random) < 11 { next.medals.append(solarMedal(stake:contract.stake,index:index)) }
        }
        next.attempts = next.medals.count > contract.medals.count ? 3 : max(0,contract.attempts-1)
        return next
    }
}
