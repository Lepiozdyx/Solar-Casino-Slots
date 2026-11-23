import SwiftUI

struct SolarEmpireHome: View {
    @ObservedObject var bank: SolarCasinoBank
    let enter: () -> Void
    let lesson: () -> Void
    let settings: () -> Void

    var body: some View {
        GeometryReader { bounds in
            VStack(spacing: 10) {
                ScrollView {
                    VStack(spacing: 13) {
                        hero(height: min(max(bounds.size.height * 0.54, 155), 470))
                        if bank.canPlay {
                            TimelineView(.periodic(from: .now, by: 1)) { time in
                                SolarEmpireSummary(bank: bank, now: time.date)
                            }
                        } else {
                            SolarCasinoStorageNotice(bank: bank)
                        }

                        Button("empire.enter", action: enter)
                            .buttonStyle(SolarGoldButtonStyle())
                            .disabled(!bank.canPlay)
                            .accessibilityIdentifier("estate_open")
                    }
                    .padding(.vertical, 1)
                }
                .scrollIndicators(.hidden)

                HStack(spacing: 10) {
                    utility("action.lesson", glyph: "HelpGlyph", action: lesson)
                    utility("action.settings", glyph: "SettingsGlyph", action: settings)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .frame(maxWidth: 464)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func hero(height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            SolarDeco.socket
            GeometryReader { bounds in
                if let artwork = SolarImageArchive.shared.solarImage("solar-estate-hero") {
                    Image(uiImage: artwork).resizable().scaledToFill()
                        .frame(width: bounds.size.width, height: bounds.size.height)
                        .clipped()
                }
            }
            LinearGradient(stops: [
                .init(color: .clear, location: 0.32),
                .init(color: SolarDeco.enamel.opacity(0.62), location: 0.72),
                .init(color: SolarDeco.enamel, location: 1)
            ], startPoint: .top, endPoint: .bottom)

            VStack(spacing: 5) {
                Text("Solar Casino Slots")
                    .font(SolarDeco.solarTitle(34))
                    .lineLimit(1).minimumScaleFactor(0.68)
                    .shadow(color: .black.opacity(0.75), radius: 7, y: 2)
                Rectangle().fill(SolarDeco.metal).frame(width: 76, height: 1)
            }
            .padding(.horizontal, 15)
            .padding(.bottom, 18)
        }
        .frame(height: height)
        .clipShape(SolarCutCorner(cut: 19))
        .overlay { SolarBrassFrame(cut: 19) }
    }

    private func utility(_ title: LocalizedStringKey, glyph: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                SolarCabinetGlyph(name: glyph).frame(width: 17, height: 17)
                Text(title).font(.footnote.weight(.semibold)).lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background { SolarCutCorner(cut: 8).fill(SolarDeco.panel) }
            .overlay { SolarBrassFrame(cut: 8).opacity(0.72) }
            .contentShape(SolarCutCorner(cut: 8))
        }
        .buttonStyle(.plain)
    }
}

private struct SolarEmpireSummary: View {
    @ObservedObject var bank: SolarCasinoBank
    let now: Date

    var body: some View {
        let ready = bank.estate.readyIncome(at: now)
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                metric("empire.treasury") { SolarChipAmount(value: bank.balance) }
                divider
                metric("empire.properties") {
                    Text(verbatim: "\(bank.estate.ownedCount) / \(bank.estate.lots.count)")
                        .monospacedDigit()
                }
            }
            Rectangle().fill(SolarDeco.brass.opacity(0.45)).frame(height: 1)
            HStack(spacing: 10) {
                metric("empire.dailyIncome") { SolarChipAmount(value: bank.estate.dailyIncome) }
                divider
                if ready > 0 {
                    metric("empire.readyIncome") {
                        SolarChipAmount(value: ready).foregroundStyle(SolarDeco.bright)
                    }
                    .accessibilityIdentifier("empire_income_ready")
                } else if let due = bank.estate.nextPayout {
                    metric("estate.nextPayout") { SolarPayoutCountdown(due: due, now: now) }
                        .accessibilityIdentifier("empire_next_payout")
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background { SolarCutCorner(cut: 12).fill(SolarDeco.socket) }
        .overlay { SolarBrassFrame(cut: 12).opacity(0.86) }
    }

    private var divider: some View {
        Rectangle().fill(SolarDeco.brass.opacity(0.45)).frame(width: 1, height: 34)
    }

    private func metric<Value: View>(_ label: LocalizedStringKey, @ViewBuilder value: () -> Value) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(SolarDeco.muted)
            value().font(.headline).lineLimit(1).minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SolarPayoutCountdown: View {
    let due: Date
    let now: Date

    var body: some View {
        let seconds = max(0, due.timeIntervalSince(now).rounded(.up))
        Text(Duration.seconds(seconds).formatted(.time(pattern: .hourMinuteSecond)))
            .monospacedDigit()
    }
}

struct SolarEmpireTip: View {
    let text: LocalizedStringKey
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(SolarDeco.gold)
            Text(text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background { SolarCutCorner(cut: 10).fill(SolarDeco.bronze) }
        .overlay { SolarBrassFrame(cut: 10).opacity(0.82) }
    }
}
