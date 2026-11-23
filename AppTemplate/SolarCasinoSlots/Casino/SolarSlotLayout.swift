import SwiftUI

struct SolarSlotLayout<Header: View, Crest: View, Reels: View, Footer: View>: View {
    let aspect: CGFloat
    let rim: CGFloat
    @ViewBuilder var header: () -> Header
    @ViewBuilder var crest: () -> Crest
    let stake: SolarSlotStake
    @ViewBuilder var reels: (CGSize) -> Reels
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        GeometryReader { screen in
            let compact = screen.size.height < 690
            VStack(spacing: compact ? 6 : 10) {
                header().frame(height: 44)
                crest().frame(height: compact ? 50 : 66)
                stake.frame(height: 48)
                GeometryReader { stage in
                    let width = max(rim + 1, min(stage.size.width, (stage.size.height - rim) * aspect + rim))
                    let size = CGSize(width: width, height: (width - rim) / aspect + rim)
                    let extraHeight = max(0, stage.size.height - size.height)
                    let topInset = min(extraHeight / 2, aspect == 1 ? 7 : 28)
                    reels(size).frame(width: size.width, height: size.height)
                        .padding(.top, topInset)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                footer().frame(height: 61)
            }
            .padding(.horizontal, compact ? 14 : 16)
            .padding(.top, 5)
            .padding(.bottom, 6)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct SolarSlotBar<Balance: View>: View {
    let locked: Bool
    let back: () -> Void
    let rules: () -> Void
    @ViewBuilder var balance: () -> Balance

    var body: some View {
        HStack(spacing: 10) {
            SolarCabinetKey(title: "action.back", glyph: "BackGlyph", action: back)
                .accessibilityIdentifier("slot_back")
            Spacer(minLength: 0)
            balance()
            Spacer(minLength: 0)
            Button(action: rules) { Image(systemName: "info") }
                .buttonStyle(SolarCabinetIconStyle())
                .accessibilityLabel(Text("slot.rules"))
                .accessibilityIdentifier("slot_rules")
        }
        .disabled(locked)
    }
}

struct SolarRulesCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(SolarDeco.ivory)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("action.back"))
    }
}

struct SolarSlotStake: View {
    let amount: Int
    let canLower: Bool
    let canRaise: Bool
    var title: LocalizedStringKey = "slot.stake"
    let change: (Int) -> Void

    var body: some View {
        HStack {
            Button { change(-1) } label: { Image(systemName: "minus") }
                .buttonStyle(SolarCabinetIconStyle())
                .disabled(!canLower)
                .accessibilityLabel(Text("slot.lower"))
                .accessibilityIdentifier("slot_stake_down")
            Spacer(minLength: 5)
            VStack(spacing: 1) {
                Text(title)
                    .font(.system(size: 10, weight: .bold)).tracking(1.8)
                    .foregroundStyle(SolarDeco.muted)
                Text(amount, format: .number)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit().contentTransition(.numericText())
                    .accessibilityIdentifier("slot_stake")
            }
            Spacer(minLength: 5)
            Button { change(1) } label: { Image(systemName: "plus") }
                .buttonStyle(SolarCabinetIconStyle())
                .disabled(!canRaise)
                .accessibilityLabel(Text("slot.raise"))
                .accessibilityIdentifier("slot_stake_up")
        }
        .padding(.horizontal, 13)
    }
}

struct SolarSlotReelTarget: View {
    var enabled: Bool
    var highlighted: Bool
    var tint: Color
    var label: LocalizedStringKey = "slot.spin"
    var identifier = "slot_reels"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Color.clear.contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .overlay {
            if highlighted {
                SolarGlint(outline: RoundedRectangle(cornerRadius: 17), tint: tint)
            }
        }
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier(identifier)
    }
}

struct SolarSlotKey<Icon: View>: View {
    let title: LocalizedStringKey
    var active = false
    var enabled = true
    let action: () -> Void
    @ViewBuilder var icon: () -> Icon

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                icon().frame(width: 24, height: 24)
                    .foregroundStyle(active ? SolarDeco.bright : SolarDeco.gold)
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .lineLimit(1).minimumScaleFactor(0.70)
                    .foregroundStyle(active ? SolarDeco.bright : SolarDeco.ivory)
            }
            .frame(height: 51)
        }
        .buttonStyle(SolarGoldButtonStyle(prominent: false))
        .overlay { if active { SolarBrassFrame(cut: 12) } }
        .disabled(!enabled)
        .frame(width: 78)
    }
}

struct SolarSlotResult<Value: View>: View {
    var title: LocalizedStringKey = "slot.lastWin"
    var multiplier = 1
    @ViewBuilder var value: () -> Value

    var body: some View {
        VStack(spacing: 3) {
            Text(title).font(.system(size: 10, weight: .bold)).tracking(1.25)
                .foregroundStyle(SolarDeco.muted)
                .lineLimit(1).minimumScaleFactor(0.7)
            HStack(spacing: 4) {
                value()
                if multiplier > 1 {
                    Text("×\(multiplier)").font(.caption.weight(.heavy))
                        .foregroundStyle(SolarDeco.bright)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("slot_last_win")
    }
}
