import SwiftUI

struct SolarCabinetScreen: View {
    @ObservedObject var ledger: SolarClubLedger
    @StateObject private var player: SolarCabinetSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scene
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showRules = false
    @State private var wallet = false

    init(game: SolarCabinet, ledger: SolarClubLedger) {
        self.ledger = ledger
        _player = StateObject(wrappedValue: SolarCabinetSession(game: game, ledger: ledger))
    }

    private var game: SolarCabinet { player.game }
    private var lock: SolarLockContract? { player.motion == .quiet ? ledger.member.lock : nil }
    private var allowsPaidTurn: Bool { ledger.bank.canPlay && scene == .active && !player.occupied && !player.freeMode && lock == nil }
    private var allowsStake: Bool { !player.occupied && !player.freeMode && lock == nil }
    private var allowsRespin: Bool {
        ledger.bank.canPlay && scene == .active && !player.occupied && lock?.complete == false
    }

    var body: some View {
        GeometryReader { bounds in
            ZStack {
                SolarFoundryBackdrop(tint: SolarFoundry.solarTint(game))
                if game != .forge {
                    Image(uiImage: SolarArtworkDepot.shared.solarPicture(game.solarCoverName))
                        .resizable().scaledToFill()
                        .frame(width: bounds.size.width, height: bounds.size.height)
                        .clipped().opacity(0.12).allowsHitTesting(false).accessibilityHidden(true)
                }
                SolarSlotLayout(
                    aspect: lock != nil ? 1 : CGFloat(game.width) / CGFloat(game.height),
                    rim: 20,
                    header: {
                        SolarSlotBar(locked: player.occupied, back: { dismiss() }, rules: { showRules = true }) {
                            SolarCoinAmount(value: ledger.balance, size: 19)
                        }
                    },
                    crest: { cabinetCrest },
                    stake: SolarSlotStake(amount: player.stake,
                                          canLower: allowsStake && player.stakeIndex > 0,
                                          canRaise: allowsStake && player.stakeIndex < player.stakes.count - 1,
                                          change: player.solarStepStake),
                    reels: { size in reelStage(size: size) },
                    footer: { controlDeck }
                )
                if let curtain = player.curtain {
                    solarTheatreCurtain(curtain).zIndex(10)
                }
            }
        }
        .foregroundStyle(SolarDeco.ivory)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showRules) { SolarRulesSheet(game: game, stake: player.stake) }
        .sheet(isPresented: $wallet) { AurumCoinPurse(usesCabinetStyle: true) }
        .onAppear { player.solarActivate(scene == .active); solarConfigureSound() }
        .onDisappear { player.solarActivate(false); SolarSoundStage.shared.solarQuiet() }
        .onChange(of: scene) { _, phase in player.solarActivate(phase == .active); solarConfigureSound() }
        .onChange(of: ledger.member.soundtrack) { _, _ in solarConfigureSound() }
        .onChange(of: ledger.member.effects) { _, _ in solarConfigureSound() }
        .onChange(of: ledger.member.bonus?.started) { _, _ in solarConfigureSound() }
        .onChange(of: ledger.member.lock != nil) { _, _ in solarConfigureSound() }
    }

    private func solarConfigureSound() {
        SolarSoundStage.shared.solarApply(ledger.member, active: scene == .active, native: true,
                                          track: player.freeMode || ledger.member.lock != nil ? "bonus" : game.rawValue)
    }

    private var cabinetCrest: some View {
        HStack(spacing: 9) {
            SolarArt("\(game.solarArtPrefix)_\(game == .forge ? 6 : 0)").frame(width: 47, height: 47)
            VStack(spacing: 3) {
                Text((lock == nil ? game.title : game.bonusTitle).uppercased())
                    .font(SolarFoundry.solarTitle(game == .carnival ? 23 : 26))
                    .foregroundStyle(SolarFoundry.metal).lineLimit(1).minimumScaleFactor(0.57)
                Rectangle().fill(LinearGradient(colors: [.clear, SolarFoundry.gold, .clear],
                                                startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
                if let bonus = ledger.member.bonus, bonus.cabinet == game, bonus.started {
                    HStack(spacing: 5) {
                        Text("slot.freeTurns \(bonus.left)").foregroundStyle(SolarDeco.bright)
                        if player.extraSpins > 0 { Text("+\(player.extraSpins)").foregroundStyle(.green) }
                        SolarCoinAmount(value: bonus.winnings, size: 11)
                    }
                    .font(.system(size: 10, weight: .bold))
                    .lineLimit(1).minimumScaleFactor(0.65)
                    .accessibilityIdentifier("slot_bonus_status")
                }
            }
            .frame(maxWidth: .infinity)
            SolarArt("\(game.solarArtPrefix)_\(game == .forge ? 0 : 6)").frame(width: 47, height: 47)
        }
    }

    @ViewBuilder private func reelStage(size: CGSize) -> some View {
        if lock != nil {
            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.35))
                if let lock = player.lockPresentation {
                    SolarLockReelSurface(contract: lock, journey: player.lockJourney, onLanding: player.solarLockRendererLanded)
                        .padding(8).allowsHitTesting(false)
                }
                RoundedRectangle(cornerRadius: 18).stroke(SolarFoundry.metal, lineWidth: 2)
                    .allowsHitTesting(false)
                SolarSlotReelTarget(enabled: allowsRespin, highlighted: allowsRespin, tint: SolarFoundry.gold,
                                    label: "slot.respin", identifier: "thunder_lock_board", action: player.solarRespin)
            }
        } else {
            SolarReelTheatre(session: player, width: size.width)
                .allowsHitTesting(false)
                .overlay {
                    SolarSlotReelTarget(enabled: allowsPaidTurn,
                                        highlighted: allowsPaidTurn && ledger.balance >= player.stake,
                                        tint: SolarDeco.bright,
                                        label: ledger.balance < player.stake ? "casino.bank" : "slot.spin") {
                        if ledger.balance < player.stake { wallet = true }
                        else { player.solarSpin() }
                    }
                }
        }
    }

    private var controlDeck: some View {
        HStack(spacing: 7) {
            SolarSlotKey(title: player.turbo ? "slot.turboOn" : "slot.turboOff", active: player.turbo,
                         enabled: !player.occupied, action: {
                player.turbo.toggle()
                SolarSoundStage.shared.solarPlay("touch")
            }) {
                Image(systemName: "bolt.fill").font(.system(size: 20, weight: .bold))
            }
            .accessibilityIdentifier("slot_turbo")

            if let lock {
                SolarSlotResult(title: "slot.lockCoins") {
                    SolarCoinAmount(value: player.lockPresentation?.collected ?? lock.collected, size: 19)
                }
                if lock.complete && !player.lockBusy {
                    SolarSlotKey(title: "estate.collect", action: player.solarCollectLock) {
                        Image(systemName: "sparkles").font(.system(size: 18, weight: .bold))
                    }
                    .accessibilityIdentifier("lock_collect")
                } else {
                    VStack(spacing: 3) {
                        HStack(spacing: 4) {
                            ForEach(0..<3) { index in
                                Circle().fill(index < (player.lockPresentation?.attempts ?? lock.attempts)
                                              ? SolarFoundry.gold : SolarFoundry.panel)
                                    .frame(width: 7, height: 7)
                            }
                        }
                        Text("slot.respins").font(.system(size: 9, weight: .bold))
                            .foregroundStyle(SolarDeco.muted)
                    }.frame(width: 78)
                }
            } else {
                let payout = player.motion == .quiet ? player.lastWin : player.spinWin
                SolarSlotResult(multiplier: payout > 0 ? player.amplifier : 1) {
                    SolarCoinAmount(value: payout, size: 20)
                }
                SolarSlotKey(title: "slot.bonus", enabled: !player.occupied && !player.freeMode,
                             action: player.solarAskForBonus) {
                    SolarArt("\(game.solarArtPrefix)_7")
                }
                .accessibilityIdentifier("buy_bonus")
            }
        }
    }
    @ViewBuilder private func solarTheatreCurtain(_ curtain: SolarCabinetSession.SolarCurtain) -> some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()
            switch curtain {
            case .purchase:
                VStack(spacing:18) {
                    SolarArt("\(game.solarArtPrefix)_7").frame(height:115)
                    Text(game.bonusTitle.uppercased()).font(SolarFoundry.solarTitle(27)).foregroundStyle(SolarFoundry.metal).multilineTextAlignment(.center)
                    Text(game == .forge ? "Start with three locked coins and three respins." : game == .carnival ? "Break three rockets to reveal your free spins." : "Enter \(game == .nougat ? 10 : 8) automatic free spins.")
                        .font(.system(size:15)).foregroundColor(.white.opacity(0.8)).multilineTextAlignment(.center)
                    SolarCoinAmount(value:player.stake*game.bonusPrice,size:25)
                    Text("Uses your virtual coins").font(.system(size:12)).foregroundColor(SolarFoundry.muted)
                    SolarMetalButton(title:"ENTER BONUS",enabled:ledger.balance >= player.stake*game.bonusPrice) { player.solarBuy() }.accessibilityIdentifier("confirm_bonus")
                    Button("action.cancel") { player.curtain = nil }.buttonStyle(SolarGoldButtonStyle(prominent: false))
                }.padding(25).background(SolarFoundry.panel).clipShape(RoundedRectangle(cornerRadius:27)).overlay(RoundedRectangle(cornerRadius:27).stroke(SolarFoundry.metal,lineWidth:1)).padding(28)
            case .introduction:
                SolarBonusWelcome(game:game,contract:ledger.member.bonus,action:player.solarEnter)
            case .lockRules:
                VStack(spacing:18) {
                    SolarArt("aurum-dynamo_0").frame(height:155)
                    Text(game.bonusTitle.uppercased()).font(SolarFoundry.solarTitle(30)).foregroundStyle(SolarFoundry.metal)
                    Text("Lock coins. Restore respins.\nFill the board for GRAND.").font(.system(size:17,weight:.semibold)).multilineTextAlignment(.center).foregroundColor(.white)
                    SolarMetalButton(title:"START RESPINS") { player.solarEnter() }
                }.padding(28)
            case .bigWin(let amount), .summary(let amount):
                VStack(spacing:4) {
                    SolarArt("aurum-celebration").frame(maxWidth:360).frame(height:250)
                    if case .summary = curtain { Text("BONUS COMPLETE").font(SolarFoundry.solarTitle(17)).tracking(2).foregroundColor(SolarFoundry.ice) }
                    Text(amount.coins).font(SolarFoundry.solarNumber(54)).foregroundStyle(SolarFoundry.metal).minimumScaleFactor(0.5).lineLimit(1).shadow(color:SolarFoundry.copper.opacity(0.7),radius:20)
                    SolarMetalButton(title:"COLLECT") { player.solarDismissCelebration() }.padding(.top,24).padding(.horizontal,40)
                }.padding(20)
                if !reduceMotion { SolarFrontCoinShower().ignoresSafeArea().zIndex(2) }
            }
        }.transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96)))
    }
}

