import SwiftUI
import Combine

@MainActor final class AurumTurnConductor: ObservableObject {
    @Published var board: [AurumTile]
    @Published var cue: AurumMotionCue?
    @Published var busy = false
    @Published var automatic = false
    @Published var lastReturn = 0
    @Published var boost = 1
    @Published var highlights: Set<Int> = []
    @Published var bigWin: Int?
    @Published var bonusTotal: Int?
    @Published var rain: UUID?
    let room: AurumRoom
    private let club: AurumClubAccount
    private var task: Task<Void,Never>?
    private var generation = UUID()
    init(room: AurumRoom,club: AurumClubAccount) { self.room = room;self.club = club;board = club.solarSavedBoard(room);lastReturn = club.state.history.first(where:{$0.room==room})?.returned ?? 0 }
    func solarStart(calm: Bool) {
        guard !busy,!club.paused else { return }
        if let feature = club.solarFeature(room) { guard feature.entered,feature.left>0 else { return };automatic = true }
        busy = true
        let session = UUID();generation = session
        task = Task { [weak self] in
            guard let self = self else { return }
            repeat {
                guard !Task.isCancelled,self.generation==session,let turn = self.club.solarReserveReel(self.room) else { break }
                self.highlights = [];self.lastReturn = 0;self.boost = 1
                let duration = calm ? 0.35:self.club.state.turbo ? 0.75:1.85
                self.cue = AurumMotionCue(room:self.room,from:self.board,to:turn.entrance,removed:[],duration:duration,seed:turn.seed)
                AurumSoundstage.shared.solarEffect("reel")
                do {
                    try await Task.sleep(nanoseconds:UInt64((duration+0.1)*1_000_000_000));guard self.generation==session else { return }
                    self.board = turn.entrance;self.cue = nil;AurumSoundstage.shared.solarEffect("stop")
                    for fall in turn.falls {
                        let span = calm ? 0.25:0.85
                        self.boost = fall.boost;self.highlights = Set(fall.removed)
                        self.cue = AurumMotionCue(room:self.room,from:fall.before,to:fall.after,removed:Set(fall.removed),duration:span,seed:turn.seed)
                        AurumSoundstage.shared.solarEffect("drop")
                        try await Task.sleep(nanoseconds:UInt64((span+0.12)*1_000_000_000));guard self.generation==session else { return }
                        self.board = fall.after;self.cue = nil;self.highlights = [];self.lastReturn += fall.amount
                    }
                    self.board = turn.final;self.cue = nil;self.highlights = Set(turn.lines.flatMap(\.indices));self.lastReturn = turn.payout
                    _ = self.club.solarFinishReel(turn.id)
                    if turn.payout>0 { AurumSoundstage.shared.solarEffect(turn.payout>=turn.stake*5 ? "win":"tap") }
                    if let feature = self.club.solarFeature(self.room) {
                        if !feature.entered { self.automatic = false;AurumSoundstage.shared.solarEffect("bonus");break }
                        if feature.left==0 { self.automatic = false;self.bonusTotal = feature.total;if !calm { self.rain = UUID() };break }
                    } else if turn.payout>=turn.stake*5 { self.bigWin = turn.payout;if !calm { self.rain = UUID() };self.automatic = false;break }
                    if self.automatic { try await Task.sleep(nanoseconds:400_000_000) }
                } catch { break }
            } while self.automatic && !Task.isCancelled
            if self.generation==session { self.automatic = false;self.busy = false;self.task = nil }
        }
    }
    func solarPause() { automatic = false }
    func solarSuspend() {
        generation = UUID();task?.cancel();task = nil;automatic = false
        club.solarRecover();board = club.solarSavedBoard(room);cue = nil;busy = false
        lastReturn = club.state.history.first(where:{$0.room==room})?.returned ?? lastReturn
        if let feature = club.solarFeature(room),feature.entered,feature.left==0 { bonusTotal = feature.total }
    }
    func solarCloseSummary() { bonusTotal = nil;rain = nil;club.solarCloseFeature(room) }
    deinit { task?.cancel() }
}
