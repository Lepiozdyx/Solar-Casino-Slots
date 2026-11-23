import Foundation
import Combine

@MainActor final class SolarCabinetSession: ObservableObject {
    enum SolarMotion: Equatable { case quiet, rolling, shaking, bursting, falling }
    enum SolarCurtain: Equatable { case purchase, introduction, summary(Int), bigWin(Int), lockRules }
    let game: SolarCabinet
    let ledger: SolarClubLedger
    @Published var board: SolarReelField
    @Published private(set) var journey: SolarReelJourney?
    @Published var motion = SolarMotion.quiet
    @Published var highlights: Set<Int> = []
    @Published var rockets: [SolarRocketWild] = []
    @Published var lastWin = 0
    @Published var spinWin = 0
    @Published var amplifier = 1
    @Published var extraSpins = 0
    @Published var stakeIndex = 1
    @Published var turbo = false
    @Published var curtain: SolarCurtain? = nil
    @Published var lockBusy = false
    @Published private(set) var lockJourney: SolarLockJourney?
    private var choreographer: Task<Void,Never>?
    private var landingWaiter: CheckedContinuation<Bool,Never>?
    private var landedID: UUID?
    private var pending: SolarResolvedSpin?
    private var inForeground = true
    var stakes: [Int] { SolarProbabilityEngine<SystemRandomNumberGenerator>.stakes }
    var stake: Int { ledger.member.bonus?.stake ?? ledger.member.lock?.stake ?? stakes[stakeIndex] }
    var occupied: Bool { motion != .quiet || curtain != nil || lockBusy }
    var freeMode: Bool { ledger.member.bonus?.cabinet == game }
    var lockPresentation: SolarLockContract? { lockJourney?.source ?? ledger.member.lock }
    init(game: SolarCabinet, ledger: SolarClubLedger) {
        self.game = game; self.ledger = ledger
        var math = SolarProbabilityEngine(random:SystemRandomNumberGenerator())
        board = math.solarFresh(game)
        rockets = ledger.member.bonus?.rockets ?? []
    }
    func solarActivate(_ foreground: Bool) {
        inForeground = foreground
        if !foreground {
            landingWaiter?.resume(returning:false); landingWaiter = nil
            choreographer?.cancel(); choreographer = nil; lockBusy = false; lockJourney = nil; journey = nil
            if let settled = pending { board = settled.lastField; rockets = settled.nextRockets; lastWin = settled.coins; spinWin = settled.coins; pending = nil }
            motion = .quiet; highlights = []; return
        }
        if motion != .quiet { motion = .quiet; highlights = [] }
        if let contract = ledger.member.bonus, contract.cabinet == game {
            if contract.left == 0 { curtain = .summary(contract.winnings) }
            else if !contract.started { curtain = .introduction }
            else { solarSchedule() }
        }
    }
    func solarStepStake(_ direction: Int) {
        guard !occupied, !freeMode, ledger.member.lock == nil else { return }
        stakeIndex = min(stakes.count-1,max(0,stakeIndex+direction)); SolarSoundStage.shared.solarPlay("touch")
    }
    func solarAskForBonus() { guard !occupied, !freeMode, ledger.member.lock == nil else { return }; curtain = .purchase }
    func solarBuy() {
        guard ledger.solarPurchase(game,stake:stake) else { curtain = nil; return }
        SolarSoundStage.shared.solarPlay("entry",strong:true)
        curtain = game == .forge ? .lockRules : .introduction
    }
    func solarEnter() {
        if ledger.member.lock != nil { curtain = nil; return }
        ledger.solarResumeBonus(); curtain = nil; SolarSoundStage.shared.solarPlay("entry",strong:true); solarSchedule()
    }
    func solarDismissCelebration() {
        if case .summary = curtain { ledger.solarCloseBonus() }
        curtain = nil; solarSchedule()
    }
    private func solarPause(_ seconds: Double) async -> Bool {
        do { try await Task.sleep(nanoseconds:UInt64(seconds*1_000_000_000)); return !Task.isCancelled } catch { return false }
    }
    private func solarSchedule() {
        guard inForeground, motion == .quiet, curtain == nil, let contract = ledger.member.bonus, contract.cabinet == game, contract.started, contract.left > 0 else { return }
        choreographer?.cancel()
        choreographer = Task { [weak self] in
            guard let self = self, await self.solarPause(self.turbo ? 0.28 : 0.72) else { return }
            self.solarSpin()
        }
    }
    func solarSpin() {
        guard inForeground, motion == .quiet, curtain == nil, ledger.member.lock == nil else { return }
        let travellingRockets = Set(rockets.map(\.id))
        guard let outcome = ledger.solarPlay(game,stake:stake) else { return }
        choreographer?.cancel()
        pending = outcome
        motion = .rolling; highlights = []; amplifier = 1; extraSpins = 0; spinWin = 0
        if game == .carnival { rockets = outcome.nextRockets.filter { travellingRockets.contains($0.id) } }
        var random = SystemRandomNumberGenerator()
        let trip = SolarReelJourney(game:game,source:board,destination:outcome.pages[0].field,fast:turbo,random:&random)
        journey = trip; landedID = nil
        SolarSoundStage.shared.solarPlay("reel")
        let currentStake = stake
        choreographer = Task { [weak self] in
            guard let self = self else { return }
            guard await self.solarWaitForLanding(trip.id), !Task.isCancelled else { return }
            self.board = trip.destination
            guard await self.solarPause(0.12) else { return }
            self.rockets = outcome.nextRockets
            SolarSoundStage.shared.solarPlay("land")
            for (index,page) in outcome.pages.enumerated() {
                if index > 0 {
                    self.motion = .falling; self.board = page.field
                    guard await self.solarPause(0.35) else { return }
                }
                if !page.pays.isEmpty {
                    self.highlights = page.cleared; self.motion = .shaking
                    SolarSoundStage.shared.solarPlay("spark")
                    guard await self.solarPause(self.turbo ? 0.2 : 0.48) else { return }
                    self.spinWin += page.coins
                    if self.game == .nougat, index < outcome.pages.count-1 {
                        self.motion = .bursting
                        guard await self.solarPause(0.24) else { return }
                    }
                }
            }
            self.amplifier = outcome.multiplier
            self.extraSpins = outcome.addedSpins
            if outcome.multiplier > 1 && outcome.coins > 0 { SolarSoundStage.shared.solarPlay("charge",strong:true); guard await self.solarPause(0.65) else { return } }
            self.lastWin = outcome.coins; self.spinWin = outcome.coins; self.motion = .quiet; self.pending = nil; self.journey = nil
            if outcome.coins > 0 { SolarSoundStage.shared.solarPlay("win",strong:outcome.coins >= currentStake*10) }
            if let bonus = self.ledger.member.bonus, !bonus.started { self.curtain = .introduction }
            else if let bonus = self.ledger.member.bonus, bonus.left == 0 { self.curtain = .summary(bonus.winnings) }
            else if outcome.lock != nil { self.curtain = .lockRules }
            else if outcome.coins >= currentStake * 12 { self.curtain = .bigWin(outcome.coins) }
            if case .bigWin = self.curtain, self.freeMode {
                guard await self.solarPause(2.5) else { return }; self.curtain = nil
            }
            self.solarSchedule()
        }
    }
    private func solarWaitForLanding(_ id: UUID) async -> Bool {
        guard !Task.isCancelled, inForeground, journey?.id == id else { return false }
        if landedID == id { return true }
        return await withCheckedContinuation { landingWaiter = $0 }
    }
    func solarRendererLanded(_ id: UUID) {
        guard let trip = journey, trip.id == id, motion == .rolling else { return }
        landedID = id; board = trip.destination
        landingWaiter?.resume(returning:true); landingWaiter = nil
    }
    func solarRespin() {
        guard inForeground, curtain == nil, !lockBusy, let source = ledger.member.lock, !source.complete,
              let destination = ledger.solarTurnLock() else { return }
        var random = SystemRandomNumberGenerator()
        lockJourney = SolarLockJourney(source:source,destination:destination,fast:turbo,random:&random)
        lockBusy = true; SolarSoundStage.shared.solarPlay("reel")
    }
    func solarLockRendererLanded(_ id: UUID) {
        guard lockBusy, lockJourney?.id == id else { return }
        lockJourney = nil; lockBusy = false; SolarSoundStage.shared.solarPlay("lock",strong:true)
    }
    func solarCollectLock() {
        guard inForeground, curtain == nil, !lockBusy, ledger.bank.canPlay,
              ledger.member.lock?.complete == true else { return }
        let amount = ledger.solarCloseLock(); lastWin = amount; spinWin = amount; curtain = .bigWin(amount)
        SolarSoundStage.shared.solarPlay("win",strong:true)
    }
    deinit { choreographer?.cancel() }
}
