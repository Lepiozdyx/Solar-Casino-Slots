import SwiftUI

struct AurumBlackjackRoom: View {
    @EnvironmentObject var club: AurumClubAccount
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduced
    @State private var rules = false
    @State private var purse = false

    private let room = AurumRoom.blackjack
    private var hand: AurumHand? { club.state.hand }
    private var playing: Bool { hand?.finished == false }

    var body: some View {
        GeometryReader { screen in
            let cardHeight = min(116, screen.size.height * 0.155)
            VStack(spacing: 10) {
                SolarSlotBar(locked: false, back: { dismiss() }, rules: { rules = true }) {
                    SolarChipAmount(value: club.balance).font(.headline)
                }
                Text(room.title)
                    .font(SolarDeco.solarTitle(30))
                    .lineLimit(1).minimumScaleFactor(0.75)
                AurumStakeControl(locked: club.paused || club.pending,
                                  display: playing ? hand?.stake : nil)
                Spacer(minLength: 0)
                cardTable(cardHeight: cardHeight)
                outcome
                Spacer(minLength: 0)
                actions
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background { AurumBackground(scene: room.scene) }
        .foregroundStyle(SolarDeco.ivory)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $rules) { AurumGameRules(room: room) }
        .sheet(isPresented: $purse) { AurumCoinPurse(usesCabinetStyle: true) }
    }

    private func cardTable(cardHeight: CGFloat) -> some View {
        VStack(spacing: 10) {
            score("table.blackjack.dealer", points: dealerScore)
            cardRow(hand?.dealer ?? [], hideAfterFirst: playing, cardHeight: cardHeight)
            Rectangle().fill(SolarDeco.metal).frame(height: 1).opacity(0.55)
            score("table.blackjack.player", points: hand.map { points(for: $0.player) } ?? "—")
            cardRow(hand?.player ?? [], hideAfterFirst: false, cardHeight: cardHeight)
        }
        .padding(13)
        .background { SolarCutCorner(cut: 16).fill(SolarDeco.socket) }
        .overlay { SolarBrassFrame() }
    }

    private func score(_ title: LocalizedStringKey, points: String) -> some View {
        HStack {
            Text(title)
                .font(.caption.weight(.bold)).foregroundStyle(SolarDeco.muted)
            Spacer()
            Text(points)
                .font(.headline.monospacedDigit()).foregroundStyle(SolarDeco.bright)
        }
    }

    private var dealerScore: String {
        guard let hand, let first = hand.dealer.first else { return "—" }
        if hand.finished { return points(for: hand.dealer) }
        return first.rank == 1 ? "1/11" : String(min(10, first.rank))
    }

    private func points(for cards: [AurumCard]) -> String {
        let total = AurumTwentyOne.solarTotal(cards)
        return total.soft ? "\(total.points - 10)/\(total.points)" : String(total.points)
    }

    private func cardRow(_ cards: [AurumCard], hideAfterFirst: Bool, cardHeight: CGFloat) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 7) {
                if cards.isEmpty {
                    AurumPlayingCard(card: nil, hidden: true, height: cardHeight)
                    AurumPlayingCard(card: nil, hidden: true, height: cardHeight)
                } else {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        AurumPlayingCard(card: card, hidden: hideAfterFirst && index > 0, height: cardHeight)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            }
            .padding(4)
            .containerRelativeFrame(.horizontal) { width, _ in
                let cardCount = CGFloat(max(2, cards.count))
                return max(width, cardCount * cardHeight * 0.68 + (cardCount - 1) * 7 + 8)
            }
        }
        .scrollIndicators(.hidden)
        .frame(height: cardHeight + 8)
        .animation(.easeOut(duration: reduced || club.state.gentle ? 0 : 0.25), value: cards.count)
    }

    private var outcome: some View {
        HStack {
            if let hand, hand.finished {
                Text(LocalizedStringKey(AurumTwentyOne.solarResultKey(hand.message)))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("table.returned")
                    .font(.caption).foregroundStyle(SolarDeco.muted)
                SolarChipAmount(value: hand.payout).font(.subheadline.weight(.semibold))
            }
        }
        .padding(.horizontal, 13)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background {
            if hand?.finished == true {
                SolarCutCorner(cut: 9).fill(SolarDeco.panel)
                SolarBrassFrame(cut: 9)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("sx_hand_result")
    }

    @ViewBuilder private var actions: some View {
        if playing {
            HStack(spacing: 8) {
                Button("table.blackjack.hit") { play("hit") }
                    .buttonStyle(SolarGoldButtonStyle())
                    .accessibilityIdentifier("sx_hit")
                Button("table.blackjack.stand") { play("stand") }
                    .buttonStyle(SolarGoldButtonStyle(prominent: false))
                    .accessibilityIdentifier("sx_stand")
                Button("table.blackjack.double") { play("double") }
                    .buttonStyle(SolarGoldButtonStyle(prominent: false))
                    .disabled(hand?.player.count != 2 || club.balance < (hand?.baseStake ?? 0))
                    .accessibilityIdentifier("sx_double")
            }
            .disabled(club.paused)
        } else {
            Button("table.blackjack.deal") {
                if club.balance < club.state.stake {
                    purse = true
                } else if club.solarDeal() {
                    AurumSoundstage.shared.solarEffect("card")
                }
            }
            .buttonStyle(SolarGoldButtonStyle())
            .disabled(club.paused || club.pending)
            .accessibilityIdentifier("sx_deal")
        }
    }

    private func play(_ action: String) {
        club.solarPlayHand(action)
        let won = hand?.finished == true && (hand?.payout ?? 0) > 0
        AurumSoundstage.shared.solarEffect(won ? "win" : "card")
    }
}

private struct AurumPlayingCard: View {
    let card: AurumCard?
    let hidden: Bool
    let height: CGFloat

    var body: some View {
        ZStack {
            if let card, !hidden {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [SolarDeco.ivory, Color(sx: 0xE3CEA2)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                VStack {
                    HStack {
                        Text(card.label)
                        Spacer()
                        Text(card.pip)
                    }
                    Spacer(minLength: 0)
                    Text(card.pip).font(.system(size: height * 0.32))
                    Spacer(minLength: 0)
                    HStack {
                        Text(card.pip)
                        Spacer()
                        Text(card.label).rotationEffect(.degrees(180))
                    }
                }
                .font(.system(size: height * 0.16, weight: .semibold, design: .serif))
                .foregroundStyle(card.red ? Color(sx: 0xA02631) : SolarDeco.enamel)
                .padding(7)
            } else {
                RoundedRectangle(cornerRadius: 8).fill(SolarDeco.socket)
                RoundedRectangle(cornerRadius: 5).strokeBorder(SolarDeco.metal).padding(4)
                AurumArt("aurum-card-ornament").padding(height * 0.14)
            }
        }
        .frame(width: height * 0.68, height: height)
        .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(SolarDeco.brass.opacity(0.65)) }
        .shadow(color: .black.opacity(0.36), radius: 3, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cardLabel)
    }

    private var cardLabel: Text {
        if let card, !hidden { return Text(verbatim: card.label + " " + card.pip) }
        return Text("table.blackjack.faceDown")
    }
}

struct AurumRouletteRoom: View {
    @EnvironmentObject var club: AurumClubAccount
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduced
    @State private var picks: [AurumRoulettePick] = []
    @State private var numbers = false
    @State private var rules = false
    @State private var purse = false
    @State private var busy = false
    @State private var angle = 0.0
    @State private var ball = 0.0
    @State private var result: AurumRouletteRound?
    @State private var task: Task<Void, Never>?
    @State private var bigWin: Int?
    @State private var rain: UUID?

    private let room = AurumRoom.roulette
    private var wager: Int { picks.reduce(0) { $0 + $1.stake } }
    private var locked: Bool { busy || club.paused || club.pending || phase != .active }
    private var canTapWheel: Bool { !locked && !picks.isEmpty && bigWin == nil }
    private var calm: Bool { reduced || club.state.gentle }

    var body: some View {
        ZStack {
            AurumBackground(scene: room.scene)
            GeometryReader { screen in
                let wheelSize = min(270, screen.size.height * 0.32, screen.size.width - 36)
                VStack(spacing: 7) {
                    SolarSlotBar(locked: busy, back: { dismiss() }, rules: { rules = true }) {
                        SolarChipAmount(value: club.balance).font(.headline)
                    }
                    Text(room.title)
                        .font(SolarDeco.solarTitle(30))
                        .lineLimit(1).minimumScaleFactor(0.75)
                    wheel.frame(width: wheelSize, height: wheelSize)
                    roundStatus
                    AurumStakeControl(locked: locked, title: "table.roulette.chipValue")
                    modes
                    ScrollView {
                        VStack(spacing: 9) {
                            if numbers { numberLayout } else { outsideLayout }
                            if !picks.isEmpty { selectedBets }
                        }
                        .padding(7)
                    }
                    .scrollIndicators(.hidden)
                    .background { SolarCutCorner(cut: 12).fill(SolarDeco.socket) }
                    .overlay { SolarBrassFrame(cut: 12) }
                    wagerBar
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .allowsHitTesting(bigWin == nil)
            .accessibilityHidden(bigWin != nil)

            if let amount = bigWin {
                AurumWinPanel(title: "table.roulette.bigWin", amount: amount, button: "table.continue") {
                    bigWin = nil
                    rain = nil
                }
            }
            if let rain, !calm { AurumChipRain(token: rain).allowsHitTesting(false) }
        }
        .foregroundStyle(SolarDeco.ivory)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $rules) { AurumGameRules(room: room) }
        .sheet(isPresented: $purse) { AurumCoinPurse(usesCabinetStyle: true) }
        .onAppear {
            if result == nil, let previous = club.state.lastWheel {
                result = previous
                angle = AurumRoulette.solarTarget(previous.number, after: 0)
                picks = previous.picks
            }
        }
        .onChange(of: phase) { _, value in
            if value != .active { settleImmediately() }
        }
        .onDisappear { settleImmediately() }
    }

    private var wheel: some View {
        Button(action: spin) {
            AurumRouletteWheel(angle: angle, ball: ball)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!canTapWheel)
        .overlay {
            if canTapWheel && club.balance >= wager {
                SolarGlint(outline: Circle(), tint: SolarDeco.bright)
            }
        }
        .accessibilityLabel(Text("table.roulette.wheel"))
        .accessibilityIdentifier("sx_wheel")
    }

    private var roundStatus: some View {
        VStack(spacing: 2) {
            HStack(spacing: 8) {
                if let result, !busy {
                    Text(result.number, format: .number)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(SolarDeco.ivory)
                        .frame(minWidth: 30)
                        .background { SolarCutCorner(cut: 4).fill(pocketColor(result.number)) }
                    Text("table.returned").font(.caption).foregroundStyle(SolarDeco.muted)
                    SolarChipAmount(value: result.payout).font(.subheadline.weight(.semibold))
                } else if busy {
                    Text("table.roulette.spinning").font(.subheadline.weight(.semibold))
                }
            }
            .frame(height: 24)
            .accessibilityIdentifier("sx_roulette_result")
            Text(picks.isEmpty ? "table.roulette.placeBet" : "table.roulette.tapWheel")
                .font(.caption.weight(.semibold))
                .foregroundStyle(canTapWheel ? SolarDeco.bright : SolarDeco.muted)
                .opacity(busy ? 0 : 1)
        }
    }

    private var modes: some View {
        HStack(spacing: 8) {
            Button("table.roulette.outside") { numbers = false }
                .buttonStyle(SolarGoldButtonStyle(prominent: !numbers))
            Button("table.roulette.numbers") { numbers = true }
                .buttonStyle(SolarGoldButtonStyle(prominent: numbers))
        }
        .disabled(locked)
    }

    private var outsideLayout: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
            ForEach(AurumRouletteArea.allCases.filter { $0 != .number }, id: \.rawValue) { area in
                choice(area, number: 0)
            }
        }
    }

    private var numberLayout: some View {
        VStack(spacing: 6) {
            choice(.number, number: 0)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 6), spacing: 6) {
                ForEach(1...36, id: \.self) { choice(.number, number: $0) }
            }
        }
    }

    private func choice(_ area: AurumRouletteArea, number: Int) -> some View {
        let selected = picks.first { $0.area == area && $0.number == number }
        return Button {
            add(area, number: number)
        } label: {
            VStack(spacing: 1) {
                betName(area, number: number).font(.system(size: area == .number ? 15 : 13, weight: .semibold))
                if let selected {
                    Text(selected.stake, format: .number)
                        .font(.system(size: 10, weight: .bold)).foregroundStyle(SolarDeco.bright)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .padding(.horizontal, 3)
            .frame(maxWidth: .infinity)
            .frame(height: 43)
            .background { SolarCutCorner(cut: 6).fill(betColor(area, number: number)) }
            .overlay {
                SolarCutCorner(cut: 6)
                    .stroke(selected == nil ? SolarDeco.brass : SolarDeco.bright, lineWidth: selected == nil ? 1 : 2)
                    .allowsHitTesting(false)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .accessibilityIdentifier("sx_roulette_" + area.rawValue + "_\(number)")
    }

    private var selectedBets: some View {
        VStack(spacing: 0) {
            ForEach(picks) { pick in
                HStack(spacing: 9) {
                    betName(pick.area, number: pick.number)
                    Spacer()
                    SolarChipAmount(value: pick.stake)
                    Button {
                        picks.removeAll { $0.id == pick.id }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(SolarDeco.gold)
                    .disabled(locked)
                    .accessibilityLabel(Text("table.roulette.remove"))
                    .accessibilityIdentifier("sx_roulette_remove_" + pick.id)
                }
                .font(.subheadline)
                .padding(.leading, 10)
            }
        }
        .background { SolarCutCorner(cut: 7).fill(SolarDeco.panel) }
    }

    private var wagerBar: some View {
        HStack(spacing: 8) {
            Text("table.roulette.total").font(.footnote.weight(.semibold)).foregroundStyle(SolarDeco.muted)
            SolarChipAmount(value: wager).font(.subheadline.weight(.semibold))
            Spacer()
            Button { picks.removeAll() } label: { Image(systemName: "trash") }
                .buttonStyle(SolarCabinetIconStyle())
                .disabled(locked || picks.isEmpty)
                .accessibilityLabel(Text("table.roulette.clear"))
                .accessibilityIdentifier("sx_roulette_clear")
        }
    }

    private func betName(_ area: AurumRouletteArea, number: Int) -> Text {
        if area == .number { return Text(number, format: .number) }
        return Text(LocalizedStringKey("table.roulette.bet." + area.rawValue))
    }

    private func betColor(_ area: AurumRouletteArea, number: Int) -> Color {
        switch area {
        case .number: pocketColor(number)
        case .red: Color(sx: 0x762734)
        case .black: SolarDeco.enamel
        default: SolarDeco.panel
        }
    }

    private func add(_ area: AurumRouletteArea, number: Int) {
        guard !locked else { return }
        if let index = picks.firstIndex(where: { $0.area == area && $0.number == number }) {
            picks[index].stake = min(5000, picks[index].stake + club.state.stake)
        } else if picks.count < 12 {
            picks.append(.init(area: area, number: number, stake: club.state.stake))
        }
        AurumSoundstage.shared.solarEffect("tap")
    }

    private func spin() {
        guard canTapWheel else { return }
        guard club.balance >= wager else {
            purse = true
            return
        }
        guard let round = club.solarReserveRoulette(picks) else { return }

        busy = true
        result = nil
        let target = AurumRoulette.solarTarget(round.number, after: angle)
        let duration = calm ? 0.45 : 4.1
        withAnimation(.timingCurve(0.12, 0.7, 0.15, 1, duration: duration)) {
            angle = target
            ball -= 6 * 360
        }
        AurumSoundstage.shared.solarEffect("ball")
        task = Task {
            do { try await Task.sleep(for: .seconds(duration + 0.15)) }
            catch { return }
            guard !Task.isCancelled else { return }
            task = nil
            guard club.solarFinishRoulette(round.id) else {
                busy = false
                return
            }
            result = round
            busy = false
            if round.payout > 0 { AurumSoundstage.shared.solarEffect("win") }
            if round.payout >= round.wager * 5 {
                bigWin = round.payout
                rain = UUID()
            }
        }
    }

    private func settleImmediately() {
        task?.cancel()
        task = nil
        if let round = club.state.pendingWheel, club.solarFinishRoulette(round.id) {
            angle = AurumRoulette.solarTarget(round.number, after: 0)
            ball = 0
            result = round
        }
        busy = false
    }
}

private func pocketColor(_ number: Int) -> Color {
    if number == 0 { return Color(sx: 0x1B644F) }
    return AurumRoulette.reds.contains(number) ? Color(sx: 0x832B38) : SolarDeco.enamel
}

private struct AurumRouletteWheel: View {
    let angle: Double
    let ball: Double

    var body: some View {
        GeometryReader { bounds in
            let size = min(bounds.size.width, bounds.size.height)
            ZStack {
                Circle().fill(SolarDeco.metal)
                Circle().fill(SolarDeco.socket).padding(4)
                pockets.rotationEffect(.degrees(angle))
                Circle()
                    .fill(SolarDeco.socket)
                    .frame(width: size * 0.61, height: size * 0.61)
                    .overlay { Circle().strokeBorder(SolarDeco.metal, lineWidth: 2) }
                AurumArt("aurum-mark-chip")
                    .frame(width: size * 0.20, height: size * 0.20)
                    .rotationEffect(.degrees(angle / 2))
                Circle()
                    .fill(SolarDeco.ivory)
                    .shadow(color: .black.opacity(0.65), radius: 2)
                    .frame(width: 9, height: 9)
                    .offset(y: -size * 0.34)
                    .rotationEffect(.degrees(ball))
                VStack {
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(SolarDeco.bright)
                    Spacer()
                }
            }
            .frame(width: size, height: size)
        }
    }

    private var pockets: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = size.width / 2 - 7
            let step = 2 * Double.pi / Double(AurumRoulette.wheel.count)
            for (index, number) in AurumRoulette.wheel.enumerated() {
                let start = -Double.pi / 2 + Double(index) * step
                let middle = start + step / 2
                var slice = Path()
                slice.move(to: center)
                slice.addArc(center: center, radius: radius, startAngle: .radians(start),
                             endAngle: .radians(start + step), clockwise: false)
                slice.closeSubpath()
                context.fill(slice, with: .color(pocketColor(number)))
                context.stroke(slice, with: .color(SolarDeco.brass), lineWidth: 0.65)

                var label = context
                let offset = radius * 0.85
                label.translateBy(x: center.x + cos(middle) * offset, y: center.y + sin(middle) * offset)
                label.rotate(by: .radians(middle + Double.pi / 2))
                label.draw(Text(verbatim: String(number)).font(.system(size: max(7, size.width / 30), weight: .bold))
                    .foregroundColor(SolarDeco.ivory), at: .zero)
            }
        }
    }
}
