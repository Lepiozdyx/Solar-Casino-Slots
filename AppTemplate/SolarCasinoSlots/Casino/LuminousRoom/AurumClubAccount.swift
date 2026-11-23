import Foundation
import Combine

struct AurumRecord: Codable,Identifiable {
    let id: UUID
    let room: AurumRoom
    let date: Date
    let wager: Int
    let returned: Int
    let free: Bool
    let note: String
}
struct AurumAccount: Codable {
    var stake = 50
    var music = true
    var sounds = true
    var haptics = true
    var gentle = false
    var turbo = false
    var boards: [String:[AurumTile]] = [:]
    var features: [String:AurumFeature] = [:]
    var pendingReel: AurumReelResult?
    var pendingWheel: AurumRouletteRound?
    var lastWheel: AurumRouletteRound?
    var hand: AurumHand?
    var history: [AurumRecord] = []
    var spins = 0
    var hands = 0
    var wheels = 0
    var biggest = 0
}
@MainActor final class AurumClubAccount: ObservableObject {
    @Published private(set) var state: AurumAccount
    let bank: SolarCasinoBank
    private var observation: AnyCancellable?
    static let stakes = [20,50,100,250,500]
    var locale: Locale { Locale.current }
    var balance: Int { bank.balance }
    var paused: Bool { !bank.canPlay }
    var pending: Bool { state.pendingReel != nil || state.pendingWheel != nil || state.hand.map{!$0.finished} == true }
    func solarNumber(_ value: Int) -> String { value.formatted(.number.locale(locale)) }
    init(bank: SolarCasinoBank) {
        self.bank = bank; state = bank.archive.slottop
        observation = bank.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
        solarRecover()
    }
    private func solarSave() { bank.solarCommit(slottop: state) }
    private func solarCredit(_ value: Int) { bank.balance = min(1_000_000_000_000,bank.balance+max(0,value)) }
    func solarPreferences(sound: Bool, haptics: Bool) { state.music = sound; state.sounds = sound; state.haptics = haptics }
    func solarToggle(_ key: String) { if key == "turbo" { state.turbo.toggle();solarSave() } }
    func solarSetStake(_ value: Int) { guard Self.stakes.contains(value),!pending else { return };state.stake = value;solarSave() }
    private func solarRecord(_ result: AurumRecord) { state.history.insert(result,at:0);state.history = Array(state.history.prefix(30)) }
    func solarSavedBoard(_ room: AurumRoom) -> [AurumTile] { state.boards[room.rawValue] ?? AurumReelArithmetic.solarBoard(room,seed:UInt64(room.rawValue.utf8.reduce(0){$0+Int($1)})) }
    func solarFeature(_ room: AurumRoom) -> AurumFeature? { state.features[room.rawValue] }
    @discardableResult func solarBuyFeature(_ room: AurumRoom) -> Bool {
        guard !paused,!pending,room.isSlot,state.features[room.rawValue]==nil else { return false }
        let amount = state.stake*room.featurePrice
        guard bank.balance>=amount else { return false }
        bank.balance -= amount
        state.features[room.rawValue] = .init(room:room,stake:state.stake,left:room.freeTurns);solarSave();return true
    }
    func solarEnterFeature(_ room: AurumRoom) { guard !paused,var feature = state.features[room.rawValue] else { return };feature.entered = true;state.features[room.rawValue] = feature;solarSave() }
    func solarCloseFeature(_ room: AurumRoom) { guard !pending,let feature = state.features[room.rawValue],feature.left==0 else { return };state.features.removeValue(forKey:room.rawValue);solarSave() }
    func solarReserveReel(_ room: AurumRoom,seed: UInt64 = .random(in:1...UInt64.max)) -> AurumReelResult? {
        guard !paused,!pending,room.isSlot else { return nil }
        var feature = state.features[room.rawValue]
        if let value = feature { guard value.entered,value.left>0 else { return nil } }
        let stake = feature?.stake ?? state.stake
        guard feature != nil || bank.balance>=stake else { return nil }
        if feature == nil { bank.balance -= stake }
        let result = AurumReelArithmetic.solarRoll(room,stake:stake,feature:feature,seed:seed)
        if feature != nil { feature!.left -= 1;feature!.played += 1;if room == .orbit { feature!.orbit += 1 };state.features[room.rawValue] = feature }
        state.pendingReel = result;solarSave();return result
    }
    @discardableResult func solarFinishReel(_ id: UUID) -> Bool {
        guard let result = state.pendingReel,result.id==id else { return false }
        solarCredit(result.payout);state.biggest = max(state.biggest,result.payout);state.spins += 1
        state.boards[result.room.rawValue] = result.final
        if var feature = state.features[result.room.rawValue] { feature.total += result.payout;feature.left = min(40,feature.left+result.awarded);state.features[result.room.rawValue] = feature }
        else if result.awarded>0 { state.features[result.room.rawValue] = .init(room:result.room,stake:result.stake,left:result.awarded) }
        state.pendingReel = nil
        solarRecord(.init(id:result.id,room:result.room,date:Date(),wager:result.free ? 0:result.stake,returned:result.payout,free:result.free,note:result.room == .prism ? "clusters":"lines"));solarSave();return true
    }
    func solarReserveRoulette(_ picks: [AurumRoulettePick],seed: UInt64 = .random(in:1...UInt64.max)) -> AurumRouletteRound? {
        guard !paused,!pending,!picks.isEmpty,picks.count<=12,Set(picks.map(\.id)).count==picks.count,picks.allSatisfy({$0.stake>0 && $0.stake<=5000 && ($0.area == .number ? (0...36).contains($0.number):$0.number==0)}) else { return nil }
        let wager = picks.reduce(0){$0+$1.stake};guard bank.balance>=wager else { return nil }
        var dice = AurumDice(seed);let round = AurumRouletteRound(id:UUID(),number:dice.solarNext(37),picks:picks)
        bank.balance -= wager;state.pendingWheel = round;solarSave();return round
    }
    @discardableResult func solarFinishRoulette(_ id: UUID) -> Bool {
        guard let round = state.pendingWheel,round.id==id else { return false }
        solarCredit(round.payout);state.wheels += 1;state.biggest = max(state.biggest,round.payout);state.lastWheel = round;state.pendingWheel = nil
        solarRecord(.init(id:round.id,room:.roulette,date:Date(),wager:round.wager,returned:round.payout,free:false,note:String(round.number)));solarSave();return true
    }
    @discardableResult func solarDeal(seed: UInt64 = .random(in:1...UInt64.max)) -> Bool {
        guard !paused,!pending,bank.balance>=state.stake else { return false }
        bank.balance -= state.stake;state.hand = AurumTwentyOne.solarDeal(stake:state.stake,seed:seed);solarSettleHand();solarSave();return true
    }
    func solarPlayHand(_ action: String) {
        guard !paused,let hand = state.hand,!hand.finished else { return }
        if action=="double" { guard hand.player.count==2,bank.balance>=hand.baseStake else { return };bank.balance -= hand.baseStake;state.hand = AurumTwentyOne.solarDouble(hand) }
        else if action=="hit" { state.hand = AurumTwentyOne.solarHit(hand) }
        else if action=="stand" { state.hand = AurumTwentyOne.solarStand(hand) }
        else { return }
        solarSettleHand();solarSave()
    }
    private func solarSettleHand() {
        guard let hand = state.hand,hand.finished,!hand.settled else { return }
        state.hand!.settled = true
        solarCredit(hand.payout);state.hands += 1;state.biggest = max(state.biggest,hand.payout)
        solarRecord(.init(id:hand.id,room:.blackjack,date:hand.date,wager:hand.stake,returned:hand.payout,free:false,note:hand.message))
    }
    func solarRecover() { if let id = state.pendingReel?.id { _ = solarFinishReel(id) };if let id = state.pendingWheel?.id { _ = solarFinishRoulette(id) };solarSettleHand();solarSave() }
}
