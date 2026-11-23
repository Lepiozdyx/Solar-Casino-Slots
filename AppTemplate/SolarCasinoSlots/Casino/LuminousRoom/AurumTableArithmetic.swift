import Foundation

struct AurumCard: Codable,Identifiable,Equatable {
    let id: Int
    var rank: Int { id%13+1 }
    var suit: Int { id/13 }
    var label: String { rank==1 ? "A":rank==11 ? "J":rank==12 ? "Q":rank==13 ? "K":String(rank) }
    var pip: String { ["♠","♥","♣","♦"][suit] }
    var red: Bool { suit==1 || suit==3 }
}
struct AurumHand: Codable,Identifiable {
    let id: UUID
    let date: Date
    let baseStake: Int
    var stake: Int
    let deck: [Int]
    var cursor = 4
    var player: [AurumCard]
    var dealer: [AurumCard]
    var finished = false
    var settled = false
    var payout = 0
    var doubled = false
    var message = ""
    var actions: [String] = []
}
enum AurumTwentyOne {
    static func solarTotal(_ cards: [AurumCard]) -> (points:Int,soft:Bool) {
        var points = cards.reduce(0){$0+min(10,$1.rank)},aces = cards.filter{$0.rank==1}.count
        var soft = false
        while aces>0 && points+10<=21 { points += 10;aces -= 1;soft = true }
        return (points,soft)
    }
    static func solarDeal(stake: Int,seed: UInt64) -> AurumHand {
        var dice = AurumDice(seed),deck = Array(0..<52);dice.solarShuffle(&deck)
        var hand = AurumHand(id:UUID(),date:Date(),baseStake:stake,stake:stake,deck:deck,player:[.init(id:deck[0]),.init(id:deck[2])],dealer:[.init(id:deck[1]),.init(id:deck[3])])
        let p = solarTotal(hand.player).points,d = solarTotal(hand.dealer).points
        if p==21 || d==21 {
            hand.finished = true;hand.message = p==21 && d==21 ? "push":p==21 ? "natural":"dealer-natural"
            hand.payout = p==21 && d==21 ? stake:p==21 ? stake*5/2:0
        };return hand
    }
    static func solarHit(_ source: AurumHand) -> AurumHand {
        guard !source.finished,source.cursor<source.deck.count else { return source }
        var hand = source;hand.player.append(.init(id:hand.deck[hand.cursor]));hand.cursor += 1;hand.actions.append("hit")
        let points = solarTotal(hand.player).points
        if points>21 { hand.finished = true;hand.message = "bust";hand.payout = 0 }
        if points==21 { hand = solarStand(hand) }
        return hand
    }
    static func solarStand(_ source: AurumHand) -> AurumHand {
        guard !source.finished else { return source }
        var hand = source;hand.actions.append("stand")
        while solarTotal(hand.dealer).points<17 && hand.cursor<hand.deck.count { hand.dealer.append(.init(id:hand.deck[hand.cursor]));hand.cursor += 1 }
        let player = solarTotal(hand.player).points,dealer = solarTotal(hand.dealer).points
        hand.finished = true
        if dealer>21 || player>dealer { hand.payout = hand.stake*2;hand.message = dealer>21 ? "dealer-bust":"win" }
        else if player==dealer { hand.payout = hand.stake;hand.message = "push" }
        else { hand.payout = 0;hand.message = "dealer-win" }
        return hand
    }
    static func solarDouble(_ source: AurumHand) -> AurumHand {
        guard !source.finished,source.player.count==2 else { return source }
        var hand = source;hand.stake *= 2;hand.doubled = true;hand.actions.append("double")
        hand.player.append(.init(id:hand.deck[hand.cursor]));hand.cursor += 1
        if solarTotal(hand.player).points>21 { hand.finished = true;hand.message = "bust";hand.payout = 0;return hand }
        return solarStand(hand)
    }
    static func solarResultKey(_ message: String) -> String {
        switch message {
        case "natural", "dealer-natural", "bust", "dealer-bust", "win", "push":
            "table.blackjack.result." + message
        default:
            "table.blackjack.result.dealer-win"
        }
    }
}
enum AurumRouletteArea: String,Codable,CaseIterable {
    case red,black,odd,even,low,high,dozen1,dozen2,dozen3,column1,column2,column3,number
    var returnFactor: Int { self == .number ? 36:[.dozen1,.dozen2,.dozen3,.column1,.column2,.column3].contains(self) ? 3:2 }
}
struct AurumRoulettePick: Codable,Identifiable,Equatable {
    let area: AurumRouletteArea
    let number: Int
    var stake: Int
    var id: String { area.rawValue+"_"+String(number) }
    func solarWins(_ result: Int) -> Bool {
        guard (0...36).contains(result) else { return false }
        if area == .number { return result==number }
        if result==0 { return false }
        switch area {
        case .red:return AurumRoulette.reds.contains(result)
        case .black:return !AurumRoulette.reds.contains(result)
        case .odd:return result%2==1
        case .even:return result%2==0
        case .low:return result<=18
        case .high:return result>=19
        case .dozen1:return result<=12
        case .dozen2:return result>=13 && result<=24
        case .dozen3:return result>=25
        case .column1:return result%3==1
        case .column2:return result%3==2
        case .column3:return result%3==0
        case .number:return result==number
        }
    }
}
struct AurumRouletteRound: Codable,Identifiable {
    let id: UUID
    let number: Int
    let picks: [AurumRoulettePick]
    var wager: Int { picks.reduce(0){$0+$1.stake} }
    var payout: Int { picks.filter{$0.solarWins(number)}.reduce(0){$0+$1.stake*$1.area.returnFactor} }
}
enum AurumRoulette {
    static let wheel = [0,32,15,19,4,21,2,25,17,34,6,27,13,36,11,30,8,23,10,5,24,16,33,1,20,14,31,9,22,18,29,7,28,12,35,3,26]
    static let reds: Set<Int> = [1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36]
    static func solarTarget(_ number: Int,after angle: Double) -> Double {
        let index = wheel.firstIndex(of:number) ?? 0,position = -(Double(index)+0.5)*360/37
        let current = angle.truncatingRemainder(dividingBy:360)
        var delta = (position-current).truncatingRemainder(dividingBy:360)
        if delta<0 { delta += 360 };return angle+5*360+delta
    }
}
