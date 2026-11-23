import SwiftUI

struct SolarRulesSheet: View {
    let game: SolarCabinet
    let stake: Int

    var body: some View {
        SolarGameRulesLayout(title: game.title) {
            SolarRuleCopy(LocalizedStringKey("rules.cabinet." + game.rawValue))
            Text("rules.payouts").font(SolarDeco.solarTitle(21))
            if game == .nougat {
                SolarRuleCopy("rules.cabinet.payouts.comet")
            } else {
                SolarRuleCopy("rules.cabinet.payouts.lines")
                if game != .forge { SolarRuleCopy("rules.cabinet.payouts.longerLines") }
            }
            VStack(spacing: 8) {
                ForEach(0..<(game == .nougat ? 7 : 6), id: \.self) { face in
                    SolarRuleRow(value: payText(face)) {
                        HStack(spacing: 10) {
                            SolarArt("\(game.solarArtPrefix)_\(face)").frame(width: 40, height: 42)
                            Text(LocalizedStringKey(game.symbols[face]))
                        }
                    }
                }
            }
            if game == .forge {
                Text("rules.jackpots \(game.bonusTitle)").font(SolarDeco.solarTitle(21))
                ForEach(SolarLockJackpot.allCases, id: \.self) { tier in
                    SolarRuleRow(value: (stake * tier.factor).formatted(.number)) {
                        Text(tier.rawValue)
                    }
                }
            }
            if game == .nougat {
                HStack(spacing: 12) {
                    SolarArt("aurum-confection_8").frame(width: 46, height: 46)
                    SolarRuleCopy("rules.cabinet.charges")
                }
            }
        }
    }

    @Environment(\.locale) private var locale

    private func payText(_ face: Int) -> String {
        if game == .nougat {
            let factors = [4.8, 3.6, 2.6, 1.9, 1.4, 1.0, 0.65]
            return factors[face].formatted(.number.precision(.fractionLength(2)).locale(locale)) + "×"
        }
        let values = game == .forge ? [90, 45, 26, 18, 14, 10] : [60, 42, 30, 22, 16, 12]
        let coins = 100 * values[face] / (game == .forge ? 5 : 15)
        return coins.formatted(.number.locale(locale))
    }
}

struct SolarGameRulesLayout<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 7) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("action.lesson")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SolarDeco.muted)
                    Text(title)
                        .font(SolarDeco.solarTitle(28))
                        .lineLimit(1).minimumScaleFactor(0.65)
                }
                Spacer(minLength: 6)
                SolarRulesCloseButton { dismiss() }
                    .accessibilityIdentifier("game_rules_close")
            }
            .padding(.top, 10)
            .padding(.horizontal, 20)
            Rectangle().fill(SolarDeco.metal).frame(height: 1).padding(.horizontal, 20)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    content()
                    SolarRuleCopy("rules.virtualCoins")
                        .font(.caption)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 11)
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .scrollIndicators(.hidden)
        }
        .background { SolarCabinetBackground() }
        .foregroundStyle(SolarDeco.ivory)
        .preferredColorScheme(.dark)
    }
}

struct SolarRuleCopy: View {
    let copy: LocalizedStringKey

    init(_ copy: LocalizedStringKey) { self.copy = copy }

    var body: some View {
        Text(copy)
            .foregroundStyle(SolarDeco.muted)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct SolarRuleRow<Label: View>: View {
    let value: String
    @ViewBuilder var label: () -> Label

    var body: some View {
        HStack(spacing: 10) {
            label().font(.subheadline.weight(.medium))
            Spacer(minLength: 0)
            Text(value).font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(SolarDeco.bright)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(minHeight: 39)
        .background { SolarCutCorner(cut: 7).fill(SolarDeco.panel) }
        .overlay { SolarCutCorner(cut: 7).stroke(SolarDeco.brass).allowsHitTesting(false) }
    }
}
