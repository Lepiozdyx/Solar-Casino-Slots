import SwiftUI

struct SolarContentView: View {
    private enum Destination: Hashable { case empire, gameHall, lesson, settings }

    @StateObject private var casino = SolarCasinoLibrary()
    @State private var path: [Destination] = []
    @State private var selectedGame: SolarCasinoGame?

    var body: some View {
        NavigationStack(path: $path) {
            cabinetScreen {
                SolarEmpireHome(bank: casino.bank,
                                enter: { path.append(.empire) },
                                lesson: { path.append(.lesson) },
                                settings: { path.append(.settings) })
            }
            .navigationDestination(for: Destination.self) { destination in
                cabinetScreen { destinationView(destination) }
            }
        }
        .foregroundStyle(SolarDeco.ivory)
        .preferredColorScheme(.dark)
        .fullScreenCover(item: $selectedGame) { game in
            SolarCasinoGameHost(library: casino, game: game)
        }
    }

    private func cabinetScreen<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            SolarCabinetBackground()
            content()
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder private func destinationView(_ destination: Destination) -> some View {
        switch destination {
        case .empire:
            SolarEmpireScreen(bank: casino.bank, back: pop,
                              gameHall: { path.append(.gameHall) })
        case .gameHall:
            SolarGameHall(library: casino, back: pop) { selectedGame = $0 }
        case .lesson:
            SolarLessonScreen(back: pop)
        case .settings:
            settings
        }
    }

    private func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    private var settings: some View {
        ZStack {
            VStack(spacing: 18) {
                SolarScreenHeading(title: "action.settings", back: pop)

                VStack(spacing: 12) {
                    settingsToggle("settings.sound", value: Binding(
                        get: { casino.thunder.member.soundtrack },
                        set: { casino.solarConfigure(sound: $0, haptics: casino.thunder.member.vibration) }
                    ))
                    settingsToggle("settings.haptics", value: Binding(
                        get: { casino.thunder.member.vibration },
                        set: { casino.solarConfigure(sound: casino.thunder.member.soundtrack, haptics: $0) }
                    ))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 8)
            .frame(maxWidth: 460)
            .disabled(!casino.bank.canPlay)

            if !casino.bank.canPlay {
                SolarCasinoStorageNotice(bank: casino.bank, close: pop)
            }
        }
    }

    private func settingsToggle(_ title: LocalizedStringKey, value: Binding<Bool>) -> some View {
        Toggle(title, isOn: value)
            .font(.headline)
            .tint(SolarDeco.brass)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background { SolarCutCorner().fill(SolarDeco.panel) }
            .overlay { SolarBrassFrame(cut: 12) }
    }
}

struct SolarChipAmount: View {
    let value: Int

    var body: some View {
        HStack(spacing: 5) {
            SolarCabinetGlyph(name: "ChipGlyph").frame(width: 17, height: 17)
            Text(value, format: .number)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .lineLimit(1)
        .minimumScaleFactor(0.65)
    }
}

struct SolarCabinetKey: View {
    let title: LocalizedStringKey
    let glyph: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SolarCabinetGlyph(name: glyph).frame(width: 19, height: 19)
        }
        .accessibilityLabel(Text(title))
        .buttonStyle(SolarCabinetIconStyle())
    }
}

struct SolarScreenHeading: View {
    let title: LocalizedStringKey
    var balance: Int? = nil
    let back: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            SolarCabinetKey(title: "action.back", glyph: "BackGlyph", action: back)
            Text(title)
                .font(SolarDeco.solarTitle(28))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .layoutPriority(1)
            Spacer(minLength: 0)
            if let balance {
                SolarChipAmount(value: balance).font(.subheadline.weight(.semibold))
                    .frame(minWidth: 72, maxWidth: 103, alignment: .trailing)
            }
        }
        .frame(height: 44)
    }
}

private struct SolarLessonScreen: View {
    let back: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            SolarScreenHeading(title: "action.lesson", back: back)

            ScrollView {
                VStack(spacing: 12) {
                    lesson("estate.lesson.income.title", "empire.help.income", "clock.fill")
                    lesson("empire.help.box.title", "empire.help.box.body", "shippingbox.fill")
                    lesson("empire.gameHall", "empire.help.hall", "suit.club.fill")
                    lesson("estate.lesson.spin.title", "estate.lesson.spin.body", "hand.tap.fill")
                }
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .frame(maxWidth: 460)
    }

    private func lesson(_ title: LocalizedStringKey, _ message: LocalizedStringKey, _ symbol: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(SolarDeco.gold)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(SolarDeco.solarTitle(20))
                Text(message).font(.subheadline).foregroundStyle(SolarDeco.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { SolarCutCorner().fill(SolarDeco.panel) }
        .overlay { SolarBrassFrame(cut: 12) }
    }
}
