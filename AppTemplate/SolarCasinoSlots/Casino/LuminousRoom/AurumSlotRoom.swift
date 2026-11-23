import SwiftUI

struct AurumSlotRoom: View {
    @EnvironmentObject var club: AurumClubAccount
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduced
    let room: AurumRoom
    @StateObject private var conductor: AurumTurnConductor
    @State private var rules = false
    @State private var offer = false
    @State private var wallet = false

    init(room: AurumRoom, club: AurumClubAccount) {
        self.room = room
        _conductor = StateObject(wrappedValue: AurumTurnConductor(room: room, club: club))
    }

    private var feature: AurumFeature? { club.solarFeature(room) }
    private var calm: Bool { reduced || club.state.gentle }
    private var introductory: Bool { feature?.entered == false }
    private var covered: Bool { introductory || offer || conductor.bigWin != nil || conductor.bonusTotal != nil }
    private var allowsPaidTurn: Bool { phase == .active && !club.paused && !conductor.busy && feature == nil && !covered }
    private var allowsStake: Bool { allowsPaidTurn && !club.pending }
    private var stake: Int { club.state.stake }

    var body: some View {
        ZStack {
            AurumBackground(scene: room.scene)
            SolarSlotLayout(
                aspect: CGFloat(room.columns) / CGFloat(room.rows),
                rim: 14,
                header: {
                    SolarSlotBar(locked: conductor.busy, back: { conductor.solarSuspend(); dismiss() }, rules: { rules = true }) {
                        AurumBalance(amount: club.balance, size: 19)
                    }
                },
                crest: { crest },
                stake: SolarSlotStake(amount: feature?.stake ?? stake,
                                      canLower: allowsStake && stake != AurumClubAccount.stakes.first,
                                      canRaise: allowsStake && stake != AurumClubAccount.stakes.last,
                                      change: adjustStake),
                reels: { _ in reelStage },
                footer: { controls }
            )
            .allowsHitTesting(!covered)
            .accessibilityHidden(covered)

            if offer { featureOffer }
            if introductory, let feature { featureEntrance(feature) }
            if let value = conductor.bigWin {
                AurumWinPanel(title: "BIG WIN", amount: value, button: "table.continue") {
                    conductor.bigWin = nil
                    conductor.rain = nil
                }
            }
            if let value = conductor.bonusTotal {
                AurumWinPanel(title: "BONUS COMPLETE", amount: value, button: "estate.collect") {
                    conductor.solarCloseSummary()
                }
            }
            if let rain = conductor.rain, !calm {
                AurumChipRain(token: rain).allowsHitTesting(false).accessibilityHidden(true)
            }
        }
        .foregroundColor(AurumInk.white)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $rules) { AurumGameRules(room: room) }
        .sheet(isPresented: $wallet) { AurumCoinPurse(usesCabinetStyle: true) }
        .onChange(of: phase) { _, value in
            if value != .active {
                conductor.solarSuspend()
                AurumSoundstage.shared.solarQuiet()
            } else {
                AurumSoundstage.shared.solarConfigure(club.state, room: room.rawValue)
            }
        }
        .onAppear {
            if let feature, feature.entered, feature.left == 0 { conductor.bonusTotal = feature.total }
        }
        .onDisappear { conductor.solarSuspend() }
    }

    private var crest: some View {
        VStack(spacing: 3) {
            Text(room.title)
                .font(AurumInk.solarFace(31)).lineLimit(1).minimumScaleFactor(0.65)
                .shadow(color: AurumInk.blue.opacity(0.35), radius: 12)
            if let feature, feature.entered {
                HStack(spacing: 5) {
                    Text("slot.freeTurns \(feature.left)").foregroundStyle(SolarDeco.bright)
                    AurumBalance(amount: feature.total, size: 11)
                }
                .font(.system(size: 10, weight: .bold))
                .lineLimit(1).minimumScaleFactor(0.65)
                .accessibilityIdentifier("sx_bonus_status")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var reelStage: some View {
        AurumReelSurface(room: room, board: conductor.board, cue: conductor.cue, highlighted: conductor.highlights)
            .padding(7)
            .background(LinearGradient(colors: [AurumInk.blue.opacity(0.7), AurumInk.raised, AurumInk.coral.opacity(0.7)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 19))
            .shadow(color: AurumInk.blue.opacity(feature != nil ? 0.28 : 0.12), radius: 23)
            .allowsHitTesting(false)
            .overlay {
                SolarSlotReelTarget(enabled: allowsPaidTurn,
                                    highlighted: allowsPaidTurn && club.balance >= stake,
                                    tint: SolarDeco.bright,
                                    label: club.balance < stake ? "casino.bank" : "slot.spin") {
                    if club.balance < stake { wallet = true }
                    else { conductor.solarStart(calm: calm) }
                }
            }
    }

    private var controls: some View {
        HStack(spacing: 7) {
            SolarSlotKey(title: club.state.turbo ? "slot.turboOn" : "slot.turboOff",
                         active: club.state.turbo, enabled: !conductor.busy, action: { club.solarToggle("turbo") }) {
                Image(systemName: "bolt.fill").font(.system(size: 20, weight: .bold))
            }
            .accessibilityIdentifier("slot_turbo")

            SolarSlotResult(multiplier: conductor.lastReturn > 0 && room == .prism ? conductor.boost : 1) {
                AurumBalance(amount: conductor.lastReturn, size: 20)
            }

            if let feature, feature.entered {
                SolarSlotKey(title: conductor.automatic ? "slot.bonusPause" : "slot.bonusResume",
                             active: conductor.automatic,
                             enabled: !club.paused && (conductor.automatic || !conductor.busy) && feature.left > 0,
                             action: {
                    if conductor.automatic { conductor.solarPause() }
                    else { conductor.solarStart(calm: calm) }
                }) {
                    Image(systemName: conductor.automatic ? "pause.fill" : "play.fill")
                        .font(.system(size: 17, weight: .bold))
                }
                .accessibilityIdentifier("sx_bonus_toggle")
            } else {
                SolarSlotKey(title: "slot.bonus", enabled: allowsPaidTurn, action: { offer = true }) {
                    AurumArt(bonusMark)
                }
                .accessibilityIdentifier("sx_feature_offer")
            }
        }
    }

    private func adjustStake(_ direction: Int) {
        let stakes = AurumClubAccount.stakes
        guard allowsStake, let index = stakes.firstIndex(of: stake), stakes.indices.contains(index + direction) else { return }
        club.solarSetStake(stakes[index + direction])
        AurumSoundstage.shared.solarEffect("tap")
    }

    private var bonusMark: String { room == .orbit ? "aurum-mark-wild" : "aurum-mark-scatter" }

    private var featureOffer: some View {
        ZStack {
            Color.black.opacity(0.86).ignoresSafeArea()
            VStack(spacing: 15) {
                HStack {
                    Spacer()
                    Button { offer = false } label: { Image(systemName: "xmark") }
                        .buttonStyle(SolarCabinetIconStyle())
                        .accessibilityLabel(Text("action.cancel"))
                }
                AurumArt(bonusMark).frame(height: 75)
                Text(room.featureName).font(AurumInk.solarFace(28))
                Text(featureDescription).font(.system(size: 14)).foregroundStyle(AurumInk.muted)
                HStack {
                    Text("slot.bonusCost").font(.footnote)
                    Spacer()
                    AurumBalance(amount: stake * room.featurePrice, size: 23)
                }
                Text("casino.virtual").font(.caption).foregroundStyle(AurumInk.muted)
                Button("slot.enterBonus") {
                    if club.solarBuyFeature(room) {
                        offer = false
                        AurumSoundstage.shared.solarEffect("bonus")
                    }
                }
                .buttonStyle(SolarGoldButtonStyle(prominent: false))
                .disabled(club.balance < stake * room.featurePrice)
                .accessibilityIdentifier("sx_feature_confirm")
            }
            .multilineTextAlignment(.center)
            .padding(20)
            .background { SolarCutCorner(cut: 18).fill(SolarDeco.panel) }
            .overlay { SolarBrassFrame(cut: 18) }
            .frame(maxWidth: 410)
            .padding(.horizontal, 22)
        }
        .accessibilityAddTraits(.isModal)
    }

    private var featureDescription: LocalizedStringKey { LocalizedStringKey("rules.feature." + room.rawValue) }

    private func featureEntrance(_ feature: AurumFeature) -> some View {
        ZStack {
            AurumScene(name: room.scene).ignoresSafeArea()
            Color.black.opacity(0.72).ignoresSafeArea()
            VStack(spacing: 13) {
                AurumArt(bonusMark).frame(height: 77).shadow(color: AurumInk.blue, radius: 24)
                Text(room.featureName).font(AurumInk.solarFace(32))
                Text("slot.freeTurns \(feature.left)")
                    .font(AurumInk.solarDigits(29)).foregroundStyle(AurumInk.coral)
                Text(featureDescription)
                    .font(.subheadline).foregroundStyle(AurumInk.muted)
                Button("slot.startBonus") {
                    club.solarEnterFeature(room)
                    conductor.solarStart(calm: calm)
                }
                .buttonStyle(SolarGoldButtonStyle(prominent: false))
                .disabled(club.paused)
                .accessibilityIdentifier("sx_bonus_enter")
                Button("slot.saveReturn") { dismiss() }
                    .buttonStyle(SolarGoldButtonStyle(prominent: false))
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: 375)
            .padding(28)
        }
        .accessibilityAddTraits(.isModal)
    }
}
struct AurumWinPanel: View {
    @EnvironmentObject var club: AurumClubAccount
    let title: LocalizedStringKey
    let amount: Int
    let button: LocalizedStringKey
    let close: ()->Void
    @State private var value = 0.0
    var body: some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()
            VStack(spacing: 23) {
                AurumArt("aurum-trophy")
                    .frame(height: 105)
                    .shadow(color: SolarDeco.gold.opacity(0.6), radius: 28)
                Text(title)
                    .font(AurumInk.solarFace(32))
                    .foregroundStyle(LinearGradient(colors: [SolarDeco.ivory, SolarDeco.gold],
                                                     startPoint: .top, endPoint: .bottom))
                    .multilineTextAlignment(.center)
                AurumCountDigits(value: value, locale: club.locale)
                    .font(AurumInk.solarDigits(47))
                    .monospacedDigit().minimumScaleFactor(0.5).lineLimit(1)
                Text("table.virtualCoins").font(.caption).foregroundStyle(SolarDeco.muted)
                Button(button, action: close)
                    .buttonStyle(SolarGoldButtonStyle(prominent: false))
                    .accessibilityIdentifier("sx_win_close")
            }
            .padding(28)
            .background { SolarCutCorner(cut: 18).fill(SolarDeco.socket) }
            .overlay { SolarBrassFrame(cut: 18) }
            .shadow(color: SolarDeco.gold.opacity(0.3), radius: 30)
            .padding(26)
        }
        .accessibilityAddTraits(.isModal)
        .onAppear {
            withAnimation(.easeOut(duration: club.state.gentle ? 0 : 0.85)) { value = Double(amount) }
        }
    }
}
struct AurumChipRain: UIViewRepresentable {
    let token: UUID
    func makeUIView(context: Context) -> AurumChipEmitter { AurumChipEmitter() }
    func updateUIView(_ view: AurumChipEmitter,context: Context) { view.solarBegin(token) }
    static func dismantleUIView(_ view: AurumChipEmitter,coordinator: ()) { view.emitter.birthRate = 0 }
}
final class AurumChipEmitter: UIView {
    let emitter = CAEmitterLayer()
    private var token: UUID?
    override init(frame: CGRect) { super.init(frame:frame);isUserInteractionEnabled = false;layer.addSublayer(emitter) }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() { super.layoutSubviews();emitter.frame = bounds;emitter.emitterPosition = CGPoint(x:bounds.midX,y:-20);emitter.emitterSize = CGSize(width:bounds.width,height:1) }
    func solarBegin(_ token: UUID) {
        guard self.token != token else { return };self.token = token
        emitter.emitterShape = .line;emitter.emitterMode = .surface;emitter.renderMode = .unordered
        let chip = CAEmitterCell();chip.contents = AurumArtwork.shared.solarGet("aurum-mark-chip")?.cgImage;chip.birthRate = 28;chip.lifetime = 5;chip.velocity = 110;chip.velocityRange = 55;chip.yAcceleration = 185;chip.emissionLongitude = .pi/2;chip.emissionRange = .pi/3;chip.scale = 26 / CGFloat(AurumArtwork.shared.solarGet("aurum-mark-chip")?.cgImage?.width ?? 320);chip.scaleRange = chip.scale * 0.4;chip.spin = 2;chip.spinRange = 4;chip.alphaSpeed = -0.15;emitter.emitterCells = [chip];emitter.birthRate = 1
        DispatchQueue.main.asyncAfter(deadline:.now()+2.5) { [weak self] in if self?.token==token { self?.emitter.birthRate = 0 } }
    }
}

private struct AurumCountDigits: View,Animatable {
    var value: Double
    let locale: Locale
    var animatableData: Double { get { value } set { value = newValue } }
    var body: some View { Text(Int(value).formatted(.number.locale(locale))) }
}