struct SolarBonusWelcome: View {
    var game: SolarCabinet
    var contract: SolarBonusContract?
    var action: () -> Void
    @State private var revealed = Set<Int>()
    var body: some View {
        VStack(spacing:20) {
            SolarArt("\(game.solarArtPrefix)_7").frame(height:135).shadow(color:SolarFoundry.solarTint(game).opacity(0.6),radius:30)
            Text(game.bonusTitle.uppercased()).font(SolarFoundry.solarTitle(31)).foregroundStyle(SolarFoundry.metal).multilineTextAlignment(.center)
            if game == .carnival, let contract = contract {
                HStack(spacing:5) {
                    ForEach(0..<contract.reveals.count,id:\.self) { index in
                        Button { _ = revealed.insert(index); SolarSoundStage.shared.solarPlay("spark",strong:true) } label: {
                            ZStack { SolarArt("aurum-festival_6").opacity(revealed.contains(index) ? 0.15 : 1); if revealed.contains(index) { Text("+\(contract.reveals[index])").font(SolarFoundry.solarNumber(31)).foregroundColor(SolarFoundry.gold) } }.frame(height:46)
                        }.buttonStyle(SolarGoldButtonStyle(prominent: false)).disabled(revealed.contains(index)).accessibilityLabel("Reveal rocket \(index+1)")
                    }
                }
                Text(revealed.count == contract.reveals.count ? "\(contract.awarded) FREE SPINS" : "BREAK THE ROCKETS").font(SolarFoundry.solarTitle(21)).foregroundColor(.white)
            } else { Text("\(contract?.awarded ?? 0) FREE SPINS").font(SolarFoundry.solarNumber(32)).foregroundColor(.white) }
            Text(game == .nougat ? "Charges add together and multiply your tumble wins." : game == .temple ? "An expanding wild reel in every free spin." : "Walking wilds. Multipliers. Extra spins.")
                .font(.system(size:15)).foregroundColor(SolarFoundry.muted).multilineTextAlignment(.center)
            SolarMetalButton(title:"START FREE SPINS",enabled:game != .carnival || revealed.count == contract?.reveals.count) { action() }.accessibilityIdentifier("start_free_spins")
        }.padding(30)
    }
}
