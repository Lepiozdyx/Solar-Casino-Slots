import Foundation
import Combine

struct SolarMemberArchive: Codable {
    var bonus: SolarBonusContract?
    var lock: SolarLockContract?
    var effects = true
    var soundtrack = true
    var vibration = true
}

@MainActor final class SolarClubLedger: ObservableObject {
    @Published private(set) var member: SolarMemberArchive
    let bank: SolarCasinoBank
    private var observation: AnyCancellable?
    private var random = SystemRandomNumberGenerator()
    var balance: Int { bank.balance }
    init(bank: SolarCasinoBank) {
        self.bank = bank; member = bank.archive.thunder
        observation = bank.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
    }
    private func solarPersist() { bank.solarCommit(thunder: member) }
    func solarPreferences(sound: Bool, haptics: Bool) {
        member.soundtrack = sound; member.effects = sound; member.vibration = haptics
    }
    func solarResumeBonus() { guard member.bonus != nil else { return }; member.bonus!.started = true; solarPersist() }
    func solarPurchase(_ game: SolarCabinet, stake: Int) -> Bool {
        let cost = stake * game.bonusPrice
        guard bank.canPlay, member.bonus == nil, member.lock == nil, bank.balance >= cost, stake > 0 else { return false }
        bank.balance -= cost
        var engine = SolarProbabilityEngine(random:random)
        if game == .forge { member.lock = engine.solarOpenLock(stake:stake) }
        else { member.bonus = engine.solarOpenBonus(game,stake:stake) }
        random = engine.random; solarPersist(); return true
    }
    /// A complete outcome is committed once, before its presentation, so interruptions cannot replay a payout.
    func solarPlay(_ game: SolarCabinet, stake: Int) -> SolarResolvedSpin? {

        guard bank.canPlay, stake > 0, member.lock == nil else { return nil }
        let active = member.bonus
        if let active = active { guard active.cabinet == game, active.started, active.left > 0 else { return nil } }
        else { guard bank.balance >= stake else { return nil }; bank.balance -= stake }
        let effective = active?.stake ?? stake
        var engine = SolarProbabilityEngine(random:random)
        let resolution = engine.solarResolve(game,stake:effective,contract:active)
        random = engine.random
        bank.balance += resolution.coins


        if var running = active {
            running.left = max(0,running.left-1) + resolution.addedSpins
            running.awarded += resolution.addedSpins; running.winnings += resolution.coins; running.rockets = resolution.nextRockets
            member.bonus = running
        } else if resolution.startsBonus {
            var opener = SolarProbabilityEngine(random:random)
            member.bonus = opener.solarOpenBonus(game,stake:effective); random = opener.random
        }
        if let lock = resolution.lock { member.lock = lock }
        solarPersist(); return resolution
    }
    func solarTurnLock() -> SolarLockContract? {
        guard bank.canPlay, let lock = member.lock, !lock.complete else { return member.lock }
        var engine = SolarProbabilityEngine(random:random); member.lock = engine.solarRespin(lock); random = engine.random; solarPersist(); return member.lock
    }
    @discardableResult func solarCloseLock() -> Int {
        guard let lock = member.lock, lock.complete else { return 0 }
        let win = lock.collected; bank.balance += win;
        member.lock = nil; solarPersist(); return win
    }
    func solarCloseBonus() { guard member.bonus?.left == 0 else { return }; member.bonus = nil; solarPersist() }
}
